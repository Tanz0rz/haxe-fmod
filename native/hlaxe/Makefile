# HashLink FMOD native library Makefile

HAXEFMOD_ROOT := ../..

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# ARM64 (Apple Silicon) Macs only - Intel Macs are not supported
ifeq ($(UNAME_S),Darwin)
ifneq ($(UNAME_M),arm64)
$(error This Makefile only supports ARM64 (Apple Silicon) Macs. Intel Mac support has not been implemented yet.)
endif
endif

TARGET := hlaxe_fmod.hdll
SOURCE := hlaxe_fmod.c

ifeq ($(UNAME_S),Darwin)
  # macOS (ARM64/Apple Silicon only)
  FMOD_DIR := $(HAXEFMOD_ROOT)/lib/Mac
  CC := cc
  CFLAGS := -dynamiclib -arch x86_64 -install_name @executable_path/$(TARGET)
  HL_INCLUDE := $(shell brew --prefix hashlink)/include
  INCLUDES := -I$(HL_INCLUDE) \
              -I$(FMOD_DIR)/api/core/inc \
              -I$(FMOD_DIR)/api/studio/inc
  LIBDIRS := -L$(FMOD_DIR)/api/core/lib \
             -L$(FMOD_DIR)/api/studio/inc/lib
  LIBS := -lfmod -lfmodstudio -lpthread
else
  # Linux
  FMOD_DIR := $(HAXEFMOD_ROOT)/lib/Linux
  CC := gcc
  CFLAGS := -shared -fPIC
  INCLUDES := -I/usr/include \
              -I$(FMOD_DIR)/api/core/inc \
              -I$(FMOD_DIR)/api/studio/inc
  LIBDIRS := -L$(FMOD_DIR)/api/core/lib/x86_64 \
             -L$(FMOD_DIR)/api/studio/lib/x86_64
  LIBS := -lfmod -lfmodstudio -lpthread
endif

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $@ $< $(INCLUDES) $(LIBDIRS) $(LIBS)

clean:
	rm -f $(TARGET)
