// VELVET · plugin/velvetzoom — the desktop zoom-out.
//
// Hyprland's own zoom (cursor:zoom_factor) cannot go below 1.0. This plugin
// renders the windows of the workspace through a scale-about-a-pivot
// transform between "wallpaper and layers" and "top layers", so every window
// shrinks as a texture — content included, live — while the wallpaper and the
// bar stay where they are. That is the zoom-out of the clip it copies.
//
// Control (hyprctl):
//   hyprctl velvetzoom set  <z> <px> <py>   glide to z around the point
//   hyprctl velvetzoom snap <z> <px> <py>   jump
//   hyprctl velvetzoom off                  glide back to 1:1 and switch off
//   hyprctl velvetzoom status
// px/py are global layout coordinates (what `hyprctl cursorpos` prints).
//
// Three things make a window that is OFF screen at 1:1 appear when the zoom
// brings it in, because Hyprland culls by the unscaled box:
//   · shouldRenderWindow(window, monitor) is re-answered for the scaled box,
//   · CSurfacePassElement::boundingBox() / opaqueRegion() answer for the scaled
//     box — through the vtable, because the compiler inlines direct calls.

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/pointer/PointerManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/devices/IPointer.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/RendererHintsPassElement.hpp>
#include <hyprland/src/render/pass/SurfacePassElement.hpp>
#include <hyprland/src/render/pass/BorderPassElement.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopTimer.hpp>

#include <dlfcn.h>
#include <sys/mman.h>
#include <unistd.h>

#include <linux/input-event-codes.h>

#include <chrono>
#include <cmath>
#include <format>
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include <unordered_set>
#include <vector>

inline HANDLE PHANDLE = nullptr;

namespace {
    using Clock = std::chrono::steady_clock;

    struct SZoom {
        bool              active = false;
        float             target = 1.F;
        float             cur    = 1.F;
        double            lx     = 0;      // ln(cur): the spring runs in log space, so every halving takes as long
        double            vel    = 0;      // d ln(z) / dt
        Vector2D          pivot  = {0, 0}; // global layout coordinates
        Clock::time_point last   = Clock::now();
    } g_zoom;

    // A critically damped spring instead of a plain exponential: it starts
    // gently, never overshoots and lands softly — the exponential jumped to
    // full speed on every notch, which read as a jolt. OMEGA ≈ 1.6 / response.
    constexpr double OMEGA    = 15.0;
    constexpr float  STEP     = 1.28F; // one wheel notch
    constexpr float  MIN_ZOOM = 0.1F;
    // Blur and shadows go below this zoom and come back above it, so their
    // switch is never seen at 1:1 — it happens while everything is moving.
    constexpr float LIGHT_BELOW = 0.93F;

    bool g_cullOn = true, g_boxOn = true, g_opaqueOn = true; // debug switches
    bool g_wheelOn = true;                                   // take SUPER+ALT+wheel ourselves
    bool g_lightOn = true;                                   // no blur, no shadows while zoomed

    bool light() {
        return g_lightOn && g_zoom.active && g_zoom.cur < LIGHT_BELOW;
    }

    void setCur(float z) {
        g_zoom.cur = z;
        g_zoom.lx  = std::log((double)z);
        g_zoom.vel = 0;
    }

    // ── windows that belong to the desktop, not to the canvas ───────────────
    // Velvet's fixed modules (cava along an edge, vitals …) sit where the
    // widgets sit and stay their size: the shell lists their classes, one per
    // line, in $XDG_RUNTIME_DIR/velvet-fixed. They are drawn without the zoom.
    std::unordered_set<std::string> g_fixed;
    time_t                          g_fixedStamp = -1;
    Clock::time_point               g_fixedCheck = Clock::now() - std::chrono::seconds(10);

    void readFixed() {
        const auto now = Clock::now();
        if (now - g_fixedCheck < std::chrono::milliseconds(700))
            return;
        g_fixedCheck     = now;
        const char* run  = getenv("XDG_RUNTIME_DIR");
        const std::string path = std::string(run ? run : "/tmp") + "/velvet-fixed";
        struct stat st{};
        if (stat(path.c_str(), &st) != 0) {
            g_fixed.clear();
            g_fixedStamp = -1;
            return;
        }
        if (st.st_mtime == g_fixedStamp)
            return;
        g_fixedStamp = st.st_mtime;
        g_fixed.clear();
        std::ifstream in(path);
        std::string   line;
        while (std::getline(in, line))
            if (!line.empty())
                g_fixed.insert(line);
    }

