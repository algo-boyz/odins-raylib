#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "dependencies/include/GL/glew.h"
#include "dependencies/include/GLFW/glfw3.h"
#include "graphics.h"
#include "shader.h"
#include "model.h"
#include "verlet.h"
#include "camera.h"
#include "peripheral.h"

#define ANIMATION_TIME 90.0f // Frames
#define ADDITION_SPEED 10
#define TARGET_FPS 60
#define NUM_SUBSTEPS 8

const unsigned int SCR_WIDTH = 1280;
const unsigned int SCR_HEIGHT = 720;
bool cursorEntered = false;
Camera* camera;
float cameraRadius = 24.0f;
int totalFrames = 0;
int main() {
    GLFWwindow* window;
    if (!glfwInit())
        return -1;
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Verlet Integration", NULL, NULL);
    if (!window) {
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    glfwSwapInterval(1);
    glfwSetCursorEnterCallback(window, cursor_enter_callback);
    glewInit();
    glClearColor(0.1, 0.1, 0.1, 1.0);
    glClearStencil(0);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glFrontFace(GL_CCW);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glPointSize(3.0);

    unsigned int phongShader = createShader("shaders/phong_vertex.glsl", "shaders/phong_fragment.glsl");
    unsigned int instanceShader = createShader("shaders/instance_vertex.glsl", "shaders/instance_fragment.glsl");
    unsigned int baseShader = createShader("shaders/base_vertex.glsl", "shaders/base_fragment.glsl");

    Mesh* mesh = createMesh("models/sphere.obj", true);
    Mesh* cubeMesh = createMesh("models/cube.obj", false);

    mfloat_t containerPosition[VEC3_SIZE] = { 0, 0, 0 };
    mfloat_t rotation[VEC3_SIZE] = { 0, 0, 0 };

    VerletObject* verlets = malloc(sizeof(VerletObject) * MAX_INSTANCES);
    instantiateVerlets(verlets, MAX_INSTANCES);
    int numActive = 0;

    mfloat_t view[MAT4_SIZE];
    camera = createCamera((mfloat_t[]) { 0, 0, cameraRadius });
    Mouse* mouse = createMouse();
    float dt = 0.000001f;
    float lastFrameTime = (float)glfwGetTime();
    char title[100] = "";
    srand(time(NULL));
    while (!glfwWindowShouldClose(window)) {
        updateMouse(window, mouse);
        processInput(window);

        if (glfwGetKey(window, GLFW_KEY_G) == GLFW_PRESS) {
            addForce(verlets, numActive, (mfloat_t[]) { 0, 3, 0 }, -30.0f * NUM_SUBSTEPS);
        }
        updateCamera(window, mouse, camera);
        createViewMatrix(view, camera);
        
        glUseProgram(phongShader);
        glUniformMatrix4fv(glGetUniformLocation(phongShader, "view"),
            1, GL_FALSE, view);
        glUseProgram(0);
        glUseProgram(baseShader);
        glUniformMatrix4fv(glGetUniformLocation(baseShader, "view"),
            1, GL_FALSE, view);
        glUseProgram(0);
        glUseProgram(instanceShader);
        glUniformMatrix4fv(glGetUniformLocation(instanceShader, "view"),
            1, GL_FALSE, view);
        glUseProgram(0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

        if (1.0 / dt >= TARGET_FPS - 5 && glfwGetKey(window, GLFW_KEY_V) == GLFW_PRESS && numActive < MAX_INSTANCES) {
            numActive += ADDITION_SPEED;
        }
        if (totalFrames % 60 == 0) {
            sprintf(title, "FPS : %-4.0f | Balls : %-10d", 1.0 / dt, numActive);
            glfwSetWindowTitle(window, title);
        }
        if (glfwGetKey(window, GLFW_KEY_LEFT) == GLFW_PRESS) {
            containerPosition[0] -= 0.05f;
        }
        if (glfwGetKey(window, GLFW_KEY_RIGHT) == GLFW_PRESS) {
            containerPosition[0] += 0.05f;
        }
        if (glfwGetKey(window, GLFW_KEY_DOWN) == GLFW_PRESS) {
            containerPosition[1] -= 0.05f;
        }
        if (glfwGetKey(window, GLFW_KEY_UP) == GLFW_PRESS) {
            containerPosition[1] += 0.05f;
        }
        float sub_dt = dt / NUM_SUBSTEPS;
        for (int i = 0; i < NUM_SUBSTEPS; i++) {
            applyForces(verlets, numActive);
            // applyCollisions(verlets, numActive);
            applyGridCollisions(verlets, numActive);
            applyConstraints(verlets, numActive, containerPosition);
            updatePositions(verlets, numActive, sub_dt);
        }
        float verletPositions[numActive * VEC3_SIZE];
        float verletVelocities[numActive];
        int posPointer = 0;
        int velPointer = 0;
        for (int i = 0; i < numActive; i++) {
            VerletObject obj = verlets[i];
            verletPositions[posPointer++] = obj.current[0];
            verletPositions[posPointer++] = obj.current[1];
            verletPositions[posPointer++] = obj.current[2];
            float vel = vec3_distance(obj.current, obj.previous) * 10;
            verletVelocities[velPointer++] = vel;
        }
        glBindBuffer(GL_ARRAY_BUFFER, mesh->positionVBO);
        glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float) * INSTANCE_STRIDE * numActive, verletPositions);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glBindBuffer(GL_ARRAY_BUFFER, mesh->velocityVBO);
        glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float) * numActive, verletVelocities);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        drawInstanced(mesh, instanceShader, GL_TRIANGLES, numActive, verlets[0].radius);
        drawMesh(cubeMesh, baseShader, GL_TRIANGLES, containerPosition, rotation, CONTAINER_RADIUS * 2 + VERLET_RADIUS * 3);

        glfwSwapBuffers(window);
        glfwPollEvents();

        dt = (float)glfwGetTime() - lastFrameTime;
        while (dt < 1.0f / TARGET_FPS) {
            dt = (float)glfwGetTime() - lastFrameTime;
        }
        lastFrameTime = (float)glfwGetTime();
        totalFrames++;
    }
    glfwTerminate();
    return 0;
}

