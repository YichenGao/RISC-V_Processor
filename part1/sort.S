#include "src/defines.h"
.section ".text.init"
    .globl sort
    .globl kth_smallest
    .globl violation

/*

QUICKSORT & PARTITION

C implementation (for reference)

int partition(int* p, int start, int end) {
    int x = p[end]; // select pivot
    int j, tmp, i = start - 1;
    for (j = start; j < end; j++) {
        if (p[j] <= x) {
            i++;
            tmp = p[i];
            p[i] = p[j];
            p[j] = tmp;
        }
    }
    tmp = p[i + 1]
    p[i + 1] = p[end]
    p[end] = tmp
    return i + 1;
}

void quicksort(int* p, int start, int end) {
    if (start < end) {
        int q = partition(p, start, end);
        quicksort(p, start, q - 1);
        quicksort(p, q + 1, end);
    }
}

Python implementation (for reference)

def partition(p, start, end):
    x = p[end]
    i = (start - 1)
    for j in range(start, end):
        if p[j] <= x:
            i = i + 1
            tmp = p[i]
            p[i] = p[j]
            p[j] = tmp

    tmp = p[i + 1]
    p[i + 1] = p[end]
    p[end] = tmp
    return i + 1

def quicksort(p, start, end):
    if start < end:
        q = partition(p, start, end)
        quicksort(p, start, q - 1)
        quicksort(p, q + 1, end)

*/

//  Inputs:
//  a0 = p (address of array)
//  a1 = start index 
//  a2 = end index

sort:
    slli a1, a1, 2 // find location of start
    add a3, a1, a0

    slli a4, a2, 2 // find location of end
    add a4, a4, a0

    mv a0, a3 // a0 = start location 
    mv a1, a4 // a1 = end location

    addi sp, sp, -4
    sw ra, (sp)
    call quicksort
    lw ra, (sp)
    addi sp, sp, 4

    ret


//  QUICKSORT (should call "partition")
// a0: start location 
// a1: end location

// a3 = value of end, a4= value of start, 
// a5 = temporary value, a6 = q
quicksort:
    //////////base case (n = 1, 2, 3)////////
    beq a0, a1, done // if n = 1

    sub t0, a1, a0 // t0 = a1 - a0
    li t1, 6
    bge t0, t1, tag2 // if n = 2
        lw t1, (a0)
        lw t2, (a1)
        blt t1, t2, done // done if t1 < t2 and n = 2
        sw t1, (a1)
        sw t2, (a0)
    tag2:
    //////////base case (n < 10) insertion sort////////
    /*li t1, 42 
    bge t0, t1, tag10 // if n < 10
    addi a5, a0, 4// i = start + 1

    loop10:
        bge a5, a1, breakloop10 // break if i >= end
        lw a3, 0(a5) // get a3 = value of key = p[i]
        addi a6, a5, -4 // j = i - 1
        lw t2, (a6) // t2 = p[j]
        whileloop:
            blt a6, a0, breakwhileloop // break if j < 0
            bge a3, t2, breakwhileloop // break if key >= p[j]
            lw t3, 4(a6)
            sw t3, (a6)
            addi a6, a6, -4// j--
        breakwhileloop:
        sw a3, 4(a6) // p[j+1] = key
        addi a5, a5, 4  // i++
    breakloop10:
    j done
    
    tag10:
    */
    /////////////end base cases/////////////////////

    bge a0, a1, done // break if start >= end:
    ////////////////partition////////////////
    // PARTITION
    //
    // Inputs:           
    // a0 = starting location
    // a1 = end location

    //a3 = x = value of pivot, a5 = i used for loop
    // a6 = j used for loop, t1 = value of p[i], t2 = value of p[j]

    sub t0, a1, a0
    srai t0, t0, 3 // divide by 8
    slli t0, t0, 2 
    add t0, t0, a0
    lw a3, 0(t0) // get a3 = value of pivot = p[middle]
    addi a5, a0, -4 // i = start - 1
    add a6, a1, 4 // j = end + 1

    loop:
        
        innerloop1:
            addi a5, a5, 4  // i++
            lw t1, (a5) // t1 = p[i]
            blt t1, a3, innerloop1  // if p[i] < pivot

        innerloop2:
            add a6, a6, -4 // j--
            lw t2, (a6) // t2 = p[j]
            blt a3, t2, innerloop2  //break if pivot < p[j]
        
        
        bge a5, a6, break // break if i >= j
        
        sw t2, (a5)   // p[j] -> p[i]
        sw t1, (a6)   // p[i] -> p[j]

        blt a5, a6, loop

    break: // exit loop

    //  the location of pivot is in a6

    ///////////partition///////////////


        mv a5, a1 // a5 = end location for replacement later
        mv a1, a6 // a2 = q location

        addi sp, sp, -12 // get enough space in stack to save values
        sw ra, 8(sp)
        sw a6, 4(sp)
        sw a5, (sp)
        call quicksort // a0 = start location, a1 = q location
        lw a5, (sp)
        lw a6, 4(sp)
        lw ra, 8(sp)

        mv a1, a5 // restore value of a1 = end location

        mv a0, a6 // a0 = p + 1 location
        addi a0, a0, 4

        sw ra, 8(sp)
        sw a6, 4(sp)
        sw a5, (sp)
        call quicksort // a0 = p, a1 = q+1, a2 = end
        lw a5, (sp)
        lw a6, 4(sp)
        lw ra, 8(sp)
        addi sp, sp, 12

    done:

  ret


