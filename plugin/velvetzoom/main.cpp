// VELVET · plugin/velvetzoom — the desktop zoom-out.
//
// Hyprland's own zoom (cursor:zoom_factor) cannot go below 1.0. This plugin
// renders the windows of the workspace through a scale-and-shift transform
// between "wallpaper and layers" and "top layers", so every window shrinks as a
// texture — content included, live — while the wallpaper and the bar stay
// where they are. That is the zoom-out of the clip it copies.
//
// The transform, in global layout coordinates:  screen = t + layout * z
//
// Control (hyprctl):
//   hyprctl velvetzoom set  <z> <px> <py>   glide to z around the point
//   hyprctl velvetzoom snap <z> <px> <py>   jump
//   hyprctl velvetzoom fit                  glide so every window of the desk shows
//   hyprctl velvetzoom off                  glide back to 1:1 and switch off
//   hyprctl velvetzoom status
// px/py are global layout coordinates (what `hyprctl cursorpos` prints).
//
// Mouse, while zoomed out, works as it does at 1:1 (v0.5): over a window the
// pointer is handed to Hyprland in the window's own (unzoomed) coordinates for
// the time an input event is processed — hover, clicks, typing focus,
// SUPER+drag to move and SUPER+right-drag to resize all land where the window
// is drawn. Over the bar, the shell's overlays and the empty desktop the
// pointer stays where it is. SUPER+ALT+left click glides back to 1:1,
// SUPER+ALT+right click fits every window of the desk on screen.
//
// Zoomed IN (Hyprland's cursor zoom, z > 1) with cursor:zoom_rigid on, the view
// stays put and the pointer stops at the edge of what is shown, instead of the
// view panning after it.
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
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/pointer/PointerManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/config/ConfigValue.hpp>
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

// ── two private members, read the legal way ─────────────────────────────────
// An explicit instantiation may name a private member; the pointer it yields
// is then an ordinary member pointer. The pointer's position (to look at it in
// window coordinates for one input event) and the cursor zoom's camera (to keep
// the pointer inside what a magnified screen shows).
template <typename Tag, typename Tag::type M>
struct SRob {
    friend typename Tag::type get(Tag) {
        return M;
    }
};
struct SPointerPos {
    using type = Vector2D Pointer::CPointerManager::*;
    friend type get(SPointerPos);
};
template struct SRob<SPointerPos, &Pointer::CPointerManager::m_pointerPos>;
struct SZoomCamera {
    using type = CBox Monitor::CMonitorZoomController::*;
    friend type get(SZoomCamera);
};
template struct SRob<SZoomCamera, &Monitor::CMonitorZoomController::m_camera>;

namespace {
    using Clock = std::chrono::steady_clock;

    // The glide. z springs in log space (every halving takes as long); the
    // shift t either follows from an anchor — the layout point `ax` stays under
    // the screen point `a`, which is how the wheel zooms — or springs on its own
    // towards `tTarget` (fit, and the way home).
    struct SZoom {
        bool              active  = false;
        float             target  = 1.F;
        float             cur     = 1.F;
        double            lx      = 0; // ln(cur)
        double            vel     = 0; // d ln(z) / dt
        bool              anchored = true;
        Vector2D          a       = {0, 0}; // screen point that stays (anchored)
        Vector2D          ax      = {0, 0}; // the layout point under it
        Vector2D          t       = {0, 0}; // current shift
        Vector2D          tTarget = {0, 0};
        Vector2D          tVel    = {0, 0};
        Clock::time_point last    = Clock::now();
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
    bool g_inputOn = true;                                   // the mouse works on the zoomed windows

    int  g_swapDepth = 0;     // > 0 while the pointer is in layout space
    bool g_bypass    = false; // our own lookups see the plain hit test
    int  g_held      = 0;     // buttons down (as seen by the input manager)
    bool g_sticky    = false; // the press that started the hold was on a window

    bool light() {
        return g_lightOn && g_zoom.active && g_zoom.cur < LIGHT_BELOW;
    }

    bool zoomedOut() {
        return g_zoom.active && g_zoom.cur < 0.999F;
    }

    void setCur(float z) {
        g_zoom.cur = z;
        g_zoom.lx  = std::log((double)z);
        g_zoom.vel = 0;
    }

    // screen = t + layout * z, and back
    Vector2D toScreen(const Vector2D& p) {
        return g_zoom.t + p * g_zoom.cur;
    }
    Vector2D toLayout(const Vector2D& p) {
        return (p - g_zoom.t) / g_zoom.cur;
    }

