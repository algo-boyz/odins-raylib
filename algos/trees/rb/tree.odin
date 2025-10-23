package rbt

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:testing"

Color :: enum {
	Red, Black, // Tree (RBT)
}
// based on the book: https://github.com/GenoWong/IntroductionToAlgorithms

when ODIN_DEBUG {
	// In debug mode, store color separately to allow for easier integration with debuggers
	Node :: struct($Key, $Value: typeid) where intrinsics.type_is_comparable(Key) {
		left, right, parent: ^Node(Key, Value),
		color:               Color,
		key:                 Key,
		value:               Value,
	}
} else {
	// In normal operation, node color is encoded in the parent ptr to save space.
	Node :: struct($Key, $Value: typeid) where intrinsics.type_is_comparable(Key) {
		parent:      uintptr,
		left, right: ^Node(Key, Value),
		key:         Key,
		value:       Value,
	}
}

Tree :: struct($Key, $Value: typeid) where intrinsics.type_is_comparable(Key) {
	allocator: mem.Allocator,
	sentinel:  Node(Key, Value),
	root:      ^Node(Key, Value),
}

@(private)
get_color :: #force_inline proc(node: ^$Node) -> Color {
	when ODIN_DEBUG {
		return node.color
	} else {
		return cast(Color)(node.parent & 1)
	}
}

@(private)
set_color :: #force_inline proc(node: ^$Node, color: Color) {
	when ODIN_DEBUG {
		node.color = color
	} else {
		node.parent = (node.parent >> 1) << 1 // Clear color attribute
		node.parent = node.parent | cast(uintptr)int(color) // Set it to the new value
	}
}

@(private)
copy_color_from :: #force_inline proc(dest_node: ^$Node, src_node: ^Node) {
	set_color(dest_node, get_color(src_node))
}

// Parent pointers need special handling to account for storing the color attribute
@(private)
get_parent :: #force_inline proc(node: ^$Node) -> ^Node {
	when ODIN_DEBUG {
		return node.parent
	} else {
		parent_ptr := (node.parent >> 1) << 1 // Remove the color attribute
		return cast(^Node)parent_ptr
	}
}

@(private)
set_parent :: #force_inline proc(node: ^$Node, parent: ^Node) {
	when ODIN_DEBUG {
		node.parent = parent
	} else {
		current_color := cast(Color)(node.parent & 1)
		node.parent = cast(uintptr)parent
		set_color(node, current_color)
	}
}

@(private)
get_grandparent :: #force_inline proc(node: ^$Node) -> ^Node {
	return get_parent(get_parent(node))
}

@(private)
init_node :: proc(tree: ^Tree($Key, $Value), key: Key, value: Value) -> ^Node(Key, Value) {
	node := new(Node(Key, Value), tree.allocator)
	node.key = key
	node.value = value
	node.left = &tree.sentinel
	node.right = &tree.sentinel
	set_parent(node, &tree.sentinel)
	set_color(node, Color.Red)
	return node
}

@(private)
rotate_right :: proc(tree: ^$Tree, node: ^$Node) {
	sibling := node.left
	node.left = sibling.right

	// Turn siblings right subtree into nodes left subtree
	if sibling.right != &tree.sentinel {
		set_parent(sibling.right, node)
	}
	set_parent(sibling, get_parent(node))
	if get_parent(node) == &tree.sentinel {
		tree.root = sibling
	} else {
		if node == get_parent(node).right {
			get_parent(node).right = sibling
		} else {
			get_parent(node).left = sibling
		}
	}
	sibling.right = node
	set_parent(node, sibling)
}

@(private)
rotate_left :: proc(tree: ^$Tree, node: ^$Node) {
	sibling := node.right
	node.right = sibling.left

	// Turn siblings left subtree into nodes right subtree
	if sibling.left != &tree.sentinel {
		set_parent(sibling.left, node)
	}
	set_parent(sibling, get_parent(node))
	if get_parent(node) == &tree.sentinel {
		tree.root = sibling
	} else {
		if node == get_parent(node).left {
			get_parent(node).left = sibling
		} else {
			get_parent(node).right = sibling
		}
	}
	sibling.left = node
	set_parent(node, sibling)
}