void processInput(GLFWwindow* window) {
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);
}

void updateCamera(GLFWwindow* window, Mouse* mouse, Camera* camera) {
    float speed = 0.08f;
    mfloat_t temp[VEC3_SIZE];

    float universalAngle = totalFrames / 4.0f;
    vec3(camera->position, MCOS(MRADIANS(universalAngle)) * cameraRadius, camera->position[1], MSIN(MRADIANS(universalAngle)) * cameraRadius);
    camera->yaw = universalAngle + 180.0f;

    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) {
        vec3_add(camera->position, camera->position, vec3_multiply_f(temp, camera->up, speed));
        camera->pitch -= 0.22f;
        cameraRadius -= 0.01f;
    }
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS) {
        vec3_subtract(camera->position, camera->position, vec3_multiply_f(temp, camera->up, speed));
        camera->pitch += 0.22f;
        cameraRadius += 0.01f;
    }
}

void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    glViewport(0, 0, width, height);
}

void cursor_enter_callback(GLFWwindow* window, int entered) {
    if (entered) {
        glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
        cursorEntered = true;
    } else { // The cursor left the content area of the window
    }
}

void instantiateVerlets(VerletObject* objects, int size) {
    int distance = 7.0f;
    for (int i = 0; i < size; i++) {
        VerletObject* obj = &(objects[i]);
        float x = MSIN(i) * distance;
        float z = MCOS(i) * distance;
        float xp = MSIN(i) * distance * 0.999;
        float zp = MCOS(i) * distance * 0.999;
        float y = rand() % (2 - 1 + 1) + 1;
        vec3(obj->current, x, y, z);
        vec3(obj->previous, xp, y, zp);
        vec3(obj->acceleration, 0, 0, 0);
        obj->radius = VERLET_RADIUS;
    }
}

