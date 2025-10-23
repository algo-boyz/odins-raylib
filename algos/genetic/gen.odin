package genetic

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:math/rand"
import "core:os"

GENE_COUNT       ::   3
GENERATIONS      :: 750
POPULATION_SIZE  :: 100
TOURNAMENT_SIZE  ::  10
MUTATION_CHANCE  ::   0.3
CROSSOVER_CHANCE ::   0.7
LOW              ::  -5.0
HIGH             ::   5.0

Chromosome :: struct {
    genes   : [ GENE_COUNT ]f64,
    fitness : f64,
}

my_rand_gen : rand.Generator


run :: proc ( ) {
    rng_from_seed :: proc( seed: u64, state: ^rand.Default_Random_State ) -> rand.Generator {
        gen := rand.default_random_generator( state )
        rand.reset( seed, gen )
        return gen
    }
    seed : u64 = 45
    my_rand_gen = rng_from_seed( seed,&{ } )

    fitness_values_file_path := "fitness_values.txt"
    output_str : strings.Builder = strings.builder_make( 10_000 )
    
    fmt.sbprintf(&output_str, "Average\tBest\n" )
    population : [ ]Chromosome = generate_starting_population( )

    for i in 0 ..< GENERATIONS {
        selected_chromosomes  : [ ]Chromosome = tournament_selection( population )
        crossover_chromosomes : [ ]Chromosome = uniform_crossover( selected_chromosomes )
        mutated_chromosomes   : [ ]Chromosome = gaussian_mutation( crossover_chromosomes )
        best : Chromosome = get_best_chromosome( mutated_chromosomes, POPULATION_SIZE )
        
        for t in 0 ..< POPULATION_SIZE {
            population[ t ] = mutated_chromosomes[ t ]
        }
        fmt.sbprintfln(&output_str, "%f\t%f", get_average_fitness( population ), best.fitness )
        // jnc
        output_string := strings.to_string( output_str )
    }
    best : Chromosome = get_best_chromosome( population, POPULATION_SIZE )
    printf_chromosome( best )
    fmt.printfln( "calculate_function value : %f", calculate_function( best ) )
}

random_double :: #force_inline proc ( low : f64, high : f64 ) -> f64 {
    return rand.float64_range( low, high, my_rand_gen )
}

random_int :: #force_inline proc ( low : int, high : int ) -> int {
    diff : int = high - low
    return rand.int_max( diff, my_rand_gen ) + low
}

get_average_fitness :: proc ( population : [ ]Chromosome ) -> f64 {
    average : f64
    for i in 0 ..< POPULATION_SIZE {
        average = average + population[ i ].fitness
    }
    return average / POPULATION_SIZE
}

normal_distribution :: proc ( ) -> f64 {
    // Box-Muller transform
    y1 : f64 = random_double( 0.0, 1.0 )
    y2 : f64 = random_double( 0.1, 1.0 )
    return math.cos( 2.0 * math.PI * y2 ) * math.sqrt_f64( -2.0 * math.log_f64( y1, math.E ) )
}

generate_starting_population :: proc ( ) -> [ ]Chromosome {
    chromosomes : [ ]Chromosome = make_slice( [ ]Chromosome, len = POPULATION_SIZE )
    if chromosomes == nil {
        fmt.printfln( "Error: Could not allocate memory for chromosomes_1." )
        os.exit( 1 )
    }
    for i in 0 ..< POPULATION_SIZE {
        for g in 0 ..< GENE_COUNT {
            chromosomes[ i ].genes[ g ] = random_double( LOW, HIGH )
        }
        chromosomes[ i ].fitness = calculate_fitness( chromosomes[ i ] )
    }
    return chromosomes
}

tournament_selection :: proc ( population : [ ]Chromosome  ) -> [ ]Chromosome {
    new_population : [ ]Chromosome = make( [ ]Chromosome, POPULATION_SIZE )
    for i in 0 ..< POPULATION_SIZE {
        // select TOURNAMENT_SIZE-many random chromosomes
        tournament_chromosomes : [ TOURNAMENT_SIZE ]Chromosome
        for t in 0 ..< TOURNAMENT_SIZE {
            index : int = random_int( 0, POPULATION_SIZE )
            tournament_chromosomes[ t ] = population[ index ]
        }
        // find chromosome with the highest fitness value in tournament and add to new population
        new_population[ i ] = get_best_chromosome( tournament_chromosomes[ : ], TOURNAMENT_SIZE )
    }
    return new_population;
}

