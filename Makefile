.PHONY: clean
all: help

# Compilers

# Include the corresponding compiler makefile
--setup: FORCE
  ifeq ($(COMPILER),llvm)
    include llvm.mk
  else
    ifeq ($(COMPILER),mcxx)
      include mcxx.mk
    else
      $(info No valid COMPILER variable defined, using mcxx)
      include mcxx.mk
    endif
  endif
FORCE:

PROGRAM_ = nbody

# Nbody parameters
BIGO?=N2

# FPGA bitstream parameters
FPGA_HWRUNTIME          = pom
FPGA_CLOCK             ?= 200
FPGA_MEMORY_PORT_WIDTH ?= 128
NBODY_BLOCK_SIZE       ?= 2048
NBODY_NCALCFORCES      ?= 8
NBODY_NUM_FBLOCK_ACCS  ?= 1

BS=$(NBODY_BLOCK_SIZE)

# Preprocessor flags
COMPILER_FLAGS_ += -Isrc -DBIGO=$(BIGO) -D_BIGO_$(BIGO) -DBLOCK_SIZE=$(BS) -DNBODY_BLOCK_SIZE=$(NBODY_BLOCK_SIZE) -DNBODY_NCALCFORCES=$(NBODY_NCALCFORCES) -DNBODY_NUM_FBLOCK_ACCS=$(NBODY_NUM_FBLOCK_ACCS) -DFPGA_MEMORY_PORT_WIDTH=$(FPGA_MEMORY_PORT_WIDTH) -DFPGA_CLOCK=$(FPGA_CLOCK) -DFPGA_HWRUNTIME=\"$(FPGA_HWRUNTIME)\" -DBOARD=\"$(BOARD)\"
 

common-help:
	@echo 'Supported targets:        $(PROGRAM_)-p, $(PROGRAM_)-i, $(PROGRAM_)-d, $(PROGRAM_)-seq, design-p, design-i, design-d, bitstream-p, bitstream-i, bitstream-d, clean, help'
	@echo 'FPGA env. variables:      BOARD, FPGA_CLOCK'
	@echo 'FPGA opt. env. variables: FPGA_MEMORY_PORT_WIDTH, MEMORY_INTERLEAVING_STRIDE, SIMPLIFY_INTERCONNECTION, INTERCONNECT_OPT, INTERCONNECT_REGSLICE, FLOORPLANNING_CONSTR, SLR_SLICES, PLACEMENT_FILE'


# Compiler flags
#CFLAGS=-O3 -std=gnu11
#MCCFLAGS=--ompss-2 --fpga $(CFLAGS) --Wn,-O3,-std=gnu11

# Linker flags
LINKER_FLAGS_ += -lrt -lm

SMP_SOURCES=                           \
    src/common/common.c                \
    src/blocking/common/common_utils.c \
    src/blocking/fpga/utils.c          \
    src/blocking/fpga/main.c

#PROGS=                                \
#    nbody_ompss.$(BIGO).$(BS).exe

NBODY_SRC = $(SMP_SOURCES) src/blocking/fpga/solver_ompss.c

$(PROGRAM_)-p: $(NBODY_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $^ -o $@ $(LINKER_FLAGS_)

$(PROGRAM_)-i: $(NBODY_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_I_) $^ -o $@ $(LINKER_FLAGS_)

$(PROGRAM_)-d: $(NBODY_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_D_) $^ -o $@ $(LINKER_FLAGS_)

$(PROGRAM_)-seq: ./src/$(PROGRAM_).c
	$(COMPILER_) $(COMPILER_FLAGS_) $^ -o $@ $(LINKER_FLAGS_)

design-p: $(NBODY_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_DESIGN_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

design-i: $(NBODY_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_I_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_DESIGN_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

design-d: $(NBODY_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_D_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_DESIGN_) $(AIT_FLAGS_D_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

bitstream-p: $(NBODY_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) \
		$(AIT_FLAGS_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

bitstream-i: $(NBODY_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_I_) \
		$(AIT_FLAGS_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

bitstream-d: $(NBODY_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_D_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_D_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)


#nbody_ompss.$(BIGO).$(BS).exe: $(SMP_SOURCES) src/blocking/fpga/solver_ompss.c
#	$(MCC) $(CPPFLAGS) $(MCCFLAGS) -o $@ $^ $(LDFLAGS)
#
#design-p: $(SMP_SOURCES) src/blocking/fpga/solver_ompss.c
#	$(eval TMPFILE := $(shell mktemp))
#	$(MCC) $(CPPFLAGS) $(MCCFLAGS) --bitstream-generation $(FPGA_LINKER_FLAGS_) \
#		--Wf,--to_step=design \
#		$^ -o $(TMPFILE) $(LDFLAGS)
#	rm $(TMPFILE)
#
#bitstream-p: $(SMP_SOURCES) src/blocking/fpga/solver_ompss.c
#	$(eval TMPFILE := $(shell mktemp))
#	$(MCC) $(CPPFLAGS) $(MCCFLAGS) --bitstream-generation $(FPGA_LINKER_FLAGS_) \
#		$^ -o $(TMPFILE) $(LDFLAGS)
#	rm $(TMPFILE)
#
#clean:
#	rm -f *.o *.exe fpgacc_* *_auto_mcxx.cpp *_ompss.cpp ait_*.json
#	rm -fr $(PROGRAM_)_ait
