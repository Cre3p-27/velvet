#!/bin/bash
#  VELVET  ·  tools/qwentts/build.sh
#  Velly's Qwen3-TTS voice, from sources: qwentts.cpp (C++/GGML, Vulkan) with
#  Velvet's two-line patch (velvet.patch: no sentence ends before its first
#  frames — short sentences came back empty in voice cloning — and a smaller
#  talker cache via QWENTTS_MAX_SEQ), the two model files, the voices.
#
#  It DOWNLOADS, so run it only when you want them:
#    · qwentts.cpp (MIT) from github.com/ServeurpersoCom/qwentts.cpp, pinned
#      commit, ~45 MB with its ggml
#    · Vulkan-Headers + SPIRV-Headers (Khronos, ~4 MB), unpacked next to the
#      build, only when /usr/include/vulkan is missing
#    · qwen-talker-1.7b-base-Q8_0.gguf (2.08 GB) and
#      qwen-tokenizer-12hz-Q8_0.gguf (291 MB) from
#      huggingface.co/Serveurperso/Qwen3-TTS-GGUF (Qwen3-TTS, Apache 2.0)
#  No sudo. Needs cmake, a C++ compiler, glslc and the Vulkan loader.
#
#    bash tools/qwentts/build.sh            build + fetch what is missing
#    bash tools/qwentts/build.sh --check    say what is there
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/velvet"
SRC="$DATA/engines/qwentts-src"
OUT="$DATA/engines/qwentts"
MODELS="$DATA/models/qwen3-tts"
COMMIT="5916bf7c79dbb4e66fc059cdc507a79a23a28bb4"
VK_TAG="vulkan-sdk-1.4.357.0"
HF="https://huggingface.co/Serveurperso/Qwen3-TTS-GGUF/resolve/main"
FILES=("qwen-talker-1.7b-base-Q8_0.gguf" "qwen-tokenizer-12hz-Q8_0.gguf")

if [ "${1:-}" = "--check" ]; then
    for f in "$OUT/tts-server" "${FILES[@]/#/$MODELS/}"; do
        if [ -e "$f" ]; then echo "ok       $f"; else echo "missing  $f"; fi
    done
    exit 0
fi

for tool in cmake c++ glslc git curl; do
    command -v "$tool" >/dev/null || { echo "needs $tool"; exit 1; }
done

# ── the source, pinned, with Velvet's patch
if [ ! -d "$SRC/.git" ]; then
    git clone --recurse-submodules https://github.com/ServeurpersoCom/qwentts.cpp.git "$SRC"
fi
git -C "$SRC" fetch --quiet origin "$COMMIT" 2>/dev/null || true
git -C "$SRC" checkout --quiet --force "$COMMIT"
git -C "$SRC" submodule update --init --recursive --quiet
git -C "$SRC" apply "$HERE/velvet.patch"

# ── Vulkan headers next to the build when the system has none
EXTRA=()
if [ ! -d /usr/include/vulkan ]; then
    HDR="$SRC/.vk-headers"
    mkdir -p "$HDR"
    for repo in Vulkan-Headers SPIRV-Headers; do
        if [ ! -d "$HDR/$repo-$VK_TAG" ]; then
            curl -sSL --fail "https://github.com/KhronosGroup/$repo/archive/refs/tags/$VK_TAG.tar.gz" | tar -xz -C "$HDR"
        fi
    done
    cmake -S "$HDR/SPIRV-Headers-$VK_TAG" -B "$HDR/spirv-build" -DCMAKE_INSTALL_PREFIX="$HDR/prefix" \
        -DSPIRV_HEADERS_ENABLE_TESTS=OFF >/dev/null
    cmake --install "$HDR/spirv-build" >/dev/null
    VK="$HDR/Vulkan-Headers-$VK_TAG/include"
    EXTRA=(-DCMAKE_PREFIX_PATH="$HDR/prefix" -DVulkan_INCLUDE_DIR="$VK"
           "-DCMAKE_CXX_FLAGS=-I$HDR/prefix/include -I$VK" "-DCMAKE_C_FLAGS=-I$HDR/prefix/include")
fi

# ── build (Vulkan), libraries found next to the binaries
nice -n 15 cmake -S "$SRC" -B "$SRC/build" -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release \
    '-DCMAKE_INSTALL_RPATH=$ORIGIN' -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON "${EXTRA[@]}" >/dev/null
nice -n 15 cmake --build "$SRC/build" --config Release -j "$(( $(nproc) > 2 ? $(nproc) - 2 : 2 ))"
mkdir -p "$OUT"
for f in tts-server qwen-tts qwen-codec; do
    cp -f "$SRC/build/$f" "$OUT/$f.new" && mv -f "$OUT/$f.new" "$OUT/$f"
done
cp -af "$SRC/build/"libggml*.so* "$OUT/"

# ── the model (resumes a broken download)
mkdir -p "$MODELS"
for f in "${FILES[@]}"; do
    curl -sSL --fail -C - --retry 5 -o "$MODELS/$f" "$HF/$f"
done

# ── Velly's voices (a reference take per voice)
python3 "$HERE/../../bin/velvet-voice" --make-qwen-voices
echo "done — SETTINGS → MODULES → VELLY → STIMM-ENGINE → QWEN3"