get_best_chromosome :: proc ( population : [ ]Chromosome, size : int ) -> Chromosome {
    max_fitness: f64
    winner_index: int
    for c in 0 ..< size {
        if population[ c ].fitness > max_fitness {
            max_fitness = population[ c ].fitness
            winner_index = c
        }
    }
    return population[ winner_index ]
}

gaussian_mutation :: proc ( population : [ ]Chromosome ) -> [ ]Chromosome {
 
    new_population : [ ]Chromosome  = make( [ ]Chromosome, POPULATION_SIZE )

    for i in 0 ..< POPULATION_SIZE {
        
        new_genes : [ GENE_COUNT ]f64
        for g in 0 ..< GENE_COUNT {
            
            old_gene : f64 = population[ i ].genes[ g ]
            if random_double( 0.0, 1.0 ) < MUTATION_CHANCE {
                new_genes[ g ] = old_gene + normal_distribution( ) * 0.1 * ( HIGH - LOW )
            } else {
                new_genes[ g ] = old_gene
            }
        }
        new_chromosome : Chromosome
        
        for gene in 0 ..< GENE_COUNT {
            new_chromosome.genes[ gene ] = new_genes[ gene ]
        }
        new_chromosome.fitness = calculate_fitness( new_chromosome )
        new_population[ i ] = new_chromosome
    }
    return new_population
}

uniform_crossover :: proc ( population : [ ]Chromosome ) -> [ ]Chromosome {

    new_population : [ ]Chromosome = make( [ ]Chromosome, POPULATION_SIZE )

    for i in 0 ..< ( POPULATION_SIZE / 2 ) {
        
        rand_chr1 : Chromosome = population[ random_int( 0, POPULATION_SIZE ) ]
        rand_chr2 : Chromosome = population[ random_int( 0, POPULATION_SIZE ) ]
        if random_double( 0.0, 1.0 ) < CROSSOVER_CHANCE {
        
            genes1 : [ GENE_COUNT ]f64
            genes2 : [ GENE_COUNT ]f64
            for g in 0 ..< GENE_COUNT {
                
                if random_double( 0.0, 1.0 ) < 0.5 {
                    genes1[ g ] = rand_chr1.genes[ g ]
                } else {
                    genes1[ g ] = rand_chr2.genes[ g ]
                }
                if random_double( 0.0, 1.0 ) < 0.5 {
                    genes2[ g ] = rand_chr1.genes[ g ]
                } else {
                    genes2[ g ] = rand_chr2.genes[ g ]
                }
            }
            new_chr1, new_chr2 : Chromosome
            for gene in 0 ..< GENE_COUNT {
                new_chr1.genes[ gene ] = genes1[ gene ]
                new_chr2.genes[ gene ] = genes2[ gene ]
            }
            new_chr1.fitness = calculate_fitness( new_chr1 )
            new_chr2.fitness = calculate_fitness( new_chr2 )
            new_population[ i ] = new_chr1
            new_population[ POPULATION_SIZE - 1 - i ] = new_chr2
        } else {
            new_population[ i ] = rand_chr1
            new_population[ POPULATION_SIZE - 1 - i ] = rand_chr2
        }
    }
    return new_population;
}

printf_chromosome :: proc ( chromosome : Chromosome ) {
    fmt.printfln( "\nBest cromosome...\n" + 
                  "    fitness value :  %f\n" +
                  "    genes         :  %f, %f, %f",
                  chromosome.fitness,
                  chromosome.genes[ 0 ],
                  chromosome.genes[ 1 ],
                  chromosome.genes[ 2 ]  )
}

calculate_function :: proc ( chromosome : Chromosome ) -> f64 {
    // Rosenbrock function with n = 3
    value : f64 = 100.0 * math.pow( ( chromosome.genes[ 1 ] - math.pow(chromosome.genes[ 0 ], 2.0 ) ), 2.0 ) + math.pow( ( 1.0 - chromosome.genes[ 0 ] ), 2.0 ) +
                  100.0 * math.pow( ( chromosome.genes[ 2 ] - math.pow(chromosome.genes[ 1 ], 2.0 ) ), 2.0 ) + math.pow( ( 1.0 - chromosome.genes[ 1 ] ), 2.0 )
    return value
}

calculate_fitness :: proc ( chromosome : Chromosome ) -> f64 {
    value : f64 = calculate_function( chromosome )
    return 1.0 / ( 1.0 + abs( value ) )
}

