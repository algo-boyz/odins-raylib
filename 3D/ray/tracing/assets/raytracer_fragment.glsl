#version 430

in vec2 fragTexCoord;

uniform vec3 viewParams;
uniform vec2 resolution;

uniform vec3 cameraPosition;
uniform vec3 cameraDirection;
uniform vec2 screenCenter;

uniform sampler2D texture0;

uniform int numRenderedFrames;

uniform bool denoise;
uniform bool pause;

uniform int raysPerPixel;
uniform int maxBounces;

uniform float blur;

struct SkyMaterial
{
	vec4 skyColorZenith;
	vec4 skyColorHorizon;
	vec4 groundColor;
	vec4 sunColor;
	vec3 sunDirection;
	float sunFocus;
	float sunIntensity;
};

struct RayTracingMaterial
{
	vec4 color;
	vec4 emission;
	float emissionStrength;
	float smoothness;
};

struct Sphere
{
	vec3 position;
	float radius;
	RayTracingMaterial material;
};

struct Triangle
{
	vec3 posA;
	vec3 posB;
	vec3 posC;
	vec3 normalA;
	vec3 normalB;
	vec3 normalC;
};

struct Mesh
{
	int firstTriangleIndex;
	int numTriangles;
	int rootNodeIndex;
	int bvhDepth;
	RayTracingMaterial material;
	vec3 boundingMin;
	vec3 boundingMax;
};

struct BoundingBox
{
	vec3 min;
	vec3 max;
};

struct Node
{
	BoundingBox bounds;
	int triangleIndex;
	int numTriangles;
	int childIndex;
};

layout(std430, binding = 1) readonly restrict buffer SphereBuffer {
	Sphere spheres[];
};

layout(std430, binding = 2) readonly restrict buffer ObjectBuffer {
	Mesh meshes[];
};

layout(std430, binding = 3) readonly restrict buffer TriangleBuffer
{
	Triangle triangles[];
};

layout(std430, binding = 4) readonly restrict buffer NodeBuffer
{
	Node nodes[];
};

uniform SkyMaterial skyMaterial;

out vec4 out_color;

struct Ray
{
	vec3 origin;
	vec3 direction;
	vec3 invDirection;
};

struct HitInfo
{
	bool didHit;
	float distance;
	vec3 hitPoint;
	vec3 hitNormal;
	RayTracingMaterial material;
};

vec3 CalcRayDir(vec2 nCoord) {
	vec3 horizontal = normalize(cross(cameraDirection, vec3(.0, 1.0, .0)));
	vec3 vertical = normalize(cross(horizontal, cameraDirection));
	return normalize(cameraDirection + horizontal * nCoord.x + vertical * nCoord.y);
}

mat3 setCamera()
{
	vec3 cw = normalize(cameraDirection);
	vec3 cp = vec3(0.0, 1.0, 0.0);
	vec3 cu = normalize(cross(cw, cp));
	vec3 cv = (cross(cu, cw));
	return mat3(cu, cv, cw);
}

HitInfo RayTriangle(Ray ray, Triangle tri)
{
	vec3 edgeAB = tri.posB - tri.posA;
	vec3 edgeAC = tri.posC - tri.posA;
	vec3 normalVector = cross(edgeAB, edgeAC);
	vec3 ao = ray.origin - tri.posA;
	vec3 dao = cross(ao, ray.direction);

	float determinant = -dot(ray.direction, normalVector);
	float invDet = 1 / determinant;

	float dst = dot(ao, normalVector) * invDet;
	float u = dot(edgeAC, dao) * invDet;
	float v = -dot(edgeAB, dao) * invDet;
	float w = 1 - u - v;

	HitInfo hitInfo;
	hitInfo.didHit = determinant >= 1E-6 && dst >= 0 && u >= 0 && v >= 0 && w >= 0;
	hitInfo.hitPoint = ray.origin + ray.direction * dst;
	hitInfo.hitNormal = normalize(tri.normalA * w + tri.normalB * u + tri.normalC * v);
	hitInfo.distance = dst;
	return hitInfo;
}

