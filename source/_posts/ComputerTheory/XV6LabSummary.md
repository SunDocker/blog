---
title: XV6LabSummary
date: 2023-01-05 11:24:08
tags:
  - Computer
  - Operation System
  - XV6
  - MIT
  - Lab
category: Computer Theory
---

## Lab 4: traps

### Basic Theory

-   Why to trap: Conversion between user mode and kernel mode

    -   What can supervisor actually do:

        -   Read or write **control registers**
        -   Use PTEs with 0 in `PTE_U`

        >   Still limited in **virtual address** set by page table

-   When to trap or What leads to trap:

    -   Syscall
    -   Fault
    -   Device

-   Key point of traps: **Isolation & Security**

-   Some relevant hardware registers / **Control registers**:

    -   pc: program counter
    -   mode: mark supervisor mode or user mode
    -   satp: supervisor **address translation** and protection, points to physical memory of page table
    -   stvec: supervisor **trap vector** base address, points to base memory of instructions handling traps
    -   sepc: supervisor exception program counter, **keep value of pc** when handling traps
    -   sscratch: supervisor scratch, keep virtual address of **trapframe page** to exchange with a0
    -   scause: supervisor cause, keep the trap **reason**

-   How to trap / Procedure of trap (take syscall as an example):

    1.   Syscall function jump to **usys.S** and execute two instructions: 

         1.   Store **syscall number** into a7
         2.   Call **`ecall` instruction**

    2.   `ecall` do three things by **hardware**:

         1.   Mark the **mode** to supervisor mode
         2.   Keep **pc** in sepc 
         3.   Set pc to **stvec** and jump to `uservec` in trampoline.S

         >   `ecall` do only these things for **more flexibility to software**

    3.   Kernel executes `uservec` in trampoline.S

         1.   Exchange a0 and sscratch

              >   So now a0 keeps trapframe page, sscratch keeps a0’s old value

         2.   Keep **32 user’s register** in trapframe

         3.   Set stack pointer to **kernel stack** (getting from trapframe)

         4.   Set t0 to **pointer of `usertrap()`** (getting from trapframe)

         5.   Set t1 to **kernel page table** and exchange satp and t1 (getting from trapframe)

              >   Now program keeps normal for **trampoline page having same map** in both user page table and kernel page table

         6.   `uservec` jumps to `usertrap()` in trap.c

    4.   `usertrap()` handles this trap

         1.   Set **stvec** to `kernelvec`

              >   Traps can be triggered in kernel space, different from user space

         2.   Keep **sepc** in trapframe

              >   May it change to another process and also trigger traps to overwrite sepc

         3.   Check **cause** for this trap and handle it (the syscall)

         4.   Call `usertrapret()`

    5.   `usertrapret()` finish some works to return to user space

         1.   Set **stvec** to `uservec `in trampoline.S
         2.   Store **kernel page table** into trapframe
         3.   Store **kernel stack pointer** into trapframe
         4.   Store `usertrap` into trapframe
         5.   Modify **sstatus** to ensure returning to user mode and interrupt on
         6.   Set **sepc** to previous kept pc
         7.   Jump to `userret` in trampoline.S

    6.   Kernel executes `uservec` in trampoline.S

         1.   Set satp to **user page table** (getting from `usertrapret()`)

         2.   Restore 32 user’s resgisters

         3.   Exchange a0 and sscratch

              >   So now sscratch keeps trapframe page, a0 keeps syscall return value

         4.   `sret`

    7.   `sret`

         1.   Mark the **mode** to user mode
         2.   Set **pc** to sepc 

    8.   Return to user space

### Task Analysis

#### Task 1: RISC-V assembly

#### Task 2: Backtrace

#### Task 3: Alarm



## Lab 5: xv6 lazy page allocation

### Basic Theory

-   Information required to properly handle **page faults**:
    -   The error **virtual address** in **stval**
    -   The error **reason** in **scause**
    -   The instruction address triggering page fault in **sepc or `trapframe->eps`**

-   Thoughts about **lazy page allocation**:

    -   **Just modify the value `p->sz`** but do not allocate pages in **`sbrk()` syscall**

        >   `sbrk()` **expands heap** to get new memory for process

    -   Lazily allocate pages when **page faults with virtual address between** `p->sz` before and after `sbrk()`, and execute page fault instructions again

-   Simple implementation of lazy page allocation:

    -   Handle a more trap case **page fault** in `usertrap()`, to `kalloc()` a **new page** and `mappages()` a **new map** in lazy allocation

    -   Delete `panic()`  in `uvmunmap()` when **unmapping lazy allocation page** not actually used

        >   XV6 `panic()` when this case happens, but actually this case **never happens** in unmodified XV6, and we require no `panic()` on this case in lazy allocation


### Task Analysis

#### Task 1: Eliminate allocation from sbrk()

#### Task 2: Lazy allocation

#### Task 3: Lazytests and Usertests



## Lab 6: Copy-on-Write Fork for xv6

### Basic Theory



### Task Analysis

#### Task 1: Implement copy-on write



