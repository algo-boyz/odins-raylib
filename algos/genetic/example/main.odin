// Name : Genetic Algorithm in Odin
// Based on C code from:
//     Github Giebisch  - GeneticAlgorithmInC
//     https://github.com/Giebisch/GeneticAlgorithmInC
// Author:  Joao Carvalho
// License:  MIT
package main

import "core:fmt"
import "core:math"
import "core:strings"
import "core:os"
import "../"

main :: proc ( ) {
    fmt.printfln( "Start genetic algorithm...\n" ) 
    genetic.run( )
    fmt.printfln( "\n... end genetic algorithm." ) 
}