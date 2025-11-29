package tinyobj

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:path/filepath"

FLAG_TRIANGULATE :: 1 << 0
INVALID_INDEX    :: 0x80000000

Material :: struct {
	name:                       string,
	ambient:                    [3]f32,
	diffuse:                    [3]f32,
	specular:                   [3]f32,
	transmittance:              [3]f32,
	emission:                   [3]f32,
	shininess:                  f32,
	ior:                        f32, // index of refraction
	dissolve:                   f32, // 1 == opaque; 0 == fully transparent
	illum:                      int,
	
	// Texture maps
	ambient_texname:            string, // map_Ka
	diffuse_texname:            string, // map_Kd
	specular_texname:           string, // map_Ks
	specular_highlight_texname: string, // map_Ns
	bump_texname:               string, // map_bump, bump
	displacement_texname:       string, // disp
	alpha_texname:              string, // map_d
}

Shape :: struct {
	name:        string,
	face_offset: int,
	length:      int,
}

Vertex_Index :: struct {
	v_idx:  int,
	vt_idx: int,
	vn_idx: int,
}

Attrib :: struct {
	vertices:       [dynamic]f32, // 3 floats per vertex
	normals:        [dynamic]f32, // 3 floats per normal
	texcoords:      [dynamic]f32, // 2 floats per texcoord
	faces:          [dynamic]Vertex_Index,
	face_num_verts: [dynamic]int,
	material_ids:   [dynamic]int,
}

OBJ :: struct {
	attrib:    Attrib,
	shapes:    [dynamic]Shape,
	materials: [dynamic]Material,
	success:   bool,
}

// OBJ format uses 1-based indexing, and negative values for relative indexing.
// This converts them to 0-based absolute indices.
@(private)
fix_index :: proc(idx: int, n: int) -> int {
	if idx > 0 do return idx - 1
	if idx == 0 do return 0
	return n + idx
}

@(private)
parse_float :: proc(s: string) -> f32 {
	val, _ := strconv.parse_f32(s)
	return val
}

@(private)
parse_int :: proc(s: string) -> int {
	val, _ := strconv.parse_int(s)
	return val
}

@(private)
init_material :: proc() -> Material {
	m: Material
	m.dissolve = 1.0
	m.shininess = 1.0
	m.ior = 1.0
	return m
}

/* Parses a material library (.mtl) file.
   Returns a list of materials and a map lookup for name -> index 
*/
parse_mtl_file :: proc(filename: string) -> ([dynamic]Material, map[string]int, bool) {
	data, ok := os.read_entire_file(filename)
	if !ok {
		fmt.eprintln("TINYOBJ: Error reading material file:", filename)
		return nil, nil, false
	}
	defer delete(data)

	content := string(data)
	materials := make([dynamic]Material)
	mat_map := make(map[string]int)

	current_mat := init_material()
	has_current := false

	it := content
	for line in strings.split_lines_iterator(&it) {
		trimmed := strings.trim_space(line)
		if len(trimmed) == 0 || trimmed[0] == '#' do continue

		parts := strings.fields(trimmed)
		defer delete(parts)
		if len(parts) == 0 do continue

		token := parts[0]

		switch token {
		case "newmtl":
			if len(parts) > 1 {
				if has_current {
					append(&materials, current_mat)
					mat_map[current_mat.name] = len(materials) - 1
				}
				current_mat = init_material()
				current_mat.name = strings.clone(parts[1])
				has_current = true
			}
		case "Ka":
			if len(parts) >= 4 {
				current_mat.ambient[0] = parse_float(parts[1])
				current_mat.ambient[1] = parse_float(parts[2])
				current_mat.ambient[2] = parse_float(parts[3])
			}
		case "Kd":
			if len(parts) >= 4 {
				current_mat.diffuse[0] = parse_float(parts[1])
				current_mat.diffuse[1] = parse_float(parts[2])
				current_mat.diffuse[2] = parse_float(parts[3])
			}
		case "Ks":
			if len(parts) >= 4 {
				current_mat.specular[0] = parse_float(parts[1])
				current_mat.specular[1] = parse_float(parts[2])
				current_mat.specular[2] = parse_float(parts[3])
			}
		case "Kt", "Tf":
			if len(parts) >= 4 {
				current_mat.transmittance[0] = parse_float(parts[1])
				current_mat.transmittance[1] = parse_float(parts[2])
				current_mat.transmittance[2] = parse_float(parts[3])
			}
		case "Ni":
			if len(parts) >= 2 do current_mat.ior = parse_float(parts[1])
		case "Ke":
			if len(parts) >= 4 {
				current_mat.emission[0] = parse_float(parts[1])
				current_mat.emission[1] = parse_float(parts[2])
				current_mat.emission[2] = parse_float(parts[3])
			}
		case "Ns":
			if len(parts) >= 2 do current_mat.shininess = parse_float(parts[1])
		case "d":
			if len(parts) >= 2 do current_mat.dissolve = parse_float(parts[1])
		case "Tr":
			if len(parts) >= 2 do current_mat.dissolve = 1.0 - parse_float(parts[1])
		case "illum":
			if len(parts) >= 2 do current_mat.illum = parse_int(parts[1])
		case "map_Ka":
			if len(parts) >= 2 do current_mat.ambient_texname = strings.clone(parts[1])
		case "map_Kd":
			if len(parts) >= 2 do current_mat.diffuse_texname = strings.clone(parts[1])
		case "map_Ks":
			if len(parts) >= 2 do current_mat.specular_texname = strings.clone(parts[1])
		case "map_Ns":
			if len(parts) >= 2 do current_mat.specular_highlight_texname = strings.clone(parts[1])
		case "map_bump", "bump":
			if len(parts) >= 2 do current_mat.bump_texname = strings.clone(parts[1])
		case "disp":
			if len(parts) >= 2 do current_mat.displacement_texname = strings.clone(parts[1])
		case "map_d":
			if len(parts) >= 2 do current_mat.alpha_texname = strings.clone(parts[1])
		}
	}
	if has_current {
		append(&materials, current_mat)
		mat_map[current_mat.name] = len(materials) - 1
	}
	return materials, mat_map, true
}