    bool isFixed(const PHLWINDOW& w) {
        return w && !g_fixed.empty() && g_fixed.contains(w->metadata().appID());
    }

    // frame statistics for `status`
    size_t   g_frames = 0;
    double   g_frameMs = 0;
    Clock::time_point g_lastFrame = Clock::now();

    CHyprSignalListener        g_preListener;
    CHyprSignalListener        g_stageListener;
    CHyprSignalListener        g_buttonListener;
    CHyprSignalListener        g_axisListener;
    CHyprSignalListener        g_workspaceListener;
    SP<IPC::Socket1::SCommand> g_command;

    void wake();

    bool settled() {
        return std::abs(std::log((double)g_zoom.target) - g_zoom.lx) < 0.0015 && std::abs(g_zoom.vel) < 0.02;
    }

    // ── the glide ───────────────────────────────────────────────────────────

    void step() {
        const auto now = Clock::now();
        double     dt  = std::chrono::duration<double>(now - g_zoom.last).count();
        g_zoom.last    = now;
        if (!g_zoom.active || dt <= 0.0)
            return;
        // a long gap is the glide having rested: never integrate a jump
        dt = std::min(dt, 1.0 / 30.0);
        const double tx = std::log((double)g_zoom.target);
        // two half steps keep the spring smooth at 60 Hz and at 240 Hz alike
        for (int i = 0; i < 2; i++) {
            const double h = dt / 2.0;
            const double a = OMEGA * OMEGA * (tx - g_zoom.lx) - 2.0 * OMEGA * g_zoom.vel;
            g_zoom.vel += a * h;
            g_zoom.lx += g_zoom.vel * h;
        }
        if (settled())
            setCur(g_zoom.target);
        else
            g_zoom.cur = (float)std::exp(g_zoom.lx);
        if (settled() && g_zoom.target >= 0.9995F) {
            setCur(1.F);
            g_zoom.active = false;
        }
    }

    // debugging: the glide, frame by frame (`hyprctl velvetzoom trace`)
    std::vector<std::pair<double, float>> g_trace;
    Clock::time_point                     g_traceT0 = Clock::now();

    void onPre(PHLMONITOR mon) {
        if (!mon)
            return;
        if (g_zoom.active) {
            const auto now = Clock::now();
            const double dt = std::chrono::duration<double, std::milli>(now - g_lastFrame).count();
            g_lastFrame     = now;
            if (dt < 250) { // a gap is the glide having rested, not a slow frame
                g_frameMs += dt;
                g_frames++;
            }
        }
        step();
        if (g_zoom.active && g_trace.size() < 400)
            g_trace.push_back({std::chrono::duration<double, std::milli>(Clock::now() - g_traceT0).count(), g_zoom.cur});
        if (g_zoom.active)
            readFixed();
        if (g_zoom.active) {
            g_pHyprRenderer->damageMonitor(mon);
            if (!settled())
                mon->scheduleFrame();
        }
    }

    // ── the transform around the windows ────────────────────────────────────

    void onStage(eRenderStage stage) {
        if (!g_zoom.active || (stage != RENDER_PRE_WINDOWS && stage != RENDER_POST_WINDOWS))
            return;

        auto mon = g_pHyprRenderer->m_renderData.pMonitor.lock();
        if (!mon)
            return;

        CRendererHintsPassElement::SData data;
        Render::SRenderModifData         modif;
        if (stage == RENDER_PRE_WINDOWS) {
            const Vector2D local = (g_zoom.pivot - mon->m_position) * mon->m_scale;
            modif.modifs.push_back({Render::SRenderModifData::RMOD_TYPE_SCALE, g_zoom.cur});
            modif.modifs.push_back({Render::SRenderModifData::RMOD_TYPE_TRANSLATE, local * (1.F - g_zoom.cur)});
        }
        data.renderModif = modif; // an empty list at the end puts the layers back to 1:1
        g_pHyprRenderer->addPassElement(makeUnique<CRendererHintsPassElement>(data));
    }

    // ── windows that are off screen at 1:1 ──────────────────────────────────

