// Test MNLBITS = 0 (all 8 bits of CLICINTCTL encode priority)

#define WORD_NBYTES XLEN/8

#define CLIC_BASE 0x04000000
#define UART_BASE 0xd0000000

#define INT1_EXCNO 16
#define INT1_CLICBASE (CLIC_BASE + 0x1000 + (INT1_EXCNO << 2))
// machine mode (mode 11), positive edge triggered (trig 01)
#define INT1_CLICINTATTR_VAL 0xc2
// priority 0x2
#define INT1_CLICINTCTL_VAL 0x2
#define INT1_CLICINTIE_VAL 0x1

#define INT2_EXCNO 17 
#define INT2_CLICBASE (CLIC_BASE + 0x1000 + (INT2_EXCNO << 2))
// machine mode (mode 11), positive edge triggered (trig 01)
#define INT2_CLICINTATTR_VAL 0xc2
// priority 0x1
#define INT2_CLICINTCTL_VAL 0x1
#define INT2_CLICINTIE_VAL 0x1

#define INT3_EXCNO 18
#define INT3_CLICBASE (CLIC_BASE + 0x1000 + (INT3_EXCNO << 2))
// machine mode (mode 11), positive edge triggered (trig 01)
#define INT3_CLICINTATTR_VAL 0xc2
// priority 0x3
#define INT3_CLICINTCTL_VAL 0x3
#define INT3_CLICINTIE_VAL 0x1

#define MSTATUS_MIE 0x8

#define CSR_MSTATUS 0x300
#define CSR_MTVEC 0x305
#define CSR_MINTTHRESH 0x347

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
    // Initialize mtvec in CLIC mode
    la t0, mtvec_base
    ori t0, t0, 3
    csrw CSR_MTVEC, t0

    // Register interrupt 1
    li t0, INT1_CLICBASE
    li t1, ((INT1_CLICINTCTL_VAL << 24) + (INT1_CLICINTATTR_VAL << 16) + (INT1_CLICINTIE_VAL << 8))
    sw t1, (t0)

    // Register interrupt 2
    li t0, INT2_CLICBASE
    li t1, ((INT2_CLICINTCTL_VAL << 24) + (INT2_CLICINTATTR_VAL << 16) + (INT2_CLICINTIE_VAL << 8))
    sw t1, (t0)

    // Register interrupt 3
    li t0, INT3_CLICBASE
    li t1, ((INT3_CLICINTCTL_VAL << 24) + (INT3_CLICINTATTR_VAL << 16) + (INT3_CLICINTIE_VAL << 8))
    sw t1, (t0)

    // mintthresh should be 0 - all levels active
    csrw CSR_MINTTHRESH, zero

    la t0, msg0
    jal t1, print_message

    // Wait for Renode to set the GPIO signals enabling all 3 interrupts.
    // It then stores a non-zero value under renode_flag, moving execution further.
wait_for_renode:
    lb t0, renode_flag
    beqz t0, wait_for_renode

    // Enable global interrupts
    csrrsi zero, CSR_MSTATUS, MSTATUS_MIE

    wfi

end_loop:
    j end_loop

// t0 is the string address, t1 saved pc
print_message:
    la t3, UART_BASE
print_message_loop:
    lb t2, (t0)
    addi t0, t0, 1
    sw t2, (t3)
    addi t2, t2, -'\n'
    beq t2, zero, print_message_end
    j print_message_loop
print_message_end:
    jalr zero, t1

.align 8
.globl mtvec_base
mtvec_base:
    // Enable preemption - by default not preemptible
    // Priorities do not influence preemption, so it shouldn't really matter here.
    csrrsi zero, mstatus, MSTATUS_MIE

    // Jump to interrupt-specific code
    csrr t0, mcause
    andi t0, t0, 0xff
    li t2, 0x10
    beq t0, t2, choose_int1
    li t2, 0x11
    beq t0, t2, choose_int2
    li t2, 0x12
    beq t0, t2, choose_int3
choose_int1:
    // Clear interrupt pending
    la t0, INT1_CLICBASE
    sb zero, (t0)

    // Print message
    la t0, msg_int1
    j print_end
choose_int2:
    la t0, INT2_CLICBASE
    sb zero, (t0)
    la t0, msg_int2
    j print_end
choose_int3:
    la t0, INT3_CLICBASE
    sb zero, (t0)
    la t0, msg_int3
    j print_end
print_end:
    jal t1, print_message
    mret

.section .rodata
msg0:
    .string "Init complete\n"
msg_int1:
    .string "Interrupt 16, priority 2\n"
msg_int2:
    .string "Interrupt 17, priority 1\n"
msg_int3:
    .string "Interrupt 18, priority 3\n"

.section .data
.globl renode_flag
renode_flag:
    .byte 0x00