/* Main OBJ parser.
   buf: The string content of the .obj file.
   base_dir: Directory to look for .mtl files (if empty, assumes current dir).
   flags: e.g. FLAG_TRIANGULATE
*/
parse_obj :: proc(buf: string, base_dir: string = "", flags: u32 = 0) -> (o: OBJ) {
	o.attrib.vertices = make([dynamic]f32)
	o.attrib.normals = make([dynamic]f32)
	o.attrib.texcoords = make([dynamic]f32)
	o.attrib.faces = make([dynamic]Vertex_Index)
	o.attrib.face_num_verts = make([dynamic]int)
	o.attrib.material_ids = make([dynamic]int)
	o.shapes = make([dynamic]Shape)
	o.materials = make([dynamic]Material)

	// Lookup for materials
	mat_map := make(map[string]int)
	defer delete(mat_map)

	current_material_id := -1
	
	// Shape tracking
	current_shape_name := ""
	face_count := 0
	prev_shape_face_offset := 0

	// Counts for relative indexing
	v_count := 0
	vn_count := 0
	vt_count := 0

	triangulate := (flags & FLAG_TRIANGULATE) != 0

	commit_shape :: proc(o: ^OBJ, name: string, offset: int, length: int) {
		if length > 0 {
			shape: Shape
			shape.name = strings.clone(name)
			shape.face_offset = offset
			shape.length = length
			append(&o.shapes, shape)
		}
	}
	it := buf
	for line in strings.split_lines_iterator(&it) {
		trimmed := strings.trim_space(line)
		if len(trimmed) == 0 || trimmed[0] == '#' do continue

		parts := strings.fields(trimmed)
		defer delete(parts)
		if len(parts) == 0 do continue

		token := parts[0]

		switch token {
		case "v":
			if len(parts) >= 4 {
				append(&o.attrib.vertices, parse_float(parts[1]))
				append(&o.attrib.vertices, parse_float(parts[2]))
				append(&o.attrib.vertices, parse_float(parts[3]))
				v_count += 1
			}
		case "vn":
			if len(parts) >= 4 {
				append(&o.attrib.normals, parse_float(parts[1]))
				append(&o.attrib.normals, parse_float(parts[2]))
				append(&o.attrib.normals, parse_float(parts[3]))
				vn_count += 1
			}
		case "vt":
			if len(parts) >= 3 {
				append(&o.attrib.texcoords, parse_float(parts[1]))
				append(&o.attrib.texcoords, parse_float(parts[2]))
				vt_count += 1
			}
		case "f":
			// Parse raw face indices first
			face_indices := make([dynamic]Vertex_Index, 0, 4)
			defer delete(face_indices)

			for i := 1; i < len(parts); i += 1 {
				vi: Vertex_Index
				vi.v_idx = INVALID_INDEX
				vi.vt_idx = INVALID_INDEX
				vi.vn_idx = INVALID_INDEX

				segment := parts[i]
				slashes := strings.split(segment, "/")
				defer delete(slashes)

				// Format: v, v/vt, v/vt/vn, v//vn

				if len(slashes) >= 1 && len(slashes[0]) > 0 {
					vi.v_idx = fix_index(parse_int(slashes[0]), v_count)
				}
				if len(slashes) >= 2 && len(slashes[1]) > 0 {
					vi.vt_idx = fix_index(parse_int(slashes[1]), vt_count)
				}
				if len(slashes) >= 3 && len(slashes[2]) > 0 {
					vi.vn_idx = fix_index(parse_int(slashes[2]), vn_count)
				}
				append(&face_indices, vi)
			}
			// Triangulation Logic
			if triangulate && len(face_indices) > 3 {
				i0 := face_indices[0]
				// Fan triangulation
				for k := 2; k < len(face_indices); k += 1 {
					i1 := face_indices[k - 1]
					i2 := face_indices[k]
					
					append(&o.attrib.faces, i0)
					append(&o.attrib.faces, i1)
					append(&o.attrib.faces, i2)
					
					append(&o.attrib.face_num_verts, 3)
					append(&o.attrib.material_ids, current_material_id)
					face_count += 1
				}
			} else {
				// No triangulation or already a triangle
				for vi in face_indices {
					append(&o.attrib.faces, vi)
				}
				append(&o.attrib.face_num_verts, len(face_indices))
				append(&o.attrib.material_ids, current_material_id)
				face_count += 1
			}
		case "usemtl":
			if len(parts) >= 2 {
				name := parts[1]
				if id, ok := mat_map[name]; ok {
					current_material_id = id
				} else {
					current_material_id = -1
				}
			}
		case "mtllib":
			if len(parts) >= 2 {
				fname := parts[1]
				full_path := fname
				if len(base_dir) > 0 {
					full_path = filepath.join({base_dir, fname})
				}
				
				// Parse MTL
				new_mats, new_map, ok := parse_mtl_file(full_path)
				if ok {
					// Merge materials
					start_idx := len(o.materials)
					for m in new_mats {
						append(&o.materials, m)
					}
					// Merge map with offset
					for name, local_idx in new_map {
						mat_map[name] = start_idx + local_idx
					}
					delete(new_mats)
					delete(new_map)
				}
				if len(base_dir) > 0 {
					delete(full_path)
				}
			}
		case "o", "g":
			if len(parts) >= 2 {
				// Commit previous shape
				if face_count > prev_shape_face_offset {
					commit_shape(&o, current_shape_name, prev_shape_face_offset, face_count - prev_shape_face_offset)
					prev_shape_face_offset = face_count
				}
				current_shape_name = parts[1]
			}
		}
	}
	// Commit last shape
	if face_count > prev_shape_face_offset {
		commit_shape(&o, current_shape_name, prev_shape_face_offset, face_count - prev_shape_face_offset)
	}
	o.success = true
	return o
}

destroy :: proc(o: ^OBJ) {
	delete(o.attrib.vertices)
	delete(o.attrib.normals)
	delete(o.attrib.texcoords)
	delete(o.attrib.faces)
	delete(o.attrib.face_num_verts)
	delete(o.attrib.material_ids)
	
	for s in o.shapes do delete(s.name)
	delete(o.shapes)

	for m in o.materials {
		delete(m.name)
		if len(m.ambient_texname) > 0 do delete(m.ambient_texname)
		if len(m.diffuse_texname) > 0 do delete(m.diffuse_texname)
        if len(m.specular_texname) > 0 do delete(m.specular_texname)
        if len(m.specular_highlight_texname) > 0 do delete(m.specular_highlight_texname)
        if len(m.bump_texname) > 0 do delete(m.bump_texname)
        if len(m.displacement_texname) > 0 do delete(m.displacement_texname)
        if len(m.alpha_texname) > 0 do delete(m.alpha_texname)
	}
	delete(o.materials)
}