    // A box in global layout coordinates, after the zoom.
    CBox zoomed(CBox box) {
        const double z = g_zoom.cur;
        return {g_zoom.pivot.x + (box.x - g_zoom.pivot.x) * z, g_zoom.pivot.y + (box.y - g_zoom.pivot.y) * z, box.w * z, box.h * z};
    }

    using ShouldRenderFn = bool (*)(void*, PHLWINDOW, PHLMONITOR);
    CFunctionHook* g_cullHook = nullptr;

    bool visibleZoomed(PHLWINDOW w, PHLMONITOR mon) {
        if (!w || !mon || !w->mapped() || w->isHidden() || !w->m_workspace || w->m_workspace != mon->m_activeWorkspace)
            return false;
        const CBox monitorBox = {mon->m_position.x, mon->m_position.y, mon->m_size.x, mon->m_size.y};
        return !zoomed(w->getFullWindowBoundingBox()).intersection(monitorBox).empty();
    }

    bool hkShouldRenderWindow(void* self, PHLWINDOW w, PHLMONITOR mon) {
        const bool seen = ((ShouldRenderFn)g_cullHook->m_original)(self, w, mon);
        if (seen || !g_zoom.active || !g_cullOn)
            return seen;
        return visibleZoomed(w, mon);
    }

    // The render pass drops an element whose box misses the damage. For a
    // window's surface that box is the unscaled one. The two methods below
    // answer for the zoomed box (monitor-local logical coordinates).
    using BoxFn    = std::optional<CBox> (*)(CSurfacePassElement*);
    using RegionFn = CRegion (*)(CSurfacePassElement*);
    BoxFn    g_boxOrig    = nullptr;
    RegionFn g_opaqueOrig = nullptr;
    void**   g_boxSlot    = nullptr;
    void**   g_opaqueSlot = nullptr;

    bool zoomsWindow(CSurfacePassElement* e) {
        return g_zoom.active && e && e->m_data.pWindow && !e->m_data.pLS && !isFixed(e->m_data.pWindow);
    }

    bool fixedSurface(CSurfacePassElement* e) {
        return g_zoom.active && e && e->m_data.pWindow && !e->m_data.pLS && isFixed(e->m_data.pWindow);
    }

    Vector2D pivotLocal(CSurfacePassElement* e) {
        const auto mon = e->m_data.pMonitor.lock();
        return mon ? g_zoom.pivot - mon->m_position : g_zoom.pivot;
    }

    std::optional<CBox> hkBoundingBox(CSurfacePassElement* e) {
        auto box = g_boxOrig(e);
        if (!g_boxOn || !box || !zoomsWindow(e))
            return box;
        const Vector2D p = pivotLocal(e);
        const double   z = g_zoom.cur;
        return CBox{p.x + (box->x - p.x) * z, p.y + (box->y - p.y) * z, box->w * z, box->h * z};
    }

    CRegion hkOpaqueRegion(CSurfacePassElement* e) {
        CRegion rg = g_opaqueOrig(e);
        if (!g_opaqueOn || !zoomsWindow(e))
            return rg;
        const Vector2D p = pivotLocal(e);
        rg.scale(g_zoom.cur);
        rg.translate(p * (1.0 - g_zoom.cur));
        return rg;
    }


    // While the overview is up the windows cast no shadow and take no blur:
    // both would be drawn for the wrong place, cost the most per frame, and
    // at this size nobody sees them.
    using NeedsFn = bool (*)(CSurfacePassElement*);
    NeedsFn g_liveBlurOrig = nullptr;
    NeedsFn g_preBlurOrig  = nullptr;
    void**  g_liveBlurSlot = nullptr;
    void**  g_preBlurSlot  = nullptr;

    bool hkNeedsLiveBlur(CSurfacePassElement* e) {
        if (light() && e && e->m_data.pWindow && !isFixed(e->m_data.pWindow))
            return false;
        return g_liveBlurOrig(e);
    }
    bool hkNeedsPreBlur(CSurfacePassElement* e) {
        if (light() && e && e->m_data.pWindow && !isFixed(e->m_data.pWindow))
            return false;
        return g_preBlurOrig(e);
    }

    using ShadowDrawFn = void (*)(void*, PHLMONITOR, const float&);
    CFunctionHook* g_shadowHook = nullptr;
    void hkShadowDraw(void* self, PHLMONITOR mon, const float& a) {
        if (light())
            return;
        ((ShadowDrawFn)g_shadowHook->m_original)(self, mon, a);
    }

