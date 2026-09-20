#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITPRO)/libnx/switch_rules

#---------------------------------------------------------------------------------
TARGET		:=	$(notdir $(CURDIR))
APP_TITLE	:=	NetherSX2
APP_AUTHOR	:=	naga
APP_VERSION	:=	1.3.0
BUILD		:=	build
SOURCES		:=	source source/hooks source/switch
DATA		:=	data
INCLUDES	:=	source source/switch \
			launcher/dependencies/build/_deps/libsmb2-src/include \
			launcher/dependencies/build/_deps/libusbhsfs-src/include

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
ARCH	:=	-march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE
LTOFLAGS := -flto=auto -fuse-linker-plugin

# __SWITCH__ for libnx; NETHERSX2 gates the port-specific shim branches.
DEFINES	:=	-D__SWITCH__ -DNETHERSX2 -DCURL_STATICLIB \
			-DNETHERSX2_VERSION='"$(APP_VERSION)"'

ifneq ($(strip $(NETHERSX2_VK_DIAGNOSTIC)),)
DEFINES += -DNETHERSX2_VK_DIAGNOSTIC
endif

# --- renderer: Vulkan via nxvk ONLY ---------------------------------------
# The switch-mesa OpenGL (NVC0 nouveau) path was removed: on Tegra X1 the
# native API is Vulkan (NVK). RENDERER is accepted as a no-op so old
# invocations keep working.
RENDERER ?= VK
# nxvk SDK (PalindromicBreadLoaf/nxvk): `make` stages switch/build/pkg with
# include/vulkan/ + lib/libnvk.a + lib/libnvk_support.a. Point NXVK_SDK_ROOT
# at that staged dir (CI downloads it as an artifact). Empty = nxvk
# installed as a devkitPro portlib (headers/libs come from PORTLIBS).
NXVK_SDK_ROOT ?=
NXVK_ROOT := $(if $(strip $(NXVK_SDK_ROOT)),$(NXVK_SDK_ROOT),$(PORTLIBS))
DEFINES	+=	-DUSE_VULKAN -DGS_RENDERER=14 -DVK_USE_PLATFORM_VI_NN
SOURCES	+=	source/lsfg \
			third_party/lsfg-vk/lsfg-vk-common/src/helpers \
			third_party/lsfg-vk/lsfg-vk-common/src/vulkan \
			third_party/lsfg-vk/lsfg-vk-backend/src \
			third_party/lsfg-vk/lsfg-vk-backend/src/extraction \
			third_party/lsfg-vk/lsfg-vk-backend/src/helpers \
			third_party/lsfg-vk/lsfg-vk-backend/src/shaderchains
INCLUDES	+=	source/lsfg \
			third_party/lsfg-vk/lsfg-vk-common/include \
			third_party/lsfg-vk/lsfg-vk-backend/include \
			third_party/lsfg-vk/lsfg-vk-backend/src

CFLAGS	:=	-g -Wall -O3 -ffunction-sections -fdata-sections -fno-omit-frame-pointer $(LTOFLAGS) \
			$(ARCH) $(DEFINES)
CFLAGS	+=	$(INCLUDE)
CXXFLAGS	:= $(CFLAGS) -std=gnu++20

ASFLAGS	:=	-g $(ARCH)
LDFLAGS	=	-specs=$(DEVKITPRO)/libnx/switch.specs -g $(ARCH) $(LTOFLAGS) -Wl,--gc-sections -Wl,-Map,$(notdir $*.map)

STORAGE_LIBS := $(TOPDIR)/launcher/dependencies/build/_deps/libsmb2-build/lib/libsmb2.a \
				$(TOPDIR)/launcher/dependencies/build/_deps/libusbhsfs-build/liblibusbhsfs.a \
				$(PORTLIBS)/lib/libntfs-3g.a

# nxvk link (see nxvk switch/README.md "Linking against the installed portlib"):
# whole-archive libnvk, support group (zlib+expat), ICD entrypoint pin.
# -lnx/-lstdc++/-lm stay after the driver (NAK's bundled Rust needs libgcc).
LIBDIRS	:= $(NXVK_ROOT) $(PORTLIBS) $(LIBNX)
LIBS	:= -Wl,--whole-archive -lnvk -Wl,--no-whole-archive \
		-Wl,--start-group -lnvk_support -lz -lexpat -Wl,--end-group \
		-Wl,-u,vk_icdGetInstanceProcAddr \
		$(STORAGE_LIBS) -lcurl -lnx -lstdc++ -lm

#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT	:=	$(CURDIR)/$(TARGET)
export TOPDIR	:=	$(CURDIR)

export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
			$(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR	:=	$(CURDIR)/$(BUILD)

CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
BINFILES	:=	$(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

#---------------------------------------------------------------------------------
# link with g++ so mesa's C++ EGL/GLES pulls in libstdc++
export LD	:=	$(CXX)

export OFILES_BIN	:=	$(addsuffix .o,$(BINFILES))
export OFILES_SRC	:=	$(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(SFILES:.s=.o)
export OFILES 	:=	$(OFILES_BIN) $(OFILES_SRC)
export HFILES_BIN	:=	$(addsuffix .h,$(subst .,_,$(BINFILES)))

export INCLUDE	:=	$(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
			$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
			-I$(CURDIR)/$(BUILD)

export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib)

ifeq ($(strip $(ICON)),)
	icons := $(wildcard *.jpg)
	ifneq (,$(findstring $(TARGET).jpg,$(icons)))
		export APP_ICON := $(TOPDIR)/$(TARGET).jpg
	else
		ifneq (,$(findstring icon.jpg,$(icons)))
			export APP_ICON := $(TOPDIR)/icon.jpg
		endif
	endif
else
	export APP_ICON := $(TOPDIR)/$(ICON)
endif

ifeq ($(strip $(NO_ICON)),)
	export NROFLAGS += --icon=$(APP_ICON)
endif

ifeq ($(strip $(NO_NACP)),)
	export NROFLAGS += --nacp=$(CURDIR)/$(TARGET).nacp
endif

ifneq ($(APP_TITLEID),)
	export NACPFLAGS += --titleid=$(APP_TITLEID)
endif

.PHONY: $(BUILD) clean all

#---------------------------------------------------------------------------------
all: $(BUILD)

$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

#---------------------------------------------------------------------------------
clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).nro $(TARGET).nacp $(TARGET).elf

#---------------------------------------------------------------------------------
else
.PHONY:	all

DEPENDS	:=	$(OFILES:.o=.d)

# libnx provides a weak 1 KiB __nx_exception_stack, while crash.c supplies the
# strong 512 KiB stack used by the re-entrant fastmem/JIT fault handler. Keep
# that defining object out of LTO so the linker sees the final strong size
# before the LTO plugin materializes symbols (and does not retain/report the
# weak libnx size).
crash.o: CFLAGS += -fno-lto

#---------------------------------------------------------------------------------
all	:	$(OUTPUT).nro

ifeq ($(strip $(NO_NACP)),)
$(OUTPUT).nro	:	$(OUTPUT).elf $(OUTPUT).nacp
else
$(OUTPUT).nro	:	$(OUTPUT).elf
endif

# Relink when the prebuilt storage archives change, not only on source edits.
$(OUTPUT).elf	:	$(OFILES) $(STORAGE_LIBS)

$(OFILES_SRC)	: $(HFILES_BIN)

%.bin.o	%_bin.h :	%.bin
	@echo $(notdir $<)
	@$(bin2o)

-include $(DEPENDS)

#---------------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------------