HitInfo RaySphere(Ray ray, vec3 center, float radius)
{
	HitInfo hitInfo;
	hitInfo.didHit = false;
	vec3 offsetRayOrigin = ray.origin - center;

	float a = dot(ray.direction, ray.direction);
	float b = 2.0 * dot(offsetRayOrigin, ray.direction);
	float c = dot(offsetRayOrigin, offsetRayOrigin) - (radius * radius);

	float discriminant = b * b - 4.0 * a * c;

	if (discriminant >= 0.0)
	{
		float distance = (-b - sqrt(discriminant)) / (2.0 * a);

		if (distance >= 0.0)
		{
			hitInfo.didHit = true;
			hitInfo.distance = distance;
			hitInfo.hitPoint = ray.origin + (ray.direction * distance);
			hitInfo.hitNormal = normalize(hitInfo.hitPoint - center);
		}
	}

	return hitInfo;
}

float RayBoundingBox(Ray ray, vec3 boundingMin, vec3 boundingMax) {
	vec3 tMin = (boundingMin - ray.origin) * ray.invDirection;
	vec3 tMax = (boundingMax - ray.origin) * ray.invDirection;
	vec3 t1 = min(tMin, tMax);
	vec3 t2 = max(tMin, tMax);
	float dstFar = min(min(t2.x, t2.y), t2.z);
	float dstNear = max(max(t1.x, t1.y), t1.z);

	bool didHit = dstFar >= dstNear && dstFar > 0;
	return didHit ? dstNear : 100000000;
}

HitInfo RayBVH(Ray ray, int nodeOffset, RayTracingMaterial material)
{
	int nodeStack[32];
	int stackIndex = 0;
	nodeStack[stackIndex++] = nodeOffset;

	HitInfo result;
	result.distance = 100000000;

	while (stackIndex > 0)
	{
		Node node = nodes[nodeStack[--stackIndex]];

		if (node.childIndex == 0)
		{
			for (int t = node.triangleIndex; t < node.triangleIndex + node.numTriangles; t++)
			{
				Triangle tri = triangles[t];

				HitInfo hitInfo = RayTriangle(ray, tri);

				if (hitInfo.didHit && hitInfo.distance < result.distance)
				{
					result = hitInfo;
				}
			}
		}
		else
		{
			int childIndexA = node.childIndex + 0;
			int childIndexB = node.childIndex + 1;
			Node childA = nodes[childIndexA];
			Node childB = nodes[childIndexB];

			float dstA = RayBoundingBox(ray, childA.bounds.min, childA.bounds.max);
			float dstB = RayBoundingBox(ray, childB.bounds.min, childB.bounds.max);

			bool isNearestA = dstA <= dstB;
			float dstNear = isNearestA ? dstA : dstB;
			float dstFar = isNearestA ? dstB : dstA;
			int childIndexNear = isNearestA ? childIndexA : childIndexB;
			int childIndexFar = isNearestA ? childIndexB : childIndexA;

			if (dstFar < result.distance) nodeStack[stackIndex++] = childIndexFar;
			if (dstNear < result.distance) nodeStack[stackIndex++] = childIndexNear;
		}
	}

	return result;
}

HitInfo CalculateRayCollision(Ray ray, int bounce)
{
	HitInfo closestHit;
	closestHit.didHit = false;

	closestHit.distance = 100000000;

	for (int i = 0; i < spheres.length(); i++)
	{
		Sphere sphere = spheres[i];
		HitInfo hitInfo = RaySphere(ray, sphere.position, sphere.radius);

		if (hitInfo.didHit && hitInfo.distance < closestHit.distance)
		{
			closestHit = hitInfo;
			closestHit.material = sphere.material;
		}
	}

	for (int i = 0; i < meshes.length(); i++)
	{
		RayTracingMaterial mat = meshes[i].material;
		HitInfo hit = RayBVH(ray, meshes[i].rootNodeIndex, mat);

		if (hit.didHit && hit.distance < closestHit.distance)
		{
			closestHit.didHit = true;
			closestHit.distance = hit.distance;
			closestHit.hitNormal = hit.hitNormal;
			closestHit.hitPoint = ray.origin + ray.direction * hit.distance;
			closestHit.material = mat;
		}
	}

	return closestHit;
}

float random(inout int state)
{
	state = state * 747796405 + 2891336453;
	int result = ((state >> ((state) >> 28) + 4) ^ state) * 277803737;
	result = (result >> 22) ^ result;
	return result / 4294967295.0;
}

float randomNormalDistribution(inout int state)
{
	float theta = 2 * 3.1415926 * random(state);
	float rho = sqrt(-2 * log(random(state)));
	return rho * cos(theta);
}

