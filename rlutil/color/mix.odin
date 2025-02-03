#!/usr/bin/env python
from random import random
from vec2 import Vec2

def mix(a, b, amount):
    return (1-amount)*a + amount*b

def clamp(x, min, max):
    if x < min: return min
    if x > max: return max
    return x

W, H = 1024, 768
MIN_RADIUS, MAX_RADIUS = W/40, W/12
BUCKET_SIZE = 1.1*MAX_RADIUS
STIFFNESS = 0.5
GRAVITY = Vec2(0, 2000)

def collisions_between(things):
    buckets = dict()
    maybe_collisions = set()
    for t in things:
        xmin = int((t.pos.x-t.radius)/BUCKET_SIZE)
        xmax = int((t.pos.x+t.radius)/BUCKET_SIZE)
        for x in range(xmin, xmax+1):
            ymin = int((t.pos.y-t.radius)/BUCKET_SIZE)
            ymax = int((t.pos.y+t.radius)/BUCKET_SIZE)
            for y in range(ymin, ymax+1):
                if (x,y) not in buckets:
                    buckets[(x,y)] = []
                else:
                    for other in buckets[(x,y)]:
                        maybe_collisions.add((other, t))
                buckets[(x,y)].append(t)

    return [(a,b) for (a,b) in maybe_collisions
            if a.pos.dist(b.pos) <= a.radius + b.radius]

class Ball:
    def __init__(self, pos, radius):
        self.pos = pos
        self.prevpos = pos
        self.radius = radius
        self.mass = radius*radius

balls = []
for _ in range(30):
    r = mix(MIN_RADIUS, MAX_RADIUS, random())
    pos = Vec2(mix(r, W-r, random()), mix(r, H-r, random()))
    balls.append(Ball(pos, r))

dt, iterations = 1/60, 5
while True:
    # Verlet:
    for b in balls:
        b.prevpos, b.pos = b.pos, (2*b.pos - b.prevpos + dt*dt*GRAVITY)

    # Solve constraints
    for _ in range(iterations):
        # Resolve overlaps:
        for (a,b) in collisions_between(balls):
            a2b = (b.pos - a.pos).normalized()
            overlap = (a.radius+b.radius) - a.pos.dist(b.pos)
            a.pos = a.pos - a2b*(STIFFNESS*overlap*(b.mass/(a.mass+b.mass)))
            b.pos = b.pos + a2b*(STIFFNESS*overlap*(a.mass/(a.mass+b.mass)))

        # Stay on screen:
        for b in balls:
            clamped = b.pos.clamped(Vec2(b.radius,b.radius),
                    Vec2(W-b.radius,H-b.radius))
            if clamped != b.pos:
                b.pos = b.pos.mix(clamped, STIFFNESS)
    # Draw:
    for b in balls:
        draw_circle(b.pos.x, b.pos.y, b.radius)