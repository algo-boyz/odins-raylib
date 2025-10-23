package main

import "core:fmt"
import "core:os"

/******************************************************************************/
/*
  Purpose:

    D2XY converts a 1D Hilbert coordinate to a 2D Cartesian coordinate.

  Modified:

    05 December 2015

  Parameters:

    Input, int M, the index of the Hilbert curve.
    The number of cells is N=2^M.
    0 < M.

    Input, int D, the Hilbert coordinate of the cell.
    0 <= D < N * N.

    Output, int *X, *Y, the Cartesian coordinates of the cell.
    0 <= *X, *Y < N.
*/
d2xy :: proc(m: int, d: int) -> (int, int) {
    n: int
    rx: int
    ry: int
    s: int
    t: int = d

    n = i4_power( 2, m )

    x := 0
    y := 0

    for s := 1; s < n; s = s * 2 {
        rx = 1 & ( t / 2 )
        ry = 1 & ( t ~ rx )
        x, y = rot ( s, x, y, rx, ry )
        x = x + s * rx
        y = y + s * ry
        t = t / 4
    }

    return x, y
}
/******************************************************************************/

/******************************************************************************/
/*
  Purpose:

    I4_POWER returns the value of I^J.

  Licensing:

    This code is distributed under the GNU LGPL license.

  Modified:

    23 October 2007

  Author:

    John Burkardt

  Parameters:

    Input, int I, J, the base and the power.  J should be nonnegative.

    Output, int I4_POWER, the value of I^J.
*/
i4_power :: proc(i: int, j: int) -> int {
    k:     int
    value: int

    if ( j < 0 ) {
        if ( i == 1 ) { value = 1 }
        else if ( i == 0 ) {
            fmt.eprintf( "\n" );
            fmt.eprintf( "I4_POWER - Fatal error!\n" );
            fmt.eprintf( "  I^J requested, with I = 0 and J negative.\n" );
            os.exit ( 1 );
        } else {
            value = 0
        }
    }
    else if ( j == 0 ) {
        if ( i == 0 ) {
            fmt.eprintf ( "\n" )
            fmt.eprintf ( "I4_POWER - Fatal error!\n" )
            fmt.eprintf ( "  I^J requested, with I = 0 and J = 0.\n" )
            os.exit ( 1 )
        }
        else { value = 1 }
    }
    else if ( j == 1 ) { value = i }
    else {
        value = 1;
        for k := 1; k <= j; k += 1 { value = value * i }
    }
    return value
}
/******************************************************************************/

/******************************************************************************/
/*
  Purpose:

    ROT rotates and flips a quadrant appropriately.

  Modified:

    05 December 2015

  Parameters:

    Input, int N, the length of a side of the square.  N must be a power of 2.

    Input/output, int *X, *Y, the old and the new coordinates.

    Input, int RX, RY, ???
*/
rot :: proc( n: int, x: int, y: int, rx: int, ry: int ) -> (int, int) {
    t: int
    x := x
    y := y

    if ( ry == 0 ) {
        /* Reflect. */
        if ( rx == 1 ) {
            x = n - 1 - x
            y = n - 1 - y
        }

        /* Flip. */
        t = x
        x = y
        y = t
    }
    return x, y
}
/******************************************************************************/

/******************************************************************************/
/*
  Purpose:

    XY2D converts a 2D Cartesian coordinate to a 1D Hilbert coordinate.

  Discussion:

    It is assumed that a square has been divided into an NxN array of cells,
    where N is a power of 2.

    Cell (0,0) is in the lower left corner, and (N-1,N-1) in the upper
    right corner.

  Modified:

    05 December 2015

  Parameters:

    Input, int M, the index of the Hilbert curve.
    The number of cells is N=2^M.
    0 < M.

    Input, int X, Y, the Cartesian coordinates of a cell.
    0 <= X, Y < N.

    Output, int XY2D, the Hilbert coordinate of the cell.
    0 <= D < N * N.
*/
xy2d :: proc( m: int, x: int, y: int ) -> int {
    d: int = 0
    n: int
    rx: int
    ry: int
    s: int

    x := x
    y := y

    n = i4_power ( 2, m )

    for s := n / 2; s > 0; s = s / 2 {
        rx = auto_cast(( x & s ) > 0)
        ry = auto_cast(( y & s ) > 0)
        d = d + s * s * ( ( 3 * rx ) ~ ry )
        x, y = rot ( s, x, y, rx, ry )
    }

    return d
}