vec3 randomDirection(inout int state)
{
	float x = randomNormalDistribution(state);
	float y = randomNormalDistribution(state);
	float z = randomNormalDistribution(state);
	return normalize(vec3(x, y, z));
}

vec3 randomHemisphereDirection(vec3 normal, inout int state)
{
	vec3 dir = randomDirection(state);
	return dir * sign(dot(normal, dir));
}

vec3 getEnvironmentLight(Ray ray)
{
	float skyGradientT = pow(smoothstep(0.0, 0.4, ray.direction.y), 0.35);
	vec3 skyGradient = mix(skyMaterial.skyColorHorizon.rgb, skyMaterial.skyColorZenith.rgb, skyGradientT);
	float sun = pow(max(0, dot(ray.direction, -skyMaterial.sunDirection)), skyMaterial.sunFocus) * skyMaterial.sunIntensity;

	float groundToSkyT = smoothstep(-0.01, 0.0, ray.direction.y);
	float sunMask = float(int(groundToSkyT >= 1));
	return mix(skyMaterial.groundColor.rgb, skyGradient, groundToSkyT) + sun * sunMask * skyMaterial.sunColor.rgb;
}

vec3 trace(Ray ray, inout int rngState, int maxBounces)
{
	vec3 incomingLight = vec3(0);
	vec3 rayColor = vec3(1);

	vec3 debugNormal = vec3(0);

	for (int i = 0; i <= maxBounces; i++)
	{
		HitInfo hitInfo = CalculateRayCollision(ray, i);
		if (hitInfo.didHit)
		{
			ray.origin = hitInfo.hitPoint;
			vec3 specularDirection = reflect(ray.direction, hitInfo.hitNormal);
			vec3 diffuseDirection = normalize(hitInfo.hitNormal + randomHemisphereDirection(hitInfo.hitNormal, rngState));
						
			ray.direction = normalize(mix(diffuseDirection, specularDirection, hitInfo.material.smoothness));
			ray.invDirection = 1 / ray.direction;

			RayTracingMaterial material = hitInfo.material;
			vec3 emittedLight = material.emission.rgb * material.emission.a;

			incomingLight += emittedLight * rayColor;
			rayColor *= material.color.rgb;

			debugNormal = hitInfo.hitNormal;
		}
		else
		{
			incomingLight += getEnvironmentLight(ray) * rayColor;
			break;
		}
	}

	return incomingLight;
}

Ray offsetRay(Ray ray, float offsetStrength, inout int rngState)
{
	ray.direction += normalize(randomDirection(rngState)) * offsetStrength;
	ray.invDirection = 1/ray.direction;
	return ray;
}

vec3 drawFrame(Ray ray, inout int rngState, int maxRaysPerPixel, int maxBounces)
{
	vec3 total = vec3(0);

	for (int i = 0; i < maxRaysPerPixel; i++)
	{
		total += trace(offsetRay(ray, blur, rngState), rngState, maxBounces);
	}

	return total / maxRaysPerPixel;
}

void main()
{
	vec2 UV = gl_FragCoord.xy / resolution;

	vec2 nCoord = (gl_FragCoord.xy - screenCenter.xy) / screenCenter.y;
	mat3 cameraMatrix = setCamera();

	float focalLength = length(cameraDirection);
	vec3 rayDirection = cameraMatrix * normalize(vec3(nCoord, focalLength));

	Ray ray;
	ray.origin = cameraPosition;
	ray.direction = rayDirection;
	ray.invDirection = 1/rayDirection;

	int pixelIndex = int(gl_FragCoord.y * gl_FragCoord.x);

	int rngState = pixelIndex + numRenderedFrames * 719393;

	vec3 render;

	if (!pause)
	{
		if (denoise)
		{
			render = drawFrame(ray, rngState, raysPerPixel, maxBounces);
		}
		else
		{
			render = drawFrame(ray, rngState, 1, 1);
		}
	}

	float weight = 1.0 / (numRenderedFrames + 1);
	vec3 accumulatedAverage = vec3(1);

	if (denoise)
	{
		if (!pause)
		{
			accumulatedAverage = ((texture(texture0, fragTexCoord).xyz * (1 - weight)) + (render * weight));
		}
		else
		{
			accumulatedAverage = texture(texture0, fragTexCoord).xyz;
		}

		out_color = vec4(accumulatedAverage, 1);
	}
	else
	{
		out_color = vec4(render, 1);
	}
}