---
title: XV6LabSummary
tags:
  - Computer
  - Operation System
  - XV6
  - MIT
  - Lab
category: Computer Theory
abbrlink: 8ecd89a3
date: 2023-01-05 11:24:08
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
    -   Fault or Abort
    -   Device

    >   We also call Syscall and Fault as ***Software Interrupt*, Internal Interrupt or Exception**

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

-   Comprehend function call stack’s structure, especially `fp` and `pre fp`, to correctly **back track** function call stack
-   Through **`fp` and PAGE-align** to find the top of function call stack, for XV6 allocates **one page for each stack**

#### Task 3: Alarm

-   Where to call `fn`: where it handles **timer interrupt**

-   When to call `fn`: 

    -   n ticks, so we need a new filed in process structrue
    -   Prevent re-entrant calls to the handler by adding a new field in process structure to sign if a handler is running

-   How to call `fn`:

    -   A new field in process structure to store `fn` address

        >   But in kernel mode, we can’t directly use **user space address** to call `fn`

    -   Modify user process **execution stream** to run `fn` by:

        -   Modifying `sepc` in **trap handling**
        -   **Store** user process previous **context** in `trapframe`
        -   **Restore** user process previous context in `sigreturn`

## Lab 5: xv6 lazy page allocation

### Basic Theory

-   **Information required** to properly handle **page faults**:

    -   The error **virtual address** in **stval**
    -   The error **reason** in **scause**
    -   The instruction address triggering page fault in **sepc or `trapframe->eps`**

-   **Thoughts** about **lazy page allocation**:

    -   **Just modify the value `p->sz`** but do not allocate pages in **`sbrk()` syscall**

        >   `sbrk()` **expands heap** to get new memory for process

    -   Lazily allocate pages when **page faults with virtual address between** `p->sz` before and after `sbrk()` occurs, and execute page fault instructions again

-   Simple **implementation** of **lazy page allocation**:

    -   Modify `sbrk()` by plan

    -   Handle a more trap case **page fault** in `usertrap()`, to `kalloc()` a **new page** and `mappages()` a **new map** in lazy allocation

    -   Delete `panic()`  in `uvmunmap()` when **unmapping lazy allocation page** not actually used

        >   XV6 `panic()` when this case happens, but actually this case **never happens** in unmodified XV6, and we require no `panic()` on this case in lazy allocation

### Task Analysis

#### Task 1: Eliminate allocation from sbrk()

-   Just follow thought and implementation in basic theory

#### Task 2: Lazy allocation

-   Just follow thought and implementation in basic theory

#### Task 3: Lazytests and Usertests

-   Just follow key points listed in guide book
    -   When user process use lazy allocated virtual address, page fault causes trap. But when **syscall use lazy allocated virtual address** (already in trap but not caused by page fault) , we need to handle it in `argaddr()` or `walkaddr()`



## Lab 6: Copy-on-Write Fork for xv6

### Basic Theory

-   **Thoughts** about **COW fork**:

    -   **Just copy page table maps** of parent process but do not copy pages when creating child process, and set these maps **read-only**

    -   Lazily copy pages when parent or child process **write these pages causing page faults**, and execute page fault instructions again

        >   For recognizing this case, we need use **a new sign bit in PTE**, or we may not distinguish this case from writing **an originally read-only page**

    -   Be careful to decide whether to **release a page** when parent process exits, for child process maybe using it

        >   We can set **a reference counter** for these pages

### Task Analysis

#### Task 1: Implement copy-on write



## Lab 7: Multithreading

### Basic Theory

#### Interrupt

>   Here we mainly talk about **the narrow interrupt**, not software interrupt

-   Differences between **interrupt** and other trap causes (software interrupt):	

    -   ***Asynchronous***: **Interrupt handler** has no relationship with current CPU running process
    -   ***Concurrency***: **Devices generating interrupt** *concurrently run* with CPU
    -   ***Program device***: Devices like network card also require programming

-   **Related registers** about interrupt:

    -   SIE: Supervisor Interrupt Enable, has one bit for **device interrupt**, one bit for **software interrupt** and one bit for **timer interrupt**
    -   SSTATUS: Supervisor STATUS, has one bit to **open or close interrupt**
    -   SIP: Supervisor Interrupt Pending, keep **the type of interrupt**

-   Basic setting of interrupt (in `main()`):

    1.   Program devices
    2.   Program PLIC (`plicinit()`)
    3.   Every CPU core call `plicinithart()` to show interest to device interrupts
    4.   `scheduler()` to `intr_on()` opening interrupt and run process

