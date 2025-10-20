# The Square Bit-Matrix Transpose

Optimized algorithm to perform transpose of a square bit-matrix, by swapping bits across top-right to bottom-left diagonally.
Taking advantage of [Binary Code Modulation](http://www.batsocks.co.uk/readme/art_bcm_1.htm). This technique allows the value of a cpu register to control the duty-cycle. Only requiring a single hardware timer to control multiple outputs.

Imagine that in an embedded environment 8 x 8-bit registers contain the values of the current cycle's 8 output pins. 
The problem is that the lowest bit of each register should be written together to the output, followed by the second lowest bit, and so on.
The naive way is by masking and shifting one bit at a time, which is inefficient. The efficient way to do this is by transposing a bit-matrix, to transform the values held in registers such that the first register contains the lowest bit of all outputs, the second register
containing the second lowest bit, and so on. Now write each register to output whenever the hardware timer triggers an interrupt.

## Theory
8-bit micros almost always have 8-bit ALU's. Rather than using bit-shifts and bit-masks to transpose one bit, an ALU shifts 8-bits at a time. 
While the number of swap operations is not less, the method exploits a form of parallelism by utilizing the hardware.

Operational complexity to transpose is _O(n\*log(n))_ vs _O(n\*n)_ without.

Modern 64-bit cpus, allow for efficient transposing of 8, 16, 32 and 64b bit-matrices. 

![matrix-transpose-method](doc/matrix-transpose-method.png)

Transpose a 8x8 bit-matrix, by recursively swapping a shrinking square-pattern.
FIrst swapping in large 4x4 blocks and ending with small 1x1 blocks. Interestingly, the order blocks are swapped does not affect the solution.

## References

- [General purpose bit matrix using bit-shift/mask](https://github.com/benjamindblock/odin-bit-matrix)