package rlight

import "core:c"
import rl "vendor:raylib"
import "core:fmt"
import "core:math"

LightType :: enum {
	DIRECTIONAL,
	POINT,
}

Light :: struct {
	type:           c.int,
	enabled:        c.int,
	position:       rl.Vector3,
	target:         rl.Vector3,
	color:          rl.Vector4,
	intensity:      f32,
	attenuation:    f32,
	light_id:       c.int, // ID for the light in the shader array

	// Shader locations
	enabledLoc:     c.int,
	typeLoc:        c.int,
	positionLoc:    c.int,
	targetLoc:      c.int,
	intensity_loc:  c.int,
	colorLoc:       c.int,
	attenuationLoc: c.int,
}

// Material properties for lighting calculations
Material :: struct {
	base_color: rl.Vector3,
	roughness:  f32,
	ior:        f32, // Index of refraction
}

// Hit information for lighting calculations
Hit :: struct {
	origin: rl.Vector3,
	normal: rl.Vector3,
}

create_light :: proc(
	type: LightType,
	position: rl.Vector3,
	target: rl.Vector3,
	color: rl.Color,
	shader: rl.Shader,
	light_id: c.int,
) -> Light {
	light := Light {
		enabled  = 1,
		type     = 0 if type == LightType.POINT else 1,
		position = position,
		target   = target,
		color    = {f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0},
		light_id = light_id,
	}

	// Create shader location strings for light array
	enabled_name := fmt.aprintf("lights[%d].enabled", light_id)
	type_name := fmt.aprintf("lights[%d].type", light_id)
	position_name := fmt.aprintf("lights[%d].position", light_id)
	target_name := fmt.aprintf("lights[%d].target", light_id)
	color_name := fmt.aprintf("lights[%d].color", light_id)
	
	defer {
		delete(enabled_name)
		delete(type_name)
		delete(position_name)
		delete(target_name)
		delete(color_name)
	}

	light.enabledLoc = rl.GetShaderLocation(shader, cstring(raw_data(enabled_name)))
	light.typeLoc = rl.GetShaderLocation(shader, cstring(raw_data(type_name)))
	light.positionLoc = rl.GetShaderLocation(shader, cstring(raw_data(position_name)))
	light.targetLoc = rl.GetShaderLocation(shader, cstring(raw_data(target_name)))
	light.colorLoc = rl.GetShaderLocation(shader, cstring(raw_data(color_name)))

	return light
}

update_light_values :: proc(shader: rl.Shader, light: Light) {
	// Send to shader light enabled state and type
	light_type: c.int = light.type
	light_enabled: c.int = light.enabled

	rl.SetShaderValue(shader, light.enabledLoc, &light_enabled, rl.ShaderUniformDataType.INT)
	rl.SetShaderValue(shader, light.typeLoc, &light_type, rl.ShaderUniformDataType.INT)

	// Send to shader light position values
	pos := light.position
	rl.SetShaderValue(shader, light.positionLoc, &pos, rl.ShaderUniformDataType.VEC3)

	// Send to shader light target position values
	target := light.target
	rl.SetShaderValue(shader, light.targetLoc, &target, rl.ShaderUniformDataType.VEC3)

	rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.intensity_loc), &light.intensity, .FLOAT);

	// Send to shader light color values
	color := light.color
	rl.SetShaderValue(shader, light.colorLoc, &color, rl.ShaderUniformDataType.VEC4)
}

// Get light direction from light to hit point
get_light_direction :: proc(light: Light, hit: Hit) -> rl.Vector3 {
	if light.type == 1 { // DIRECTIONAL
		return rl.Vector3Normalize(light.target)
	} else { // POINT
		return rl.Vector3Normalize(light.position - hit.origin)
	}
}

// Blinn-Phong illumination model
illum_blinn_phong :: proc(view_dir: rl.Vector3, light_dir: rl.Vector3, hit: Hit, material: Material) -> rl.Vector3 {
	// Diffuse component
	diffuse_intensity := max(0.0, rl.Vector3DotProduct(light_dir, hit.normal))
	diffuse := material.base_color * diffuse_intensity

	// Specular component (Phong model)
	spec_factor: f32 = 50.0
	reflected := reflect(light_dir, -1) * hit.normal
	specular_intensity := math.pow(max(0.0, rl.Vector3DotProduct(reflected, view_dir)), spec_factor)
	specular := rl.Vector3{specular_intensity, specular_intensity, specular_intensity}

	return diffuse + specular
}