    // ── windows that belong to the desktop, not to the canvas ───────────────
    // Velvet's fixed modules (cava along an edge, vitals …) sit where the
    // widgets sit and stay their size: the shell lists their classes, one per
    // line, in $XDG_RUNTIME_DIR/velvet-fixed. They are drawn without the zoom.
    std::unordered_set<std::string> g_fixed;
    time_t                          g_fixedStamp = -1;
    Clock::time_point               g_fixedCheck = Clock::now() - std::chrono::seconds(10);

    std::string runtimeDir() {
        const char* run = getenv("XDG_RUNTIME_DIR");
        return run ? run : "/tmp";
    }

    void readFixed() {
        const auto now = Clock::now();
        if (now - g_fixedCheck < std::chrono::milliseconds(700))
            return;
        g_fixedCheck           = now;
        const std::string path = runtimeDir() + "/velvet-fixed";
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

    // What the desktop scripts need to know (the canvas engine scales its
    // panning by it): "<target z> <active>", written when it changes.
    float g_written = -1.F;
    void  writeState() {
        const float z = g_zoom.active ? g_zoom.target : 1.F;
        if (z == g_written)
            return;
        g_written = z;
        std::ofstream out(runtimeDir() + "/velvet-zoom-state", std::ios::trunc);
        out << std::format("{:.4f} {}\n", z, g_zoom.active ? 1 : 0);
    }

    // frame statistics for `status`
    size_t            g_frames    = 0;
    double            g_frameMs   = 0;
    Clock::time_point g_lastFrame = Clock::now();

    CHyprSignalListener        g_preListener;
    CHyprSignalListener        g_stageListener;
    CHyprSignalListener        g_buttonListener;
    CHyprSignalListener        g_axisListener;
    CHyprSignalListener        g_workspaceListener;
    SP<IPC::Socket1::SCommand> g_command;

    void wake();

    bool settled() {
        const bool zDone = std::abs(std::log((double)g_zoom.target) - g_zoom.lx) < 0.0015 && std::abs(g_zoom.vel) < 0.02;
        if (g_zoom.anchored)
            return zDone;
        return zDone && g_zoom.t.distance(g_zoom.tTarget) < 0.5 && g_zoom.tVel.size() < 2.0;
    }

    // From anchored to free without a jump: the shift and its speed as they are.
    void unanchor() {
        if (!g_zoom.anchored)
            return;
        g_zoom.t        = g_zoom.a - g_zoom.ax * g_zoom.cur;
        g_zoom.tVel     = g_zoom.ax * (-(double)g_zoom.cur * g_zoom.vel);
        g_zoom.anchored = false;
    }

    // From free to anchored at screen point a, without a jump.
    void anchorAt(const Vector2D& a) {
        g_zoom.ax       = toLayout(a);
        g_zoom.a        = a;
        g_zoom.anchored = true;
        g_zoom.tVel     = {0, 0};
    }

    void deactivate() {
        setCur(1.F);
        g_zoom.target   = 1.F;
        g_zoom.active   = false;
        g_zoom.anchored = true;
        g_zoom.a = g_zoom.ax = g_zoom.t = g_zoom.tTarget = g_zoom.tVel = {0, 0};
        if (g_held == 0)
            g_sticky = false;
        writeState();
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
            if (!g_zoom.anchored) {
                const Vector2D at = (g_zoom.tTarget - g_zoom.t) * (OMEGA * OMEGA) - g_zoom.tVel * (2.0 * OMEGA);
                g_zoom.tVel       = g_zoom.tVel + at * h;
                g_zoom.t          = g_zoom.t + g_zoom.tVel * h;
            }
        }
        if (settled()) {
            setCur(g_zoom.target);
            if (!g_zoom.anchored) {
                g_zoom.t    = g_zoom.tTarget;
                g_zoom.tVel = {0, 0};
            }
        } else
            g_zoom.cur = (float)std::exp(g_zoom.lx);
        if (g_zoom.anchored)
            g_zoom.t = g_zoom.a - g_zoom.ax * g_zoom.cur;
        if (settled() && g_zoom.target >= 0.9995F)
            deactivate();
    }

    // debugging: the glide, frame by frame (`hyprctl velvetzoom trace`)
    std::vector<std::pair<double, float>> g_trace;
    Clock::time_point                     g_traceT0 = Clock::now();

