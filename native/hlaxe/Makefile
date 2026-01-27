# HashLink FMOD native library Makefile

HAXEFMOD_ROOT := ../..
FMOD_LINUX := $(HAXEFMOD_ROOT)/lib/Linux

CC := gcc
CFLAGS := -shared -fPIC
INCLUDES := -I/usr/include \
            -I$(FMOD_LINUX)/api/core/inc \
            -I$(FMOD_LINUX)/api/studio/inc
LIBDIRS := -L$(FMOD_LINUX)/api/core/lib/x86_64 \
           -L$(FMOD_LINUX)/api/studio/lib/x86_64
LIBS := -lfmod -lfmodstudio -lpthread

TARGET := hlaxe_fmod.hdll
SOURCE := hlaxe_fmod.c

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $@ $< $(INCLUDES) $(LIBDIRS) $(LIBS)

clean:
	rm -f $(TARGET)