// Cook-Torrance illumination model (Physically Based Rendering)
illum_cook_torrance :: proc(view_dir: rl.Vector3, light_dir: rl.Vector3, hit: Hit, material: Material) -> rl.Vector3 {
	half_vec := rl.Vector3Normalize(light_dir + view_dir)
	n_dot_l := rl.Vector3DotProduct(hit.normal, light_dir)
	n_dot_h := rl.Vector3DotProduct(hit.normal, half_vec)
	n_dot_v := rl.Vector3DotProduct(hit.normal, view_dir)
	v_dot_h := rl.Vector3DotProduct(view_dir, half_vec)

	// Geometric term
	geo_a := (2.0 * n_dot_h * n_dot_v) / v_dot_h
	geo_b := (2.0 * n_dot_h * n_dot_l) / v_dot_h
	geo_term := min(1.0, min(geo_a, geo_b))

	// Roughness term (Beckmann Distribution)
	rough_sq := material.roughness * material.roughness
	rough_a := 1.0 / (rough_sq * n_dot_h * n_dot_h * n_dot_h * n_dot_h)
	rough_exp := (n_dot_h * n_dot_h - 1.0) / (rough_sq * n_dot_h * n_dot_h)
	rough_term := rough_a * math.exp(rough_exp)

	// Fresnel term
	fresnel_term := fresnel_factor(1.0, material.ior, v_dot_h)

	// Cook-Torrance BRDF
	PI :: math.PI
	specular := (geo_term * rough_term * fresnel_term) / (PI * n_dot_v * n_dot_l)
	return rl.Vector3{specular, specular, specular} + material.base_color * max(0.0, n_dot_l)
}

// Fresnel factor using Schlick's approximation
fresnel_factor :: proc(n1: f32, n2: f32, v_dot_h: f32) -> f32 {
	rn := (n1 - n2) / (n1 + n2)
	r0 := rn * rn
	f := 1.0 - v_dot_h
	return r0 + (1.0 - r0) * (f * f * f * f * f)
}

// Vector reflection
reflect :: proc(incident: rl.Vector3, normal: rl.Vector3) -> rl.Vector3 {
    return incident - normal * 2.0 * rl.Vector3DotProduct(normal, incident)
}

// Vector refraction
refract :: proc(incident: rl.Vector3, normal: rl.Vector3, n: f32) -> rl.Vector3 {
	cosi := -rl.Vector3DotProduct(normal, incident)
	sint2 := n * n * (1.0 - cosi * cosi)
	
	// Total Internal Reflection
	if sint2 > 1.0 {
		return reflect(incident, normal)
	}
	
	return incident * n + (normal * n * cosi - math.sqrt(1.0 - sint2))
}

// Phase functions for volumetric rendering

// Isotropic phase function
isotropic_phase_func :: proc(mu: f32) -> f32 {
	PI :: math.PI
	return 1.0 / (4.0 * PI)
}

// Rayleigh phase function
rayleigh_phase_func :: proc(mu: f32) -> f32 {
	PI :: math.PI
	return (3.0 * (1.0 + mu * mu)) / (16.0 * PI)
}

// Henyey-Greenberg phase function
henyey_greenstein_phase_func :: proc(mu: f32, g: f32) -> f32 {
	PI :: math.PI
	return (1.0 - g * g) / ((4.0 * PI) * math.pow(1.0 + g * g - 2.0 * g * mu, 1.5))
}

// Schlick phase function (approximation of Henyey-Greenberg)
schlick_phase_func :: proc(mu: f32, hg_g: f32) -> f32 {
	PI :: math.PI
	// Schlick Phase Function factor
	// Pharr and Humphreys [2004] equivalence to g from Henyey-Greenberg
	shk_g := 1.55 * hg_g - 0.55 * (hg_g * hg_g * hg_g)
	
	return (1.0 - shk_g * shk_g) / (4.0 * PI * (1.0 + shk_g * mu) * (1.0 + shk_g * mu))
}

// Volume sampling for volumetric rendering
VolumeSampler :: struct {
	origin:        rl.Vector3, // start of ray
	pos:           rl.Vector3, // current pos of accumulation ray
	height:        f32,        // [0..1] within the volume
	transmittance: f32,        // energy loss by absorption & out-scattering
	radiance:      rl.Vector3, // output color
	alpha:         f32,
}

construct_volume :: proc(origin: rl.Vector3) -> VolumeSampler {
	return VolumeSampler{
		origin        = origin,
		pos           = origin,
		height        = 0.0,
		transmittance = 1.0,
		radiance      = {0, 0, 0},
		alpha         = 0.0,
	}
}