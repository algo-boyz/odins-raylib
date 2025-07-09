CC       := gcc
CC_FLAGS := -Wall -g

MIDDLEWARE_SRCS := input-handler.c float16.c
MIDDLEWARE_DIR  := src

BASE_OUTPUT  := input-handler.exe
BASE_SRCS    := device-tester.c
BASE_DIR     := src
BASE_INCLUDE := $(addprefix -I,$(BASE_DIR)) $(addprefix -I,$(MIDDLEWARE_DIR))
BASE_SOURCES := $(addprefix $(BASE_DIR)/,$(BASE_SRCS))  $(addprefix $(MIDDLEWARE_DIR)/,$(MIDDLEWARE_SRCS))

LIB_DIRS    :=
LIB_NAMES   := raylib opengl32 gdi32 winmm m
LIBS        := $(addprefix -l,$(LIBS)) $(addprefix -L,$(LIB_DIRS))

.PHONY: build

build:
	$(CC) $(CC_FLAGS) $(BASE_SOURCES) o $(BASE_OUTPUT) $(BASE_INCLUDE) $(LIBS)
