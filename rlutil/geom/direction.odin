package geom

import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

RelativeDirection :: enum {
	FACING_EACH_OTHER,
	A_BEHIHD_B, 
	B_BEHIND_A,
	NEITHER_FACING_EACH_OTHER,
}

getRelativeDirection :: proc(a:  i32, d1: i32, b: i32, d2: i32) -> RelativeDirection {
	ba := a - b
	ab := b - a

	 aFacingB := (ab < 0 && d1 == -1) || (ab > 0 && d1 == 1)
	 bFacingA := (ba < 0 && d2 == -1) || (ba > 0 && d2 == 1)

	 if aFacingB && bFacingA {
		 return .FACING_EACH_OTHER  
	 }

	 if aFacingB && !bFacingA {
		 return .B_BEHIND_A  
	 }
	  
	 if bFacingA && !aFacingB {
		 return .A_BEHIHD_B  
	 }
	
	 return .NEITHER_FACING_EACH_OTHER
}

rand_direction :: proc() -> (dir: rl.Vector2) {
    dir = {
        rand.float32_range(-1, 1),
        rand.float32_range(-1, 1),
    }
    return linalg.normalize(dir)
}