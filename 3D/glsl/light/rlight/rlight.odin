package rlight

import "core:c"
import rl "vendor:raylib"
import "core:fmt"

LightType :: enum {
	DIRECTIONAL,
	POINT,
}

Light :: struct {
	type:           c.int,
	enabled:        c.int,
	position:       rl.Vector3,
	target:         rl.Vector3,
	color:          rl.Vector4, // Changed to Vector4 for easier shader passing
	attenuation:    f32,
	light_id:       c.int, // ID for the light in the shader array

	// Shader locations
	enabledLoc:     c.int,
	typeLoc:        c.int,
	positionLoc:    c.int,
	targetLoc:      c.int,
	colorLoc:       c.int,
	attenuationLoc: c.int,
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

	// Send to shader light color values
	color := light.color
	rl.SetShaderValue(shader, light.colorLoc, &color, rl.ShaderUniformDataType.VEC4)
}