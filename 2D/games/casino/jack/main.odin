package blackjack

import "core:fmt"
import "core:math/rand"
import "core:slice"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

FONT_SIZE :: 28
CARD_WIDTH :: 70
CARD_HEIGHT :: 120

BUTTON_WIDTH: f32 : 100.0
BUTTON_HEIGHT: f32 : 40.0

WINDOW_PADDING: f32 : BUTTON_HEIGHT / 2

BET_AMOUNTS :: [4]int{10, 25, 50, 100}
STARTING_BANKROLL :: 1000

Suit :: enum {
    Hearts, Spades, Diamonds, Clubs,
}

Rank :: enum {
    Ace, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten, Jack, Queen, King,
}

Card :: struct {
    full_name: string,
}

Deck :: [dynamic]Card
CardTextures :: struct {
    textures: map[string]rl.Texture2D,
    card_back: rl.Texture2D,
}

MouseState :: enum {
    Default,
    Hover,
    Pressed,
}

GameState :: enum u8 {
    EvalBet,
    PlaceBet,
    PlayerTurn,
    DealerTurn,
}

Screen :: enum u8 {
    Splash,
    Game,
    Score,
}

Game :: struct {
    screen:                 Screen,
    state:                  GameState,
    cards:                  CardTextures,
    deck, player, dealer:   Deck,
    bg:                     rl.Texture2D,
    bankroll:               int,      // Player's money
    current_bet:            int,      // Current bet amount
    outcome_message:        cstring,  // Message to display when hand is over
    sounds: struct {
        draw_card, stash, end_game: rl.Sound,
    },
}