    void onPre(PHLMONITOR mon) {
        if (!mon)
            return;
        if (g_zoom.active) {
            const auto   now = Clock::now();
            const double dt  = std::chrono::duration<double, std::milli>(now - g_lastFrame).count();
            g_lastFrame      = now;
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

    // The shift as the monitor sees it (monitor-local logical coordinates):
    // local screen = local layout * z + localShift.
    Vector2D localShift(const Vector2D& monPos) {
        return g_zoom.t - monPos * (1.0 - g_zoom.cur);
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
            modif.modifs.push_back({Render::SRenderModifData::RMOD_TYPE_SCALE, g_zoom.cur});
            modif.modifs.push_back({Render::SRenderModifData::RMOD_TYPE_TRANSLATE, localShift(mon->m_position) * mon->m_scale});
        }
        data.renderModif = modif; // an empty list at the end puts the layers back to 1:1
        g_pHyprRenderer->addPassElement(makeUnique<CRendererHintsPassElement>(data));
    }

    // ── windows that are off screen at 1:1 ──────────────────────────────────

    // A box in global layout coordinates, after the zoom.
    CBox zoomed(CBox box) {
        const Vector2D p = toScreen(box.pos());
        return {p.x, p.y, box.w * g_zoom.cur, box.h * g_zoom.cur};
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

    Vector2D shiftOf(CSurfacePassElement* e) {
        const auto mon = e->m_data.pMonitor.lock();
        return localShift(mon ? mon->m_position : Vector2D{0, 0});
    }

    std::optional<CBox> hkBoundingBox(CSurfacePassElement* e) {
        auto box = g_boxOrig(e);
        if (!g_boxOn || !box || !zoomsWindow(e))
            return box;
        const Vector2D s = shiftOf(e);
        const double   z = g_zoom.cur;
        return CBox{s.x + box->x * z, s.y + box->y * z, box->w * z, box->h * z};
    }

    CRegion hkOpaqueRegion(CSurfacePassElement* e) {
        CRegion rg = g_opaqueOrig(e);
        if (!g_opaqueOn || !zoomsWindow(e))
            return rg;
        rg.scale(g_zoom.cur);
        rg.translate(shiftOf(e));
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
    void           hkShadowDraw(void* self, PHLMONITOR mon, const float& a) {
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
        const Vector2D s   = shiftOf(e) * (mon ? mon->m_scale : 1.F); // physical pixels, like the damage
        const auto     ext = const_cast<CRegion&>(damage).getExtents();
        const double   z   = g_zoom.cur;
        const CRegion  unzoomed(CBox{(ext.x - s.x) / z, (ext.y - s.y) / z, ext.w / z, ext.h / z});
        // the renderer also clips against its own frame damage while drawing
        const bool hadBlur = e->m_data.blur;
        if (light())
            e->m_data.blur = false; // a blurred backdrop of the wrong place costs a lot and shows nothing
        auto&         rd       = g_pHyprRenderer->m_renderData;
        const CRegion savedDmg = rd.damage;
        const CRegion savedFin = rd.finalDamage;
        rd.damage              = unzoomed;
        rd.finalDamage         = unzoomed;
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

    // ── the mouse on a zoomed desk ──────────────────────────────────────────
    //  Hyprland finds the window under the pointer, works out where in it the
    //  pointer is, starts and runs SUPER+drag — all from one number, the
    //  pointer's position. For the length of one input event that number is
    //  moved into the window's own (unzoomed) space; the cursor is drawn from
    //  it again the moment the event is done. Over the bar, the shell's
    //  overlays and the empty desktop it is left alone, and windows are not
    //  found where they would be at 1:1 (they are not there any more).

    Vector2D& pointerPos() {
        return Pointer::mgr().get()->*get(SPointerPos{});
    }


    PHLMONITOR monitorAt(const Vector2D& p) {
        for (auto& m : State::monitorState()->monitors())
            if (CBox{m->m_position.x, m->m_position.y, m->m_size.x, m->m_size.y}.containsPoint(p))
                return m;
        return nullptr;
    }

    // Is the (real) pointer over a zoomed window, and not over something the
    // zoom does not touch?
    bool overZoomedWindow(const Vector2D& p) {
        const auto mon = monitorAt(p);
        if (!mon)
            return false;
        // the bar, the frame, notifications, the shell's overlays
        Vector2D coords;
        PHLLS    ls;
        const auto ht = Desktop::viewState()->hitTest();
        if (ht.layerPopupSurfaceAt(p, mon, &coords, &ls))
            return false;
        for (int layer : {3, 2}) // overlay, top
            if (ht.layerSurfaceAt(p, &mon->m_layerSurfaceLayers[layer], &coords, &ls))
                return false;
        // a fixed module, drawn where it is
        const auto& ws = Desktop::windowState()->windows();
        for (auto it = ws.rbegin(); it != ws.rend(); ++it) {
            const auto& w = *it;
            if (!w || !isFixed(w) || !w->mapped() || w->isHidden() || !w->m_workspace || !w->m_workspace->isVisible())
                continue;
            if (w->getFullWindowBoundingBox().containsPoint(p))
                return false;
        }
        g_bypass   = true;
        const auto w = ht.windowAt(toLayout(p), Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING);
        g_bypass   = false;
        return w && !isFixed(w);
    }

    bool wantSwap() {
        if (!g_inputOn || !zoomedOut() || !g_pInputManager || !Pointer::mgr())
            return false;
        if (g_pInputManager->isConstrained())
            return false;
        // a hold (a drag, a text selection, SUPER+drag) keeps the space it began in
        if (g_held > 0 || (g_layoutManager && g_layoutManager->dragController()->target()))
            return g_sticky;
        return overZoomedWindow(pointerPos());
    }

    struct SSwap {
        bool     on = false;
        Vector2D real, moved;
        explicit SSwap(bool want) {
            if (!want || g_swapDepth > 0)
                return;
            auto& p = pointerPos();
            real    = p;
            moved   = toLayout(real);
            p       = moved;
            on      = true;
            g_swapDepth++;
        }
        ~SSwap() {
            if (!on)
                return;
            auto& p = pointerPos();
            // if Hyprland moved the pointer meanwhile, keep that move
            p = p == moved ? real : toScreen(p);
            g_swapDepth--;
        }
    };

    // Zoomed IN with a rigid camera: the pointer stays inside what is shown.
    void keepInCamera() {
        static auto PRIGID    = CConfigValue<Config::INTEGER>("cursor:zoom_rigid");
        static auto PDETACHED = CConfigValue<Config::INTEGER>("cursor:zoom_detached_camera");
        if (!*PRIGID || !*PDETACHED || !Pointer::mgr())
            return;
        const Vector2D p   = pointerPos();
        const auto     mon = monitorAt(p);
        if (!mon || !mon->m_cursorZoom || mon->m_cursorZoom->value() <= 1.001F || mon->m_zoomAnimProgress->value() != 1.0)
            return;
        const CBox cam = mon->m_zoomController.*get(SZoomCamera{});
        if (cam.w < 2 || cam.h < 2 || cam.w >= mon->m_size.x - 0.5)
            return;
        const Vector2D lo = mon->m_position + cam.pos();
        const Vector2D hi = lo + cam.size() - Vector2D{1, 1};
        const Vector2D c  = {std::clamp(p.x, lo.x, hi.x), std::clamp(p.y, lo.y, hi.y)};
        if (c != p)
            Pointer::mgr()->warpTo(c);
    }

    using MouseMoveFn = void (*)(void*, uint32_t, bool, bool, std::optional<Vector2D>);
    CFunctionHook* g_mouseMoveHook = nullptr;

    void hkMouseMoveUnified(void* self, uint32_t time, bool refocus, bool mouse, std::optional<Vector2D> overridePos) {
        if (g_swapDepth == 0 && !overridePos)
            keepInCamera();
        SSwap swap(!overridePos && wantSwap());
        ((MouseMoveFn)g_mouseMoveHook->m_original)(self, time, refocus, mouse, overridePos);
    }

    using MouseButtonFn = void (*)(void*, IPointer::SButtonEvent, SP<IPointer>);
    CFunctionHook* g_mouseButtonHook = nullptr;

    void hkOnMouseButton(void* self, IPointer::SButtonEvent e, SP<IPointer> mouse) {
        if (e.state == WL_POINTER_BUTTON_STATE_PRESSED) {
            if (g_held == 0)
                g_sticky = g_swapDepth == 0 && wantSwap();
            g_held++;
        }
        {
            SSwap swap(g_swapDepth == 0 && (g_held > 0 ? g_sticky && zoomedOut() && g_inputOn : wantSwap()));
            ((MouseButtonFn)g_mouseButtonHook->m_original)(self, e, mouse);
        }
        if (e.state != WL_POINTER_BUTTON_STATE_PRESSED && g_held > 0 && --g_held == 0)
            g_sticky = false;
    }

    // A window is not where it would be at 1:1 any more: a lookup at the real
    // pointer finds nothing there (fixed modules excepted).
    using WindowAtFn = PHLWINDOW (*)(void*, const Vector2D&, uint16_t, PHLWINDOW);
    CFunctionHook* g_windowAtHook = nullptr;

    PHLWINDOW hkWindowAt(void* self, const Vector2D& pos, uint16_t props, PHLWINDOW ignore) {
        auto w = ((WindowAtFn)g_windowAtHook->m_original)(self, pos, props, ignore);
        if (!w || !g_inputOn || g_bypass || g_swapDepth > 0 || !zoomedOut())
            return w;
        return isFixed(w) ? w : nullptr;
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

    // ── jumps ───────────────────────────────────────────────────────────────

    // Glide home: 1:1, no shift.
    void goHome() {
        if (!g_zoom.active)
            return;
        unanchor();
        g_zoom.target  = 1.F;
        g_zoom.tTarget = {0, 0};
        wake();
    }

    // Glide so that every window of the desk under the pointer shows, in the
    // part of the screen the bar leaves free.
    bool fitAll() {
        const Vector2D at  = Pointer::mgr() ? pointerPos() : Vector2D{0, 0};
        PHLMONITOR     mon = monitorAt(at);
        if (!mon)
            mon = Desktop::focusState()->monitor();
        if (!mon || !mon->m_activeWorkspace)
            return false;
        readFixed();
        CBox all;
        bool any = false;
        for (auto& w : Desktop::windowState()->windows()) {
            if (!w || !w->mapped() || w->isHidden() || isFixed(w) || !w->m_workspace)
                continue;
            if (w->m_workspace != mon->m_activeWorkspace)
                continue;
            const CBox b = w->getFullWindowBoundingBox();
            if (!any) {
                all = b;
                any = true;
            } else {
                const double x0 = std::min(all.x, b.x), y0 = std::min(all.y, b.y);
                const double x1 = std::max(all.x + all.w, b.x + b.w), y1 = std::max(all.y + all.h, b.y + b.h);
                all             = {x0, y0, x1 - x0, y1 - y0};
            }
        }
        if (!any || all.w < 1 || all.h < 1) {
            goHome();
            return true;
        }
        CBox         work   = mon->logicalBoxMinusReserved();
        const double margin = std::min(work.w, work.h) * 0.04;
        work                = {work.x + margin, work.y + margin, work.w - 2 * margin, work.h - 2 * margin};
        // everything already shows at 1:1
        if (all.x >= work.x - margin && all.y >= work.y - margin && all.x + all.w <= work.x + work.w + margin && all.y + all.h <= work.y + work.h + margin) {
            goHome();
            return true;
        }
        float z = (float)std::min(work.w / all.w, work.h / all.h);
        z       = std::clamp(z, MIN_ZOOM, 0.99F);
        // the middle of the windows lands in the middle of the free screen
        const Vector2D tFit = work.middle() - all.middle() * z;
        if (!g_zoom.active) {
            setCur(1.F);
            g_zoom.active   = true;
            g_zoom.anchored = false;
            g_zoom.t        = {0, 0};
            g_zoom.tVel     = {0, 0};
            g_zoom.last     = Clock::now();
        } else
            unanchor();
        g_zoom.target  = z;
        g_zoom.tTarget = tFit;
        wake();
        return true;
    }

    // ── SUPER+ALT + left / right click ──────────────────────────────────────
    std::unordered_set<uint32_t> g_eaten; // presses taken, so their releases are too

    bool superAlt() {
        if (!g_pInputManager)
            return false;
        const auto mods = g_pInputManager->getModsFromAllKBs();
        const auto want = Input::HL_MODIFIER_META | Input::HL_MODIFIER_ALT;
        const auto care = want | Input::HL_MODIFIER_CTRL | Input::HL_MODIFIER_SHIFT;
        return (mods & care) == want;
    }

    void onButton(IPointer::SButtonEvent e, Event::SCallbackInfo& info) {
        if (e.state != WL_POINTER_BUTTON_STATE_PRESSED) {
            if (g_eaten.erase(e.button))
                info.cancelled = true;
            return;
        }
        if ((e.button != BTN_LEFT && e.button != BTN_RIGHT) || !superAlt())
            return;
        if (access("/tmp/velvet-map-open", F_OK) == 0)
            return;
        // Hyprland's own zoom (z > 1) is magnified: that one is not ours. The
        // key bind runs desktop_zoom.py (reset / fit), which puts the screen
        // back to 1:1 first — so the click is left alone for it.
        if (Pointer::mgr()) {
            const auto mon = monitorAt(pointerPos());
            if (mon && mon->m_cursorZoom && mon->m_cursorZoom->value() > 1.005F)
                return;
        }
        if (e.button == BTN_LEFT)
            goHome();
        else
            fitAll();
        g_eaten.insert(e.button);
        info.cancelled = true;
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
        } catch (...) { return 1.F; }
    }

    Vector2D anchorNow() {
        const Vector2D at = Pointer::mgr() ? pointerPos() : Vector2D{0, 0};
        PHLMONITOR     m  = monitorAt(at);
        if (!m && !State::monitorState()->monitors().empty())
            m = State::monitorState()->monitors().front();
        if (!m)
            return at;
        // inside the central half, so the shrunken desktop stays on screen
        return {std::clamp(at.x, m->m_position.x + m->m_size.x * 0.25, m->m_position.x + m->m_size.x * 0.75),
                std::clamp(at.y, m->m_position.y + m->m_size.y * 0.25, m->m_position.y + m->m_size.y * 0.75)};
    }

    // Start a fresh overview anchored at a: the layout point under a stays.
    void begin(const Vector2D& a) {
        setCur(1.F);
        g_zoom.target   = 1.F;
        g_zoom.active   = true;
        g_zoom.anchored = true;
        g_zoom.a        = a;
        g_zoom.ax       = a;
        g_zoom.t        = {0, 0};
        g_zoom.tVel     = {0, 0};
        g_zoom.last     = Clock::now();
        g_fixedCheck    = Clock::now() - std::chrono::seconds(10);
        readFixed();
    }

    int               g_burst     = 0;
    Clock::time_point g_lastNotch = Clock::now() - std::chrono::seconds(10);

    // notches > 0 shrink (wheel down), < 0 grow. Returns whether the plugin took it.
    bool wheelNotches(double notches, bool dryRun = false) {
        if (notches == 0)
            return false;
        // no desktop zoom under the window map (it writes this file while it is up)
        if (access("/tmp/velvet-map-open", F_OK) == 0)
            return false;
        const bool out = notches > 0;
        if (!g_zoom.active) {
            if (!out)
                return false; // magnifying belongs to Hyprland's own zoom
            if (cursorZoom() > 1.005F)
                return false; // shrink the magnified screen first
            if (dryRun)
                return true;
            begin(anchorNow());
        } else if (g_zoom.target > 0.999F && !out) {
            return false; // already on the way home: let the wheel magnify after
        } else if (dryRun) {
            return true;
        } else if (!g_zoom.anchored) {
            // after a fit or on the way home: zoom around the pointer from here
            anchorAt(anchorNow());
        }

        const auto now = Clock::now();
        g_burst        = std::chrono::duration<double>(now - g_lastNotch).count() < 0.14 ? std::min(8, g_burst + 1) : 0;
        g_lastNotch    = now;
        const double accel = 1.0 + 0.9 * std::min(1.0, g_burst / 5.0);
        float        z     = g_zoom.target * (float)std::pow((double)STEP, -notches * accel);
        z                  = std::clamp(z, MIN_ZOOM, 1.F);
        if (z >= 0.995F) {
            goHome(); // home is 1:1 with no shift, wherever the anchor was
            return true;
        }
        g_zoom.target = z;
        wake();
        return true;
    }

    void onAxis(IPointer::SAxisEvent e, Event::SCallbackInfo& info) {
        if (!g_wheelOn || e.axis != WL_POINTER_AXIS_VERTICAL_SCROLL || !superAlt())
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
        writeState();
        for (auto& m : State::monitorState()->monitors()) {
            g_pHyprRenderer->damageMonitor(m);
            m->scheduleFrame();
        }
        if (g_pacer)
            g_pacer->updateTimeout(std::chrono::milliseconds(1));
    }

    // The pivot an anchored zoom is equivalent to (for `status`).
    Vector2D pivotNow() {
        if (g_zoom.anchored && std::abs(g_zoom.a.x - g_zoom.ax.x) < 0.5 && std::abs(g_zoom.a.y - g_zoom.ax.y) < 0.5)
            return g_zoom.a;
        const double k = 1.0 - g_zoom.cur;
        return k > 0.0005 ? g_zoom.t / k : g_zoom.a;
    }

    IPC::Socket1::SResponse onCommand(const IPC::Socket1::SRequest& req) {
        std::istringstream in(req.command);
        std::string        name, verb;
        in >> name >> verb;

        if (verb == "set" || verb == "snap") {
            float  z  = 1.F;
            double px = 0, py = 0;
            if (!(in >> z >> px >> py))
                return "usage: velvetzoom set|snap <z> <px> <py>";
            z = std::clamp(z, 0.05F, 1.F);
            if (z >= 0.9995F) {
                goHome();
                return "ok";
            }
            // around a pivot: the pivot is drawn at itself, so t = p · (1 - z)
            const Vector2D p = {px, py};
            if (!g_zoom.active)
                begin(p);
            else {
                unanchor();
                g_zoom.tTarget = p * (1.0 - z);
            }
            g_zoom.target = z;
            if (verb == "snap") {
                setCur(z);
                g_zoom.t = g_zoom.anchored ? g_zoom.a - g_zoom.ax * z : g_zoom.tTarget;
                g_zoom.tVel = {0, 0};
            }
            wake();
            return "ok";
        }
        if (verb == "fit")
            return fitAll() ? "ok" : "no desk";
        if (verb == "pick") { // focus the window drawn at (x, y)
            double x = 0, y = 0;
            if (!(in >> x >> y))
                return "usage: velvetzoom pick <x> <y>";
            const auto w = g_zoom.active ? pickAt({x, y}) : nullptr;
            return w ? std::format("{:x}", (uintptr_t)w.get()) : "none";
        }
        if (verb == "wheel") { // as the wheel would: positive shrinks, negative grows
            double n = 0;
            in >> n;
            return wheelNotches(n) ? "taken" : "passed on";
        }
        if (verb == "off") {
            goHome();
            return "ok";
        }
        if (verb == "wheelon" || verb == "wheeloff") { // let the key bind have the wheel instead
            g_wheelOn = verb == "wheelon";
            return g_wheelOn ? "the plugin takes SUPER+ALT+wheel" : "the wheel is left to the key bind";
        }
        if (verb == "input") { // debugging: the mouse on zoomed windows on/off
            int on = 1;
            in >> on;
            g_inputOn = on != 0;
            return g_inputOn ? "the mouse works on the zoomed windows" : "the mouse sees windows where they are at 1:1";
        }
        if (verb == "light") {
            int on = 1;
            in >> on;
            g_lightOn = on != 0;
            return g_lightOn ? "no blur or shadow while zoomed" : "blur and shadow stay";
        }
        if (verb == "map") { // debugging: where a screen point is in the layout, and back
            double x = 0, y = 0;
            in >> x >> y;
            const Vector2D l = toLayout({x, y});
            return std::format("layout={:.1f},{:.1f} screen={:.1f},{:.1f} over-window={}", l.x, l.y, toScreen(l).x, toScreen(l).y, overZoomedWindow({x, y}));
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
            g_frames            = 0;
            g_frameMs           = 0;
            return o;
        }
        if (verb == "status") {
            const Vector2D p = pivotNow();
            return std::format("active={} z={:.4f} target={:.4f} pivot={:.0f},{:.0f} shift={:.0f},{:.0f} anchored={} patches: cull={} box={} opaque={} draw={} light={} blur={} shadow={} wheel={} "
                               "fixed={} border={} input={} move={} button={} hit={} fit=yes mods=super+alt",
                               g_zoom.active, g_zoom.cur, g_zoom.target, p.x, p.y, g_zoom.t.x, g_zoom.t.y, g_zoom.anchored, !!g_cullHook, !!g_boxSlot, !!g_opaqueSlot,
                               !!g_drawSurfaceHook, g_lightOn, !!g_liveBlurSlot, !!g_shadowHook, g_wheelOn, g_fixed.size(), !!g_drawBorderHook, g_inputOn, !!g_mouseMoveHook,
                               !!g_mouseButtonHook, !!g_windowAtHook);
        }
        return "velvetzoom set|snap <z> <px> <py> · fit · off · status";
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

    g_axisListener   = Event::bus()->m_events.input.mouse.axis.listen([](IPointer::SAxisEvent e, Event::SCallbackInfo& i) { onAxis(e, i); });
    g_buttonListener = Event::bus()->m_events.input.mouse.button.listen([](IPointer::SButtonEvent e, Event::SCallbackInfo& i) { onButton(e, i); });

    // another workspace is a fresh desk: leave the overview first
    g_workspaceListener = Event::bus()->m_events.workspace.active.listen([](PHLWORKSPACE) { goHome(); });

    g_cullHook = hookByName("shouldRenderWindow", "CMonitor", (void*)&hkShouldRenderWindow);

    g_drawSurfaceHook = hookByName("drawSurface", "IElementRenderer::drawSurface", (void*)&hkDrawSurface);
    g_drawBorderHook  = hookByName("draw", "CGLElementRenderer::draw(Hyprutils::Memory::CWeakPointer<CBorderPassElement>", (void*)&hkDrawBorder);

    g_boxOrig      = (BoxFn)addressOf("boundingBox", "CSurfacePassElement::boundingBox");
    g_opaqueOrig   = (RegionFn)addressOf("opaqueRegion", "CSurfacePassElement::opaqueRegion");
    g_boxSlot      = patchVtable("_ZTV19CSurfacePassElement", (void*)g_boxOrig, (void*)&hkBoundingBox);
    g_opaqueSlot   = patchVtable("_ZTV19CSurfacePassElement", (void*)g_opaqueOrig, (void*)&hkOpaqueRegion);
    g_liveBlurOrig = (NeedsFn)addressOf("needsLiveBlur", "CSurfacePassElement::needsLiveBlur");
    g_preBlurOrig  = (NeedsFn)addressOf("needsPrecomputeBlur", "CSurfacePassElement::needsPrecomputeBlur");
    g_liveBlurSlot = patchVtable("_ZTV19CSurfacePassElement", (void*)g_liveBlurOrig, (void*)&hkNeedsLiveBlur);
    g_preBlurSlot  = patchVtable("_ZTV19CSurfacePassElement", (void*)g_preBlurOrig, (void*)&hkNeedsPreBlur);
    g_shadowHook   = hookByName("draw", "CHyprDropShadowDecoration::draw(", (void*)&hkShadowDraw);
    if (!g_cullHook || !g_boxSlot || !g_opaqueSlot || !g_drawSurfaceHook)
        HyprlandAPI::addNotification(PHANDLE, "[velvetzoom] windows that are off screen at 1:1 will not show while zoomed out", CHyprColor{1.0, 0.7, 0.2, 1.0}, 6000);

    // the mouse on a zoomed desk
    g_mouseMoveHook   = hookByName("mouseMoveUnified", "CInputManager::mouseMoveUnified", (void*)&hkMouseMoveUnified);
    g_mouseButtonHook = hookByName("onMouseButton", "CInputManager::onMouseButton", (void*)&hkOnMouseButton);
    g_windowAtHook    = hookByName("windowAt", "CViewHitTester::windowAt", (void*)&hkWindowAt);
    if (!g_mouseMoveHook || !g_mouseButtonHook || !g_windowAtHook) {
        g_inputOn = false;
        HyprlandAPI::addNotification(PHANDLE, "[velvetzoom] the mouse will not reach zoomed-out windows on this Hyprland", CHyprColor{1.0, 0.7, 0.2, 1.0}, 6000);
    }

    IPC::Socket1::SCommand cmd;
    cmd.name    = "velvetzoom";
    cmd.match   = IPC::Socket1::COMMAND_MATCH_PREFIX;
    cmd.handler = [](const IPC::Socket1::SRequest& r) { return onCommand(r); };
    g_command   = HyprlandAPI::registerHyprCtlCommand(PHANDLE, cmd);

    writeState();
    return {"velvetzoom", "Zoom the desktop out: windows shrink as textures, the wallpaper stays", "Velvet", "0.5"};
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
    for (auto* h : {&g_cullHook, &g_drawSurfaceHook, &g_shadowHook, &g_drawBorderHook, &g_mouseMoveHook, &g_mouseButtonHook, &g_windowAtHook}) {
        if (*h)
            HyprlandAPI::removeFunctionHook(PHANDLE, *h);
        *h = nullptr;
    }
    if (g_command)
        HyprlandAPI::unregisterHyprCtlCommand(PHANDLE, g_command);
}
