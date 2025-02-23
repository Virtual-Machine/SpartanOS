.include "width.s"

.equ MAX_HARTS,    4
.equ SAVE_REGS,    16
.equ STACK_SIZE,   1024
.equ STACK_SHIFT,  10
.equ CONTEXT_SIZE, (SAVE_REGS * REGBYTES)

.globl _text_start
.globl _text_end
.globl _rodata_start
.globl _rodata_end
.globl _data_start
.globl _data_end
.globl _bss_start
.globl _bss_end
.globl _memory_start
.globl _memory_end

.section .text.init,"ax",@progbits
.globl _entry
_entry:
	# setup default trap vector
	la      t0, trap_vector
	csrw    mtvec, t0

	# set up stack pointer based on hartid
	csrr    t0, mhartid
	slli    t0, t0, STACK_SHIFT
	la      sp, stacks + STACK_SIZE
	add     sp, sp, t0

	# sleep spin all harts except hart 0
	csrr    a0, mhartid
	bnez    a0, spin

	# jump to start() in kernel/start.c
	call start
spin:
	wfi
	j spin

.align 2
trap_vector:
	# Save registers.
	addi    sp, sp, -CONTEXT_SIZE
	sxsp    ra, 0
	sxsp    a0, 1
	sxsp    a1, 2
	sxsp    a2, 3
	sxsp    a3, 4
	sxsp    a4, 5
	sxsp    a5, 6
	sxsp    a6, 7
	sxsp    a7, 8
	sxsp    t0, 9
	sxsp    t1, 10
	sxsp    t2, 11
	sxsp    t3, 12
	sxsp    t4, 13
	sxsp    t5, 14
	sxsp    t6, 15

	# Invoke the handler.
	mv      a0, sp
	csrr    a1, mcause
	csrr    a2, mepc
	jal     trap_handler

	# Restore registers.
	lxsp    ra, 0
	lxsp    a0, 1
	lxsp    a1, 2
	lxsp    a2, 3
	lxsp    a3, 4
	lxsp    a4, 5
	lxsp    a5, 6
	lxsp    a6, 7
	lxsp    a7, 8
	lxsp    t0, 9
	lxsp    t1, 10
	lxsp    t2, 11
	lxsp    t3, 12
	lxsp    t4, 13
	lxsp    t5, 14
	lxsp    t6, 15
	addi sp, sp, CONTEXT_SIZE

	# Return
	mret



.globl timer_interrupt
.align 4
timer_interrupt:
	# start.c has set up the memory that mscratch points to:
	# scratch[0,8,16] : register save area.
	csrrw a0, mscratch, a0
	sx a1, 0(a0)
	sx a2, 8(a0)
	sx a3, 16(a0)

	lx a1, 24(a0)
	addi a1, a1, 1
	sx a1, 24(a0)

	li a1, 0x02004000
	lx a2, 0(a1)
	li a3, 0x1E8480
	add a2, a2, a3
	sx a2, 0(a1) 

	# raise a machine software interrupt.
	li a1, 2
	csrw mip, a1

	lx a3, 16(a0)
	lx a2, 8(a0)
	lx a1, 0(a0)
	csrrw a0, mscratch, a0

	mret

.bss
.align 4
.globl stacks
stacks:
	.skip STACK_SIZE * MAX_HARTS