    // drawSurface() intersects the damage it is handed with the UNSCALED window
    // box and only then pushes the result through the zoom. So the damage has
    // to arrive in unscaled space: the part of the layout that lands on the
    // monitor once it is zoomed. Without this a window that is off screen at
    // 1:1 — or only half on — is painted as nothing, or as a sliver.
    using DrawSurfaceFn = void (*)(void*, WP<CSurfacePassElement>, const CRegion&);
    CFunctionHook* g_drawSurfaceHook = nullptr;

    void hkDrawSurface(void* self, WP<CSurfacePassElement> el, const CRegion& damage) {
        auto* e = el.get();
        if (fixedSurface(e)) {
            // a fixed module: drawn where it is, at its size — the zoom is lifted for it alone
            auto&      rd    = g_pHyprRenderer->m_renderData;
            const auto saved = rd.renderModif;
            rd.renderModif.modifs.clear();
            ((DrawSurfaceFn)g_drawSurfaceHook->m_original)(self, el, damage);
            rd.renderModif = saved;
            return;
        }
        if (!zoomsWindow(e)) {
            ((DrawSurfaceFn)g_drawSurfaceHook->m_original)(self, el, damage);
            return;
        }
        const auto     mon = e->m_data.pMonitor.lock();
        const Vector2D p   = pivotLocal(e) * (mon ? mon->m_scale : 1.F); // physical pixels, like the damage
        const auto     ext = const_cast<CRegion&>(damage).getExtents();
        const double   z   = g_zoom.cur;
        const CRegion  unzoomed(CBox{p.x + (ext.x - p.x) / z, p.y + (ext.y - p.y) / z, ext.w / z, ext.h / z});
        // the renderer also clips against its own frame damage while drawing
        const bool    hadBlur   = e->m_data.blur;
        if (light())
            e->m_data.blur = false; // a blurred backdrop of the wrong place costs a lot and shows nothing
        auto&         rd        = g_pHyprRenderer->m_renderData;
        const CRegion savedDmg  = rd.damage;
        const CRegion savedFin  = rd.finalDamage;
        rd.damage               = unzoomed;
        rd.finalDamage          = unzoomed;
        ((DrawSurfaceFn)g_drawSurfaceHook->m_original)(self, el, unzoomed);
        rd.damage      = savedDmg;
        rd.finalDamage = savedFin;
        e->m_data.blur = hadBlur;
    }

    // A fixed module's border is drawn where the module is, too.
    using DrawBorderFn = void (*)(void*, WP<CBorderPassElement>, const CRegion&);
    CFunctionHook* g_drawBorderHook = nullptr;
    size_t         g_borderCalls = 0, g_borderWin = 0, g_borderFixed = 0;

    void hkDrawBorder(void* self, WP<CBorderPassElement> el, const CRegion& damage) {
        auto* e = el.get();
        g_borderCalls++;
        if (e && e->m_data.window.lock())
            g_borderWin++;
        if (e && isFixed(e->m_data.window.lock()))
            g_borderFixed++;
        if (!g_zoom.active || !e || !isFixed(e->m_data.window.lock())) {
            ((DrawBorderFn)g_drawBorderHook->m_original)(self, el, damage);
            return;
        }
        auto&      rd    = g_pHyprRenderer->m_renderData;
        const auto saved = rd.renderModif;
        rd.renderModif.modifs.clear();
        ((DrawBorderFn)g_drawBorderHook->m_original)(self, el, damage);
        rd.renderModif = saved;
    }

    // ── patching ────────────────────────────────────────────────────────────

    CFunctionHook* hookByName(const std::string& fn, const std::string& mustContain, void* destination) {
        for (auto& f : HyprlandAPI::findFunctionsByName(PHANDLE, fn)) {
            if (f.demangled.find(mustContain) == std::string::npos)
                continue;
            auto* h = HyprlandAPI::createFunctionHook(PHANDLE, f.address, destination);
            if (h && h->hook())
                return h;
        }
        return nullptr;
    }

    void* addressOf(const std::string& fn, const std::string& mustContain) {
        for (auto& f : HyprlandAPI::findFunctionsByName(PHANDLE, fn))
            if (f.demangled.find(mustContain) != std::string::npos)
                return f.address;
        return nullptr;
    }

