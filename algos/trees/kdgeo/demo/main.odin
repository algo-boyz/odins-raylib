package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:math"
import "core:strconv"
import kd "../"

City :: struct {
    lat, lon: f64,
    name, country_code: string,
}

new_city :: proc(name: string, lat: f64, lon: f64, country_code: string) -> ^City {
    c := new(City)
    c.lat  = lat
    c.lon  = lon
    c.name = strings.clone(name)
    c.country_code = strings.clone(country_code)
    return c
}

main :: proc() {
    countries: map[string]string
    cities: [dynamic]^City
    kdtree: kd.Tree
    // Lisbon
    lat := 38.7167
    lon := -9.1333
    countries_csv, err_1 := os.read_entire_file("countries.csv")
    if err_1 != true {
        fmt.println("Error reading countries.csv file:", err_1)
        os.exit(1)
    }
    defer delete(countries_csv) 

    cities_csv, err_2 := os.read_entire_file("cities.csv")
    if err_2 != true {
        fmt.println("Error reading cities1000_filtered.csv file:", err_2)
        os.exit(1)
    }
    defer delete(cities_csv)

    countries = csv_to_countries(string(countries_csv))
    cities, kdtree = csv_to_cities(string(cities_csv))
    defer delete(countries)
    defer delete(cities)

    res, ok := kd.nearest(&kdtree, lat, lon)
    if !ok {
        fmt.println("No nearest city found.")
        return
    }
    city := cast(^City)res.data
    country := countries[ city.country_code ] or_else "Unknown"

    fmt.printf("Nearest: %v, %v - Distance: %v km\n", city.name, country, res.distance) 
}

TRIM :: " \t\n\r"

// Converts countries.csv to map of countries.
csv_to_countries :: proc(content: string) -> map[string]string {
    rows := strings.split(content, "\n")
    countries := make(map[string]string, len(rows))
    for line in rows {
        v := strings.split(line, ",")
        if len(v) < 2 {
            continue
        }
        countries[strings.trim(v[ 0 ], TRIM)] = strings.trim(v[ 1 ], TRIM)
    }
    return countries
}

// Header cities.csv:
//    0 City name
//    1 Latitude
//    2 Longitude
//    3 Country code
csv_to_cities :: proc(content: string) -> ([dynamic]^City, kd.Tree)  {
    rows := strings.split(content, "\n")
    cities := make([dynamic]^City, 0, len(rows))
    tree := kd.create()

    for row in rows {
        v := strings.split(row, ",")
        if len(v) < 4 {
            continue
        }
        name    := strings.trim(v[ 0 ], TRIM)
        lat, _  := strconv.parse_f64(v[ 1 ])
        lon, _  := strconv.parse_f64(v[ 2 ])
        code    := strings.trim(v[ 3 ], TRIM)
        
        city := new_city(name, lat, lon, code)
        // Append to check correctness
        append(&cities, city)
        
        kd.insert(&tree, city.lat, city.lon, city)
    }
    return cities, tree
}