// Initialize card deck
init_cards :: proc() -> Deck {
    suits := [4]string{"hearts", "spades", "diamond", "clubs"}
    ranks := [13]string{"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}
    cards := make(Deck)
    for suit in suits {
        for rank in ranks {
            append(&cards, Card{full_name = fmt.tprintf("%s_%s", suit, rank)})
        }
    }
    return cards
}

load_card_txtures :: proc() -> CardTextures {
    card_txtures: CardTextures
    card_txtures.textures = make(map[string]rl.Texture2D)
    for card in init_cards() {
        image := rl.LoadImage(fmt.ctprintf("assets/cards/%s.png", card.full_name))
        rl.ImageResize(&image, 70, 100)
        card_txtures.textures[card.full_name] = rl.LoadTextureFromImage(image)
        rl.UnloadImage(image)
    }
    card_back_image := rl.LoadImage("assets/cards/card_back.png")
    rl.ImageResize(&card_back_image, 70, 100)
    card_txtures.card_back = rl.LoadTextureFromImage(card_back_image)
    rl.UnloadImage(card_back_image)

    return card_txtures
}

unload_card_txtures :: proc(card_txtures: ^CardTextures) {
    for _, texture in card_txtures.textures {
        rl.UnloadTexture(texture)
    }
    delete(card_txtures.textures)
    rl.UnloadTexture(card_txtures.card_back)
}

render_card :: proc(card_txtures: ^CardTextures, card: Card, dest_x: f32, dest_y: f32) {
    texture := card_txtures.textures[card.full_name]
    rl.DrawTexture(texture, i32(dest_x), i32(dest_y), rl.WHITE)
}

render_card_back :: proc(card_txtures: ^CardTextures, dest_x: f32, dest_y: f32) {
    rl.DrawTexture(card_txtures.card_back, i32(dest_x), i32(dest_y), rl.WHITE)
}

render_player :: proc(game: ^Game) {
    dest_x := f32(rl.GetScreenWidth()) / 2 - CARD_WIDTH / 2 * f32(len(game.player))
    dest_y := f32(rl.GetScreenHeight()) - CARD_HEIGHT - CARD_HEIGHT / 4
    for card in game.player {
        render_card(&game.cards, card, dest_x, dest_y)
        dest_x += CARD_WIDTH
    }
}

render_dealer :: proc(game: ^Game, showCards: bool = false) {
    dest_x := f32(rl.GetScreenWidth()) / 2 - CARD_WIDTH / 2 * f32(len(game.dealer))
    dest_y:f32 = CARD_HEIGHT / 4
    for i := 0; i < len(game.dealer); i += 1 {
        if i != 0 && !showCards {
            render_card_back(&game.cards, dest_x, dest_y)
        } else {
            render_card(&game.cards, game.dealer[i], dest_x, dest_y)
        }
        dest_x += CARD_WIDTH
    }
}

deal_card :: proc(deck: ^Deck, hand: ^Deck) {
    card_index := rand.int_max(len(deck^))
    card := deck^[card_index]
    append(hand, card)
    unordered_remove(deck, card_index)
}

current_score :: proc(hand: []Card) -> (score: int) {
    total_aces:int
    for card in hand {
        parts := strings.split(card.full_name, "_")
        if len(parts) != 2 do continue
        rank := parts[1]
        switch rank {
        case "A":
            total_aces += 1
        case "J", "Q", "K":
            score += 10
        case "10":
            score += 10
        case:
            score += int(rank[0] - '0')
        }
    }
    // Handle aces
    for i in 0..<total_aces {
        if score + 11 <= 21 {
            score += 11
        } else {
            score += 1
        }
    }
    return score
}

// Check if a hand is a blackjack (21 with just 2 cards)
is_blackjack :: proc(hand: []Card) -> bool {
    return len(hand) == 2 && current_score(hand) == 21
}

// Process game outcome and update bankroll
process_game_outcome :: proc(game: ^Game) -> cstring {
    player_score := current_score(game.player[:])
    dealer_score := current_score(game.dealer[:])
    player_blackjack := is_blackjack(game.player[:])
    dealer_blackjack := is_blackjack(game.dealer[:])
    
    // Natural blackjack pays 3:2
    if player_blackjack && !dealer_blackjack {
        game.bankroll += int(f32(game.current_bet) * 1.5)
        rl.PlaySound(game.sounds.stash)
        return "Blackjack! You won!"
    } else if dealer_blackjack && !player_blackjack {
        game.bankroll -= game.current_bet
        return "Dealer got blackjack! You lost!"
    } else if player_blackjack && dealer_blackjack {
        rl.PlaySound(game.sounds.stash)
        return "Both got blackjack! Push!"
    }
    
    // Regular win conditions
    if player_score > 21 {
        game.bankroll -= game.current_bet
        return "You busted!"
    } else if dealer_score > 21 {
        game.bankroll += game.current_bet
        return "The dealer busted, you won!"
    } else if player_score > dealer_score {
        game.bankroll += game.current_bet
        return "You won!"
    } else if player_score < dealer_score {
        rl.PlaySound(game.sounds.end_game)
        game.bankroll -= game.current_bet
        return "You lost!"
    } else {
        return "It's a tie! Push!"
    }
}

// initialize the game state and the deck
reset :: proc(game: ^Game, screen: Screen = .Game) {
    // Keep the bankroll and background texture from the previous game
    current_bankroll := game.bankroll
    if current_bankroll <= 0 {
        current_bankroll = STARTING_BANKROLL // Reset if bankrupt
    }
    
    // Save the background texture
    bg_texture := game.bg
    
    game^ = Game {
        screen = screen,
        state = .PlaceBet, // Start with betting phase
        deck = init_cards(),
        player = make(Deck, 0, 2),
        dealer = make(Deck, 0, 2),
        cards = load_card_txtures(),
        bankroll = current_bankroll,
        current_bet = 0,
        bg = bg_texture,
    }
    game.sounds.draw_card = rl.LoadSound("assets/audio/draw_card.mp3")
    game.sounds.stash = rl.LoadSound("assets/audio/coin_stash.mp3")
    game.sounds.end_game = rl.LoadSound("assets/audio/end_game.mp3")
}

start_new_hand :: proc(game: ^Game) {
    // Clear previous hands but keep the same game object
    clear(&game.player)
    clear(&game.dealer)
    clear(&game.deck)
    game.deck = init_cards()
    game.state = .PlaceBet
    game.current_bet = 0
    game.outcome_message = ""
    
    // Deal new cards after bet is placed
}

main :: proc() {
    when !ODIN_DEBUG {rl.SetTraceLogLevel(.FATAL)}
    rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(1400, 700, "Blackjack")
    rl.SetTargetFPS(144)
    rl.InitAudioDevice()
    // Load style sheet
    rl.GuiLoadStyle("assets/cherry.rgs")
    rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), FONT_SIZE)
    rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.TEXT_PADDING), i32(WINDOW_PADDING))
    rl.GuiSetStyle(.LABEL, i32(rl.GuiControlProperty.TEXT_PADDING), 0)
        
    game: Game
    game.bankroll = STARTING_BANKROLL
    reset(&game, .Splash)

    // Load background
    bg := rl.LoadImage("assets/bg.jpg")
    game.bg = rl.LoadTextureFromImage(bg)
    rl.UnloadImage(bg)
    mouseState := MouseState.Default
    center_txt: cstring
    center_x, center_y: f32
    button_row_width, button_row_x, button_row_y: f32
    confirm_btn, cancel_btn: rl.Rectangle
    confirm_btn_txt, cancel_btn_txt: cstring
    pointer: rl.Vector2

    game_loop: for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)
        
        // Draw background properly scaled to window size
        window_width := f32(rl.GetScreenWidth())
        window_height := f32(rl.GetScreenHeight())
        rl.DrawTexturePro(
            game.bg,
            {0, 0, f32(game.bg.width), f32(game.bg.height)},
            {0, 0, window_width, window_height},
            {0, 0},
            0,
            rl.WHITE
        )
        pointer = rl.GetMousePosition()
        center_txt = ""
        center_x = f32(rl.GetScreenWidth() / 2)
        center_y = f32(rl.GetScreenHeight() / 2)
        button_row_width = BUTTON_WIDTH * 2 + WINDOW_PADDING
        button_row_x = center_x - button_row_width / 2
        button_row_y = center_y - BUTTON_HEIGHT / 2
        confirm_btn = rl.Rectangle{button_row_x, button_row_y, BUTTON_WIDTH, BUTTON_HEIGHT}
        cancel_btn = rl.Rectangle {
            button_row_x + BUTTON_WIDTH + WINDOW_PADDING,
            button_row_y,
            BUTTON_WIDTH,
            BUTTON_HEIGHT,
        }
        confirm_btn_txt = ""
        cancel_btn_txt = ""
        
        // Always display bankroll info during game
        if game.screen != .Splash {
            bankroll_txt := fmt.ctprintf("Bankroll: $%d", game.bankroll)
            bankroll_width := f32(rl.MeasureText(bankroll_txt, FONT_SIZE))
            rl.GuiLabel(
                {
                    WINDOW_PADDING, 
                    WINDOW_PADDING, 
                    bankroll_width, 
                    FONT_SIZE
                },
                bankroll_txt
            )
            
            // Display current bet if applicable
            if game.state != .PlaceBet && game.current_bet > 0 {
                bet_txt := fmt.ctprintf("Bet: $%d", game.current_bet)
                bet_width := f32(rl.MeasureText(bet_txt, FONT_SIZE))
                rl.GuiLabel(
                    {
                        WINDOW_PADDING, 
                        WINDOW_PADDING * 2 + FONT_SIZE, 
                        bet_width, 
                        FONT_SIZE
                    },
                    bet_txt
                )
            }
        }
        
        switch game.screen {
        case .Splash:
            {
                confirm_btn_txt = "Play"
                cancel_btn_txt = "Quit"
                center_txt = "Blackjack"
            }
        case .Game:
            {
                if game.state == .PlaceBet {
                    // Betting phase UI
                    center_txt = fmt.ctprintf("Place your bet: $%d", game.current_bet)
                    
                    // Render bet amount buttons - Positioned above the player's cards area
                    bet_button_width: f32 = 100
                    bet_padding: f32 = 10
                    total_bet_width := bet_button_width * f32(len(BET_AMOUNTS)) + bet_padding * f32(len(BET_AMOUNTS) - 1)
                    bet_start_x := center_x - total_bet_width/2
                    
                    // Position bet buttons above where the player's cards would be
                    player_area_y := f32(rl.GetScreenHeight()) - CARD_HEIGHT - CARD_HEIGHT / 4
                    bet_row_y := player_area_y - BUTTON_HEIGHT - 40  // Position above player's card area
                    
                    // Draw a panel behind the bet buttons for visibility
                    current_x: f32 = bet_start_x
                    for i in BET_AMOUNTS {
                        bet_txt := fmt.ctprintf("$%d", i)
                        bet_btn := rl.Rectangle{current_x, bet_row_y, bet_button_width, BUTTON_HEIGHT}
                        if rl.GuiButton(bet_btn, bet_txt) && game.bankroll >= i {
                            game.current_bet = i
                        }
                        // Update current_x for the next button
                        current_x += bet_button_width + bet_padding
                    }
                    
                    // Deal button (only active when a bet is placed)
                    confirm_btn_txt = "Deal"
                    cancel_btn_txt = "Back"
                    
                    // Disable deal button if no bet is placed
                    if game.current_bet <= 0 {
                        rl.GuiDisable()
                    }
                    
                    if rl.GuiButton(confirm_btn, confirm_btn_txt) && game.current_bet > 0 {
                        game.state = .PlayerTurn
                        // Deal cards now
                        rl.PlaySound(game.sounds.draw_card)
                        time.accurate_sleep(time.Duration(20 * time.Millisecond))
                        rl.PlaySound(game.sounds.draw_card)
                        time.accurate_sleep(time.Duration(40 * time.Millisecond))
                        rl.PlaySound(game.sounds.draw_card)
                        time.accurate_sleep(time.Duration(60 * time.Millisecond))
                        rl.PlaySound(game.sounds.draw_card)

                        deal_card(&game.deck, &game.player)
                        deal_card(&game.deck, &game.player)
                        deal_card(&game.deck, &game.dealer)
                        deal_card(&game.deck, &game.dealer)
                        
                        // Check for blackjack immediately
                        if is_blackjack(game.player[:]) || is_blackjack(game.dealer[:]) {
                            game.state = .DealerTurn
                            game.outcome_message = process_game_outcome(&game)
                            game.screen = .Score
                        }
                    }
                    
                    // Re-enable UI
                    rl.GuiEnable()
                    
                    if rl.GuiButton(cancel_btn, cancel_btn_txt) {
                        game.screen = .Splash
                    }
                } else if game.state == .PlayerTurn {
                    // Player's turn - show Hit and Stay buttons
                    confirm_btn_txt = "Hit"
                    cancel_btn_txt = "Stay"
                    
                    // Check if player busted
                    player_score := current_score(game.player[:])
                    if player_score > 21 {
                        game.state = .DealerTurn
                        game.outcome_message = process_game_outcome(&game)
                        game.screen = .Score
                    } else if player_score == 21 {
                        // Auto-stay at 21
                        game.state = .DealerTurn
                    }
                    
                    render_player(&game)
                    render_dealer(&game, false) // Only show first dealer card
                    
                    // Display current hand value
                    player_score_txt := fmt.ctprintf("Your hand: %d", player_score)
                    score_width := f32(rl.MeasureText(player_score_txt, FONT_SIZE))
                    rl.GuiLabel(
                        {
                            center_x - score_width/2,
                            f32(rl.GetScreenHeight()) - CARD_HEIGHT - CARD_HEIGHT/4 - FONT_SIZE - 10,
                            score_width,
                            FONT_SIZE
                        },
                        player_score_txt
                    )
                    
                    // Hit button pressed
                    if rl.GuiButton(confirm_btn, confirm_btn_txt) {
                        deal_card(&game.deck, &game.player)
                    }
                    
                    // Stay button pressed
                    if rl.GuiButton(cancel_btn, cancel_btn_txt) {
                        game.state = .DealerTurn
                    }
                } else if game.state == .DealerTurn {
                    // If player's turn is over, dealer plays
                    // Dealer draws until they have at least 17
                    for current_score(game.dealer[:]) < 17 {
                        deal_card(&game.deck, &game.dealer)
                    }
                    game.outcome_message = process_game_outcome(&game)
                    game.screen = .Score
                }
            }
        case .Score:
            {
                confirm_btn_txt = "New"
                cancel_btn_txt = "Quit"
                
                center_txt = game.outcome_message
                player_score := current_score(game.player[:])
                dealer_score := current_score(game.dealer[:])
                
                center_txt = fmt.ctprintf(
                    "%s\nYour score: %i, Dealer's score: %i",
                    game.outcome_message,
                    player_score,
                    dealer_score,
                )
                
                render_player(&game)
                render_dealer(&game, true) // Show all dealer cards
                
                // Check if player is bankrupt
                if game.bankroll <= 0 {
                    center_txt = fmt.ctprintf(
                        "%s\nGame Over - You're bankrupt!",
                        center_txt
                    )
                }
            }
        }
        
        if rl.GuiButton(confirm_btn, confirm_btn_txt) {
            switch game.screen {
            case .Splash:
                reset(&game, .Game)
            case .Game:
                if game.state == .PlayerTurn {
                    // Player hit (already handled above)
                }
            case .Score:
                if game.bankroll <= 0 {
                    // Reset bankroll if player is bankrupt
                    game.bankroll = STARTING_BANKROLL
                    reset(&game, .Game)
                } else {
                    // Start a new hand with the current bankroll
                    start_new_hand(&game)
                    game.screen = .Game
                }
            }
        } else if rl.GuiButton(cancel_btn, cancel_btn_txt) {
            switch game.screen {
            case .Splash:
                break game_loop
            case .Game:
                if game.state == .PlaceBet {
                    game.screen = .Splash
                } else if game.state == .PlayerTurn {
                    // Player stayed (already handled above)
                }
            case .Score:
                break game_loop
            }
        }
        
        if len(center_txt) > 0 {
            // Multi-line support for center text
            lines := strings.split(string(center_txt), "\n")
            line_height := FONT_SIZE + 5
            start_y := center_y - FONT_SIZE - BUTTON_HEIGHT - WINDOW_PADDING
            
            for line in lines {
                line_width := f32(rl.MeasureText(strings.clone_to_cstring(line), FONT_SIZE))
                rl.GuiLabel(
                    {
                        center_x - line_width / 2,
                        start_y,
                        line_width,
                        FONT_SIZE,
                    },
                    strings.clone_to_cstring(line),
                )
                start_y += f32(line_height)
            }
        }
        
        rl.EndDrawing()
    }
    
    unload_card_txtures(&game.cards)
    rl.UnloadSound(game.sounds.end_game)
    rl.UnloadSound(game.sounds.draw_card)
    rl.UnloadSound(game.sounds.stash)
    rl.UnloadTexture(game.bg)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}