#include "verlet.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#define GRAVITY -15.0f
#define THREAD_COUNT 8
#define CONTAINER_RADIUS 6.0f
#define VERLET_RADIUS 0.15f

void applyForces(VerletObject* objects, int size) {
    for (int i = 0; i < size; i++) {
        objects[i].acceleration[1] += GRAVITY;
    }
}

void handleCollision(VerletObject* a, VerletObject* b) {
    mfloat_t axis[VEC3_SIZE];
    vec3_subtract(axis, a->current, b->current);
    mfloat_t dist = vec3_length(axis);
    if (dist < a->radius + b->radius) {
        mfloat_t norm[VEC3_SIZE];
        vec3_divide_f(norm, axis, dist);
        mfloat_t delta = a->radius + b->radius - dist;
        vec3_multiply_f(norm, norm, 0.5 * delta);
        vec3_add(a->current, a->current, norm);
        vec3_subtract(b->current, b->current, norm);
    }
}

void applyCollisions(VerletObject* objects, int size) {
    for (int a = 0; a < size; a++) {
        for (int b = 0; b < size; b++) {
            if (a != b) {
                handleCollision(&objects[a], &objects[b]);
            }
        }
    }
}

#define DIMENSION 58
#define MAX_PER_CELL 4
VerletObject* grid[DIMENSION][DIMENSION][DIMENSION][MAX_PER_CELL];

void handleGridCollision(VerletObject** currentCell, VerletObject** otherCell) {
    for (int a = 0; currentCell[a]; a++) {
        for (int b = 0; otherCell[b]; b++) {
            VerletObject* vA = currentCell[a];
            VerletObject* vB = otherCell[b];
            if (vA != vB) {
                // printf("%p <-> %p\n", vA, vB);
                handleCollision(vA, vB);
            }
        }
    }
}

void pushNode(int gridX, int gridY, int gridZ, VerletObject* obj) {
    VerletObject** currentCell = grid[gridX][gridY][gridZ];
    int i = 0;
    while (currentCell[i])
        i++;
    grid[gridX][gridY][gridZ][i] = obj;
}

void fillGrid(VerletObject* objects, int size) {
    for (int i = 0; i < size; i++) {
        VerletObject* obj = &(objects[i]);
        int gridX = obj->current[0] / (VERLET_RADIUS * 2) + DIMENSION / 2;
        int gridY = obj->current[1] / (VERLET_RADIUS * 2) + DIMENSION / 2;
        int gridZ = obj->current[2] / (VERLET_RADIUS * 2) + DIMENSION / 2;
        gridX = clampi(gridX, 0, DIMENSION - 1);
        gridY = clampi(gridY, 0, DIMENSION - 1);
        gridZ = clampi(gridZ, 0, DIMENSION - 1);
        pushNode(gridX, gridY, gridZ, obj);
    }
}

void clearGrid() {
    memset(grid, 0, DIMENSION * DIMENSION * DIMENSION * MAX_PER_CELL * sizeof(VerletObject*));
}

void* threadFunction(void* arg) {
    int thread_id = *((int*)arg);
    int start = 1 + thread_id * ((DIMENSION) / THREAD_COUNT);
    int end = 1 + (thread_id + 1) * ((DIMENSION) / THREAD_COUNT);
    if (thread_id == THREAD_COUNT - 1) {
        end += DIMENSION % THREAD_COUNT - 2;
    }
    for (int x = start; x < end; x++) {
        for (int y = 1; y < DIMENSION - 1; y++) {
            for (int z = 1; z < DIMENSION - 1; z++) {
                VerletObject** currentCell = grid[x][y][z];
                if (!currentCell[0])
                    continue;
                for (int dx = -1; dx <= 1; dx++) {
                    for (int dy = -1; dy <= 1; dy++) {
                        for (int dz = -1; dz <= 1; dz++) {
                            VerletObject** otherCell = grid[x + dx][y + dy][z + dz];
                            if (!otherCell[0])
                                continue;
                            handleGridCollision(currentCell, otherCell);
                        }
                    }
                }
            }
        }
    }
    return NULL;
}

