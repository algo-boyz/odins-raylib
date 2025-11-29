package main

import "core:fmt"
import "core:os"
import "core:testing"

@(test)
test_bvh_parser :: proc(t: ^testing.T) {
    // Load the BVH file
    filename :: "odins-raylib/3D/models/bvh/assets/stance.bvh"
    fmt.println("Loading BVH file:", filename)
    
    bvh, err := bvh_load(filename)
    if err != .None {
        fmt.eprintln("Failed to load BVH file!")
        fmt.eprintln("Error:", err)
        os.exit(1)
    }
    defer bvh_free(&bvh)
    
    fmt.println("✓ BVH file loaded successfully!\n")
    
    // Print basic information
    fmt.println("--- BVH File Information ---")
    fmt.println("Number of joints:", len(bvh.joints))
    fmt.println("Total channels:", bvh.channel_count)
    fmt.println("Frame count:", bvh.frame_count)
    fmt.println("Frame time:", bvh.frame_time, "seconds")
    fmt.println("Animation duration:", f32(bvh.frame_count) * bvh.frame_time, "seconds")
    fmt.println("Motion data size:", len(bvh.motion_data), "floats")
    fmt.println()
    
    // Print joint hierarchy
    fmt.println("--- Joint Hierarchy ---")
    for joint, idx in bvh.joints {
        indent := ""
        parent_idx := joint.parent
        depth := 0
        
        // Calculate depth for indentation
        temp_idx := idx
        for bvh.joints[temp_idx].parent != -1 {
            depth += 1
            temp_idx = bvh.joints[temp_idx].parent
        }
        
        for _ in 0..<depth {
            indent = fmt.tprint(indent, "  ")
        }
        
        fmt.printf("%s[%d] %s", indent, idx, joint.name)
        
        if joint.end_site {
            fmt.print(" (End Site)")
        }
        
        fmt.println()
        fmt.printf("%s    Offset: (%.2f, %.2f, %.2f)\n", 
                   indent, joint.offset.x, joint.offset.y, joint.offset.z)
        
        if len(joint.channels) > 0 {
            fmt.printf("%s    Channels (%d): ", indent, len(joint.channels))
            for channel, i in joint.channels {
                if i > 0 do fmt.print(", ")
                switch channel {
                case .X_POSITION: fmt.print("Xposition")
                case .Y_POSITION: fmt.print("Yposition")
                case .Z_POSITION: fmt.print("Zposition")
                case .X_ROTATION: fmt.print("Xrotation")
                case .Y_ROTATION: fmt.print("Yrotation")
                case .Z_ROTATION: fmt.print("Zrotation")
                }
            }
            fmt.println()
        }
        fmt.println()
    }
    
    // Print first frame of motion data
    if bvh.frame_count > 0 && len(bvh.motion_data) > 0 {
        fmt.println("--- First Frame Motion Data ---")
        channel_idx := 0
        for joint, joint_idx in bvh.joints {
            if len(joint.channels) == 0 do continue
            
            fmt.printf("%s: ", joint.name)
            for channel in joint.channels {
                if channel_idx >= len(bvh.motion_data) do break
                
                val := bvh.motion_data[channel_idx]
                switch channel {
                case .X_POSITION: fmt.printf("Xpos=%.2f ", val)
                case .Y_POSITION: fmt.printf("Ypos=%.2f ", val)
                case .Z_POSITION: fmt.printf("Zpos=%.2f ", val)
                case .X_ROTATION: fmt.printf("Xrot=%.2f ", val)
                case .Y_ROTATION: fmt.printf("Yrot=%.2f ", val)
                case .Z_ROTATION: fmt.printf("Zrot=%.2f ", val)
                }
                channel_idx += 1
            }
            fmt.println()
        }
        fmt.println()
    }
    
    // Verify motion data integrity
    expected_size := int(bvh.frame_count * bvh.channel_count)
    actual_size := len(bvh.motion_data)
    
    fmt.println("--- Data Integrity Check ---")
    fmt.printf("Expected motion data size: %d floats\n", expected_size)
    fmt.printf("Actual motion data size: %d floats\n", actual_size)
    
    if expected_size == actual_size {
        fmt.println("✓ Motion data size matches expected size!")
    } else {
        fmt.println("✗ Motion data size mismatch!")
    }
    
    fmt.println("\n=== Test Complete ===")
}