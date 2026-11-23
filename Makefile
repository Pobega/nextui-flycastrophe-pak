PAK_NAME ?= $(shell jq -r .name pak.json 2>/dev/null || echo DC)
PLATFORMS ?= tg5040 tg5050 h700

FLYCASTROPHE_REPO ?= https://github.com/Helaas/Flycastrophe.git
FLYCASTROPHE_COMMIT ?= 1d7ef4ed8640230a728dee0517a6088e2ff470fa
SUBMODULES := core/deps/asio core/deps/libchdr core/deps/rcheevos core/deps/tinygettext

CONTAINER_RUNTIME ?= $(shell command -v docker 2>/dev/null || command -v podman 2>/dev/null || (command -v flatpak-spawn >/dev/null 2>&1 && echo "flatpak-spawn --host podman"))
ifeq (,$(CONTAINER_RUNTIME))
$(error Neither docker nor podman found in PATH)
endif

ifneq (,$(findstring podman,$(CONTAINER_RUNTIME)))
CONTAINER_MOUNT_OPTS ?= --security-opt label=disable
else
CONTAINER_MOUNT_OPTS ?=
endif

PUSH_PLATFORM ?= tg5040
PUSH_SDCARD_PATH ?= /mnt/SDCARD

BUILD_DIR := $(CURDIR)/build
SRC_DIR := $(BUILD_DIR)/flycastrophe
CORES_DIR := $(BUILD_DIR)/cores
DIST_DIR := $(CURDIR)/dist

.PHONY: all src build package release bump-version push clean distclean $(foreach p,$(PLATFORMS),build-$(p))

all: release

src: $(SRC_DIR)/.patched