    // Point the vtable entry that holds `original` at `replacement`.
    void** patchVtable(const char* vtableSymbol, void* original, void* replacement) {
        auto** vt = (void**)dlsym(RTLD_DEFAULT, vtableSymbol);
        if (!vt || !original)
            return nullptr;
        for (int i = 2; i < 64; i++) {
            if (vt[i] != original)
                continue;
            const long page = sysconf(_SC_PAGESIZE);
            auto       base = (void*)((uintptr_t)&vt[i] & ~(uintptr_t)(page - 1));
            if (mprotect(base, page, PROT_READ | PROT_WRITE) != 0)
                return nullptr;
            vt[i] = replacement;
            mprotect(base, page, PROT_READ);
            return &vt[i];
        }
        return nullptr;
    }

    void unpatch(void**& slot, void* original) {
        if (!slot)
            return;
        const long page = sysconf(_SC_PAGESIZE);
        auto       base = (void*)((uintptr_t)slot & ~(uintptr_t)(page - 1));
        if (mprotect(base, page, PROT_READ | PROT_WRITE) == 0) {
            *slot = original;
            mprotect(base, page, PROT_READ);
        }
        slot = nullptr;
    }



    // The window drawn under a point, topmost first, and focus it.
    PHLWINDOW pickAt(const Vector2D& at) {
        const auto& ws = Desktop::windowState()->windows();
        for (auto it = ws.rbegin(); it != ws.rend(); ++it) {
            const auto& w = *it;
            if (!w || !w->mapped() || w->isHidden() || !w->m_workspace || !w->m_workspace->isVisible())
                continue;
            const CBox box = w->getFullWindowBoundingBox();
            if ((isFixed(w) ? box : zoomed(box)).containsPoint(at)) {
                Desktop::focusState()->fullWindowFocus(w, Desktop::FOCUS_REASON_CLICK);
                return w;
            }
        }
        return nullptr;
    }

    // ── a click while zoomed out ────────────────────────────────────────────
    // The pointer still hits the windows where they are at 1:1, not where they
    // are drawn. So a click is swallowed, handed to the window UNDER the zoomed
    // pointer (it gets the focus), and the desktop glides back to 1:1.
    void onButton(IPointer::SButtonEvent e, Event::SCallbackInfo& info) {
        if (!g_zoom.active || g_zoom.target > 0.999F)
            return;
        info.cancelled = true;
        if (e.state != WL_POINTER_BUTTON_STATE_PRESSED)
            return;

        if (e.button == BTN_LEFT && Pointer::mgr())
            pickAt(Pointer::mgr()->position());
        g_zoom.target = 1.F;
        wake();
    }

    // ── SUPER+ALT + wheel, taken in the compositor ──────────────────────────
    //  The key bind used to start a script per notch: ~100 ms of process
    //  start-up, irregular — the zoom moved in lumps. Here every notch lands
    //  the moment it happens and just moves the target; the glide in onPre
    //  does the rest, so quick notches run together. Magnifying (z >= 1) is
    //  Hyprland's own cursor zoom and stays with the script: we only step
    //  aside when the screen is already magnified, or the wheel turns up.
    float cursorZoom() {
        const std::string out = HyprlandAPI::invokeHyprctlCommand("getoption", "cursor:zoom_factor");
        const auto        at  = out.find("float:");
        if (at == std::string::npos)
            return 1.F;
        try {
            return std::stof(out.substr(at + 6));
        } catch (...) {
            return 1.F;
        }
    }

    Vector2D anchorNow() {
        const Vector2D at = Pointer::mgr() ? Pointer::mgr()->position() : Vector2D{0, 0};
        PHLMONITOR     m;
        for (auto& mon : State::monitorState()->monitors())
            if (CBox{mon->m_position.x, mon->m_position.y, mon->m_size.x, mon->m_size.y}.containsPoint(at)) {
                m = mon;
                break;
            }
        if (!m && !State::monitorState()->monitors().empty())
            m = State::monitorState()->monitors().front();
        if (!m)
            return at;
        // inside the central half, so the shrunken desktop stays on screen
        return {std::clamp(at.x, m->m_position.x + m->m_size.x * 0.25, m->m_position.x + m->m_size.x * 0.75),
                std::clamp(at.y, m->m_position.y + m->m_size.y * 0.25, m->m_position.y + m->m_size.y * 0.75)};
    }

