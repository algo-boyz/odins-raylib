package geom

import "core:math"
import rl "vendor:raylib"

PI :: 3.14159265358979323846 
DEG2RAD :: PI/180.0
RAD2DEG :: 180.0/PI
Pi :: 3.14159265358979323846
TwoPi :: 6.28318530717958647692
HalfPi :: 1.57079632679489661923
QuarterPi :: 0.78539816339744830962
TwoOverPi :: 0.63661977236758134308
MaxFloatBeforePrecisionLoss :: 100000
Tolerance :: 0.001
FloatMax :: 3.40282347e+38
FloatEpsilon :: 1.19209290e-7

point_in_circle :: proc(point: rl.Vector2, c: rl.Circle) -> bool {
    pointToOrigen:rl.Vector2 = c.pos - point
    return length_squared(pointToOrigen) <= c.radius * c.radius
}

length_squared :: proc(v: rl.Vector2) -> f32 {
    return (v.x * v.x) + (v.y * v.y)
}

circle_collision :: proc(a, b: rl.Circle, pushout: ^f32) -> bool {
  result := false
  
  distanceSquared := length_squared(b.pos - a.pos)
  if(distanceSquared < (a.radius + b.radius) * (a.radius + b.radius))
  {
    if pushout != nil {
      pushout = math.sqrt_f32(distanceSquared) - a.radius - b.radius
    }
    result = true
  }
  
  return result
}


rect_circle_collision :: proc(rect: rl.Rectangle,  c: rl.Circle,  pushout: rl.Vector2) -> bool {
    topLeft := rect.pos
    topRight := rect.pos + rl.Vector2{rect.size.x}
    bottomLeft := rect.pos + rl.Vector2{0, rect.size.y}
    bottomRight := rect.pos + rect.size
  
    projectedPos := rl.Vector2{}
    projectedPos.y = clamp(c.pos.y, topLeft.y, bottomRight.y)
    projectedPos.x = clamp(c.pos.x, topLeft.x, bottomRight.x)
  
  if  point_in_circle(projectedPos, c) {
    if pushout {
      pointDir := c.pos - projectedPos
      lengthToPoint := len(pointDir)
      penetrationLength := c.radius - lengthToPoint
      
      pushoutDir := rl.Normalize(pointDir)
      
      *pushout = pushoutDir * penetrationLength
    }
    return true
  }
  
  return false
}