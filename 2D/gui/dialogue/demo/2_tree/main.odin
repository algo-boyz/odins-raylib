package main

import "base:runtime"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import raydial "../../"

Game_State :: struct {
    player_health: i32,
    player_gold: i32,
    has_sword: bool,
    has_shield: bool,
    has_potion: bool,
    has_key: bool,
}

on_buy_sword :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^Game_State)user_data
    if state.has_sword {
        fmt.println("You already own a sword!")
    } else if state.player_gold >= 50 {
        state.player_gold -= 50
        state.has_sword = true
        fmt.println("You bought a sword!")
    } else {
        fmt.println("Not enough gold!")
    }
}

on_buy_shield :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^Game_State)user_data
    if state.has_shield {
        fmt.println("You already own a shield!")
    } else if state.player_gold >= 30 {
        state.player_gold -= 30
        state.has_shield = true
        fmt.println("You bought a shield!")
    } else {
        fmt.println("Not enough gold!")
    }
}

on_buy_potion :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^Game_State)user_data
    if state.has_potion {
        fmt.println("You already have a potion!")
    } else if state.player_gold >= 20 {
        state.player_gold -= 20
        state.has_potion = true
        fmt.println("You bought a healing potion!")
    } else {
        fmt.println("Not enough gold!")
    }
}

on_find_key :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^Game_State)user_data
    state.has_key = true
    fmt.println("You found a mysterious key!")
}

on_use_potion :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^Game_State)user_data
    if state.has_potion {
        state.player_health = 100
        state.has_potion = false
        fmt.println("You used the healing potion!")
    } else {
        fmt.println("You don't have a potion!")
    }
}

on_attack :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^Game_State)user_data
    damage := i32(10)
    if state.has_sword { damage += 5 }

    state.player_gold += damage / 2

    fmt.printfln("You dealt %d damage to the monster!", damage)
}

on_defend :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^Game_State)user_data
    defense := i32(5)
    if state.has_shield { defense += 5 }

    if state.player_health < 100 {
        state.player_health += defense / 2
        if state.player_health > 100 { state.player_health = 100 }
    }

    fmt.printfln("You defended against the monster, blocking %d damage!", defense)
}

on_navigate_to_shop :: proc "c" (user_data: rawptr) {
    manager := cast(^raydial.Manager)user_data
    context = runtime.default_context()
    raydial.transition_to_node(manager, "shop")
}

on_navigate_to_dungeon :: proc "c" (user_data: rawptr) {
    manager := cast(^raydial.Manager)user_data
    context = runtime.default_context()
    raydial.transition_to_node(manager, "dungeon")
}

on_navigate_to_battle :: proc "c" (user_data: rawptr) {
    manager := cast(^raydial.Manager)user_data
    context = runtime.default_context()
    raydial.transition_to_node(manager, "battle")
}

on_navigate_to_treasure :: proc "c" (user_data: rawptr) {
    manager := cast(^raydial.Manager)user_data
    context = runtime.default_context()
    raydial.transition_to_node(manager, "treasure")
}

on_navigate_to_root :: proc "c" (user_data: rawptr) {
    manager := cast(^raydial.Manager)user_data
    context = runtime.default_context()
    raydial.transition_to_node(manager, "root")
}