    int       g_burst = 0;
    Clock::time_point g_lastNotch = Clock::now() - std::chrono::seconds(10);

    // notches > 0 shrink (wheel down), < 0 grow. Returns whether the plugin took it.
    bool wheelNotches(double notches, bool dryRun = false) {
        if (notches == 0)
            return false;
        // no desktop zoom under the window map (it writes this file while it is up)
        if (access("/tmp/velvet-map-open", F_OK) == 0)
            return false;
        const bool out = notches > 0;
        if (!g_zoom.active || g_zoom.target > 0.999F) {
            if (!out)
                return false; // magnifying belongs to Hyprland's own zoom
            if (cursorZoom() > 1.005F)
                return false; // shrink the magnified screen first
            if (dryRun)
                return true;
            setCur(1.F);
            g_zoom.target = 1.F;
            g_zoom.active = true;
            g_zoom.pivot  = anchorNow();
            g_zoom.last   = Clock::now();
            g_fixedCheck  = Clock::now() - std::chrono::seconds(10);
            readFixed();
        } else if (dryRun) {
            return true;
        }

        const auto now = Clock::now();
        g_burst         = std::chrono::duration<double>(now - g_lastNotch).count() < 0.14 ? std::min(8, g_burst + 1) : 0;
        g_lastNotch     = now;
        const double accel = 1.0 + 0.9 * std::min(1.0, g_burst / 5.0);
        float        z     = g_zoom.target * (float)std::pow((double)STEP, -notches * accel);
        z                  = std::clamp(z, MIN_ZOOM, 1.F);
        g_zoom.target      = z >= 0.995F ? 1.F : z;
        wake();
        return true;
    }

    void onAxis(IPointer::SAxisEvent e, Event::SCallbackInfo& info) {
        if (!g_wheelOn || e.axis != WL_POINTER_AXIS_VERTICAL_SCROLL || !g_pInputManager)
            return;
        const auto mods = g_pInputManager->getModsFromAllKBs();
        const auto want = Input::HL_MODIFIER_META | Input::HL_MODIFIER_ALT;
        const auto care = want | Input::HL_MODIFIER_ALT | Input::HL_MODIFIER_SHIFT;
        if ((mods & care) != want)
            return;
        const double notches = e.deltaDiscrete != 0 ? e.deltaDiscrete / 120.0 : e.delta / 15.0;
        if (wheelNotches(notches))
            info.cancelled = true;
    }

    // ── hyprctl velvetzoom ──────────────────────────────────────────────────

    // The pacer: while the glide moves, a timer outside the render loop asks
    // every monitor for its next frame. Asking from inside a frame (render.pre)
    // was sometimes dropped, and then the glide only moved when something else
    // on screen redrew — in lumps. That was the choppy zoom.
    SP<CEventLoopTimer> g_pacer;

    void pace() {
        if (!g_pacer)
            return;
        if (g_zoom.active && !settled()) {
            for (auto& m : State::monitorState()->monitors()) {
                g_pHyprRenderer->damageMonitor(m);
                m->scheduleFrame();
            }
            g_pacer->updateTimeout(std::chrono::milliseconds(4));
        } else
            g_pacer->updateTimeout(std::nullopt);
    }

    void wake() {
        g_zoom.last = Clock::now();
        for (auto& m : State::monitorState()->monitors()) {
            g_pHyprRenderer->damageMonitor(m);
            m->scheduleFrame();
        }
        if (g_pacer)
            g_pacer->updateTimeout(std::chrono::milliseconds(1));
    }

