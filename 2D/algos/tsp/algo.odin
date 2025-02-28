package tsp

Algorithm :: enum {
    Brute,
    NN,
    Christofides,
    ACO,
}

algo_to_string :: proc(alg: Algorithm) -> string {
    switch alg {
    case .Brute:
        return "Brute force"
    case .NN:
        return "NN"
    case .Christofides:
        return "Christofides"
    case .ACO:
        return "ACO"
    }
    return ""
}