-   Hardware about interrupt:

    -   PLIC **route interrupts** from devices to **CPU claiming** to receive interrupt
    -   CPU handle interrupt with trap mechanism 
    -   CPU will **notice PLIC** after handling interrupt

    >   Kernel need to **program PLIC** to tell it how to route interrupts

-   Software about interrupt / **Driver**:

    -   Bottom part: **interrupt handler**
    -   Top part: **interfaces** for user or kernel process

#### Multithreading

-   Three parts of thread’s status to keep when switching
    -   **Program counter**
    -   **Registers** storing variables
    -   Program **stack**

-   XV6’s multithread mechanism
    -   **One kernel thread** per user process, which **handling traps** for user process
    -   **Only one user thread** per user process, which **controlling instructions** of user process

    >   So we may conclude that in XV6, one user process has two threads, but they never run together

-   Implementation of multithread switch / Timer interrupt:

    1.   **Hardware** produce interrupt periodically, convert user space into ***<u>kernel</u>’s*** timer interrupt handler

         >   With **trap** mechanism

    2.   Timer interrupt handler **yields** CPU to **thread scheduler**

         1.   Call `yield()` to acquire process’s **lock**, change process’s **state** to `RUNNABLE` and call `sched()`

         2.   `sched()` do some checks and call `swtch`

         3.   `swtch`:

              1.   Store kernel process’s **registers** into a `context`

                   >   `context` is stored in corresponding **user process structure**
         
              2.   Convert to this **CPU’s scheduler process** by restoring its `context` thus jumping to `swtch()` called before

                   >   Every CPU has a **scheduler process** also in **kernel**;
                   >
                   >   Scheduler process’s `context` is stored in its **CPU structure**

              3.   Continue executing `scheduler()`
         
         4.   `scheduler()` switch another `RUNNABLE` process to `RUNNING`

              1.   Release process’s **lock**
              2.   Find another `RUNNABLE` process
              3.   Call `swtch`
         
         5.   `swtch`
         
              1.   Store this **CPU’s scheduler process** `context`
              2.   **Restore** another kernel process’s `context` thus jumping to `swtch()` called before
              3.   Another kernel finish **timer interrupt** and return to **user space**

    >   Other interrupts causing **thread waiting** are similar to timer interrupt

### Task Analysis

#### Task 1: Uthread: switching between threads

#### Task 2: Using threads

#### Task 3: Barrier



## Lab 8: locks

### Basic Theory



### Task Analysis

#### Task1: Memory allocator

#### Task2: Buffer cache



## Lab 9: file system

### Basic Theory

>   The file system we talk about below is in XV6’s pattern

#### 1 Disk Level

*Disk layout:*

-   Block0: **boot** block, launch operation system
-   Block1: super **block**, describe file system
-   Block2 - Block46: **metadata** block
    -   Block2 - Block31: **log**
    -   Block32 - Block45: **inode**
    -   Block46: **bitmap** block
-   Block47 - Block n (954 in total): **data** block

#### 2 Buffer Cache Level

>   We use *<u>buffer cache</u>* to represent all the cache, use *<u>block cache</u>* to represent a certain block in buffer cache

*Allocate an inode / `ialloc()`:*

-   Visit all inode blocks by `bread()`, check if it is free then use it, and `brelse()`

-   `bread()`:

    1.   Call `bget()` to get this block’s cache / `bget()`:

         1.   `acquire()` **buffer cache’**s `spinlock`

         2.   Visit **all block caches** to find if this block is already cached, if yes:

              1.   Increase this block cache’s `refcnt`

              2.   `release()` **buffer cache’**s `spinlock`

              3.   `acquiresleep()` **block cache**’s `sleeplock`

                   >   Anytime only one process can use a block cache, and it may cause much time to handle it. So there must be a `sleeplock`

         3.   If not cached, recycle the **LRU free block cache** (`panic()` if no free block cache)

              1.   If `refcnt` equals zero, then it is free. Set some fields of this block cache
              2.   `release()` **buffer cache’**s `spinlock`
              3.   `acquiresleep()` **block cache**’s `sleeplock`

         >   One disk block can only have one block cache, or error may occur. So there must be a `spinlock` to protect buffer cache

    2.   Read from **disk** if it is **not valid**

    3.   Return the block cache

-   `brelse()`:

    1.   `releasesleep()` block cache’s `sleeplock`
    2.   `acquire()` buffer cache’s `spinlock`
    3.   Decrease this block cache’s `refcnt`
    4.   If no process is waiting for this block cache (`refcnt==0`), then follow **LRU** to locate this block cache in buffer
    5.   `release()` buffer cache’s `spinlock`

