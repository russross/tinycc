.data
.globl words
words:
.word base+4
.quad base+8
.word next_word - .
next_word:
.word base - .
.text
.globl reloc_base
reloc_base:
hi1:
.word 0x517
hi2:
.word 0x597
lo1:
.word 0x50513
lo2:
.word 0x58593
ret
.reloc 8, R_RISCV_PCREL_LO12_I, hi1
.reloc 4, R_RISCV_PCREL_HI20, words
.reloc 0, R_RISCV_PCREL_HI20, base
.reloc 12, R_RISCV_PCREL_LO12_I, hi2

.globl jump_addend
jump_addend:
li a0,1
j 1f+4
1:
li a0,0
ret