@(private)
rebalance_after_insert :: proc(tree: ^$Tree, node: ^$Node) {
	node := node
	uncle: ^Node
	for (node != tree.root && get_color(get_parent(node)) == Color.Red) {
		// Rebalancing cases
		if get_grandparent(node) != &tree.sentinel &&
		   get_parent(node) == get_grandparent(node).left {
			uncle = get_grandparent(node).right
			if uncle != &tree.sentinel && get_color(uncle) == Color.Red {
				set_color(get_parent(node), Color.Black)
				set_color(uncle, Color.Black)
				set_color(get_grandparent(node), Color.Red)
				node = get_grandparent(node)
			} else {
				if node == get_parent(node).right {
					// Case 2
					node = get_parent(node)
					rotate_left(tree, node)
				}
				// Case 3
				set_color(get_parent(node), Color.Black)
				set_color(get_grandparent(node), Color.Red)
				rotate_right(tree, get_grandparent(node))
			}
		} else if get_grandparent(node) != &tree.sentinel {
			uncle = get_grandparent(node).left
			if uncle != &tree.sentinel && get_color(uncle) == Color.Red {
				set_color(get_parent(node), Color.Black)
				set_color(uncle, Color.Black)
				set_color(get_grandparent(node), Color.Red)
				node = get_grandparent(node)
			} else {
				if node == get_parent(node).left {
					// Case 2
					node = get_parent(node)
					rotate_right(tree, node)
				}
				// Case 3
				set_color(get_parent(node), Color.Black)
				set_color(get_grandparent(node), Color.Red)
				rotate_left(tree, get_grandparent(node))
			}
		}
	}
	set_color(tree.root, Color.Black)
}

@(private)
max_node :: proc(tree: ^$Tree, node: ^$TreeNode) -> ^TreeNode {
	node := node
	for node.right != &tree.sentinel {
		node = node.right
	}
	return node
}

@(private)
min_node :: proc(tree: ^$Tree, node: ^$TreeNode) -> ^TreeNode {
	node := node
	for node.left != &tree.sentinel {
		node = node.left
	}
	return node
}

@(private)
find_successor :: proc(tree: ^$Tree, node: ^$Node) -> ^Node {
	assert(node != nil)
	node := node
	if get_color(node.left) == Color.Red {
		return max_node(tree, node.left)
	} else if node.right != &tree.sentinel {
		return min_node(tree, node.right)
	}
	parent := get_parent(node)
	for parent != &tree.sentinel && node == parent.right {
		node = parent
		parent = get_parent(node)
	}
	return parent
}

@(private)
rebalance_after_removal :: proc(tree: ^$Tree, node: ^$Node) {
	node := node
	sibling: ^Node
	for tree.root != node && get_color(node) == Color.Black {
		if node == get_parent(node).left {
			sibling = get_parent(node).right
			if get_color(sibling) == Color.Red {
				set_color(sibling, Color.Black)
				set_color(get_parent(node), Color.Red)
				rotate_left(tree, get_parent(node))
				sibling = get_parent(node).right
			}
			if get_color(sibling.right) == Color.Black && get_color(sibling.left) == Color.Black {
				set_color(sibling, Color.Red)
				node = get_parent(node)
			} else {
				if get_color(sibling.right) == Color.Black {
					set_color(sibling, Color.Red)
					set_color(sibling.left, Color.Black)
					rotate_right(tree, sibling)
					sibling = get_parent(node).right
				}
				copy_color_from(sibling, get_parent(node))
				set_color(get_parent(node), Color.Black)
				set_color(sibling.right, Color.Black)
				rotate_left(tree, get_parent(node))
				node = tree.root
			}
		} else {
			sibling = get_parent(node).left
			if get_color(sibling) == Color.Red {
				set_color(sibling, Color.Black)
				set_color(get_parent(node), Color.Red)
				rotate_right(tree, get_parent(node))
				sibling = get_parent(node).left
			}
			if get_color(sibling.right) == Color.Black && get_color(sibling.left) == Color.Black {
				set_color(sibling, Color.Red)
				node = get_parent(node)
			} else {
				if get_color(sibling.left) == Color.Black {
					set_color(sibling, Color.Red)
					set_color(sibling.right, Color.Black)
					rotate_left(tree, sibling)
					sibling = get_parent(node).left
				}
				copy_color_from(sibling, get_parent(node))
				set_color(get_parent(node), Color.Black)
				set_color(sibling.left, Color.Black)
				rotate_right(tree, get_parent(node))
				node = tree.root
			}
		}
	}
	set_color(node, Color.Black)
}

@(private)
find_node :: proc(tree: ^Tree($Key, $Value), key: Key) -> (^Node(Key, Value), bool) {
	node := tree.root
	for node != &tree.sentinel {
		switch {
		case key == node.key:
			return node, true
		case key > node.key:
			node = node.right
		case key < node.key:
			node = node.left
		}
	}
	return nil, false
}

@(private)
free_nodes :: proc(tree: ^$Tree, node: ^$Node) {
	if node == &tree.sentinel {
		return
	}
	free_nodes(tree, node.left)
	free(node, tree.allocator)
	free_nodes(tree, node.right)
}


// Public interface

init :: proc(
	$Key, $Value: typeid,
	allocator: mem.Allocator = context.allocator,
) -> ^Tree(Key, Value) {
	tree := new(Tree(Key, Value), allocator)
	tree.sentinel = Node(Key, Value){}
	tree.allocator = allocator
	tree.root = &tree.sentinel
	return tree
}