main :: proc() {
    screen_width :: 1024
    screen_height :: 768
    rl.InitWindow(screen_width, screen_height, "Dialogue Tree Example")
    rl.SetTargetFPS(60)

    game_state: Game_State = {
        player_health = 100,
        player_gold = 100,
        has_sword = false,
        has_shield = false,
        has_potion = false,
        has_key = false,
    }

    // Create dialogue nodes
    root_node := raydial.create_dialogue_node("root", "Welcome to the game!")
    shop_node := raydial.create_dialogue_node("shop", "Welcome to the shop!")
    dungeon_node := raydial.create_dialogue_node("dungeon", "You enter the dungeon...")
    battle_node := raydial.create_dialogue_node("battle", "Prepare for battle!")
    treasure_node := raydial.create_dialogue_node("treasure", "You found a treasure room!")

    // Create dialogue manager
    manager := raydial.create_dialogue_manager(root_node)

    // Connect nodes in the dialogue tree
    raydial.add_choice(root_node, shop_node)
    raydial.add_choice(root_node, dungeon_node)
    raydial.add_choice(dungeon_node, battle_node)
    raydial.add_choice(dungeon_node, treasure_node)

    // Set up root node
    root_panel := raydial.create_panel({100, 100, 824, 568}, rl.LIGHTGRAY)

    root_title := raydial.create_label({120, 120, 784, 40}, "Welcome to the Adventure!", true)
    root_message := raydial.create_label({120, 180, 784, 40}, "Choose your path:", true)

    shop_button := raydial.create_button({120, 240, 300, 50}, "Visit the Shop", on_navigate_to_shop, manager)
    dungeon_button := raydial.create_button({120, 310, 300, 50}, "Enter the Dungeon", on_navigate_to_dungeon, manager)

    raydial.add_component(root_panel, root_title)
    raydial.add_component(root_panel, root_message)
    raydial.add_component(root_panel, shop_button)
    raydial.add_component(root_panel, dungeon_button)
    root_node.components = root_panel

    // Set up shop node
    shop_panel := raydial.create_panel({100, 100, 824, 568}, rl.LIGHTGRAY)

    shop_title := raydial.create_label({120, 120, 784, 40}, "Welcome to the Shop!", false)
    gold_label := raydial.create_label({120, 180, 784, 40}, "Your gold: 100", true)

    sword_button := raydial.create_button({120, 240, 300, 50}, "Buy Sword (50g)", on_buy_sword, &game_state)
    shield_button := raydial.create_button({120, 310, 300, 50}, "Buy Shield (30g)", on_buy_shield, &game_state)
    potion_button := raydial.create_button({120, 380, 300, 50}, "Buy Potion (20g)", on_buy_potion, &game_state)
    back_button := raydial.create_button({120, 450, 300, 50}, "Back to Main Menu", on_navigate_to_root, manager)

    raydial.add_component(shop_panel, shop_title)
    raydial.add_component(shop_panel, gold_label)
    raydial.add_component(shop_panel, sword_button)
    raydial.add_component(shop_panel, shield_button)
    raydial.add_component(shop_panel, potion_button)
    raydial.add_component(shop_panel, back_button)
    shop_node.components = shop_panel

    // Set up dungeon node
    dungeon_panel := raydial.create_panel({100, 100, 824, 568}, rl.DARKGRAY)

    dungeon_title := raydial.create_label({120, 120, 784, 40}, "You enter the dungeon...", true)
    dungeon_message := raydial.create_label({120, 180, 784, 80}, "The dungeon is dark and damp. You hear strange noises echoing through the halls. What will you do?", true)
    dungeon_stats_label := raydial.create_label({120, 270, 784, 40}, "Your stats will appear here", true)
    dungeon_equip_label := raydial.create_label({120, 320, 784, 40}, "Your equipment will appear here", true)

    battle_button := raydial.create_button({120, 380, 300, 50}, "Fight Monsters", on_navigate_to_battle, manager)
    treasure_button := raydial.create_button({120, 450, 300, 50}, "Search for Treasure", on_navigate_to_treasure, manager)
    dungeon_back_button := raydial.create_button({440, 450, 300, 50}, "Return to Town", on_navigate_to_root, manager)

    raydial.add_component(dungeon_panel, dungeon_title)
    raydial.add_component(dungeon_panel, dungeon_message)
    raydial.add_component(dungeon_panel, dungeon_stats_label)
    raydial.add_component(dungeon_panel, dungeon_equip_label)
    raydial.add_component(dungeon_panel, battle_button)
    raydial.add_component(dungeon_panel, treasure_button)
    raydial.add_component(dungeon_panel, dungeon_back_button)
    dungeon_node.components = dungeon_panel

    // Set up battle node
    battle_panel := raydial.create_panel({100, 100, 824, 568}, rl.DARKGRAY)

    battle_title := raydial.create_label({120, 120, 784, 40}, "Prepare for battle!", true)
    battle_message := raydial.create_label({120, 180, 784, 80}, "A fierce monster appears before you! You must fight to survive!", true)
    health_label := raydial.create_label({120, 280, 784, 40}, "Health: 100", true)

    attack_button := raydial.create_button({120, 340, 300, 50}, "Attack", on_attack, &game_state)
    defend_button := raydial.create_button({120, 410, 300, 50}, "Defend", on_defend, &game_state)
    use_potion_button := raydial.create_button({120, 480, 300, 50}, "Use Potion", on_use_potion, &game_state)
    battle_back_button := raydial.create_button({440, 480, 300, 50}, "Back to Dungeon", on_navigate_to_dungeon, manager)

    raydial.add_component(battle_panel, battle_title)
    raydial.add_component(battle_panel, battle_message)
    raydial.add_component(battle_panel, health_label)
    raydial.add_component(battle_panel, attack_button)
    raydial.add_component(battle_panel, defend_button)
    raydial.add_component(battle_panel, use_potion_button)
    raydial.add_component(battle_panel, battle_back_button)
    battle_node.components = battle_panel

    // Set up treasure node
    treasure_panel := raydial.create_panel({100, 100, 824, 568}, rl.GOLD)

    treasure_title := raydial.create_label({120, 120, 784, 40}, "You found a treasure room!", false)
    treasure_message := raydial.create_label({120, 180, 784, 40}, "There's a locked chest and a mysterious key on the ground.", false)

    find_key_button := raydial.create_button({120, 240, 300, 50}, "Pick up the Key", on_find_key, &game_state)
    treasure_back_button := raydial.create_button({120, 310, 300, 50}, "Return to Dungeon", on_navigate_to_dungeon, manager)

    raydial.add_component(treasure_panel, treasure_title)
    raydial.add_component(treasure_panel, treasure_message)
    raydial.add_component(treasure_panel, find_key_button)
    raydial.add_component(treasure_panel, treasure_back_button)
    treasure_node.components = treasure_panel

    for !rl.WindowShouldClose() {
        raydial.update_dialogue_manager(manager)

        // Update UI text based on game state
        gold_data := cast(^raydial.Label_Data)gold_label.data
        gold_data.text = fmt.tprintf("Your gold: %d", game_state.player_gold)

        health_data := cast(^raydial.Label_Data)health_label.data
        health_data.text = fmt.tprintf("Health: %d", game_state.player_health)

        // Update dungeon stats text
        dungeon_stats_data := cast(^raydial.Label_Data)dungeon_stats_label.data
        dungeon_stats_data.text = fmt.tprintf("Health: %d | Gold: %d", game_state.player_health, game_state.player_gold)

        // Update dungeon equipment text
        equip_parts: [dynamic]string
        defer delete(equip_parts)
        if game_state.has_sword { append(&equip_parts, "Sword") }
        if game_state.has_shield { append(&equip_parts, "Shield") }
        if game_state.has_potion { append(&equip_parts, "Potion") }
        if game_state.has_key { append(&equip_parts, "Key") }
        dungeon_equip_text := len(equip_parts) > 0 ? strings.join(equip_parts[:], ", ") : "None"
        dungeon_equip_data := cast(^raydial.Label_Data)dungeon_equip_label.data
        dungeon_equip_data.text = dungeon_equip_text

        // Enable/disable shop buttons based on what player owns
        raydial.set_component_enabled(sword_button, !game_state.has_sword && game_state.player_gold >= 50)
        raydial.set_component_enabled(shield_button, !game_state.has_shield && game_state.player_gold >= 30)
        raydial.set_component_enabled(potion_button, !game_state.has_potion && game_state.player_gold >= 20)

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        raydial.draw_dialogue_manager(manager)

        rl.DrawText("Press ESC to exit", 10, 10, 20, rl.DARKGRAY)
        rl.EndDrawing()
    }
    raydial.free_dialogue_manager(manager)
    rl.CloseWindow()
}