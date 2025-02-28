/*
gcc physac_simple_explosion.c -o bin/physac_simple_explosion -I ../../../projects/raylib-quickstart/build/external/raylib-master/src/ -L ../../../projects/raylib-quickstart/bin/Debug/ -lraylib -lm -lpthread -ldl -lX11 && ./bin/physac_simple_explosion
*/
#include "raylib.h"
#include "raymath.h"

#define EXPLOSION_RADIUS 90

#define PHYSAC_IMPLEMENTATION
#include "../../../projects/Physac/src/physac.h"

typedef struct {
    Vector2 position;
    float timeElapsed;
    bool active;
} Explosion;

//angle, distance and force from explosion to effected circle
float angleRad;
float distance;
float velX; 
float velY;

int main()
{
    int screenWidth = 800;
    int screenHeight = 450;

    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(screenWidth, screenHeight, "[physac] Basic demo");

    InitPhysics();
    SetPhysicsGravity(0, 0);

    PhysicsBody circle0 = CreatePhysicsBodyCircle((Vector2){ screenWidth/2 -75, screenHeight/2 -60 }, 35, 0.2);
    PhysicsBody circle1 = CreatePhysicsBodyCircle((Vector2){ screenWidth/2, screenHeight/2 }, 35, 0.2);
    PhysicsBody circle2 = CreatePhysicsBodyCircle((Vector2){50,50}, 10, 0.2);
    PhysicsBody circle3 = CreatePhysicsBodyCircle((Vector2){80,80}, 100, 0.2);
    PhysicsBody circle4 = CreatePhysicsBodyCircle((Vector2){300,380}, 10, 0.2);
    PhysicsBody circle5 = CreatePhysicsBodyCircle((Vector2){330,385}, 10, 0.2);
    PhysicsBody circle6 = CreatePhysicsBodyCircle((Vector2){305,370}, 10, 0.2);
    PhysicsBody circle7 = CreatePhysicsBodyCircle((Vector2){310,375}, 10, 0.2);
    PhysicsBody circle8 = CreatePhysicsBodyCircle((Vector2){305,385}, 10, 0.2);
    
    SetTargetFPS(60);

    Explosion explosion = {0};
    explosion.active = false;

    while (!WindowShouldClose())
    {
        //---EXOLOSION BEGIN
        if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)){
            if (!explosion.active) {
                explosion.position = GetMousePosition();
                explosion.timeElapsed = 0.0f;
                explosion.active = true;
                // Apply explosion force only once per click
                for (int i = GetPhysicsBodiesCount() - 1; i >= 0; i--) {
                    PhysicsBody body = GetPhysicsBody(i);
                    if (CheckCollisionCircles(body->position, body->shape.radius, explosion.position, EXPLOSION_RADIUS)) {
                        float angleRad = atan2(body->position.y - explosion.position.y, body->position.x - explosion.position.x);
                        float forceMagnitude = Vector2Distance(body->position,explosion.position);
                        //float forceMagnitude = 100.0f; // should be determined by distance
                        float velX = cos(angleRad) * forceMagnitude;
                        float velY = sin(angleRad) * forceMagnitude;
                        PhysicsAddForce(body, (Vector2){velX, velY});
                    }
                }
            }
        }
        if (explosion.active) {
            explosion.timeElapsed += GetFrameTime();
            if (explosion.timeElapsed >= 1.0f) {
                explosion.active = false;
            }
        }
        //---EXOLOSION END

        BeginDrawing();

            ClearBackground(BLACK);

            DrawFPS(screenWidth - 90, screenHeight - 30);
            //animate explosion
            if (explosion.active) {
                float alpha = 1.0f - (explosion.timeElapsed / 1.0f);
                float explosionSize = EXPLOSION_RADIUS + (explosion.timeElapsed * 30.0f);
                Color yellow = (Color){255, 255, 0, (unsigned char)(alpha * 255)};
                DrawCircleV(explosion.position, explosionSize, yellow);
                Color orange = (Color){255, 165, 0, (unsigned char)(alpha * 255)};
                DrawCircleV(explosion.position, explosionSize * 0.5f, orange);
            }

            // Draw created physics bodies and bounce off walls
            //bodiesCount = GetPhysicsBodiesCount();
            for (int i = 0; i < GetPhysicsBodiesCount(); i++)
            {
                PhysicsBody body = GetPhysicsBody(i);
                 // Check walls collision for bouncing
                if ((body->position.x >= (GetScreenWidth() - 45)) || (body->position.x <= 45)) body->velocity.x *= -.8f;
                if ((body->position.y >= (GetScreenHeight() - 45)) || (body->position.y <= 45)) body->velocity.y *= -.8f;

                //draw physics circles
                if (body != NULL)
                {
                    int vertexCount = GetPhysicsShapeVerticesCount(i);
                    for (int j = 0; j < vertexCount; j++)
                    {
                        // Get physics bodies shape vertices to draw lines
                        // Note: GetPhysicsShapeVertex() already calculates rotation transformations
                        Vector2 vertexA = GetPhysicsShapeVertex(body, j);

                        int jj = (((j + 1) < vertexCount) ? (j + 1) : 0);   // Get next vertex or first to close the shape
                        Vector2 vertexB = GetPhysicsShapeVertex(body, jj);

                        DrawLineV(vertexA, vertexB, GREEN);     // Draw a line between two vertex positions
                    }
                }
            }

        EndDrawing();
    }
    ClosePhysics();
    CloseWindow();
    return 0;
}