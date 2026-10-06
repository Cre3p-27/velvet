# Builds against the Hyprland headers installed on this machine. A plugin is
# tied to the exact compositor build: after a Hyprland update, rebuild.
OUT ?= build/velvetzoom.so

all: $(OUT)

# Built beside the old file and moved over it: a running Hyprland has the old
# one mapped, and writing into that file in place would pull it out from under it.
$(OUT): main.cpp
	@mkdir -p $(dir $(OUT))
	g++ -shared -fPIC --no-gnu-unique main.cpp -o $(OUT).new -O2 -DWLR_USE_UNSTABLE -std=c++26 \
		$(shell pkg-config --cflags pixman-1 libdrm hyprland)
	mv -f $(OUT).new $(OUT)

clean:
	rm -rf build

.PHONY: all clean
