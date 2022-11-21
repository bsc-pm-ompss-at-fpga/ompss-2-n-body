#!/bin/bash -e

BUILD_TARGET=$1

if [ "$BOARD" == "" ]; then
  echo "BOARD environment variable not defined"
  exit 1
elif [ "$FPGA_HWRUNTIME" == "" ]; then
  echo "FPGA_HWRUNTIME environment variable not defined"
  exit 1
elif [ "$FPGA_CLOCK" == "" ]; then
  exit 1
fi

PROG_NAME=nbody
OUT_DIR=$(pwd -P)/build
RES_FILE=$(pwd -P)/resources_results.json

make clean
mkdir -p $OUT_DIR

if [ "$BUILD_TARGET" == "binary" ]; then
  #Only build the binaries
  make nbody_ompss.N2.${NBODY_BLOCK_SIZE}.exe
  mv nbody_ompss.N2.${NBODY_BLOCK_SIZE}.exe $OUT_DIR
else
  make bitstream-p

  mv ${PROG_NAME}_ait/${PROG_NAME}.bin $OUT_DIR/bitstream.bin
  mv ${PROG_NAME}_ait/${PROG_NAME}.bit $OUT_DIR/bitstream.bit
  mv ${PROG_NAME}_ait/${PROG_NAME}.xtasks.config $OUT_DIR/xtasks.config

  printf "{\"benchmark\": \"${PROG_NAME}\", " >>$RES_FILE
  printf "\"toolchain\": \"ompss-2\", " >>$RES_FILE
  printf "\"hwruntime\": \"${FPGA_HWRUNTIME}\", " >>$RES_FILE
  printf "\"board\": \"${BOARD}\", " >>$RES_FILE
  printf "\"builder\": \"${CI_NODE}\", " >>$RES_FILE
  printf "\"version\": \"${NBODY_NUM_FBLOCK_ACCS}accs ${NBODY_BLOCK_SIZE}BS ${FPGA_CLOCK}mhz memport_${FPGA_MEMORY_PORT_WIDTH}\", " >>$RES_FILE
  printf "\"accels_freq\": \"${FPGA_CLOCK}\", " >>$RES_FILE
  printf "\"memory_port_width\": \"${FPGA_MEMORY_PORT_WIDTH}" >>$RES_FILE
  for PARAM in BRAM DSP FF LUT; do
    printf "\", \"${PARAM}_HLS\": \"" >>$RES_FILE
    grep "$PARAM" ${PROG_NAME}_ait/${PROG_NAME}.resources-hls.txt | awk '{printf $2}' >>$RES_FILE
  done
  if $(grep -q URAM ${PROG_NAME}_ait/${PROG_NAME}.resources-hls.txt); then
    printf "\", \"URAM_HLS\": \"" >>$RES_FILE
    grep "URAM" ${PROG_NAME}_ait/${PROG_NAME}.resources-hls.txt | awk '{printf $2}' >>$RES_FILE
  fi
  for PARAM in BRAM DSP FF LUT; do
    printf "\", \"${PARAM}_IMPL\": \"" >>$RES_FILE
    grep "${PARAM}" ${PROG_NAME}_ait/${PROG_NAME}.resources-impl.txt | awk '{printf $2}' >>$RES_FILE
  done
  if $(grep -q URAM ${PROG_NAME}_ait/${PROG_NAME}.resources-impl.txt); then
    printf "\", \"URAM_IMPL\": \"" >>$RES_FILE
    grep "URAM" ${PROG_NAME}_ait/${PROG_NAME}.resources-impl.txt | awk '{printf $2}' >>$RES_FILE
  fi
  for PARAM in WNS TNS NUM_ENDPOINTS NUM_FAIL_ENDPOINTS; do
    printf "\", \"${PARAM}\": \"" >>$RES_FILE
    grep "${PARAM}" ${PROG_NAME}_ait/${PROG_NAME}.timing-impl.txt | awk '{printf $2}' >>$RES_FILE
  done
  printf "\"},\n" >>$RES_FILE
fi
