package main

import "core:fmt"
import "core:math"
import "core:mem"
import rl "vendor:raylib"

WIDTH :: 1000
HEIGHT :: 500
RADIUS :: 30

// Point structure
Point :: struct {
    x: f32,
    y: f32,
}

// TreeNode structure
TreeNode :: struct {
    value: i32,
    position: Point,
    left: ^TreeNode,
    right: ^TreeNode,
}

// BinaryTree structure
BinaryTree :: struct {
    root: ^TreeNode,
    root_position: Point,
}

// BINARY TREE FUNCTIONS

create_binary_tree :: proc(root_position: Point) -> ^BinaryTree {
    tree := new(BinaryTree)
    tree.root = nil
    tree.root_position = root_position
    return tree
}

create_binary_tree_node :: proc(value: i32, position: Point) -> ^TreeNode {
    node := new(TreeNode)
    node.value = value
    node.position = position
    node.left = nil
    node.right = nil
    return node
}

insert :: proc(tree: ^BinaryTree, value: i32) {
    if tree.root == nil {
        tree.root = create_binary_tree_node(value, tree.root_position)
        return
    } else {
        insert_helper(tree.root, value)
    }
}

insert_helper :: proc(node: ^TreeNode, value: i32) {
    X_CHANGE :: 150
    Y_CHANGE :: 80
    
    if node == nil {
        return
    }
    
    curr_node_position := node.position
    
    if node.value > value {
        if node.left != nil {
            insert_helper(node.left, value)
        } else {
            new_position := Point{
                x = curr_node_position.x - X_CHANGE,
                y = curr_node_position.y + Y_CHANGE,
            }
            node.left = create_binary_tree_node(value, new_position)
        }
    } else {
        if node.right != nil {
            insert_helper(node.right, value)
        } else {
            new_position := Point{
                x = curr_node_position.x + X_CHANGE,
                y = curr_node_position.y + Y_CHANGE,
            }
            node.right = create_binary_tree_node(value, new_position)
        }
    }
}

// VISUALIZATION FUNCTIONS

draw_binary_tree :: proc(tree: ^BinaryTree, node_radius: i32) {
    if tree == nil {
        return
    }
    draw_binary_tree_helper(tree.root, node_radius, nil)
}

draw_binary_tree_helper :: proc(node: ^TreeNode, node_radius: i32, parent_position: ^Point) {
    if node == nil {
        return
    }
    
    rl.DrawCircleLines(i32(node.position.x), i32(node.position.y), f32(node_radius), rl.WHITE)
    draw_binary_tree_node_value(node)
    
    if parent_position != nil {
        draw_parent_child_line(parent_position^, node.position, node_radius)
    }
    
    draw_binary_tree_helper(node.left, node_radius, &node.position)
    draw_binary_tree_helper(node.right, node_radius, &node.position)
}

draw_parent_child_line :: proc(parent_position: Point, node_position: Point, node_radius: i32) {
    dx := node_position.x - parent_position.x
    dy := node_position.y - parent_position.y
    d := math.sqrt(dx * dx + dy * dy)
    ux := dx / d
    uy := dy / d
    
    parent_slide := Point{
        x = parent_position.x + ux * f32(node_radius),
        y = parent_position.y + uy * f32(node_radius),
    }
    
    node_slide := Point{
        x = node_position.x - ux * f32(node_radius),
        y = node_position.y - uy * f32(node_radius),
    }
    
    rl.DrawLine(i32(parent_slide.x), i32(parent_slide.y), i32(node_slide.x), i32(node_slide.y), rl.WHITE)
}

draw_binary_tree_node_value :: proc(node: ^TreeNode) {
    font_size :: 20
    
    text := fmt.tprintf("%d", node.value)
    text_cstring := fmt.ctprintf("%d", node.value)
    
    text_size := rl.MeasureTextEx(rl.GetFontDefault(), text_cstring, font_size, 1)
    text_x := i32(node.position.x - text_size.x / 2)
    text_y := i32(node.position.y - text_size.y / 2)
    
    rl.DrawTextEx(rl.GetFontDefault(), text_cstring, {f32(text_x), f32(text_y)}, font_size, 1, rl.WHITE)
}

// SEARCH FUNCTIONS

dfs :: proc(tree: ^BinaryTree) {
    if tree == nil {
        return
    }
    dfs_helper(tree.root)
    fmt.println()
}

dfs_helper :: proc(node: ^TreeNode) {
    if node == nil {
        return
    }
    
    dfs_helper(node.left)
    fmt.printf("%d (%d, %d) ", node.value, i32(node.position.x), i32(node.position.y))
    dfs_helper(node.right)
}

main :: proc() {
    root_position := Point{x = WIDTH / 2, y = 100}
    tree := create_binary_tree(root_position)
    // Insert values
    insert(tree, 10)
    insert(tree, 50)
    insert(tree, 12)
    insert(tree, 20)
    insert(tree, 15)
    insert(tree, 0)
    insert(tree, -1)
    insert(tree, -4)
    insert(tree, -3)
    insert(tree, 2)
    rl.InitWindow(WIDTH, HEIGHT, "BINARY TREE")
    defer rl.CloseWindow()
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.BLACK)
        draw_binary_tree(tree, RADIUS)
    }
}