#!/bin/bash

BENCH_DIR="../bench"

function run_test ()
{
    # Generate names of memory files
    PROG_NAME=$1
    ASM="../prog/${PROG_NAME}.asm"
    PMEM="../prog/${PROG_NAME}.pmem"
    DMEM_IN="../prog/${PROG_NAME}.dmem"
    DMEM_OUT="../prog/${PROG_NAME}.dmem.postsim"
    DMEM_GOLD="../prog/${PROG_NAME}.dmem.golden"

    # Remove old postsim DMEM file
    rm -f $DMEM_OUT
    
    # Generate simulator command
    ASM_CMD="python ../utils/asm.py -i ${ASM} -o ${PMEM} -d ../utils/isa.xml -s"
    SIM="../bench/swt16/Vswt16_top"
    SIM_CMD="${SIM} --exitOnNop --pmemFile ${PMEM} --dmemFile ${DMEM_IN} --dmemDump"
    
    # Run simulation
    echo "======================================="
    echo "Test program: ${PROG_NAME}"
    echo ${ASM_CMD}
    eval ${ASM_CMD}
    echo ${SIM_CMD}
    eval ${SIM_CMD}

    # Compare generated DMEM file to golden DMEM file
    SUCCESS=0
    cmp --silent ${DMEM_OUT} ${DMEM_GOLD} || SUCCESS=1

    if [ "$SUCCESS" = "0" ]; then
        echo "SUCCESS."
    else
        echo "FAILURE."
    fi
    
    return $SUCCESS
}

# Build simulator
cd $BENCH_DIR && make

# Exit if simulator build failed
if [ "$?" != "0" ]; then
    echo "FAILURE: SIMULATOR BUILD FAILED."
    exit 1 # terminate and indicate error
fi


# Runt tests
NUM_FAILED=0
run_test "hex_test_bypass_stall";  NUM_FAILED=$(($NUM_FAILED + $?))
run_test "hex_test_arith";         NUM_FAILED=$(($NUM_FAILED + $?))
run_test "hex_test_branch";        NUM_FAILED=$(($NUM_FAILED + $?))
run_test "hex_test_jmp";           NUM_FAILED=$(($NUM_FAILED + $?))
run_test "hex_test_load_store";    NUM_FAILED=$(($NUM_FAILED + $?))
run_test "hex_test_factorial";     NUM_FAILED=$(($NUM_FAILED + $?))

echo "======================================="

if [ "$NUM_FAILED" = "0" ]; then
    echo "SUCCESS: ALL TESTS PASSED."
else
    echo "FAILURE: NUMBER OF FAILED TESTS = ${NUM_FAILED}"
fi