$(SRC_DIR)/.patched: $(wildcard $(CURDIR)/patches/*.patch)
	@mkdir -p $(BUILD_DIR)
	@if [ ! -d "$(SRC_DIR)/.git" ]; then \
		echo "Cloning $(FLYCASTROPHE_REPO)..."; \
		git clone $(FLYCASTROPHE_REPO) $(SRC_DIR); \
	fi
	@echo "Checking out $(FLYCASTROPHE_COMMIT)..."
	@git -C $(SRC_DIR) checkout -q $(FLYCASTROPHE_COMMIT)
	@echo "Updating submodules: $(SUBMODULES)..."
	@git -C $(SRC_DIR) submodule update --init --recursive $(SUBMODULES)
	@echo "Applying patches..."
	@for p in $(CURDIR)/patches/*.patch; do \
		[ -f "$$p" ] || continue; \
		if git -C $(SRC_DIR) apply -R --check "$$p" >/dev/null 2>&1; then \
			echo "Patch $$(basename "$$p") already applied"; \
		elif git -C $(SRC_DIR) apply --check "$$p" >/dev/null 2>&1; then \
			echo "Applying patch $$(basename "$$p")"; \
			git -C $(SRC_DIR) apply "$$p"; \
		else \
			echo "Error: Failed to apply patch $$p"; exit 1; \
		fi; \
	done
	@touch $(SRC_DIR)/.patched

build: $(foreach p,$(PLATFORMS),build-$(p))

CPU_FLAGS_tg5040 := -O3 -mcpu=cortex-a53 -mtune=cortex-a53
CPU_FLAGS_tg5050 := -O3 -mcpu=cortex-a55 -mtune=cortex-a55
CPU_FLAGS_h700 := -O3 -mcpu=cortex-a53 -mtune=cortex-a53

GLES_FLAGS_tg5040 := -DUSE_GLES=ON
GLES_FLAGS_tg5050 := -DUSE_GLES=OFF -DUSE_GLES2=ON -DCMAKE_C_STANDARD_INCLUDE_DIRECTORIES=/workspace/build/flycastrophe/core/deps/glad/include -DCMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES=/workspace/build/flycastrophe/core/deps/glad/include -DCMAKE_SHARED_LINKER_FLAGS=-lmali
GLES_FLAGS_h700 := -DUSE_GLES=ON

define BUILD_PLATFORM_RULE
build-$(1): src
	@echo "Building flycastrophe_libretro.so for $(1)..."
	@mkdir -p $(CORES_DIR)/$(1) $(BUILD_DIR)/build-$(1)
	$$(CONTAINER_RUNTIME) run --rm $$(CONTAINER_MOUNT_OPTS) \
		-v $$(CURDIR):/workspace:rw \
		ghcr.io/loveretro/$(1)-toolchain:latest \
		bash -euc '\
			git config --global --add safe.directory "*" && \
			cd /workspace/build/flycastrophe && \
			cmake -S . -B /workspace/build/build-$(1) -G Ninja \
				-DCMAKE_TOOLCHAIN_FILE=/opt/aarch64-nextui-linux-gnu/Toolchain.cmake \
				-DCMAKE_BUILD_TYPE=Release \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
				-DLIBRETRO=ON \
				-DFLYCASTROPHE=ON \
				$(GLES_FLAGS_$(1)) \
				-DUSE_VULKAN=OFF \
				-DUSE_OPENMP=OFF \
				-DUSE_HOST_LIBZIP=OFF \
				-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
				-DCMAKE_C_FLAGS="$(CPU_FLAGS_$(1))" \
				-DCMAKE_CXX_FLAGS="$(CPU_FLAGS_$(1))" \
				-DCMAKE_SYSTEM_NAME=Linux \
				-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
				-DCMAKE_SYSROOT=/opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc \
				-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER && \
			ninja -C /workspace/build/build-$(1) flycast_libretro && \
			mkdir -p /workspace/build/cores/$(1) && \
			cp /workspace/build/build-$(1)/flycastrophe_libretro.so /workspace/build/cores/$(1)/flycastrophe_libretro.so && \
			/opt/aarch64-nextui-linux-gnu/bin/aarch64-nextui-linux-gnu-strip --strip-unneeded /workspace/build/cores/$(1)/flycastrophe_libretro.so && \
			chmod 0755 /workspace/build/cores/$(1)/flycastrophe_libretro.so \
		'
endef

$(foreach p,$(PLATFORMS),$(eval $(call BUILD_PLATFORM_RULE,$(p))))

package:
	@echo "Packaging $(PAK_NAME).pak.zip and platform distributions..."
	@mkdir -p $(DIST_DIR)
	@rm -rf $(BUILD_DIR)/staging $(DIST_DIR)/$(PAK_NAME).pak.zip
	@mkdir -p $(BUILD_DIR)/staging/cores/tg5040 $(BUILD_DIR)/staging/cores/tg5050 $(BUILD_DIR)/staging/cores/h700
	@cp pak.json launch.sh default*.cfg LICENSE README.md $(BUILD_DIR)/staging/
	@chmod 0755 $(BUILD_DIR)/staging/launch.sh
	@cp $(CORES_DIR)/tg5040/flycastrophe_libretro.so $(BUILD_DIR)/staging/cores/tg5040/
	@cp $(CORES_DIR)/tg5050/flycastrophe_libretro.so $(BUILD_DIR)/staging/cores/tg5050/
	@cp $(CORES_DIR)/h700/flycastrophe_libretro.so $(BUILD_DIR)/staging/cores/h700/
	@cd $(BUILD_DIR)/staging && zip -r $(DIST_DIR)/$(PAK_NAME).pak.zip .
	@mkdir -p $(DIST_DIR)/Emus/tg5040/$(PAK_NAME).pak $(DIST_DIR)/Emus/tg5050/$(PAK_NAME).pak $(DIST_DIR)/Emus/h700/$(PAK_NAME).pak
	@cp launch.sh $(DIST_DIR)/Emus/tg5040/$(PAK_NAME).pak/
	@cp default-smartpro.cfg $(DIST_DIR)/Emus/tg5040/$(PAK_NAME).pak/default.cfg
	@cp default-brick.cfg $(DIST_DIR)/Emus/tg5040/$(PAK_NAME).pak/
	@cp $(CORES_DIR)/tg5040/flycastrophe_libretro.so $(DIST_DIR)/Emus/tg5040/$(PAK_NAME).pak/
	@cp launch.sh $(DIST_DIR)/Emus/tg5050/$(PAK_NAME).pak/
	@cp default-smartpros.cfg $(DIST_DIR)/Emus/tg5050/$(PAK_NAME).pak/default.cfg
	@cp default-brickpro.cfg $(DIST_DIR)/Emus/tg5050/$(PAK_NAME).pak/
	@cp $(CORES_DIR)/tg5050/flycastrophe_libretro.so $(DIST_DIR)/Emus/tg5050/$(PAK_NAME).pak/
>>>>>>> 733c7f9 (feat: add tg5050 platform build and bundled minarch.elf)
	@cp launch.sh $(DIST_DIR)/Emus/h700/$(PAK_NAME).pak/
	@cp default.cfg $(DIST_DIR)/Emus/h700/$(PAK_NAME).pak/default.cfg
	@cp $(CORES_DIR)/h700/flycastrophe_libretro.so $(DIST_DIR)/Emus/h700/$(PAK_NAME).pak/
	@echo "Successfully packaged $(DIST_DIR)/$(PAK_NAME).pak.zip"

release: build package

bump-version:
ifneq ($(strip $(RELEASE_VERSION)),)
	@jq --arg v "$(RELEASE_VERSION)" '.version = ($$v | sub("^v"; ""))' pak.json > pak.json.tmp && mv pak.json.tmp pak.json
	@echo "Version bumped to $$(jq -r .version pak.json)"
endif

push: release
	adb push $(DIST_DIR)/Emus/$(PUSH_PLATFORM)/$(PAK_NAME).pak/. $(PUSH_SDCARD_PATH)/Emus/$(PUSH_PLATFORM)/$(PAK_NAME).pak

clean:
	rm -rf $(BUILD_DIR)/build-* $(BUILD_DIR)/cores $(BUILD_DIR)/staging $(DIST_DIR)

distclean: clean
	rm -rf $(BUILD_DIR)
