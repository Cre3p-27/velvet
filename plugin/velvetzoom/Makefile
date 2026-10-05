# Builds against the Hyprland headers installed on this machine. A plugin is
# tied to the exact compositor build: after a Hyprland update, rebuild.
OUT ?= build/velvetzoom.so

all: $(OUT)

$(OUT): main.cpp
	@mkdir -p $(dir $(OUT))
	g++ -shared -fPIC --no-gnu-unique main.cpp -o $(OUT) -O2 -DWLR_USE_UNSTABLE -std=c++26 \
		$(shell pkg-config --cflags pixman-1 libdrm hyprland)

clean:
	rm -rf build

.PHONY: all clean
