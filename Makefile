.PHONY: clean
all: help

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

common-help:
	@echo 'Supported targets:           $(PROGRAM_)-p, $(PROGRAM_)-i, $(PROGRAM_)-d, $(PROGRAM_)-seq, design-p, design-i, design-d, bitstream-p, bitstream-i, bitstream-d, clean, help'
	@echo 'FPGA env. variables:         BOARD, FPGA_CLOCK, FPGA_MEMORY_PORT_WIDTH, MEMORY_INTERLEAVING_STRIDE, SIMPLIFY_INTERCONNECTION, INTERCONNECT_OPT, INTERCONNECT_REGSLICE, FLOORPLANNING_CONSTR, SLR_SLICES, PLACEMENT_FILE'
	@echo 'Benchmark env. variables:    BIGO, NBODY_BLOCK_SIZE, NBODY_NCALCFORCES, NBODY_NUM_FBLOCK_ACCS'

# FPGA bitstream parameters
FPGA_CLOCK             ?= 200
FPGA_HWRUNTIME         ?= pom
FPGA_MEMORY_PORT_WIDTH ?= 128
INTERCONNECT_OPT       ?= performance

# Nbody parameters
BIGO                  ?= N2
NBODY_BLOCK_SIZE      ?= 2048
NBODY_NCALCFORCES     ?= 8
NBODY_NUM_FBLOCK_ACCS ?= 1
BS                     = $(NBODY_BLOCK_SIZE)

# Preprocessor flags
COMPILER_FLAGS_ += -DFPGA_HWRUNTIME=\"$(FPGA_HWRUNTIME)\" -DBOARD=\"$(BOARD)\" -DFPGA_MEMORY_PORT_WIDTH=$(FPGA_MEMORY_PORT_WIDTH) -DFPGA_CLOCK=$(FPGA_CLOCK)
COMPILER_FLAGS_ += -Isrc -DBIGO=$(BIGO) -D_BIGO_$(BIGO) -DBLOCK_SIZE=$(BS) -DNBODY_BLOCK_SIZE=$(NBODY_BLOCK_SIZE) -DNBODY_NCALCFORCES=$(NBODY_NCALCFORCES) -DNBODY_NUM_FBLOCK_ACCS=$(NBODY_NUM_FBLOCK_ACCS)

# Linker flags
LINKER_FLAGS_ += -lrt -lm

PROGRAM_SRC = \
    src/common/common.c                \
    src/blocking/common/common_utils.c \
    src/blocking/fpga/utils.c          \
    src/blocking/fpga/main.c           \
	src/blocking/fpga/solver_ompss.c

$(PROGRAM_)-p: $(PROGRAM_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $^ -o $@ $(LINKER_FLAGS_)

$(PROGRAM_)-i: $(PROGRAM_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_I_) $^ -o $@ $(LINKER_FLAGS_)

$(PROGRAM_)-d: $(PROGRAM_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_D_) $^ -o $@ $(LINKER_FLAGS_)

$(PROGRAM_)-seq: $(PROGRAM_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $^ -o $@ $(LINKER_FLAGS_)

design-p: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_DESIGN_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

design-i: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_I_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_DESIGN_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

design-d: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_D_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_DESIGN_) $(AIT_FLAGS_D_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

bitstream-p: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) \
		$(AIT_FLAGS_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

bitstream-i: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_I_) \
		$(AIT_FLAGS_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

bitstream-d: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_D_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_D_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

