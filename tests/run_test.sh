function run_test ()
{
    # Generate names of memory files
    PROG_NAME=$1
    PMEM="../prog/${PROG_NAME}.pmem"
    DMEM_IN="../prog/${PROG_NAME}.dmem"
    DMEM_OUT="../prog/${PROG_NAME}.dmem.postsim"
    DMEM_GOLD="../prog/${PROG_NAME}.dmem.golden"

    # How many cycles should be run?
    PIPE_DEPTH=5
    NUM_CYCLES=$(wc -l ${PMEM} | awk '{print $1}')
    NUM_CYCLES=$(($NUM_CYCLES + $PIPE_DEPTH))
    
    # Generate simulator command
    SIM="../bench/swt16/Vswt16_top"
    SIM_CMD="${SIM} --simTime $((2*$NUM_CYCLES)) --pmemFile ${PMEM} --dmemFile ${DMEM_IN} --dmemDump"
    
    # Run simulation
    echo "======================================="
    echo "Test program: ${PROG_NAME}"
    echo "Test cycles : ${NUM_CYCLES}"
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

NUM_FAILED=0
run_test "hex_test_bypass_stall";  NUM_FAILED=$(($NUM_FAILED + $?))
run_test "hex_test_arith";         NUM_FAILED=$(($NUM_FAILED + $?))

echo "======================================="

if [ "$NUM_FAILED" = "0" ]; then
    echo "SUCCESS: ALL TESTS PASSED."
else
    echo "FAILURE: NUMBER OF FAILED TESTS = ${NUM_FAILED}"
fi

