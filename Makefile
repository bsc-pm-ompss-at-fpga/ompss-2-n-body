# Compilers
CC=gcc
MCC=mcc

# Nbody parameters
BIGO?=N2
BS?=2048

# Preprocessor flags
CPPFLAGS=-Isrc -DBIGO=$(BIGO) -D_BIGO_$(BIGO) -DBLOCK_SIZE=$(BS)

# Compiler flags
CFLAGS=-O3 -std=gnu11
MCCFLAGS=--ompss-2 $(CFLAGS) --Wn,-O3,-std=gnu11

# Linker flags
LDFLAGS=-lrt -lm

SMP_SOURCES=                           \
    src/common/common.c                \
    src/blocking/common/common_utils.c \
    src/blocking/smp/utils.c           \
    src/blocking/smp/main.c

PROGS=                                \
    nbody_ompss.$(BIGO).$(BS).exe

all: $(PROGS)

nbody_ompss.$(BIGO).$(BS).exe: $(SMP_SOURCES) src/blocking/smp/solver_ompss.c
	$(MCC) $(CPPFLAGS) $(MCCFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f *.o *.exe
