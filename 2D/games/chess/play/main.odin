package main

import "../"

main :: proc() {
    game := chess.init()
    chess.run(game)
    chess.destroy(game)
}