    IPC::Socket1::SResponse onCommand(const IPC::Socket1::SRequest& req) {
        std::istringstream in(req.command);
        std::string        name, verb;
        in >> name >> verb;

        if (verb == "set" || verb == "snap") {
            float  z = 1.F;
            double px = 0, py = 0;
            if (!(in >> z >> px >> py))
                return "usage: velvetzoom set|snap <z> <px> <py>";
            z = std::clamp(z, 0.05F, 1.F);
            if (!g_zoom.active)
                setCur(1.F);
            g_zoom.active = true;
            g_zoom.target = z;
            g_zoom.pivot  = {px, py};
            g_fixedCheck  = Clock::now() - std::chrono::seconds(10);
            readFixed();
            if (verb == "snap")
                setCur(z);
            wake();
            return "ok";
        }
        if (verb == "pick") { // as a click would: focus the window at (x, y), then glide home
            double x = 0, y = 0;
            if (!(in >> x >> y))
                return "usage: velvetzoom pick <x> <y>";
            const auto w = g_zoom.active ? pickAt({x, y}) : nullptr;
            g_zoom.target = 1.F;
            wake();
            return w ? std::format("{:x}", (uintptr_t)w.get()) : "none";
        }
        if (verb == "wheel") { // as the wheel would: positive shrinks, negative grows
            double n = 0;
            in >> n;
            return wheelNotches(n) ? "taken" : "passed on";
        }
        if (verb == "off") {
            g_zoom.target = 1.F;
            wake();
            return "ok";
        }
        if (verb == "wheelon" || verb == "wheeloff") { // let the key bind have the wheel instead
            g_wheelOn = verb == "wheelon";
            return g_wheelOn ? "the plugin takes SUPER+ALT+wheel" : "the wheel is left to the key bind";
        }
        if (verb == "light") {
            int on = 1;
            in >> on;
            g_lightOn = on != 0;
            return g_lightOn ? "no blur or shadow while zoomed" : "blur and shadow stay";
        }
        if (verb == "toggle") { // debugging: switch one of the patches off
            std::string what;
            int         on = 1;
            in >> what >> on;
            (what == "cull" ? g_cullOn : what == "box" ? g_boxOn : g_opaqueOn) = on != 0;
            return std::format("cull={} box={} opaque={}", g_cullOn, g_boxOn, g_opaqueOn);
        }
        if (verb == "fns") { // debugging: which functions by this name exist
            std::string n, out;
            in >> n;
            for (auto& f : HyprlandAPI::findFunctionsByName(PHANDLE, n))
                out += f.demangled + "\n";
            return out.empty() ? "none" : out;
        }
        if (verb == "trace") {
            std::string out;
            for (auto& [t, z] : g_trace)
                out += std::format("{:.0f}:{:.4f} ", t, z);
            g_trace.clear();
            g_traceT0 = Clock::now();
            return out.empty() ? "empty" : out;
        }
        if (verb == "borders")
            return std::format("calls={} withWindow={} fixed={}", g_borderCalls, g_borderWin, g_borderFixed);
        if (verb == "frames") { // average frame interval while zoomed, then reset
            const std::string o = std::format("frames={} avg={:.2f}ms", g_frames, g_frames ? g_frameMs / g_frames : 0.0);
            g_frames  = 0;
            g_frameMs = 0;
            return o;
        }
        if (verb == "status")
            return std::format("active={} z={:.4f} target={:.4f} pivot={:.0f},{:.0f} patches: cull={} box={} opaque={} draw={} light={} blur={} shadow={} wheel={} fixed={} border={} mods=super+alt", g_zoom.active, g_zoom.cur,
                               g_zoom.target, g_zoom.pivot.x, g_zoom.pivot.y, !!g_cullHook, !!g_boxSlot, !!g_opaqueSlot, !!g_drawSurfaceHook, g_lightOn, !!g_liveBlurSlot, !!g_shadowHook,
                               g_wheelOn, g_fixed.size(), !!g_drawBorderHook);
        return "velvetzoom set|snap <z> <px> <py> · off · status";
    }
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    const std::string HASH        = __hyprland_api_get_hash();
    const std::string CLIENT_HASH = __hyprland_api_get_client_hash();
    if (HASH != CLIENT_HASH) {
        HyprlandAPI::addNotification(PHANDLE, "[velvetzoom] built for another Hyprland — rebuild it", CHyprColor{1.0, 0.2, 0.2, 1.0}, 8000);
        throw std::runtime_error("[velvetzoom] version mismatch");
    }

    g_pacer = makeShared<CEventLoopTimer>(std::nullopt, [](SP<CEventLoopTimer>, void*) { pace(); }, nullptr);
    g_pEventLoopManager->addTimer(g_pacer);

    g_preListener   = Event::bus()->m_events.render.pre.listen([](PHLMONITOR m) { onPre(m); });
    g_stageListener = Event::bus()->m_events.render.stage.listen([](eRenderStage s) { onStage(s); });