pthread_t threads[THREAD_COUNT];
int thread_ids[THREAD_COUNT];

void applyGridCollisions(VerletObject* objects, int size) {
    clearGrid();
    fillGrid(objects, size);
    for (int t = 0; t < THREAD_COUNT; t++) {
        thread_ids[t] = t;
        pthread_create(&threads[t], NULL, threadFunction, (void*)&thread_ids[t]);
    }
    for (int t = 0; t < THREAD_COUNT; t++) {
        pthread_join(threads[t], NULL);
    }
}

void applyConstraints(VerletObject* objects, int size, mfloat_t* containerPosition) {
    mfloat_t bWidth = CONTAINER_RADIUS;
    for (int i = 0; i < size; i++) {
        VerletObject* obj = &(objects[i]);
        if (obj->current[0] < -bWidth + containerPosition[0]) {
            mfloat_t disp = obj->current[0] - obj->previous[0];
            obj->current[0] = -bWidth + containerPosition[0];
            obj->previous[0] = obj->current[0] + disp;
        }
        if (obj->current[0] > bWidth + containerPosition[0]) {
            mfloat_t disp = obj->current[0] - obj->previous[0];
            obj->current[0] = bWidth + containerPosition[0];
            obj->previous[0] = obj->current[0] + disp;
        }
        if (obj->current[1] < -bWidth + containerPosition[1]) {
            mfloat_t disp = obj->current[1] - obj->previous[1];
            obj->current[1] = -bWidth + containerPosition[1];
            obj->previous[1] = obj->current[1] + disp;
        }
        if (obj->current[1] > bWidth + containerPosition[1]) {
            mfloat_t disp = obj->current[1] - obj->previous[1];
            obj->current[1] = bWidth + containerPosition[1];
            obj->previous[1] = obj->current[1] + disp;
        }
        if (obj->current[2] < -bWidth + containerPosition[2]) {
            mfloat_t disp = obj->current[2] - obj->previous[2];
            obj->current[2] = -bWidth + containerPosition[2];
            obj->previous[2] = obj->current[2] + disp;
        }
        if (obj->current[2] > bWidth + containerPosition[2]) {
            mfloat_t disp = obj->current[2] - obj->previous[2];
            obj->current[2] = bWidth + containerPosition[2];
            obj->previous[2] = obj->current[2] + disp;
        }
    }
}

void updatePositions(VerletObject* objects, int size, float dt) {
    for (int i = 0; i < size; i++) {
        VerletObject* obj = &(objects[i]);
        mfloat_t disp[VEC3_SIZE];
        vec3_subtract(disp, obj->current, obj->previous);
        vec3_assign(obj->previous, obj->current);
        vec3_multiply_f(obj->acceleration, obj->acceleration, dt * dt);
        vec3_add(obj->current, obj->current, disp);
        vec3_add(obj->current, obj->current, obj->acceleration);
        vec3_zero(obj->acceleration);
    }
}

void addForce(VerletObject* objects, int size, mfloat_t* center, float strength) {
    for (int i = 0; i < size; i++) {
        VerletObject* obj = &(objects[i]);
        mfloat_t disp[VEC3_SIZE];
        vec3_subtract(disp, obj->current, center);
        mfloat_t dist = vec3_length(disp);
        if (dist > 0) {
            mfloat_t norm[VEC3_SIZE];
            vec3_divide_f(norm, disp, dist);
            vec3_multiply_f(norm, norm, strength);
            vec3_add(obj->acceleration, obj->acceleration, norm);
        }
    }
}