destroy :: proc(tree: ^Tree($Key, $Value)) {
	free_nodes(tree, tree.root)
	free(tree, tree.allocator)
}

rm_node :: proc(tree: ^Tree($Key, $Value), key: Key) -> (Value, bool) {
	child, successor: ^Node(Key, Value)

	if node_to_delete, ok := find_node(tree, key); ok {
		defer free(successor, tree.allocator)
		if node_to_delete.left == &tree.sentinel || node_to_delete.right == &tree.sentinel {
			successor = node_to_delete
		} else {
			successor = find_successor(tree, node_to_delete)
		}
		if successor.left != &tree.sentinel {
			child = successor.left
		} else {
			child = successor.right
		}
		set_parent(child, get_parent(successor))
		if get_parent(successor) == &tree.sentinel {
			tree.root = child
		} else if successor == get_parent(successor).left {
			get_parent(successor).left = child
		} else {
			get_parent(successor).right = child
		}
		if successor != node_to_delete {
			key_to_be_deleted := node_to_delete.key
			value_to_be_deleted := node_to_delete.value
			node_to_delete.key = successor.key
			node_to_delete.value = successor.value
			successor.key = key_to_be_deleted
			successor.value = value_to_be_deleted
		}
		if get_color(successor) == Color.Black {
			rebalance_after_removal(tree, child)
		}
		return successor.value, true
	}
	return Value{}, false
}

insert_node :: proc(tree: ^Tree($Key, $Value), key: Key, value: Value) -> bool {
	parent := tree.root
	if parent == &tree.sentinel {
		tree.root = init_node(tree, key, value)
		rebalance_after_insert(tree, tree.root)
	} else {
		for {
			if parent.key == key { 	// Duplicate
				return false
			} else if (parent.key > key) {
				if (parent.left == &tree.sentinel) {
					node := init_node(tree, key, value)
					parent.left = node
					set_parent(node, parent)
					rebalance_after_insert(tree, node)
					break
				} else {
					parent = parent.left
				}
			} else {
				if (parent.right == &tree.sentinel) {
					node := init_node(tree, key, value)
					parent.right = node
					set_parent(node, parent)
					rebalance_after_insert(tree, node)
					break
				} else {
					parent = parent.right
				}
			}
		}
	}
	return true
}

visit_sub_nodes :: proc(
	tree: ^Tree($Key, $Value),
	node: ^Node(Key, Value),
	visitor: proc(value: Value),
) {
	if node == &tree.sentinel {
		return
	}
	visit_sub_nodes(tree, node.left, visitor)
	visitor(node.value)
	visit_sub_nodes(tree, node.right, visitor)
}

find :: proc(tree: ^Tree($Key, $Value), key: Key) -> (Value, bool) {
	if node, ok := find_node(tree, key); ok {
		return node.value, true
	} else {
		return Value{}, false
	}
}

@(test)
test_simple_tree :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	tree := init(string, string, mem.tracking_allocator(&track))
	defer {
		destroy(tree)
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	testing.expect(t, insert_node(tree, "Mal", "Captain"))
	testing.expect(t, insert_node(tree, "Zoe", "First Mate"))
	testing.expect(t, insert_node(tree, "Wash", "Pilot"))
	testing.expect(t, insert_node(tree, "Inara", "Consort"))
	testing.expect(t, insert_node(tree, "Jayne", "Muscle"))
	testing.expect(t, insert_node(tree, "Kaylee", "Mechanic"))
	testing.expect(t, insert_node(tree, "Simon", "Doctor"))
	testing.expect(t, insert_node(tree, "River", "Secret Weapon"))
	testing.expect(t, insert_node(tree, "Book", "Preacher"))

	// Duplicates are not allowed
	testing.expect(t, !insert_node(tree, "Mal", "Can't have two captains"))

	testing.expect(
		t,
		tree.root.key == "Mal",
		fmt.tprintf("Incorrect root node, expected 'Mal' got %v\n", tree.root.key),
	)

	// :-(
	wash, ok := rm_node(tree, "Wash")
	testing.expect(t, ok)
	testing.expect(t, wash == "Pilot")
	// Prove it's removed
	_, ok = find(tree, "Wash")
	testing.expect(t, !ok)

	// Lookup some values
	_, ok = find(tree, "Mal")
	testing.expect(t, ok)
	_, ok = find(tree, "River")
	testing.expect(t, ok)
	_, ok = find(tree, "Zoe")
	testing.expect(t, ok)
	_, ok = find(tree, "Kaylee")
	testing.expect(t, ok)
	_, ok = find(tree, "Jayne")
	testing.expect(t, ok)

	// Try to find a non-existent key
	_, ok = find(tree, "Ravager")
	testing.expect(t, !ok)
}