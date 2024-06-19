#!/bin/bash

build_test() {
    TEST_PATH=$1
    TEST_FBASENAME="$(basename "$TEST_PATH")"
    TEST_FBASENAME="${TEST_FBASENAME%.*}"
    riscv64-zephyr-elf-gcc -march=rv32i_zicsr_zbs -static -nostdlib -nostartfiles -g \
        -T link.ld \
        "$TEST_PATH" -o "bin/$TEST_FBASENAME.elf" \
        -DXLEN=32 -mabi=ilp32
}

mkdir -p bin/

build_test ./clic_preemption-01.S
build_test ./clic_priorities-01.S
build_test ./clic_level_prio-01.S
build_test ./clic_indirect_csr-01.S

