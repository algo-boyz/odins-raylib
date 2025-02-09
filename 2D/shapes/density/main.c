#include <raylib.h>
#include <raymath.h>
// https://github.com/arceryz/raylib-examples
// A dense injection is a function from integers 0->infinity to
// the real line [0, 1] such that every point on the real line,
// gets approached infinity close by the function.
// The function does not map the same point twice (hence injective).
//
// The Straight Dense Injection does this by iterating a subdivided
// grid while skipping earlier points.
// The grid becomes finer and finer as n increase.
float StraightDI(int n)
{
    float r = pow(2, floor(log2(n+1)));
    float v = (1.5 + n) / r - 1;
    return v;
}

// The Inward Dense Injection satisfies the same DI conditions but
// iterates the grid points in an alternating fashion rather than increasing.
// This means each layer converges to 0.5. 
// This one looks nicer and is better suited when symmetry is preferred.
float InwardDI(int n)
{
    float r = pow(2, floor(log2(n+1)));
    float A = 1 - n%2;
    float s = floor((float)(n+1-r)/2);
    float v = (0.5 + s + A*(r-1-2*s))/r;
    return v;
}

// Rather than convering inwards, this one converges outwards.
float OutwardDI(int n)
{
    int r = (int)pow(2, floor(log2(n+1)));
    float A = 1 - (3*r-3-n)%2;
    float s = floor((float)(2*r-2-n)/2);
    float v = (0.5 + s + A*(r-1-2*s))/r;
    return v;
}

int main()
{
    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(1000, 800, "Dense Injection");

    int ladders = 8;
    int maxPoints = 1 << ladders;
    float height = 500;
    float width = 900;
    Color gridColor = ColorFromHSV(0, 0, 0.2);

    float speed = 100;
    float baseSpeed = 100;
    int speedFactor = 0;

    float circleRadius = 4;
    int numPoints = 0;
    float numPointsF = 0;
    int diType = 0;

    float x0 = 500 - width/2;
    float y0 = 500 - height/2;

    Vector2 *points = RL_MALLOC(sizeof(Vector2)*maxPoints);

    // Load Latex formulas.
    Texture2D diTextures[3] = {
        LoadTexture("sdi.png"),
        LoadTexture("idi.png"),
        LoadTexture("odi.png")
    };
    for (int i = 0; i < 3; i++) GenTextureMipmaps(&diTextures[i]);

    while(!WindowShouldClose()) {
        numPointsF = Wrap(numPointsF+GetFrameTime()*speed, 0, maxPoints-1);
        numPoints = (int)numPointsF;
        speed = baseSpeed * pow(2, speedFactor);
        float lastValue = 0;
        if (IsKeyPressed(KEY_SPACE)) numPointsF = 0;
        if (IsKeyPressed(KEY_RIGHT)) diType = Clamp(diType+1, 0, 2);
        if (IsKeyPressed(KEY_LEFT)) diType = Clamp(diType-1, 0, 2);
        if (IsKeyPressed(KEY_UP)) speedFactor = Clamp(speedFactor+1, -6, 2);
        if (IsKeyPressed(KEY_DOWN)) speedFactor = Clamp(speedFactor-1, -6, 2);

        BeginDrawing();
        ClearBackground(BLACK);

        // Iterate all ladders and draw points.
        // Keep track of points in vector list. 

        for (int i=0, n=0; i < ladders; i++) {
            float y = y0 + height*1.0/ladders*(i+0.5);
            DrawLine(x0, y, x0+width, y, gridColor);
            DrawCircle(x0, y, circleRadius, gridColor);
            DrawCircle(x0+width, y, circleRadius, gridColor);

            // Draw 2^i points on each ladder, up until the total number of points.
            for (int j=0; j < pow(2, i) && n < numPoints; j++, n++) {
                float diValues[3] = { StraightDI(n), InwardDI(n), OutwardDI(n) };
                float f = diValues[diType];
                if (n == numPoints-1) lastValue = f;

                float x = x0 + width*f;
                points[n] = (Vector2){ x0 + width/maxPoints*n, y0+10-150*f };
                DrawCircleV(points[n], 2, DARKBLUE);

                DrawLine(x, y, x, y0+height, gridColor);
                DrawCircle(x, y, circleRadius, ColorFromHSV(360*f, 1, 1));
            }
        }

        DrawLineStrip(points, numPoints, DARKBLUE);
        Texture texture = diTextures[diType];
        DrawTextureEx(texture, (Vector2){ 500-texture.width/2.0f*0.75, 50 }, 0, 0.75, WHITE);
        const char *diNames[] = { 
            "1. Straight Dense Injection (SDI)", 
            "2. Inward Dense Injection (IDI)", 
            "3. Outward Dense Injection (ODI)"
        };
        DrawText(diNames[diType], 10, 10, 20, DARKGRAY);
        DrawText(TextFormat("(Left/Right) Change Function, (Up/Down) Speed = %3.1f", speed), 700, 10, 10, DARKGRAY);
        EndDrawing();
    }
}