#### 3 Logging Level

***Crash** includes:*

-   Power fault
-   Core `panic()`

>   Exclude disk fault like data missing

---

***Key** point:*

-   The **atomicity** of multiple operation of **writing block**, not the **order**
-   **Fast recovery**

---

***Thoughts** about logging:*

1.   *Write log*: **write data to log** when requiring to write file system

2.   *Commit op*: **Record numbers** representing a groups of file system **writing** when they totally finish and **store data in log**

     >   Follow “**write ahead rule**”: before committing, all the written data must be in the log

3.   *Install log*: **Move** log’s blocks’ data to file system’s blocks when really ready to execute these writing

4.   *Clean log*: **Clean records** after installing log

---

***A Log’s Structure***:

-   **Header block**: valid **log block amount** and **disk block number** each log block corresponding
-   **Log’s data block**: actual blocks’ data to store in disk

---

***Implementation of Logging:***

-   `begin_op()`

    1.   `acquire()` log’s lock
    2.   If log is **committing**, sleep
    3.   If **concurrent operation amount** (`outstanding`) is over upper limit, sleep
    4.   If not the above two cases, increase `outstanding`, `release()` lock and continue

-   `log_write()`: update **log header in memory** including block number and block amount

-   `end_op()`

    1.   `acquire()` log’s lock

    2.   Decrease `outstanding`

    3.   If this is the last outstanding operation (`outsanding == 0`), mark it, else `wakeup()` sleeping process in `begin_op()`

    4.   `release()` log’s lock

    5.   `commit()` if marked above

         1.   `write_log()`(write log): **write** block’s data from **buffer cache** to disk **log** according to log header in memory

              >   `bwrite()` will be used in `write_log()`, but should not be directly used without logging

         2.   `write_head()`(commit op): write **log header** into disk log’s header block

              >   Inside `write_head()` is a `bwrite()` call which is the actual “**commit point**”

         3.   `install_trans()`(install)

         4.   Set log header `n`(amount) to 0 and `write_head()`(clean log)

---

*File System **Recovering**:*

>   `initlog() -> recover_from_log()`

1.   `read_head()` to read **log header** from disk into memory
2.   `install_trans()`

#### 4 Inode Level

*Inode Structure’s Fields:*

-   `type`: file or directory, or this inode is free
-   `nlink`: count how many file names link to this inode
-   `size`: file or directory data bytes
-   12 Direct block numbers: direct index to data block
-   1 Indirect block number: one level indirect indiex to data block

---

*Find nth byte in a file:*

1.   `n / block_size` leads to the **block number**
2.   `n % block_size` leads to the **byte offset** in a block

#### 5 Directory Level

>   Directory index block also follows index structrue above

*Directory Data Block Structure / **Directory entries**:*

-   16 bytes per entry
    -   First 2 bytes: subdirectory’s or file’s **inode number**
    -   Next 14 bytes: subdirectory’s or file’s **name**

---

*Find a pathname:*

1.   Begin with **`root ` inode** having index number 1 in XV6
2.   Scan **`root`’s data blocks** find the first level pathname’s corresponding **index number**
3.   Follow **index number** to find deeper level pathname in the data blocks
4.   Repeat above steps until find the correct file or meet error

---

*Create a file and firstly write data into it:*

1.   **Allocate an inode** and write `type`, `nlink` and other infomation in it
2.   Find parent directory and **create a new entry** in its data block
3.   Modify **parent directory’s inode**: *size* and so on
4.   Scan `bitmap` to find an unused **data block** for new file to write and update `bitmap`
5.   Modify **new file’s inode**: *size*, *direct block number* and so on

#### 6 Pathname Level

#### 7 File Descriptor Level

### Task Analysis

#### Task1: Large files

#### Task2: Symbolic links



## Lab10: mmap

### Basic Theory

-   Goals of memory mapped files: handle files with **memory related instructions** like `load` and `store`
-   Thoughts about **eager mmap**: 
    -   Copy the whole file to memory by **offset and length**, allocating pages
    -   **Unmap and write back dirty block** after finishing handling the file
-   Thoughts about **lazy mmap**: 
    -   Just **match PTE with VMA** (Virtual Memory Area) which contains information about file but do not allocating pages
    -   Lazily allocate pages when actually reading or writing mmap file causing **page fault**

### Task Analysis

#### Task1: mmap