    g_axisListener = Event::bus()->m_events.input.mouse.axis.listen([](IPointer::SAxisEvent e, Event::SCallbackInfo& i) { onAxis(e, i); });
    g_buttonListener = Event::bus()->m_events.input.mouse.button.listen([](IPointer::SButtonEvent e, Event::SCallbackInfo& i) { onButton(e, i); });

    // another workspace is a fresh desk: leave the overview first
    g_workspaceListener = Event::bus()->m_events.workspace.active.listen([](PHLWORKSPACE) {
        if (g_zoom.active) {
            g_zoom.target = 1.F;
            wake();
        }
    });

    g_cullHook = hookByName("shouldRenderWindow", "CMonitor", (void*)&hkShouldRenderWindow);

    g_drawSurfaceHook = hookByName("drawSurface", "IElementRenderer::drawSurface", (void*)&hkDrawSurface);
    g_drawBorderHook  = hookByName("draw", "CGLElementRenderer::draw(Hyprutils::Memory::CWeakPointer<CBorderPassElement>", (void*)&hkDrawBorder);

    g_boxOrig    = (BoxFn)addressOf("boundingBox", "CSurfacePassElement::boundingBox");
    g_opaqueOrig = (RegionFn)addressOf("opaqueRegion", "CSurfacePassElement::opaqueRegion");
    g_boxSlot    = patchVtable("_ZTV19CSurfacePassElement", (void*)g_boxOrig, (void*)&hkBoundingBox);
    g_opaqueSlot = patchVtable("_ZTV19CSurfacePassElement", (void*)g_opaqueOrig, (void*)&hkOpaqueRegion);
    g_liveBlurOrig = (NeedsFn)addressOf("needsLiveBlur", "CSurfacePassElement::needsLiveBlur");
    g_preBlurOrig  = (NeedsFn)addressOf("needsPrecomputeBlur", "CSurfacePassElement::needsPrecomputeBlur");
    g_liveBlurSlot = patchVtable("_ZTV19CSurfacePassElement", (void*)g_liveBlurOrig, (void*)&hkNeedsLiveBlur);
    g_preBlurSlot  = patchVtable("_ZTV19CSurfacePassElement", (void*)g_preBlurOrig, (void*)&hkNeedsPreBlur);
    g_shadowHook   = hookByName("draw", "CHyprDropShadowDecoration::draw(", (void*)&hkShadowDraw);
    if (!g_cullHook || !g_boxSlot || !g_opaqueSlot || !g_drawSurfaceHook)
        HyprlandAPI::addNotification(PHANDLE, "[velvetzoom] windows that are off screen at 1:1 will not show while zoomed out", CHyprColor{1.0, 0.7, 0.2, 1.0}, 6000);


    IPC::Socket1::SCommand cmd;
    cmd.name    = "velvetzoom";
    cmd.match   = IPC::Socket1::COMMAND_MATCH_PREFIX;
    cmd.handler = [](const IPC::Socket1::SRequest& r) { return onCommand(r); };
    g_command   = HyprlandAPI::registerHyprCtlCommand(PHANDLE, cmd);

    return {"velvetzoom", "Zoom the desktop out: windows shrink as textures, the wallpaper stays", "Velvet", "0.4"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_zoom.active = false;
    if (g_pacer) {
        g_pacer->cancel();
        g_pEventLoopManager->removeTimer(g_pacer);
        g_pacer.reset();
    }
    g_preListener.reset();
    g_stageListener.reset();
    g_buttonListener.reset();
    g_axisListener.reset();
    g_workspaceListener.reset();
    unpatch(g_boxSlot, (void*)g_boxOrig);
    unpatch(g_opaqueSlot, (void*)g_opaqueOrig);
    unpatch(g_liveBlurSlot, (void*)g_liveBlurOrig);
    unpatch(g_preBlurSlot, (void*)g_preBlurOrig);
    for (auto* h : {&g_cullHook, &g_drawSurfaceHook, &g_shadowHook, &g_drawBorderHook}) {
        if (*h)
            HyprlandAPI::removeFunctionHook(PHANDLE, *h);
        *h = nullptr;
    }
    if (g_command)
        HyprlandAPI::unregisterHyprCtlCommand(PHANDLE, g_command);
}
