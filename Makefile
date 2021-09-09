# Compilers
CC=gcc
MCC=fpgacc

# Nbody parameters
BIGO?=N2
BS?=2048

# FPGA bitstream parameters
FPGA_HWRUNTIME          = pom
FPGA_CLOCK             ?= 200
FPGA_MEMORY_PORT_WIDTH ?= 128
NBODY_BLOCK_SIZE       ?= 2048
NBODY_NCALCFORCES      ?= 8
NBODY_NUM_FBLOCK_ACCS  ?= 1

# Preprocessor flags
CPPFLAGS=-Isrc -DBIGO=$(BIGO) -D_BIGO_$(BIGO) -DBLOCK_SIZE=$(BS) -DNBODY_BLOCK_SIZE=$(NBODY_BLOCK_SIZE) -DNBODY_NCALCFORCES=$(NBODY_NCALCFORCES) -DNBODY_NUM_FBLOCK_ACCS=$(NBODY_NUM_FBLOCK_ACCS) -DFPGA_MEMORY_PORT_WIDTH=$(FPGA_MEMORY_PORT_WIDTH)

# Compiler flags
CFLAGS=-O3 -std=gnu11 -k
MCCFLAGS=--ompss-2 --fpga $(CFLAGS) --Wn,-O3,-std=gnu11

# Linker flags
LDFLAGS=-lrt -lm

FPGA_LINKER_FLAGS_ =--Wf,--name=nbody,--board=$(BOARD),-c=$(FPGA_CLOCK),--hwruntime=$(FPGA_HWRUNTIME),--interconnect_opt=performance,--picos_max_deps_per_task=3,--picos_max_args_per_task=11,--picos_max_copies_per_task=11,--picos_tm_size=32,--picos_dm_size=102,--picos_vm_size=102

ifdef INTERCONNECT_REGSLICE
	FPGA_LINKER_FLAGS_ += --Wf,--interconnect_regslice,$(INTERCONNECT_REGSLICE)
endif

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
