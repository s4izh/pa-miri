#!/bin/bash

set -e

PROGRAMS_DIR="programs"
TOHOST_TESTS_DIR="tohost_tests"
ORCHESTRATOR_TEST="rv_processor_a1_unicycle.anyrom"
SIMULATOR="vsim"

TEST_LIST=()
TEST_DIR_PATH="${PROGRAMS_DIR}/${TOHOST_TESTS_DIR}"

if [ ! -d "${TEST_DIR_PATH}" ]; then
    echo "[ERROR] Test directory not found: ${TEST_DIR_PATH}"
    echo "Please create it and move your 'tohost' assembly tests there."
    exit 1
fi

for test_file in $(find "${TEST_DIR_PATH}" -maxdepth 1 -name "*.s"); do
    target_name="${TOHOST_TESTS_DIR}/$(basename "${test_file}" .s)"
    TEST_LIST+=("${target_name}")
done

total_tests=${#TEST_LIST[@]}

if [ ${total_tests} -eq 0 ]; then
    echo "[WARNING] No tests found in ${TEST_DIR_PATH}. Exiting."
    exit 0
fi

declare -A test_results
declare -A test_failure_reasons
declare -A test_wave_commands
any_failures=0

echo "========================================================"
echo "Starting RISC-V Processor Regression"
echo "Found ${total_tests} tests in '${TEST_DIR_PATH}'"
echo "Simulator: ${SIMULATOR}"
echo "========================================================"

make -C "${PROGRAMS_DIR}" clean

for test_target in "${TEST_LIST[@]}"; do
    test_name=$(basename "${test_target}")
    
    echo
    echo "--------------------------------------------------------"
    echo ">> [STARTING] Test: ${test_name}"
    echo "--------------------------------------------------------"

    echo ">> Compiling assembly for ${test_target}..."
    if ! make -C "${PROGRAMS_DIR}" TARGET="${test_target}"; then
        echo ">> [FAIL] Assembly compilation failed for ${test_target}"
        test_results["${test_target}"]=$'[FAIL]'
        test_failure_reasons["${test_target}"]="Assembly compilation failed."
        test_wave_commands["${test_target}"]="N/A - Simulation did not run."
        any_failures=1
        continue
    fi
    echo ">> Compilation successful."

    ROM_FILE="${PROGRAMS_DIR}/${test_target}.rom.hex"
    SRAM_FILE="${PROGRAMS_DIR}/${test_target}.sram.hex"

    if [ ! -f "${ROM_FILE}" ]; then
        echo ">> [FAIL] Hex file not found after compilation: ${ROM_FILE}"
        test_results["${test_target}"]=$'[FAIL]'
        test_failure_reasons["${test_target}"]="Hex file was not generated."
        test_wave_commands["${test_target}"]="N/A - Simulation did not run."
        any_failures=1
        continue
    fi

    echo ">> Simulating..."
    output=$(./tools/orchestrator simulate \
        --test "${ORCHESTRATOR_TEST}" \
        --sim "${SIMULATOR}" \
        --rom_file "${ROM_FILE}" \
        --sram_file "${SRAM_FILE}" || true)

    result_line=$(echo "${output}" | grep "tohost was written with value:")
    wave_command_base="./tools/orchestrator waves --test \"${ORCHESTRATOR_TEST}\" --sim \"${SIMULATOR}\""
    
    echo ">> Analyzing results..."

    if [[ -z "$result_line" ]]; then
        echo ">> [FAIL] Test: ${test_name} (TIMEOUT/CRASH)"
        test_results["${test_target}"]=$'[FAIL]'
        test_failure_reasons["${test_target}"]="Simulation timed out or crashed. No 'tohost' signature found."
        test_wave_commands["${test_target}"]="${wave_command_base}"
        any_failures=1
    else
        result_value=$(echo "${result_line}" | awk '{print $NF}')
        if [[ "$result_value" == "0" ]]; then
            echo ">> [PASS] Test: ${test_name}"
            test_results["${test_target}"]=$'[PASS]'
        else
            echo ">> [FAIL] Test: ${test_name} (WRONG VALUE)"
            test_results["${test_target}"]=$'[FAIL]'
            test_failure_reasons["${test_target}"]="Incorrect 'tohost' value. Expected 0, but got ${result_value}."
            test_wave_commands["${test_target}"]="${wave_command_base}"
            any_failures=1
        fi
    fi
done

if [ ${any_failures} -ne 0 ]; then
    echo
    echo "========================================================"
    echo "Detailed Failure Report"
    echo "========================================================"
    for test_target in "${TEST_LIST[@]}"; do
        result=${test_results[${test_target}]}
        if [[ "$result" == "[FAIL]" ]]; then
            test_name=$(basename "${test_target}")
            reason=${test_failure_reasons[${test_target}]}
            wave_cmd_base=${test_wave_commands[${test_target}]}

            printf "%-20s %s\n" "Test: ${test_name}" "${result}"
            printf "  - Reason: %s\n" "${reason}"

            if [[ "${wave_cmd_base}" != N/A* ]]; then
                ROM_FILE="${PROGRAMS_DIR}/${test_target}.rom.hex"
                SRAM_FILE="${PROGRAMS_DIR}/${test_target}.sram.hex"
                full_wave_cmd="${wave_cmd_base} --rom_file \"${ROM_FILE}\" --sram_file \"${SRAM_FILE}\""
                echo "  - To view waves, run:"
                echo "      ${full_wave_cmd}"
            fi
            echo "--------------------------------------------------------"
        fi
    done
fi

echo
echo "========================================================"
echo "Regression Summary"
echo "========================================================"
for test_target in "${TEST_LIST[@]}"; do
    test_name=$(basename "${test_target}")
    result=${test_results[${test_target}]}
    printf "%-20s %s\n" "Test: ${test_name}" "${result}"
done

if [ ${any_failures} -ne 0 ]; then
    echo "========================================================"
    echo "Some tests failed. Please refer to the detailed report above."
    exit 1
else
    echo "========================================================"
    echo "All tests passed successfully!"
    exit 0
fi
