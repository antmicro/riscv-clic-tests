#define miselect 0x350
#define mireg 0x351
#define mireg2 0x352

#define miselect_clicintctl 0x1000
#define miselect_clicintipe 0x1400
#define miselect_clicinttrig 0x1480
#define miselect_xcliccfg 0x14a0

#define CLIC_BASE 0x04000000
#define CLIC_PENDING_BASE CLIC_BASE + 0x1000
#define CLIC_ENABLE_BASE CLIC_BASE + 0x1001
#define UART_TX 0xd0000000

// machine mode (mode 11), positive edge triggered (trig 01)
#define CLICINTATTR_VAL 0xc2
// priority 0x1
#define CLICINTCTL_VAL 0x1
// disabled
#define CLICINTIE_VAL 0x0

.globl rvtest_entry_point
rvtest_entry_point:
	// Set all interrupts to edge triggered so that we can change their pending bit
	li t0, 4096
	li t1, CLIC_PENDING_BASE
	li t2, ((CLICINTCTL_VAL << 24) + (CLICINTATTR_VAL << 16) + (CLICINTIE_VAL << 8))
1:
	sw t2, (t1)
	addi t1, t1, 4
	addi t0, t0, -1
	bnez t0, 1b
	li s0, miselect_clicintipe
	li s1, miselect_clicinttrig
1:
	mv a0, s0
	li a1, CLIC_PENDING_BASE
	mv a2, zero
	li a3, 0xc0fe5a5a
	jal verify_read
	bnez a0, bad_ending
	addi s0, s0, 1
	blt s0, s1, 1b

	li s0, miselect_clicintipe
	li s1, miselect_clicinttrig
1:
	mv a0, s0
	li a1, CLIC_ENABLE_BASE
	li a2, 1
	li a3, 0x705ac280
	jal verify_read
	bnez a0, bad_ending
	addi s0, s0, 1
	blt s0, s1, 1b


	// all tests ok
	li a0, UART_TX
	li t0, 'O'
	sw t0, (a0)
	li t0, 'K'
	sw t0, (a0)
	j newline_halt

bad_ending:
	li a0, UART_TX
	li t0, 'X'
	sw t0, (a0)
	sw t0, (a0)
// fallthrough
newline_halt:
	li t0, '\r'
	sw t0, (a0)
	li t0, '\n'
	sw t0, (a0)
	j .

verify_read:
	// a0 - miselect value
	// a1 - MMIO base
	// a2 - mireg(=0) vs mireg2(!=0) select
	// a3 - bit pattern to test with

	// set all bits using MMIO
	mv t4, zero
	li t5, 32
	li t1, miselect_clicintipe
	sub t0, a0, t1
	slli t0, t0, 7 // *= 0x80
	add t0, t0, a1
1:
	bext t2, a3, t4
	sb t2, 0(t0)
	addi t0, t0, 4
	addi t4, t4, 1
	bltu t4, t5, 1b

	// read back mireg/mireg2 and verify match with the pattern specified in a3
	csrw miselect, a0
	bnez a2, 1f
	csrr t3, mireg
	j 2f
1:
	csrr t3, mireg2
2:
	sub t3, t3, a3 // we could actually return here already if t3!=0

	// clear all bits using the CSR
	bnez a2, 1f
	csrw mireg, zero
	j 2f
1:
	csrw mireg2, zero
2:
	// verify that all bits are clear using MMIO
	li t4, 32
	li t1, miselect_clicintipe
	sub t0, a0, t1
	slli t0, t0, 7 // *= 0x80
	add t0, t0, a1
1:
	lb t2, 0(t0)
	bnez t2, 1f
	addi t0, t0, 4
	addi t4, t4, -1
	bgtz t4, 1b

1:
	or t3, t3, t2
	snez a0, t3
	jr ra
