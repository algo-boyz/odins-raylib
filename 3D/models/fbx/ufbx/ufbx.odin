package ufbx

import "core:c"

// Basic Types

String :: struct {
        data: cstring,
        length: c.size_t,
}

Blob :: struct {
        data: rawptr,
        size: c.size_t,
}

Real :: f64
Vec2 :: [2]Real
Vec3 :: [3]Real
Vec4 :: [4]Real
Quat :: [4]Real

Rotation_Order :: enum c.int {
        XYZ,
	XZY,
	YZX,
	YXZ,
	ZXY,
	ZYX,
	SPHERIC,  
}

// Explicit translation+rotation+scale transformation.
// NOTE: Rotation is a quaternion, not Euler angles!
Transform :: struct {
        translation: Vec3, 
	rotation: Quat,
	scale: Vec3,
}

// 4x3 matrix encoding an affine transformation.
// `cols[0..2]` are the X/Y/Z basis vectors, `cols[3]` is the translation
Matrix :: struct {
        cols: [4]Vec3,
}

Void_List :: struct {
        data: rawptr,
        count: c.size_t,
}

Bool_List :: struct {
        data: [^]c.bool,
        count: c.size_t,
}

Uint32_List :: struct {
        data: [^]u32,
        count: c.size_t,
}

Real_List :: struct {
        data: [^]Real,
        count: c.size_t,
}

Vec2_List :: struct {
        data: [^]Vec2,
        count: c.size_t,
}

Vec3_List :: struct {
        data: [^]Vec3,
        count: c.size_t,
}

Vec4_List :: struct {
        data: [^]Vec4,
        count: c.size_t,
}

String_List :: struct {
        data: [^]String,
        count: c.size_t,
}

// Document Object Model

Dom_Value_Type :: enum c.int {
	NUMBER,
	STRING,
	ARRAY_I8,
	ARRAY_I32,
	ARRAY_I64,
	ARRAY_F32,
	ARRAY_F64,
	ARRAY_RAW_STRING,
	ARRAY_IGNORED,
}

Dom_Value :: struct {
        type: Dom_Value_Type,
	value_str: String,
	value_blob: Blob,
	value_int: i64,
	value_double: f64,    
}

Dom_Value_List :: struct {
        data: [^]Dom_Value,
        count: c.size_t,
}

Dom_Node :: struct {
        name: String,
        children: Dom_Node_List,
        values: Dom_Value_List,
}

Dom_Node_List :: struct {
        data: [^]Dom_Node,
        count: c.size_t,
}

// -- Properties

// FBX elements have properties which are arbitrary key/value pairs that can
// have inherited default values or be animated. In most cases you don't need
// to access these unless you need a feature not implemented directly in ufbx.
// NOTE: Prefer using `ufbx_find_prop[_len](...)` to search for a property by
// name as it can find it from the defaults if necessary.

// Data type contained within the property. All the data fields are always
// populated regardless of type, so there's no need to switch by type usually
// eg. `prop->value_real` and `prop->value_int` have the same value (well, close)
// if `prop->type == UFBX_PROP_INTEGER`. String values are not converted from/to.
Prop_Type :: enum c.int {
        UNKNOWN,
	BOOLEAN,
	INTEGER,
	NUMBER,
	VECTOR,
	COLOR,
	COLOR_WITH_ALPHA,
	STRING,
	DATE_TIME,
	TRANSLATION,
	ROTATION,
	SCALING,
	DISTANCE,
	COMPOUND,
	BLOB,
	REFERENCE,      
}

// Property flags: Advanced information about properties, not usually needed.
Prop_Flag :: enum {
        // Supports animation.
	// NOTE: ufbx ignores this and allows animations on non-animatable properties.
	ANIMATABLE = 0,

	// User defined (custom) property.
	USER_DEFINED = 1,

	// Hidden in UI.
	HIDDEN = 2,

	// Disallow modification from UI for components.
	LOCK_X = 4,
	LOCK_Y = 5,
	LOCK_Z = 6,
	LOCK_W = 7,

	// Disable animation from components.
	MUTE_X = 8,
	MUTE_Y = 9,
	MUTE_Z = 10,
	MUTE_W = 11,

	// Property created by ufbx when an element has a connected `ufbx_anim_prop`
	// but doesn't contain the `ufbx_prop` it's referring to.
	// NOTE: The property may have been found in the templated defaults.
	SYNTHETIC = 12,

	// The property has at least one `ufbx_anim_prop` in some layer.
	ANIMATED = 13,

	// Used by `ufbx_evaluate_prop()` to indicate the the property was not found.
	NOT_FOUND = 14,

	// The property is connected to another one.
	// This use case is relatively rare so `ufbx_prop` does not track connections
	// directly. You can find connections from `ufbx_element.connections_dst` where
	// `ufbx_connection.dst_prop` is this property and `ufbx_connection.src_prop` is defined.
	CONNECTED = 15,

	// The value of this property is undefined (represented as zero).
	NO_VALUE = 16,

	// This property has been overridden by the user.
	// See `ufbx_anim.prop_overrides` for more information.
	OVERRIDDEN = 17,

	// Value type.
	// `REAL/VEC2/VEC3/VEC4` are mutually exclusive but may coexist with eg. `STRING`
	// in some rare cases where the string defines the unit for the vector.
	VALUE_REAL = 20,
	VALUE_VEC2 = 21,
	VALUE_VEC3 = 22,
	VALUE_VEC4 = 23,
	VALUE_INT  = 24,
	VALUE_STR  = 25,
	VALUE_BLOB = 26,
}

Prop_Flags :: distinct bit_set[Prop_Flag; c.int]

Prop_Value :: struct #raw_union {
        value_real_arr: [4]Real,
        value_real: Real,
        value_vec2: Vec2,
        value_vec3: Vec3,
        value_vec4: Vec4,
}

Prop :: struct {
        name: String,
        _internal_key: i32,
        type: Prop_Type,
        flags: Prop_Flags,
        value_str: String,
        value_blob: Blob,
        value_int: i64,
        using value: Prop_Value,
}

Prop_List :: struct {
        data: [^]Prop,
        count: c.size_t,
}

// List of alphabetically sorted properties with potential defaults.
// For animated objects in as scene from `ufbx_evaluate_scene()` this list
// only has the animated properties, the originals are stored under `defaults`.
Props :: struct {
        props: Prop_List,
        num_animated: c.size_t,
        defaults: [^]Props,
}

Element_Type :: enum c.int {
	UNKNOWN,             // < `ufbx.unknown`
	NODE,                // < `ufbx.node`
	MESH,                // < `ufbx.mesh`
	LIGHT,               // < `ufbx.light`
	CAMERA,              // < `ufbx.camera`
	BONE,                // < `ufbx.bone`
	EMPTY,               // < `ufbx.empty`
	LINE_CURVE,          // < `ufbx.line_curve`
	NURBS_CURVE,         // < `ufbx.nurbs_curve`
	NURBS_SURFACE,       // < `ufbx.nurbs_surface`
	NURBS_TRIM_SURFACE,  // < `ufbx.nurbs_trim_surface`
	NURBS_TRIM_BOUNDARY, // < `ufbx.nurbs_trim_boundary`
	PROCEDURAL_GEOMETRY, // < `ufbx.procedural_geometry`
	STEREO_CAMERA,       // < `ufbx.stereo_camera`
	CAMERA_SWITCHER,     // < `ufbx.camera_switcher`
	MARKER,              // < `ufbx.marker`
	LOD_GROUP,           // < `ufbx.lod_group`
	SKIN_DEFORMER,       // < `ufbx.skin_deformer`
	SKIN_CLUSTER,        // < `ufbx.skin_cluster`
	BLEND_DEFORMER,      // < `ufbx.blend_deformer`
	BLEND_CHANNEL,       // < `ufbx.blend_channel`
	BLEND_SHAPE,         // < `ufbx.blend_shape`
	CACHE_DEFORMER,      // < `ufbx.cache_deformer`
	CACHE_FILE,          // < `ufbx.cache_file`
	MATERIAL,            // < `ufbx.material`
	TEXTURE,             // < `ufbx.texture`
	VIDEO,               // < `ufbx.video`
	SHADER,              // < `ufbx.shader`
	SHADER_BINDING,      // < `ufbx.shader_binding`
	ANIM_STACK,          // < `ufbx.anim_stack`
	ANIM_LAYER,          // < `ufbx.anim_layer`
	ANIM_VALUE,          // < `ufbx.anim_value`
	ANIM_CURVE,          // < `ufbx.anim_curve`
	DISPLAY_LAYER,       // < `ufbx.display_layer`
	SELECTION_SET,       // < `ufbx.selection_set`
	SELECTION_NODE,      // < `ufbx.selection_node`
	CHARACTER,           // < `ufbx.character`
	CONSTRAINT,          // < `ufbx.constraint`
	POSE,                // < `ufbx.pose`
	METADATA_OBJECT,     // < `ufbx.metadata_object`
}

// Element "base-class" common to each element.
// Some fields (like `connections_src`) are advanced and not visible
// in the specialized element structs.
// NOTE: The `element_id` value is consistent when loading the
// _same_ file, but re-exporting the file will invalidate them. (TOMOVE)
Element :: struct {
        name: String,
        props: Props,
        element_id: u32,
        typed_id: u32,
        instances: Node_List,
        type: Element_Type,
        connections_src: Connection_List,
        connections_dst: Connection_List,
        node: ^Dom_Node,
        scene: ^Scene,
}

Element_List :: struct {
        data: [^]^Element,
        count: c.size_t,
}

Unknown :: struct {
        element: Element,

	// FBX format specific type information.
	// In ASCII FBX format:
	//   super_type: ID, "type::name", "sub_type" { ... }
        type: String,
        super_type: String,
        sub_type: String,
}

Unknown_List :: struct {
        data: [^]^Unknown,
        count: c.size_t,
}

// Connection between two elements.
// Source and destination are somewhat arbitrary but the destination is
// often the "container" like a parent node or mesh containing a deformer.
Connection :: struct {
	src: ^Element,
	dst: ^Element,
        src_prop: String,
        dst_prop: String,
}

Connection_List :: struct {
        data: [^]Connection,
        count: c.size_t,
}


// -- Nodes

// Inherit type specifies how hierarchial node transforms are combined.
// `NORMAL` is combined using the "proper" multiplication
// `NO_SHEAR` does component-wise { pos+pos, rot*rot, scale*scale }
// `NO_SCALE` ignores the parent scale { pos+pos, rot*rot, scale }
Inherit_Type :: enum c.int {
        NO_SHEAR, // R*r*S*s
	NORMAL,   // R*S*r*s
	NO_SCALE, // R*r*s
}

// Nodes form the scene transformation hierarchy and can contain attached
// elements such as meshes or lights. In normal cases a single `ufbx_node`
// contains only a single attached element, so using `type/mesh/...` is safe.
Node :: struct {
        element: Element,

	// Node hierarchy

	// Parent node containing this one if not root.
	//
	// Always non-`NULL` for non-root nodes unless
	// `ufbx_load_opts.allow_nodes_out_of_root` is enabled.
        parent: ^Node,

	// List of child nodes parented to this node.
        children: Node_List,

	// Attached element type and typed pointers.
	//
	// Set to `NULL` if not in use, so checking `attrib_type` is not required.
        mesh: ^Mesh,
        light: ^Light,
        camera: ^Camera,
        bone: ^Bone,

	// Less common attributes use these fields.
	//
	// Defined even if it is one of the above, eg. `ufbx_mesh`. In case there
	// is multiple attributes this will be the first one.
        attrib: ^Element,

	// Geometry transform helper if one exists.
	// See `UFBX_GEOMETRY_TRANSFORM_HANDLING_HELPER_NODES`.
        geometry_transform_helper: ^Node,

	// `attrib->type` if `attrib` is defined, otherwise `UFBX_ELEMENT_UNKNOWN`.
        attrib_type: Element_Type,

	// List of _all_ attached attribute elements.
	//
	// In most cases there is only zero or one attributes per node, but if you
	// have a very exotic FBX file nodes may have multiple attributes.
        all_attribs: Element_List,

	// Local transform in parent, geometry transform is a non-inherited
	// transform applied only to attachments like meshes
        inherit_type: Inherit_Type,
        local_transform: Transform,
        geometry_transform: Transform,

	// Raw Euler angles in degrees for those who want them

	// Specifies the axis order `euler_rotation` is applied in.
        rotation_order: Rotation_Order,
	// Rotation around the local X/Y/Z axes in `rotation_order`.
	// The angles are specified in degrees.
        euler_rotation: Vec3,

	// Transform to the global "world" space, may be incorrect if the node
	// uses `UFBX_INHERIT_NORMAL`, prefer using the `node_to_world` matrix.
	world_transform: Transform,

	// Matrices derived from the transformations, for transforming geometry
	// prefer using `geometry_to_world` as that supports geometric transforms.

	// Transform from this node to `parent` space.
	// Equivalent to `ufbx_transform_to_matrix(&local_transform)`.
        node_to_parent: Matrix,
        // Transform from this node to the world space, ie. multiplying all the
	// `node_to_parent` matrices of the parent chain together.
	// NOTE: Not the same as `ufbx_transform_to_matrix(&world_transform)`
	// as this matrix will account for potential shear (if `inherit_type == UFBX_INHERIT_NORMAL`).
	node_to_world: Matrix,
	// Transform from the attribute to this node. Does not affect the transforms
	// of `children`!
	// Equivalent to `ufbx_transform_to_matrix(&geometry_transform)`.
	geometry_to_node: Matrix,
	// Transform from attribute space to world space.
	// Equivalent to `ufbx_matrix_mul(&node_to_world, &geometry_to_node)`.
	geometry_to_world: Matrix,

	// ufbx-specific adjustment for switching between coodrinate/unit systems.
	// HINT: In most cases you don't need to deal with these as these are baked
	// into all the transforms above and into `ufbx_evaluate_transform()`.
	adjust_pre_rotation: Quat,  // < Rotation applied between parent and self
	adjust_pre_scale: Vec3,     // < Scaling applied between parent and self
	adjust_post_rotation: Quat, // < Rotation applied in local space at the end

	// Materials used by `mesh` or other `attrib`.
	// There may be multiple copies of a single `ufbx_mesh` with different materials
	// in the `ufbx_node` instances.
        materials: Material_List,

	// Visibility state.
        visible: c.bool,

	// True if this node is the implicit root node of the scene.
	is_root: c.bool,

	// True if the node has a non-identity `geometry_transform`.
	has_geometry_transform: c.bool,

	// If `true` the transform is adjusted by ufbx, not enabled by default.
	// See `adjust_pre_rotation`, `adjust_pre_scale`, `adjust_post_rotation`.
	has_adjust_transform: c.bool,

	// True if this node is node is a synthetic geometry transform helper.
	// See `UFBX_GEOMETRY_TRANSFORM_HANDLING_HELPER_NODES`.
	is_geometry_transform_helper: c.bool,

	// How deep is this node in the parent hierarchy. Root node is at depth `0`
	// and the immediate children of root at `1`.
	node_depth: u32,
}

Node_List :: struct {
        data: [^]^Node,
        count: c.size_t,
}


// Vertex attribute: All attributes are stored in a consistent indexed format
// regardless of how it's actually stored in the file.
//
// `values` is a contiguous array of attribute values.
// `indices` maps each mesh index into a value in the `values` array.
//
// If `unique_per_vertex` is set then the attribute is guaranteed to have a
// single defined value per vertex accessible via:
//   attrib.values.data[attrib.indices.data[mesh->vertex_first_index[vertex_ix]]
Vertex_Attrib :: struct {
	exists: c.bool,
	values: Void_List,
	indices: Uint32_List,
	value_reals: c.size_t,
	unique_per_vertex: c.bool,
}

// 1D vertex attribute, see `ufbx_vertex_attrib` for information
Vertex_Real :: struct {
	exists: c.bool,
	values: Real_List,
	indices: Uint32_List,
	value_reals: c.size_t,
	unique_per_vertex: c.bool,
}

// 2D vertex attribute, see `ufbx_vertex_attrib` for information
Vertex_Vec2 :: struct {
	exists: c.bool,
	values: Vec2_List,
	indices: Uint32_List,
	value_reals: c.size_t,
	unique_per_vertex: c.bool,
}

// 3D vertex attribute, see `ufbx_vertex_attrib` for information
Vertex_Vec3 :: struct {
	exists: c.bool,
	values: Vec3_List,
	indices: Uint32_List,
	value_reals: c.size_t,
	unique_per_vertex: c.bool,
}

// 4D vertex attribute, see `ufbx_vertex_attrib` for information
Vertex_Vec4 :: struct {
	exists: c.bool,
	values: Vec4_List,
	indices: Uint32_List,
	value_reals: c.size_t,
	unique_per_vertex: c.bool,
}


// Vertex UV set/layer
Uv_Set :: struct {
        name: String,
        index: u32,
        
	// Vertex attributes, see `ufbx_mesh` attributes for more information
	vertex_uv: Vertex_Vec2,        // < UV / texture coordinates
	vertex_tangent: Vertex_Vec3,   // < (optional) Tangent vector in UV.x direction
	vertex_bitangent: Vertex_Vec3, // < (optional) Tangent vector in UV.y direction
}

// Vertex color set/layer
Color_Set :: struct {
	name: String,
	index: u32,

	// Vertex attributes, see `ufbx_mesh` attributes for more information
	vertex_color: Vertex_Vec4, // < Per-vertex RGBA color
}

Uv_Set_List :: struct {
        data: [^]Uv_Set,
        count: c.size_t,
}

Color_Set_List :: struct {
        data: [^]Color_Set,
        count: c.size_t,
}

Edge :: struct {
        indices: [2]u32,
}

Edge_List :: struct {
        data: [^]Edge,
        count: c.size_t,
}

// Polygonal face with arbitrary number vertices, a single face contains a
// contiguous range of mesh indices, eg. `{5,3}` would have indices 5, 6, 7
//
// NOTE: `num_indices` maybe less than 3 in which case the face is invalid!
// [TODO #23: should probably remove the bad faces at load time]
Face :: struct {
	index_begin: u32,
	num_indices: u32,
}

Face_List :: struct {
        data: [^]Face,
        count: c.size_t,
}

Mesh_Material :: struct {
        material: ^Material,

	// Sub-set of the geometry that uses this specific material
	num_faces: c.size_t,     // < Number of faces (polygons) using this material
	num_triangles: c.size_t, // < Number of triangles using this material if triangulated

	num_empty_faces: c.size_t, // < Number of faces with zero vertices
	num_point_faces: c.size_t, // < Number of faces with a single vertex
	num_line_faces: c.size_t,  // < Number of faces with two vertices

	// Indices to `ufbx_mesh.faces[]` that use this material.
	// Always contains `num_faces` elements.
	face_indices: Uint32_List,      
}

Mesh_Material_List :: struct {
        data: [^]Mesh_Material,
        count: c.size_t,
}

Face_Group :: struct {
	id: i32,       // < Numerical ID for this group.
	name: String,  // < Name for the face group.

	// Sub-set of the geometry in this face group
	num_faces: c.size_t,     // < Number of faces (polygons) using this material
	num_triangles: c.size_t, // < Number of triangles using this material if triangulated

	// Indices to `ufbx_mesh.faces[]` that use this material.
	// Always contains `num_faces` elements.
	face_indices: Uint32_List,
}

Face_Group_List :: struct {
        data: [^]Face_Group,
        count: c.size_t,
}

Subdivision_Weight_Range :: struct {
	weight_begin: u32,
	num_weights: u32,
}

Subdivision_Weight_Range_List :: struct {
        data: [^]Subdivision_Weight_Range,
        count: c.size_t,
}

Subdivision_Weight :: struct {
        weight: Real,
        index: u32,
}

Subdivision_Weight_List :: struct {
        data: [^]Subdivision_Weight,
        count: c.size_t,
}

Subdivision_Result :: struct {
        result_memory_used: c.size_t,
	temp_memory_used: c.size_t,
	result_allocs: c.size_t,
	temp_allocs: c.size_t,

	// Weights of vertices in the source model.
	// Defined if `ufbx_subdivide_opts.evaluate_source_vertices` is set.
	source_vertex_ranges: Subdivision_Weight_Range_List,
	source_vertex_weights: Subdivision_Weight_List,

	// Weights of skin clusters in the source model.
	// Defined if `ufbx_subdivide_opts.evaluate_skin_weights` is set.
	skin_cluster_ranges: Subdivision_Weight_Range_List,
	skin_cluster_weights: Subdivision_Weight_List,
}

Subdivision_Display_Mode :: enum c.int {
	DISABLED,
	HULL,
	HULL_AND_SMOOTH,
	SMOOTH,
}

Subdivision_Boundary :: enum c.int {
	DEFAULT,
	LEGACY,
	// OpenSubdiv: `VTX_BOUNDARY_EDGE_AND_CORNER` / `FVAR_LINEAR_CORNERS_ONLY`
	SHARP_CORNERS,
	// OpenSubdiv: `VTX_BOUNDARY_EDGE_ONLY` / `FVAR_LINEAR_NONE`
	SHARP_NONE,
	// OpenSubdiv: `FVAR_LINEAR_BOUNDARIES`
	SHARP_BOUNDARY,
	// OpenSubdiv: `FVAR_LINEAR_ALL`
	SHARP_INTERIOR,
}


// Polygonal mesh geometry.
//
// Example mesh with two triangles (x, z) and a quad (y).
// The faces have a constant UV coordinate x/y/z.
// The vertices have _per vertex_ normals that point up/down.
//
//     ^   ^     ^
//     A---B-----C
//     |x /     /|
//     | /  y  / |
//     |/     / z|
//     D-----E---F
//     v     v   v
//
// Attributes may have multiple values within a single vertex, for example a
// UV seam vertex has two UV coordinates. Thus polygons are defined using
// an index that counts each corner of each face polygon. If an attribute is
// defined (even per-vertex) it will always have a valid `indices` array.
//
//   {0,3}    {3,4}    {7,3}   faces ({ index_begin, num_indices })
//   0 1 2   3 4 5 6   7 8 9   index
//
//   0 1 3   1 2 4 3   2 4 5   vertex_indices[index]
//   A B D   B C E D   C E F   vertices[vertex_indices[index]]
//
//   0 0 1   0 0 1 1   0 1 1   vertex_normal.indices[index]
//   ^ ^ v   ^ ^ v v   ^ v v   vertex_normal.data[vertex_normal.indices[index]]
//
//   0 0 0   1 1 1 1   2 2 2   vertex_uv.indices[index]
//   x x x   y y y y   z z z   vertex_uv.data[vertex_uv.indices[index]]
//
// Vertex position can also be accessed uniformly through an accessor:
//   0 1 3   1 2 4 3   2 4 5   vertex_position.indices[index]
//   A B D   B C E D   C E F   vertex_position.data[vertex_position.indices[index]]
//
// Some geometry data is specified per logical vertex. Vertex positions are
// the only attribute that is guaranteed to be defined _uniquely_ per vertex.
// Vertex attributes _may_ be defined per vertex if `unique_per_vertex == true`.
// You can access the per-vertex values by first finding the first index that
// refers to the given vertex.
//
//   0 1 2 3 4 5  vertex
//   A B C D E F  vertices[vertex]
//
//   0 1 4 2 5 9  vertex_first_index[vertex]
//   0 0 0 1 1 1  vertex_normal.indices[vertex_first_index[vertex]]
//   ^ ^ ^ v v v  vertex_normal.data[vertex_normal.indices[vertex_first_index[vertex]]]
//
Mesh :: struct {
        element: Element,

	// Number of "logical" vertices that would be treated as a single point,
	// one vertex may be split to multiple indices for split attributes, eg. UVs
	num_vertices: c.size_t,  // < Number of logical "vertex" points
	num_indices: c.size_t,   // < Number of combiend vertex/attribute tuples
	num_faces: c.size_t,     // < Number of faces (polygons) in the mesh
	num_triangles: c.size_t, // < Number of triangles if triangulated

	// Number of edges in the mesh.
	// NOTE: May be zero in valid meshes if the file doesn't contain edge adjacency data!
	num_edges: c.size_t,

	max_face_triangles: c.size_t, // < Maximum number of triangles in a  face in this mesh

	num_empty_faces: c.size_t, // < Number of faces with zero vertices
	num_point_faces: c.size_t, // < Number of faces with a single vertex
	num_line_faces: c.size_t,  // < Number of faces with two vertices

	// Faces and optional per-face extra data
	faces: Face_List,           // < Face index range
	face_smoothing: Bool_List,  // < Should the face have soft normals
	face_material: Uint32_List, // < Indices to `ufbx_mesh.materials[]` and `ufbx_node.materials[]`
	face_group: Uint32_List,    // < Face polygon group index, indices to `ufbx_mesh.face_groups[]`
	face_hole: Bool_List,       // < Should the face be hidden as a "hole"

	// Edges and optional per-edge extra data
	edges: Edge_List,           // < Edge index range
	edge_smoothing: Bool_List,  // < Should the edge have soft normals
	edge_crease: Real_List,     // < Crease value for subdivision surfaces
	edge_visibility: Bool_List, // < Should the edge be visible

	// Logical vertices and positions, alternatively you can use
	// `vertex_position` for consistent interface with other attributes.
	vertex_indices: Uint32_List,
	vertices: Vec3_List,

	// First index referring to a given vertex, `UFBX_NO_INDEX` if the vertex is unused.
	vertex_first_index: Uint32_List,

	// Vertex attributes, see the comment over the struct.
	//
	// NOTE: Not all meshes have all attributes, in that case `indices/data == NULL`!
	//
	// NOTE: UV/tangent/bitangent and color are the from first sets,
	// use `uv_sets/color_sets` to access the other layers.
	vertex_position: Vertex_Vec3,  // < Vertex positions
	vertex_normal: Vertex_Vec3,    // < (optional) Normal vectors (TODO: Generate?)
	vertex_uv: Vertex_Vec2,        // < (optional) UV / texture coordinates
	vertex_tangent: Vertex_Vec3,   // < (optional) Tangent vector in UV.x direction
	vertex_bitangent: Vertex_Vec3, // < (optional) Tangent vector in UV.y direction
	vertex_color: Vertex_Vec4,     // < (optional) Per-vertex RGBA color
	vertex_crease: Vertex_Real,    // < (optional) Crease value for subdivision surfaces

	// Multiple named UV/color sets
	// NOTE: The first set contains the same data as `vertex_uv/color`!
	uv_sets: Uv_Set_List,
	color_sets: Color_Set_List,

	// List of materials used by the mesh. This is a list of structures that contains
	// compact lists of face indices that use a specific material which can be more
	// useful convenient `face_material`. Use `materials[index].material` for the
	// actual material pointers.
	// NOTE: These can be wrong if you want to support per-instance materials!
	// Use `ufbx_node.materials[]` to get the per-instance materials at the same indices.
	// HINT: If this mesh has no material then `materials[]` will be empty, but if
	// you enable `ufbx_load_opts.allow_null_material` there will be a single
	// `ufbx_mesh_material` with `material == NULL` with all the faces in it.
	materials: Material_List,

	// Face groups for this mesh.
	face_groups: Face_Group_List,

	// Skinned vertex positions, for efficiency the skinned positions are the
	// same as the static ones for non-skinned meshes and `skinned_is_local`
	// is set to true meaning you need to transform them manually using
	// `ufbx_transform_position(&node->geometry_to_world, skinned_pos)`!
	skinned_is_local: c.bool,
	skinned_position: Vertex_Vec3,
	skinned_normal: Vertex_Vec3,

	// Deformers
	skin_deformers: Skin_Deformer_List,
	blend_deformers: Blend_Deformer_List,
	cache_deformers: Cache_Deformer_List,
	all_deformers: Element_List,

	// Subdivision
	subdivision_preview_levels: u32,
	subdivision_render_levels: u32,
	subdivision_display_mode: Subdivision_Display_Mode,
	subdivision_boundary: Subdivision_Boundary,
	subdivision_uv_boundary: Subdivision_Boundary,

	// Normals have been generated instead of evalauted.
	// Either from missing normals (via `ufbx_load_opts.generate_missing_normals`), skinning,
	// tessellation, or subdivision.
	generated_normals: c.bool,

	// Subdivision (result)
	subdivision_evaluated: c.bool,
	subdivision_result: ^Subdivision_Result,

	// Tessellation (result)
	from_tessellated_nurbs: c.bool,
}

Mesh_List :: struct {
        data: [^]^Mesh,
        count: c.size_t,
}

// The kind of light source
Light_Type :: enum c.int {
	// Single point at local origin, at `node->world_transform.position`
	POINT,
	// Infinite directional light pointing locally towards `light->local_direction`
	// For global: `ufbx_transform_direction(&node->node_to_world, light->local_direction)`
	DIRECTIONAL,
	// Cone shaped light towards `light->local_direction`, between `light->inner/outer_angle`.
	// For global: `ufbx_transform_direction(&node->node_to_world, light->local_direction)`
	SPOT,
	// Area light, shape specified by `light->area_shape`
	// TODO: Units?
	AREA,
	// Volumetric light source
	// TODO: How does this work
	VOLUME,
}

// How fast does the light intensity decay at a distance
Light_Decay :: enum c.int {
	NONE,      // < 1 (no decay)
	LINEAR,    // < 1 / d
	QUADRATIC, // < 1 / d^2 (physically accurate)
	CUBIC,     // < 1 / d^3
}

Light_Area_Shape :: enum c.int {
	RECTANGLE,
	SPHERE,
}

// Light source attached to a `ufbx_node`
Light :: struct {
        element: Element,

	// Color and intensity of the light, usually you want to use `color * intensity`
	// NOTE: `intensity` is 0.01x of the property `"Intensity"` as that matches
	// matches values in DCC programs before exporting.
	color: Vec3,
	intensity: Real,

	// Direction the light is aimed at in node's local space, usually -Y
	local_direction: Vec3,

	// Type of the light and shape parameters
	type: Light_Type,
	decay: Light_Decay,
	area_shape: Light_Area_Shape,
	inner_angle: Real,
	outer_angle: Real,

	cast_light: c.bool,
	cast_shadows: c.bool,
}

Light_List :: struct {
        data: [^]^Light,
        count: c.size_t,
}

Projection_Mode :: enum c.int {
	PERSPECTIVE, // Perspective projection.
	ORTHOGRAPHIC, // Orthographic projection.
}

// Method of specifying the rendering resolution from properties
// NOTE: Handled internally by ufbx, ignore unless you interpret `ufbx_props` directly!
Aspect_Mode :: enum c.int {
	// No defined resolution
	WINDOW_SIZE,
	// `"AspectWidth"` and `"AspectHeight"` are relative to each other
	FIXED_RATIO,
	// `"AspectWidth"` and `"AspectHeight"` are both pixels
	FIXED_RESOLUTION,
	// `"AspectWidth"` is pixels, `"AspectHeight"` is relative to width
	FIXED_WIDTH,
	// < `"AspectHeight"` is pixels, `"AspectWidth"` is relative to height
	FIXED_HEIGHT,
}

// Method of specifying the field of view from properties
// NOTE: Handled internally by ufbx, ignore unless you interpret `ufbx_props` directly!
Aperture_Mode :: enum c.int {
	// Use separate `"FieldOfViewX"` and `"FieldOfViewY"` as horizontal/vertical FOV angles
	HORIZONTAL_AND_VERTICAL,
	// Use `"FieldOfView"` as horizontal FOV angle, derive vertical angle via aspect ratio
	HORIZONTAL,
	// Use `"FieldOfView"` as vertical FOV angle, derive horizontal angle via aspect ratio
	VERTICAL,
	// Compute the field of view from the render gate size and focal length
	FOCAL_LENGTH,
}

// Method of specifying the render gate size from properties
// NOTE: Handled internally by ufbx, ignore unless you interpret `ufbx_props` directly!
Gate_Fit :: enum c.int {
	// Use the film/aperture size directly as the render gate
	NONE,
	// Fit the render gate to the height of the film, derive width from aspect ratio
	VERTICAL,
	// Fit the render gate to the width of the film, derive height from aspect ratio
	HORIZONTAL,
	// Fit the render gate so that it is fully contained within the film gate
	FILL,
	// Fit the render gate so that it fully contains the film gate
	OVERSCAN,
	// Stretch the render gate to match the film gate
	// TODO: Does this differ from `NONE`?
	STRETCH,
} 

// Camera film/aperture size defaults
// NOTE: Handled internally by ufbx, ignore unless you interpret `ufbx_props` directly!
Aperture_Format :: enum c.int {
	CUSTOM,              // < Use `"FilmWidth"` and `"FilmHeight"`
	_16MM_THEATRICAL,     // < 0.404 x 0.295 inches
	SUPER_16MM,          // < 0.493 x 0.292 inches
	_35MM_ACADEMY,        // < 0.864 x 0.630 inches
	_35MM_TV_PROJECTION,  // < 0.816 x 0.612 inches
	_35MM_FULL_APERTURE,  // < 0.980 x 0.735 inches
	_35MM_185_PROJECTION, // < 0.825 x 0.446 inches
	_35MM_ANAMORPHIC,     // < 0.864 x 0.732 inches (squeeze ratio: 2)
	_70MM_PROJECTION,     // < 2.066 x 0.906 inches
	VISTAVISION,         // < 1.485 x 0.991 inches
	DYNAVISION,          // < 2.080 x 1.480 inches
	IMAX,                // < 2.772 x 2.072 inches
}

Coordinate_Axis :: enum c.int {
	POSITIVE_X,
	NEGATIVE_X,
	POSITIVE_Y,
	NEGATIVE_Y,
	POSITIVE_Z,
	NEGATIVE_Z,
	UNKNOWN,
}

// Coordinate axes the scene is represented in.
// NOTE: `front` is the _opposite_ from forward!
Coordinate_Axes :: struct {
	right: Coordinate_Axis,
	up: Coordinate_Axis,
	front: Coordinate_Axis,
} 

// Camera attached to a `ufbx_node`
Camera :: struct {
        element: Element,

	// Projection mode (perspective/orthographic).
	projection_mode: Projection_Mode,

	// If set to `true`, `resolution` reprensents actual pixel values, otherwise
	// it's only useful for its aspect ratio.
	resolution_is_pixels: c.bool,

	// Render resolution, either in pixels or arbitrary units, depending on above
	resolution: Vec2,

	// Horizontal/vertical field of view in degrees
	// Valid if `projection_mode == UFBX_PROJECTION_MODE_PERSPECTIVE`.
	field_of_view_deg: Vec2,

	// Component-wise `tan(field_of_view_deg)`, also represents the size of the
	// proection frustum slice at distance of 1.
	// Valid if `projection_mode == UFBX_PROJECTION_MODE_PERSPECTIVE`.
	field_of_view_tan: Vec2,

	// Orthographic camera extents.
	// Valid if `projection_mode == UFBX_PROJECTION_MODE_ORTHOGRAPHIC`.
	orthographic_extent: Real,

	// Orthographic camera size.
	// Valid if `projection_mode == UFBX_PROJECTION_MODE_ORTHOGRAPHIC`.
	orthographic_size: Vec2,

	// Size of the projection plane at distance 1.
	// Equal to `field_of_view_tan` if perspective, `orthographic_size` if orthographic.
	projection_plane: Vec2,

	// Aspect ratio of the camera.
	aspect_ratio: Real,

	// Near plane of the frustum in units from the camera.
	near_plane: Real,

	// Far plane of the frustum in units from the camera.
	far_plane: Real,

	// Coordinate system that the projection uses.
	// FBX saves cameras with +X forward and +Y up, but you can override this using
	// `ufbx_load_opts.target_camera_axes` and it will be reflected here.
	projection_axes: Coordinate_Axes,

	// Advanced properties used to compute the above
	aspect_mode: Aspect_Mode,
	aperture_mode: Aperture_Mode,
	gate_fit: Gate_Fit,
	aperture_format: Aperture_Format,
	focal_length_mm: Real,     // < Focal length in millimeters
	film_size_inch: Vec2,      // < Film size in inches
	aperture_size_inch: Vec2,  // < Aperture/film gate size in inches
	squeeze_ratio: Real,       // < Anamoprhic stretch ratio
}

Camera_List :: struct {
        data: [^]^Camera,
        count: c.size_t,
}

// Bone attached to a `ufbx_node`, provides the logical length of the bone
// but most interesting information is directly in `ufbx_node`.
Bone :: struct {
        element: Element,

	// Visual radius of the bone
        radius: Real,

	// Length of the bone relative to the distance between two nodes
	relative_length: Real,

	// Is the bone a root bone
	is_root: c.bool,
}

Bone_List :: struct {
        data: [^]^Bone,
        count: c.size_t,
}

// Empty/NULL/locator connected to a node, actual details in `ufbx_node`
Empty :: struct {
        element: Element,
}

Empty_List :: struct {
        data: [^]^Empty,
        count: c.size_t,
}

// -- Node attributes (curves/surfaces)

// Segment of a `ufbx_line_curve`, indices refer to `ufbx_line_curve.point_indces[]`
Line_Segment :: struct {
	index_begin: u32,
	num_indices: u32,
}

Line_Segment_List :: struct {
        data: [^]Line_Segment,
        count: c.size_t,
}

Line_Curve :: struct {
        element: Element,

	color: Vec3,

	control_points: Vec3_List, // < List of possible values the line passes through
	point_indices: Uint32_List, // < Indices to `control_points[]` the line goes through

	segments: Line_Segment_List,

	// Tessellation (result)
	from_tessellated_nurbs: c.bool,
}

Line_Curve_List :: struct {
        data: [^]^Line_Curve,
        count: c.size_t,
}

Nurbs_Topology :: enum c.int {
	// The endpoints are not connected.
	OPEN,
	// Repeats first `ufbx_nurbs_basis.order - 1` control points after the end.
	PERIODIC,
	// Repeats the first control point after the end.
	CLOSED,
}

// NURBS basis functions for an axis
Nurbs_Basis :: struct {
	// Number of control points influencing a point on the curve/surface.
	// Equal to the degree plus one.
	order: u32,

	// Topology (periodicity) of the dimension.
	topology: Nurbs_Topology,

	// Subdivision of the parameter range to control points.
	knot_vector: Real_List,

	// Range for the parameter value.
	t_min: Real,
	t_max: Real,

	// Parameter values of control points.
	spans: Real_List,

	// `true` if this axis is two-dimensional.
	is_2d: c.bool,

	// Number of control points that need to be copied to the end.
	// This is just for convenience as it could be derived from `topology` and
	// `order`. If for example `num_wrap_control_points == 3` you should repeat
	// the first 3 control points after the end.
	// HINT: You don't need to worry about this if you use ufbx functions
	// like `ufbx_evaluate_nurbs_curve_point()` as they handle this internally.
	num_wrap_control_points: c.size_t,

	// `true` if the parametrization is well defined.
	valid: c.bool,

}

Nurbs_Curve :: struct {
        element: Element,

	// Basis in the U axis
	basis: Nurbs_Basis,

	// Linear array of control points
	// NOTE: The control points are _not_ homogeneous, meaning you have to multiply
	// them by `w` before evaluating the surface.
	control_points: Vec4_List,
}

Nurbs_Curve_List :: struct {
        data: [^]^Nurbs_Curve,
        count: c.size_t,
}

Nurbs_Surface :: struct {
        element: Element,

	// Basis in the U/V axes
	basis_u: Nurbs_Basis,
	basis_v: Nurbs_Basis,

	// Number of control points for the U/V axes
	num_control_points_u: c.size_t,
	num_control_points_v: c.size_t,

	// 2D array of control points.
	// Memory layout: `V * num_control_points_u + U`
	// NOTE: The control points are _not_ homogeneous, meaning you have to multiply
	// them by `w` before evaluating the surface.
	control_points: Vec4_List,

	// How many segments tessellate each step in `ufbx_nurbs_basis.steps`.
	span_subdivision_u: u32,
	span_subdivision_v: u32,

	// If `true` the resulting normals should be flipped when evaluated.
	flip_normals: c.bool,

	// Material for the whole surface.
	// NOTE: May be `NULL`!
	material: ^Material,
}

Nurbs_Surface_List :: struct {
        data: [^]^Nurbs_Surface,
        count: c.size_t,
}

Nurbs_Trim_Surface :: struct {
        element: Element,
}

Nurbs_Trim_Surface_List :: struct {
        data: [^]^Nurbs_Trim_Surface,
        count: c.size_t,
}

Nurbs_Trim_Boundary :: struct {
        element: Element,
}

Nurbs_Trim_Boundary_List :: struct {
        data: [^]^Nurbs_Trim_Boundary,
        count: c.size_t,
}

// -- Node attributes (advanced)

Procedural_Geometry :: struct {
        element: Element,
}

Procedural_Geometry_List :: struct {
        data: [^]^Procedural_Geometry,
        count: c.size_t,
}

Stereo_Camera :: struct {
        element: Element,

	left: ^Camera,
	right: ^Camera,
}

Stereo_Camera_List :: struct {
        data: [^]^Stereo_Camera,
        count: c.size_t,
}

Camera_Switcher :: struct {
        element: Element,
}

Camera_Switcher_List :: struct {
        data: [^]^Camera_Switcher,
        count: c.size_t,
}

Marker_Type :: enum c.int {
	UNKNOWN,     // < Unknown marker type
	FK_EFFECTOR, // < FK (Forward Kinematics) effector
	IK_EFFECTOR, // < IK (Inverse Kinematics) effector
}

// Tracking marker for effectors
Marker :: struct {
        element: Element,

	// Type of the marker
	type: Marker_Type,
};

Marker_List :: struct {
        data: [^]^Marker,
        count: c.size_t,
}

// LOD level display mode.
Lod_Display :: enum c.int {
	USE_LOD, // < Display the LOD level if the distance is appropriate.
	SHOW,    // < Always display the LOD level.
	HIDE,    // < Never display the LOD level.
}

// Single LOD level within an LOD group.
// Specifies properties of the Nth child of the _node_ containing the LOD group.
Lod_Level :: struct {
	// Minimum distance to show this LOD level.
	// NOTE: In world units by default, or in screen percentage if
	// `ufbx_lod_group.relative_thresholds` is set.
	distance: Real,

	// LOD display mode.
	// NOTE: Mostly for editing, you should probably ignore this
	// unless making a modeling program.
	display: Lod_Display,
}

Lod_Level_List :: struct {
        data: [^]Lod_Level,
        count: c.size_t,
}

// Group of LOD (Level of Detail) levels for an object.
// The actual LOD models are defined in the parent `ufbx_node.children`.
Lod_Group :: struct {
        element: Element,

	// If set to `true`, `ufbx_lod_level.distance` represents a screen size percentage.
	relative_distances: c.bool,

	// LOD levels matching in order to `ufbx_node.children`.
	lod_levels: Lod_Level_List,

	// If set to `true` don't account for parent transform when computing the distance.
	ignore_parent_transform: c.bool,

	// If `use_distance_limit` is enabled hide the group if the distance is not between
	// `distance_limit_min` and `distance_limit_max`.
	use_distance_limit: c.bool,
	distance_limit_min: Real,
	distance_limit_max: Real,
}

Lod_Group_List :: struct {
        data: [^]^Lod_Group,
        count: c.size_t,
}


// -- Deformers

// Method to evaluate the skinning on a per-vertex level
Skinning_Method :: enum c.int {
	// Linear blend skinning: Blend transformation matrices by vertex weights
	LINEAR,
	// One vertex should have only one bone attached
	RIGID,
	// Convert the transformations to dual quaternions and blend in that space
	DUAL_QUATERNION,
	// Blend between `LINEAR` and `BLENDED_DQ_LINEAR`
	// The blend weight can be found either per-vertex in `ufbx_skin_vertex.dq_weight`
	// or in `ufbx_skin_deformer.dq_vertices/dq_weights` (indexed by vertex).
	BLENDED_DQ_LINEAR,
}

// Skin weight information for a single mesh vertex
Skin_Vertex :: struct {
	// Each vertex is influenced by weights from `ufbx_skin_deformer.weights[]`
	// The weights are sorted by decreasing weight so you can take the first N
	// weights to get a cheaper approximation of the vertex.
	// NOTE: The weights are not guaranteed to be normalized!
	weight_begin: u32, // < Index to start from in the `weights[]` array
	num_weights: u32, // < Number of weights influencing the vertex

	// Blend weight between Linear Blend Skinning (0.0) and Dual Quaternion (1.0).
	// Should be used if `skinning_method == UFBX_SKINNING_METHOD_BLENDED_DQ_LINEAR`
	dq_weight: Real,

}

Skin_Vertex_List :: struct {
        data: [^]Skin_Vertex,
        count: c.size_t,
}

// Single per-vertex per-cluster weight, see `ufbx_skin_vertex`
Skin_Weight :: struct {
	cluster_index: u32, // < Index into `ufbx_skin_deformer.clusters[]`
	weight: Real,       // < Amount this bone influence the vertex
}

Skin_Weight_List :: struct {
        data: [^]Skin_Weight,
        count: c.size_t,
}

// Skin deformer specifies a binding between a logical set of bones (a skeleton)
// and a mesh. Each bone is represented by a `ufbx_skin_cluster` that contains
// the binding matrix and a `ufbx_node *bone` that has the current transformation.
Skin_Deformer :: struct {
        element: Element,

	skinning_method: Skinning_Method,

	// Clusters (bones) in the skin
	clusters: Skin_Cluster_List,

	// Per-vertex weight information
	vertices: Skin_Vertex_List,
	weights: Skin_Weight_List,

	// Largest amount of weights a single vertex can have
	max_weights_per_vertex: c.size_t,

	// Blend weights between Linear Blend Skinning (0.0) and Dual Quaternion (1.0).
	// HINT: You probably want to use `vertices` and `ufbx_skin_vertex.dq_weight` instead!
	// NOTE: These may be out-of-bounds for a given mesh, `vertices` is always safe.
	num_dq_weights: c.size_t,
	dq_vertices: Uint32_List,
	dq_weights: Real_List,
}

Skin_Deformer_List :: struct {
        data: [^]^Skin_Deformer,
        count: c.size_t,
}

// Cluster of vertices bound to a single bone.
Skin_Cluster :: struct {
        element: Element,

	// The bone node the cluster is attached to
	// NOTE: Always valid if found from `ufbx_skin_deformer.clusters[]` unless
	// `ufbx_load_opts.connect_broken_elements` is `true`.
	bone_node: ^Node,

	// Binding matrix from local mesh vertices to the bone
	geometry_to_bone: Matrix,

	// Binding matrix from local mesh _node_ to the bone.
	// NOTE: Prefer `geometry_to_bone` in most use cases!
	mesh_node_to_bone: Matrix,

	// Matrix that specifies the rest/bind pose transform of the node,
	// not generally needed for skinning, use `geometry_to_bone` instead.
	bind_to_world: Matrix,

	// Precomputed matrix/transform that accounts for the current bone transform
	// ie. `ufbx_matrix_mul(&cluster->bone->node_to_world, &cluster->geometry_to_bone)`
	geometry_to_world: Matrix,
	geometry_to_world_transform: Transform,

	// Raw weights indexed by each _vertex_ of a mesh (not index!)
	// HINT: It may be simpler to use `ufbx_skin_deformer.vertices[]/weights[]` instead!
	// NOTE: These may be out-of-bounds for a given mesh, `ufbx_skin_deformer.vertices` is always safe.
	num_weights: c.size_t,       // < Number of vertices in the cluster
	vertices: Uint32_List, // < Vertex indices in `ufbx_mesh.vertices[]`
	weights: Real_List,   // < Per-vertex weight values
}

Skin_Cluster_List :: struct {
        data: [^]^Skin_Cluster,
        count: c.size_t,
}

// Blend shape deformer can contain multiple channels (think of sliders between morphs)
// that may optionally have in-between keyframes.
Blend_Deformer :: struct {
        element: Element,

	// Independent morph targets of the deformer.
	channels: Blend_Channel_List,
}

Blend_Deformer_List :: struct {
        data: [^]^Blend_Deformer,
        count: c.size_t,
}

// Blend shape associated with a target weight in a series of morphs
Blend_Keyframe :: struct {
	// The target blend shape offsets.
	shape: ^Blend_Shape,

	// Weight value at which to apply the keyframe at full strength
	target_weight: Real,

	// The weight the shape should be currently applied with
	effective_weight: Real,
}

Blend_Keyframe_List :: struct {
        data: [^]Blend_Keyframe,
        count: c.size_t,
}

// Blend channel consists of multiple morph-key targets that are interpolated.
// In simple cases there will be only one keyframe that is the target shape.
Blend_Channel :: struct {
        element: Element,

	// Current weight of the channel
	weight: Real,

	// Key morph targets to blend between depending on `weight`
	// In usual cases there's only one target per channel
	keyframes: Blend_Keyframe_List,
};

Blend_Channel_List :: struct {
        data: [^]^Blend_Channel,
        count: c.size_t,
}

// Blend shape target containing the actual vertex offsets
Blend_Shape :: struct {
        element: Element,

	// Vertex offsets to apply over the base mesh
	// NOTE: The `offset_vertices` may be out-of-bounds for a given mesh!
	num_offsets: c.size_t,        // < Number of vertex offsets in the following arrays
	offset_vertices: Uint32_List, // < Indices to `ufbx_mesh.vertices[]`
	position_offsets: Vec3_List,  // < Always specified per-vertex offsets
	normal_offsets: Vec3_List,    // < Empty if not specified
}

Blend_Shape_List :: struct {
        data:[^]^Blend_Shape,
        count: c.size_t,
}

Cache_File_Format :: enum c.int {
	UNKNOWN, // < Unknown cache file format
	PC2,     // < .pc2 Point cache file
	MC,      // < .mc/.mcx Maya cache file
}

Cache_Data_Format :: enum c.int {
	UNKNOWN,     // < Unknown data format
	REAL_FLOAT,  // < `float data[]`
	VEC3_FLOAT,  // < `struct { float x, y, z; } data[]`
	REAL_DOUBLE, // < `double data[]`
	VEC3_DOUBLE, // < `struct { double x, y, z; } data[]`
}

Cache_Data_Encoding :: enum c.int {
	UNKNOWN,       // < Unknown data encoding
	LITTLE_ENDIAN, // < Contiguous little-endian array
	BIG_ENDIAN,    // < Contiguous big-endian array
}

// Known interpretations of geometry cache data.
Cache_Interpretation :: enum c.int {
	// Unknown interpretation, see `ufbx_cache_channel.interpretation_name` for more information.
	UNKNOWN,

	// Generic "points" interpretation, FBX SDK default. Usually fine to interpret
	// as vertex positions if no other cache channels are specified.
	POINTS,

	// Vertex positions.
	VERTEX_POSITION,

	// Vertex normals.
	VERTEX_NORMAL,
}

Cache_Frame :: struct {
	// Name of the channel this frame belongs to.
	channel: String,

	// Time of this frame in seconds.
	time: f64,

	// Name of the file containing the data.
	// The specified file may contain multiple frames, use `data_offset` etc. to
	// read at the right position.
	filename: String,

	// Format of the wrapper file.
	file_format: Cache_File_Format,

	data_format: Cache_Data_Format,     // < Format of the data in the file
	data_encoding: Cache_Data_Encoding, // < Binary encoding of the data
	data_offset: u64,                   // < Byte offset into the file
	data_count: u32,                    // < Number of data elements
	data_element_bytes: u32,            // < Size of a single data element in bytes
	data_total_bytes: u64,              // < Size of the whole data blob in bytes
}

Cache_Frame_List :: struct {
        data: [^]Cache_Frame,
        count: c.size_t,
}

Cache_Channel :: struct {
	// Name of the geometry cache channel.
	name: String,

	// What does the data in this channel represent.
	interpretation: Cache_Interpretation,

	// Source name for `interpretation`, especially useful if `interpretation` is
	// `UFBX_CACHE_INTERPRETATION_UNKNOWN`.
	interpretation_name: String,

	// List of frames belonging to this channel.
	// Sorted by time (`ufbx_cache_frame.time`).
	frames: Cache_Frame_List,
}

Cache_Channel_List :: struct {
        data: [^]Cache_Channel,
        count: c.size_t,
}

Geometry_Cache :: struct {
	root_filename: String,
	channels: Cache_Channel_List,
	frames: Cache_Frame_List,
	extra_info: String_List,
}

Cache_Deformer :: struct {
        element: Element,

	channel: String,
	file: ^Cache_File,

	// Only valid if `ufbx_load_opts.load_external_files` is set!
	external_cache: ^Geometry_Cache,
	external_channel: ^Cache_Channel,
}

Cache_Deformer_List :: struct {
        data: [^]^Cache_Deformer,
        count: c.size_t,
}

Cache_File :: struct {
        element: Element,

	filename: String,
	absolute_filename: String,
	relative_filename: String,
	raw_filename: Blob,
	raw_absolute_filename: Blob,
	raw_relative_filename: Blob,

	format: Cache_File_Format,

	// Only valid if `ufbx_load_opts.load_external_files` is set!
	external_cache: ^Geometry_Cache,
}

Cache_File_List :: struct {
        data: [^]^Cache_File,
        count: c.size_t,
}

// -- Materials

// Material property, either specified with a constant value or a mapped texture
Material_Map :: struct {
	// Constant value or factor for the map.
	// May be specified simultaneously with a texture, in this case most shading models
	// use multiplicative tinting of the texture values.
	values: Vec4,
	value_int: i64,

	// Texture if connected, otherwise `NULL`.
	// May be valid but "disabled" (application specific) if `texture_enabled == false`.
	texture: ^Texture,

	// `true` if the file has specified any of the values above.
	// NOTE: The value may be set to a non-zero default even if `has_value == false`,
	// for example missing factors are set to `1.0` if a color is defined.
	has_value: c.bool,

	// Controls whether shading should use `texture`.
	// NOTE: Some shading models allow this to be `true` even if `texture == NULL`.
	texture_enabled: c.bool,

	// Set to `true` if this feature should be disabled (specific to shader type).
	feature_disabled: c.bool,

	// Number of components in the value from 1 to 4 if defined, 0 if not.
	value_components: u8,
}

// Material feature
Material_Feature_Info :: struct {
	// Whether the material model uses this feature or not.
	// NOTE: The feature can be enabled but still not used if eg. the corresponding factor is at zero!
	enabled: c.bool,

	// Explicitly enabled/disabled by the material.
	is_explicit: c.bool,
}

// Texture attached to an FBX property
Material_Texture :: struct {
	material_prop: String, // < Name of the property in `ufbx_material.props`
	shader_prop: String,   // < Shader-specific property mapping name

	// Texture attached to the property.
	texture: ^Texture,
}

Material_Texture_List :: struct {
        data: [^]Material_Texture,
        count : c.size_t,
}

// Shading model type
Shader_Type :: enum c.int {
	// Unknown shading model
	UNKNOWN,
	// FBX builtin diffuse material
	FBX_LAMBERT,
	// FBX builtin diffuse+specular material
	FBX_PHONG,
	// Open Shading Language standard surface
	// https://github.com/Autodesk/standard-surface
	OSL_STANDARD_SURFACE,
	// Arnold standard surface
	// https://docs.arnoldrenderer.com/display/A5AFMUG/Standard+Surface
	ARNOLD_STANDARD_SURFACE,
	// 3ds Max Physical Material
	// https://knowledge.autodesk.com/support/3ds-max/learn-explore/caas/CloudHelp/cloudhelp/2022/ENU/3DSMax-Lighting-Shading/files/GUID-C1328905-7783-4917-AB86-FC3CC19E8972-htm.html
	_3DS_MAX_PHYSICAL_MATERIAL,
	// 3ds Max PBR (Metal/Rough) material
	// https://knowledge.autodesk.com/support/3ds-max/learn-explore/caas/CloudHelp/cloudhelp/2021/ENU/3DSMax-Lighting-Shading/files/GUID-A16234A5-6500-4662-8B20-A5EC9FE1B255-htm.html
	_3DS_MAX_PBR_METAL_ROUGH,
	// 3ds Max PBR (Spec/Gloss) material
	// https://knowledge.autodesk.com/support/3ds-max/learn-explore/caas/CloudHelp/cloudhelp/2021/ENU/3DSMax-Lighting-Shading/files/GUID-18087194-B2A6-43EF-9B80-8FD1736FAE52-htm.html
	_3DS_MAX_PBR_SPEC_GLOSS,
	// 3ds glTF Material
	// https://help.autodesk.com/view/3DSMAX/2023/ENU/?guid=GUID-7ABFB805-1D9F-417E-9C22-704BFDF160FA
	GLTF_MATERIAL,
	// Stingray ShaderFX shader graph.
	// Contains a serialized `"ShaderGraph"` in `ufbx_props`.
	SHADERFX_GRAPH,
	// Variation of the FBX phong shader that can recover PBR properties like
	// `metalness` or `roughness` from the FBX non-physical values.
	BLENDER_PHONG,
	// Wavefront .mtl format shader (used by .obj files)
	WAVEFRONT_MTL,
}

// FBX builtin material properties, matches maps in `ufbx_material_fbx_maps`
Material_Fbx_Map :: enum c.int {
	DIFFUSE_FACTOR,
	DIFFUSE_COLOR,
	SPECULAR_FACTOR,
	SPECULAR_COLOR,
	SPECULAR_EXPONENT,
	REFLECTION_FACTOR,
	REFLECTION_COLOR,
	TRANSPARENCY_FACTOR,
	TRANSPARENCY_COLOR,
	EMISSION_FACTOR,
	EMISSION_COLOR,
	AMBIENT_FACTOR,
	AMBIENT_COLOR,
	NORMAL_MAP,
	BUMP,
	BUMP_FACTOR,
	DISPLACEMENT_FACTOR,
	DISPLACEMENT,
	VECTOR_DISPLACEMENT_FACTOR,
	VECTOR_DISPLACEMENT,
}

// Known PBR material properties, matches maps in `ufbx_material_pbr_maps`
Material_Pbr_Map :: enum c.int {
	BASE_FACTOR,
	BASE_COLOR,
	ROUGHNESS,
	METALNESS,
	DIFFUSE_ROUGHNESS,
	SPECULAR_FACTOR,
	SPECULAR_COLOR,
	SPECULAR_IOR,
	SPECULAR_ANISOTROPY,
	SPECULAR_ROTATION,
	TRANSMISSION_FACTOR,
	TRANSMISSION_COLOR,
	TRANSMISSION_DEPTH,
	TRANSMISSION_SCATTER,
	TRANSMISSION_SCATTER_ANISOTROPY,
	TRANSMISSION_DISPERSION,
	TRANSMISSION_ROUGHNESS,
	TRANSMISSION_EXTRA_ROUGHNESS,
	TRANSMISSION_PRIORITY,
	TRANSMISSION_ENABLE_IN_AOV,
	SUBSURFACE_FACTOR,
	SUBSURFACE_COLOR,
	SUBSURFACE_RADIUS,
	SUBSURFACE_SCALE,
	SUBSURFACE_ANISOTROPY,
	SUBSURFACE_TINT_COLOR,
	SUBSURFACE_TYPE,
	SHEEN_FACTOR,
	SHEEN_COLOR,
	SHEEN_ROUGHNESS,
	COAT_FACTOR,
	COAT_COLOR,
	COAT_ROUGHNESS,
	COAT_IOR,
	COAT_ANISOTROPY,
	COAT_ROTATION,
	COAT_NORMAL,
	COAT_AFFECT_BASE_COLOR,
	COAT_AFFECT_BASE_ROUGHNESS,
	THIN_FILM_THICKNESS,
	THIN_FILM_IOR,
	EMISSION_FACTOR,
	EMISSION_COLOR,
	OPACITY,
	INDIRECT_DIFFUSE,
	INDIRECT_SPECULAR,
	NORMAL_MAP,
	TANGENT_MAP,
	DISPLACEMENT_MAP,
	MATTE_FACTOR,
	MATTE_COLOR,
	AMBIENT_OCCLUSION,
	GLOSSINESS,
	COAT_GLOSSINESS,
	TRANSMISSION_GLOSSINESS,
}

// Known material features
Material_Feature :: enum c.int {
	PBR,
	METALNESS,
	DIFFUSE,
	SPECULAR,
	EMISSION,
	TRANSMISSION,
	COAT,
	SHEEN,
	OPACITY,
	AMBIENT_OCCLUSION,
	MATTE,
	UNLIT,
	IOR,
	DIFFUSE_ROUGHNESS,
	TRANSMISSION_ROUGHNESS,
	THIN_WALLED,
	CAUSTICS,
	EXIT_TO_BACKGROUND,
	INTERNAL_REFLECTIONS,
	DOUBLE_SIDED,
	ROUGHNESS_AS_GLOSSINESS,
	COAT_ROUGHNESS_AS_GLOSSINESS,
	TRANSMISSION_ROUGHNESS_AS_GLOSSINESS,
}

Material_Fbx_Maps :: struct {
        // ufbx_material_map maps[UFBX_MATERIAL_FBX_MAP_COUNT];
        diffuse_factor: Material_Map,
        diffuse_color: Material_Map,
        specular_factor: Material_Map,
        specular_color: Material_Map,
        specular_exponent: Material_Map,
        reflection_factor: Material_Map,
        reflection_color: Material_Map,
        transparency_factor: Material_Map,
        transparency_color: Material_Map,
        emission_factor: Material_Map,
        emission_color: Material_Map,
        ambient_factor: Material_Map,
        ambient_color: Material_Map,
        normal_map: Material_Map,
        bump: Material_Map,
        bump_factor: Material_Map,
        displacement_factor: Material_Map,
        displacement: Material_Map,
        vector_displacement_factor: Material_Map,
        vector_displacement: Material_Map,
}

Material_Pbr_Maps :: struct {
        // ufbx_material_map maps[UFBX_MATERIAL_PBR_MAP_COUNT];
        base_factor: Material_Map,
        base_color: Material_Map,
        roughness: Material_Map,
        metalness: Material_Map,
        diffuse_roughness: Material_Map,
        specular_factor: Material_Map,
        specular_color: Material_Map,
        specular_ior: Material_Map,
        specular_anisotropy: Material_Map,
        specular_rotation: Material_Map,
        transmission_factor: Material_Map,
        transmission_color: Material_Map,
        transmission_depth: Material_Map,
        transmission_scatter: Material_Map,
        transmission_scatter_anisotropy: Material_Map,
        transmission_dispersion: Material_Map,
        transmission_roughness: Material_Map,
        transmission_extra_roughness: Material_Map,
        transmission_priority: Material_Map,
        transmission_enable_in_aov: Material_Map,
        subsurface_factor: Material_Map,
        subsurface_color: Material_Map,
        subsurface_radius: Material_Map,
        subsurface_scale: Material_Map,
        subsurface_anisotropy: Material_Map,
        subsurface_tint_color: Material_Map,
        subsurface_type: Material_Map,
        sheen_factor: Material_Map,
        sheen_color: Material_Map,
        sheen_roughness: Material_Map,
        coat_factor: Material_Map,
        coat_color: Material_Map,
        coat_roughness: Material_Map,
        coat_ior: Material_Map,
        coat_anisotropy: Material_Map,
        coat_rotation: Material_Map,
        coat_normal: Material_Map,
        coat_affect_base_color: Material_Map,
        coat_affect_base_roughness: Material_Map,
        thin_film_thickness: Material_Map,
        thin_film_ior: Material_Map,
        emission_factor: Material_Map,
        emission_color: Material_Map,
        opacity: Material_Map,
        indirect_diffuse: Material_Map,
        indirect_specular: Material_Map,
        normal_map: Material_Map,
        tangent_map: Material_Map,
        displacement_map: Material_Map,
        matte_factor: Material_Map,
        matte_color: Material_Map,
        ambient_occlusion: Material_Map,
        glossiness: Material_Map,
        coat_glossiness: Material_Map,
        transmission_glossiness: Material_Map,
}

Material_Features :: struct {
        // ufbx_material_feature_info features[UFBX_MATERIAL_FEATURE_COUNT];
        pbr: Material_Feature_Info,
        metalness: Material_Feature_Info,
        diffuse: Material_Feature_Info,
        specular: Material_Feature_Info,
        emission: Material_Feature_Info,
        transmission: Material_Feature_Info,
        coat: Material_Feature_Info,
        sheen: Material_Feature_Info,
        opacity: Material_Feature_Info,
        ambient_occlusion: Material_Feature_Info,
        matte: Material_Feature_Info,
        unlit: Material_Feature_Info,
        ior: Material_Feature_Info,
        diffuse_roughness: Material_Feature_Info,
        transmission_roughness: Material_Feature_Info,
        thin_walled: Material_Feature_Info,
        caustics: Material_Feature_Info,
        exit_to_background: Material_Feature_Info,
        internal_reflections: Material_Feature_Info,
        double_sided: Material_Feature_Info,
        roughness_as_glossiness: Material_Feature_Info,
        coat_roughness_as_glossiness: Material_Feature_Info,
        transmission_roughness_as_glossiness: Material_Feature_Info,
}

// Surface material properties such as color, roughness, etc. Each property may
// be optionally bound to an `ufbx_texture`.
Material :: struct {
        element: Element,

	// FBX builtin properties
	// NOTE: These may be empty if the material is using a custom shader
	fbx: Material_Fbx_Maps,

	// PBR material properties, defined for all shading models but may be
	// somewhat approximate if `shader == NULL`.
	pbr: Material_Pbr_Maps,

	// Material features, primarily applies to `pbr`.
	features: Material_Features,

	// Shading information
	shader_type: Shader_Type,      // < Always defined
	shader: ^Shader,               // < Optional extended shader information
	shading_model_name: String,    // < Often one of `{ "lambert", "phong", "unknown" }`

	// Prefix before shader property names with trailing `|`.
	// For example `"3dsMax|Parameters|"` where properties would have names like
	// `"3dsMax|Parameters|base_color"`. You can ignore this if you use the built-in
	// `ufbx_material_fbx_maps fbx` and `ufbx_material_pbr_maps pbr` structures.
	shader_prop_prefix: String,

	// All textures attached to the material, if you want specific maps if might be
	// more convenient to use eg. `fbx.diffuse_color.texture` or `pbr.base_color.texture`
	textures: Material_Texture_List, // < Sorted by `material_prop`
}

Material_List :: struct {
        data: [^]^Material,
        count: c.size_t,
}

Texture_Type :: enum c.int {
	// Texture associated with an image file/sequence. `texture->filename` and
	// and `texture->relative_filename` contain the texture's path. If the file
	// has embedded content `texture->content` may hold `texture->content_size`
	// bytes of raw image data.
	FILE,
	// The texture consists of multiple texture layers blended together.
	LAYERED,
	// Reserved as these _should_ exist in FBX files.
	PROCEDURAL,
	// Node in a shader graph.
	// Use `ufbx_texture.shader` for more information.
	SHADER,
}

// Blend modes to combine layered textures with, compatible with common blend
// mode definitions in many art programs. Simpler blend modes have equations
// specified below where `src` is the layer to compososite over `dst`.
// See eg. https://www.w3.org/TR/2013/WD-compositing-1-20131010/#blendingseparable
Blend_Mode :: enum c.int {
	TRANSLUCENT,   // < `src` effects result alpha
	ADDITIVE,      // < `src + dst`
	MULTIPLY,      // < `src * dst`
	MULTIPLY_2X,   // < `2 * src * dst`
	OVER,          // < `src * src_alpha + dst * (1-src_alpha)`
	REPLACE,       // < `src` Replace the contents
	DISSOLVE,      // < `random() + src_alpha >= 1.0 ? src : dst`
	DARKEN,        // < `min(src, dst)`
	COLOR_BURN,    // < `src > 0 ? 1 - min(1, (1-dst) / src) : 0`
	LINEAR_BURN,   // < `src + dst - 1`
	DARKER_COLOR,  // < `value(src) < value(dst) ? src : dst`
	LIGHTEN,       // < `max(src, dst)`
	SCREEN,        // < `1 - (1-src)*(1-dst)`
	COLOR_DODGE,   // < `src < 1 ? dst / (1 - src)` : (dst>0?1:0)`
	LINEAR_DODGE,  // < `src + dst`
	LIGHTER_COLOR, // < `value(src) > value(dst) ? src : dst`
	SOFT_LIGHT,    // < https://www.w3.org/TR/2013/WD-compositing-1-20131010/#blendingsoftlight
	HARD_LIGHT,    // < https://www.w3.org/TR/2013/WD-compositing-1-20131010/#blendinghardlight
	VIVID_LIGHT,   // < Combination of `COLOR_DODGE` and `COLOR_BURN`
	LINEAR_LIGHT,  // < Combination of `LINEAR_DODGE` and `LINEAR_BURN`
	PIN_LIGHT,     // < Combination of `DARKEN` and `LIGHTEN`
	HARD_MIX,      // < Produces primary colors depending on similarity
	DIFFERENCE,    // < `abs(src - dst)`
	EXCLUSION,     // < `dst + src - 2 * src * dst`
	SUBTRACT,      // < `dst - src`
	DIVIDE,        // < `dst / src`
	HUE,           // < Replace hue
	SATURATION,    // < Replace saturation
	COLOR,         // < Replace hue and saturatio
	LUMINOSITY,    // < Replace value
	OVERLAY,       // < Same as `HARD_LIGHT` but with `src` and `dst` swapped
}

// Blend modes to combine layered textures with, compatible with common blend
Wrap_Mode :: enum c.int {
	REPEAT, // < Repeat the texture past the [0,1] range
	CLAMP,  // < Clamp the normalized texture coordinates to [0,1]
}

// Single layer in a layered texture
Texture_Layer :: struct {
	texture: ^Texture,      // < The inner texture to evaluate, never `NULL`
	blend_mode: Blend_Mode, // < Equation to combine the layer to the background
	alpha: Real,            // < Blend weight of this layer
}

Texture_Layer_List :: struct {
        data: [^]Texture_Layer,
        count: c.size_t,
}

Shader_Texture_Type :: enum c.int {
	UNKNOWN,
	// Select an output of a multi-output shader.
	// HINT: If this type is used the `texture` and
	// `ufbx_shader_texture.main_texture_output_index` fields are set.
	SELECT_OUTPUT,
	// Open Shading Language (OSL) shader.
	// https://github.com/AcademySoftwareFoundation/OpenShadingLanguage
	OSL,
}

Shader_Texture_Input :: struct {
	// Name of the input.
	name: String,

	// Constant value of the input.
        values: Vec4,
	value_int: i64,
	value_str: String,
	value_blob: Blob,

	// Texture connected to this input.
	texture: ^Texture,

	// Index of the output to use if `texture` is a multi-output shader node.
	texture_output_index: i64,

	// Controls whether shading should use `texture`.
	// NOTE: Some shading models allow this to be `true` even if `texture == NULL`.
	texture_enabled: c.bool,

	// Property representing this input.
	prop: ^Prop,

	// Property representing `texture`.
	texture_prop: ^Prop,

	// Property representing `texture_enabled`.
	texture_enabled_prop: ^Prop,
}

Shader_Texture_Input_List :: struct {
        data: [^]Shader_Texture_Input,
        count: c.size_t,
}

Shader_Texture :: struct {
	// Type of this shader node.
	type: Shader_Texture_Type,

	// Name of the shader to use.
	shader_name: String,

	// 64-bit opaque identifier for the shader type.
	shader_type_id: u64,

	// Input values/textures (possibly further shader textures) to the shader.
	// Sorted by `ufbx_shader_texture_input.name`.
	inputs: Shader_Texture_Input_List,

	// Shader source code if found.
	shader_source: String,
	raw_shader_source: Blob,

	// Representative texture for this shader.
	// Only specified if `main_texture.outputs[main_texture_output_index]` is semantically
	// equivalent to this texture.
	main_texture: ^Texture,

	// Output index of `main_texture` if it is a multi-output shader.
	main_texture_output_index: i64,

	// Prefix for properties related to this shader in `ufbx_texture`.
	// NOTE: Contains the trailing '|' if not empty.
	prop_prefix: String,
}

// Unique texture within the file.
Texture_File :: struct {
	// Index in `ufbx_scene.texture_files[]`.
	index: u32,

	// Paths to the resource.
	filename: String,
	absolute_filename: String,
	relative_filename: String,
	raw_filename: Blob,
	raw_absolute_filename: Blob,
	raw_relative_filename: Blob,

	// Optional embedded content blob, eg. raw .png format data
	content: Blob,
}

Texture_File_List :: struct {
        data: [^]Texture_File,
        count: c.size_t,
}

// Texture that controls material appearance
Texture :: struct {
        element: Element,

        // Texture type (file / layered / procedural / shader)
	type: Texture_Type,

	// FILE: Paths to the resource
	filename: String,
	absolute_filename: String,
	relative_filename: String,
	raw_filename: Blob,
	raw_absolute_filename: Blob,
	raw_relative_filename: Blob,

	// FILE: Optional embedded content blob, eg. raw .png format data
	content: Blob,

	// FILE: Optional video texture
	video: ^Video,

	// FILE: Index into `ufbx_scene.texture_files[]` or `UFBX_NO_INDEX`.
	file_index: u32,

	// FILE: True if `file_index` has a valid value.
	has_file: c.bool,

	// LAYERED: Inner texture layers, ordered from _bottom_ to _top_
	layers: Texture_Layer_List,

	// SHADER: Shader information
	// NOTE: May be specified even if `type == UFBX_TEXTURE_FILE` if `ufbx_load_opts.disable_quirks`
	// is _not_ specified. Some known shaders that represent files are interpreted as `UFBX_TEXTURE_FILE`.
	shader: ^Shader_Texture,

	// List of file textures representing this texture.
	// Defined even if `type == UFBX_TEXTURE_FILE` in which case the array contains only itself.
	file_textures: Texture_List,

	// Name of the UV set to use
	uv_set: String,

	// Wrapping mode
	wrap_u: Wrap_Mode,
	wrap_v: Wrap_Mode,

	// UV transform
	has_uv_transform: c.bool,       // < Has a non-identity `transform` and derived matrices.
	uv_transform: Transform,        // < Texture transformation in UV space
	texture_to_uv: Matrix,          // < Matrix representation of `transform`
	uv_to_texture: Matrix,          // < UV coordinate to normalized texture coordinate matrix
};

Texture_List :: struct {
        data: [^]^Texture,
        count: c.size_t,
}

// TODO: Video textures
Video :: struct {
        element: Element,

	// Paths to the resource
	filename: String,
	absolute_filename: String,
	relative_filename: String,
	raw_filename: Blob,
	raw_absolute_filename: Blob,
	raw_relative_filename: Blob,

	// Optional embedded content blob
	content: Blob,
}

Video_List :: struct {
        data: [^]^Video,
        count: c.size_t,
}

// Shader specifies a shading model and contains `ufbx_shader_binding` elements
// that define how to interpret FBX properties in the shader.
Shader :: struct {
        element: Element,

	// Known shading model
	type: Shader_Type,

	// TODO: Expose actual properties here

	// Bindings from FBX properties to the shader
	// HINT: `ufbx_find_shader_prop()` translates shader properties to FBX properties
	bindings: Shader_Binding_List,
}

Shader_List :: struct {
        data: [^]^Shader,
        count: c.size_t,
}

// Binding from a material property to shader implementation
Shader_Prop_Binding :: struct {
	shader_prop: String,   // < Property name used by the shader implementation
	material_prop: String, // < Property name inside `ufbx_material.props`
}

Shader_Prop_Binding_List :: struct {
        data: [^]Shader_Prop_Binding,
        count: c.size_t,
}

// Shader binding table
Shader_Binding :: struct {
        element: Element,
	prop_bindings: Shader_Prop_Binding_List, // < Sorted by `shader_prop`
}

Shader_Binding_List :: struct {
        data: [^]^Shader_Binding,
        count: c.size_t,
}


// -- Animation

Anim_Layer_Desc :: struct {
	layer: ^Anim_Layer,
	weight: Real,
}

Anim_Layer_Desc_List :: struct {
        data: [^]Anim_Layer_Desc,
        count: c.size_t,
}

Prop_Override :: struct {
	// Element (`ufbx_element.id`) to override the property from
	// NOTE: You can get this from typed structs eg. `my_node->element.id`
	element_id: u32,

	// Property name to override.
	prop_name: cstring,

	// Override value, use `value.x` for scalars. `value_int` is initialized
	// from `value.x` if zero so keep `value` zeroed even if you don't need it!
	value: Vec3,
	value_str: cstring,
	value_int: i64,

	// Internal: Gets filled automatically by `ufbx_prepare_prop_overrides()`
	_internal_key: u32,
}

Prop_Override_List :: struct {
        data: [^]Prop_Override,
        count: c.size_t,
}

Anim :: struct {
	layers: Anim_Layer_Desc_List,

	// Override individual `ufbx_prop` values from elements
	// NOTE: Call `ufbx_prepare_prop_overrides()` to obtain this!
	prop_overrides: Prop_Override_List,

	ignore_connections: c.bool,

	// Not used by evaluation
	time_begin: f64,
	time_end: f64,
}

Anim_Stack :: struct {
        element: Element,

	time_begin: f64,
	time_end: f64,

	layers: Anim_Layer_List,
	anim: Anim,
}

Anim_Stack_List :: struct {
        data: [^]^Anim_Stack,
        count: c.size_t,
}

Anim_Prop :: struct {
	element: ^Element,
	_internal_key: u32,
	prop_name: String,
	anim_value: ^Anim_Value,
}

Anim_Prop_List :: struct {
        data: [^]Anim_Prop,
        count: c.size_t,
}

Anim_Layer :: struct {
        element: Element,

	weight: Real,
	weight_is_animated: c.bool,
	blended: c.bool,
	additive: c.bool,
	compose_rotation: c.bool,
	compose_scale: c.bool,

	anim_values: Anim_Value_List,
	anim_props: Anim_Prop_List, // < Sorted by `element,prop_name`

	anim: Anim,

	_min_element_id: u32,
	_max_element_id: u32,
	_element_id_bitmask: [4]u32,
}

Anim_Layer_List :: struct {
        data: [^]^Anim_Layer,
        count: c.size_t,
}

Anim_Value :: struct {
        element: Element,
	default_value: Vec3,
	curves: [3]^Anim_Curve,
}

Anim_Value_List :: struct {
        data: [^]^Anim_Value,
        count: c.size_t,
}

// Animation curve segment interpolation mode between two keyframes
Interpolation :: enum c.int {
	CONSTANT_PREV, // < Hold previous key value
	CONSTANT_NEXT, // < Hold next key value
	LINEAR,        // < Linear interpolation between two keys
	CUBIC,         // < Cubic interpolation, see `ufbx_tangent`
}

// Tangent vector at a keyframe, may be split into left/right
Tangent :: struct {
	dx: f32, // < Derivative in the time axis
	dy: f32, // < Derivative in the (curve specific) value axis
}

// Single real `value` at a specified `time`, interpolation between two keyframes
// is determined by the `interpolation` field of the _previous_ key.
// If `interpolation == UFBX_INTERPOLATION_CUBIC` the span is evaluated as a
// cubic bezier curve through the following points:
//
//   (prev->time, prev->value)
//   (prev->time + prev->right.dx, prev->value + prev->right.dy)
//   (next->time - next->left.dx, next->value - next->left.dy)
//   (next->time, next->value)
//
// HINT: You can use `ufbx_evaluate_curve(ufbx_anim_curve *curve, double time)`
// rather than trying to manually handle all the interpolation modes.
Keyframe :: struct {
	time: f64,
	value: Real,
	interpolation: Interpolation,
	left: Tangent,
	right: Tangent,
}

Keyframe_List :: struct {
        data: [^]Keyframe,
        count: c.size_t,
}

Anim_Curve :: struct {
        element: Element,
	keyframes: Keyframe_List,
}

Anim_Curve_List :: struct {
        data: [^]^Anim_Curve,
        count: c.size_t,
}

// -- Collections

// Collection of nodes to hide/freeze
Display_Layer :: struct {
        element: Element,

	// Nodes included in the layer (exclusively at most one layer per node)
	nodes: Node_List,

	// Layer state
	visible: c.bool, // < Contained nodes are visible
	frozen: c.bool,  // < Contained nodes cannot be edited

	ui_color: Vec3, // < Visual color for UI
}

Display_Layer_List :: struct {
        data: [^]Display_Layer,
        count: c.size_t,
}

// Named set of nodes/geometry features to select.
Selection_Set :: struct {
        element: Element,

	// Included nodes and geometry features
	nodes: Selection_Node_List,
}

Selection_Set_List :: struct {
        data: [^]^Selection_Set,
        count: c.size_t,
}

// Selection state of a node, potentially contains vertex/edge/face selection as well.
Selection_Node :: struct {
        element: Element,

	// Selection targets, possibly `NULL`
	target_node: ^Node,
	target_mesh: ^Mesh,
	include_node: c.bool, // < Is `target_node` included in the selection

	// Indices to selected components.
	// Guaranteed to be valid as per `ufbx_load_opts.index_error_handling`
	// if `target_mesh` is not `NULL`.
	vertices: Uint32_List, // < Indices to `ufbx_mesh.vertices`
	edges: Uint32_List,    // < Indices to `ufbx_mesh.edges`
	faces: Uint32_List,    // < Indices to `ufbx_mesh.faces`
}

Selection_Node_List :: struct {
        data: [^]^Selection_Node,
        count: c.size_t,
}


// -- Constraints

Character :: struct {
        element: Element,
}

Character_List :: struct {
        data: [^]^Character,
        count: c.size_t,
}

// Type of property constrain eg. position or look-at
Constraint_Type :: enum c.int {
	UNKNOWN,
	AIM,
	PARENT,
	POSITION,
	ROTATION,
	SCALE,
	// Inverse kinematic chain to a single effector `ufbx_constraint.ik_effector`
	// `targets` optionally contains a list of pole targets!
	SINGLE_CHAIN_IK,
}

// Target to follow with a constraint
Constraint_Target :: struct {
	node: ^Node,          // < Target node reference
	weight: Real,         // < Relative weight to other targets (does not always sum to 1)
	transform: Transform, // < Offset from the actual target
}

Constraint_Target_List :: struct {
        data: [^]Constraint_Target,
        count: c.size_t,
}

// Method to determine the up vector in aim constraints
Constraint_Aim_Up_Type :: enum c.int {
	SCENE,      // < Align the up vector to the scene global up vector
	TO_NODE,    // < Aim the up vector at `ufbx_constraint.aim_up_node`
	ALIGN_NODE, // < Copy the up vector from `ufbx_constraint.aim_up_node`
	VECTOR,     // < Use `ufbx_constraint.aim_up_vector` as the up vector
	NONE,       // < Don't align the up vector to anything
}

// Method to determine the up vector in aim constraints
Constraint_Ik_Pole_Type :: enum c.int {
	VECTOR, // < Use towards calculated from `ufbx_constraint.targets`
	NODE,   // < Use `ufbx_constraint.ik_pole_vector` directly
}

Constraint :: struct {
        element: Element,

	// Type of constraint to use
	type: Constraint_Type,
	type_name: String,

	// Node to be constrained
	node: ^Node,

	// List of weighted targets for the constraint (pole vectors for IK)
	targets: Constraint_Target_List,

	// State of the constraint
	weight: Real,
	active: c.bool,

	// Translation/rotation/scale axes the constraint is applied to
	constrain_translation: [3]c.bool,
	constrain_rotation: [3]c.bool,
	constrain_scale: [3]c.bool,

	// Offset from the constrained position
	transform_offset: Transform,

	// AIM: Target and up vectors
	aim_vector: Vec3,
	aim_up_type: Constraint_Aim_Up_Type,
	aim_up_node: ^Node,
	aim_up_vector: Vec3,

	// SINGLE_CHAIN_IK: Target for the IK, `targets` contains pole vectors!
	ik_effector: ^Node,
	ik_end_node: ^Node,
	ik_pole_vector: Vec3,
}

Constraint_List :: struct {
        data: [^]^Constraint,
        count: c.size_t,
}


// -- Miscellaneous

Bone_Pose :: struct {
	bone_node: ^Node,
	bone_to_world: Matrix,
}

Bone_Pose_List :: struct {
        data: [^]Bone_Pose,
        count: c.size_t,
}

Pose :: struct {
        element: Element,

	bind_pose: c.bool,
	bone_poses: Bone_Pose_List,
}

Pose_List :: struct {
        data: [^]^Pose,
        count: c.size_t,
}

Metadata_Object :: struct {
        element: Element,
}

Metadata_Object_List :: struct {
        data: [^]^Metadata_Object,
        count: c.size_t,
}

// -- Named elements

Name_Element :: struct {
	name: String,
	type: Element_Type,
	_internal_key: u32,
	element: ^Element,
}

Name_Element_List :: struct {
        data: [^]Name_Element,
        count: c.size_t,
}


// -- Scene

// Scene is the root object loaded by ufbx that everything is accessed from.

Exporter :: enum c.int {
	UNKNOWN,
	FBX_SDK,
	BLENDER_BINARY,
	BLENDER_ASCII,
	MOTION_BUILDER,
	BC_UNITY_EXPORTER,
}

Application :: struct {
	vendor: String,
	name: String,
	version: String,
}

File_Format :: enum c.int {
	UNKNOWN, // < Unknown file format
	FBX,     // < .fbx Kaydara/Autodesk FBX file
	OBJ,     // < .obj Wavefront OBJ file
	MTL,     // < .mtl Wavefront MTL (Material template library) file
}

Warning_Type :: enum c.int {
	// Missing external file file (for example .mtl for Wavefront .obj file or a
	// geometry cache)
	MISSING_EXTERNAL_FILE,

	// Loaded a Wavefront .mtl file derived from the filename instead of a proper
	// `mtllib` statement.
	IMPLICIT_MTL,

	// Truncated array has been auto-expanded.
	TRUNCATED_ARRAY,

	// Out-of-bounds index has been clamped to be in-bounds.
	// HINT: You can use `ufbx_index_error_handling` to adjust behavior.
	INDEX_CLAMPED,

	// Non-UTF8 encoded strings.
	// HINT: You can use `ufbx_unicode_error_handling` to adjust behavior.
	BAD_UNICODE,

	// Non-node element connected to root.
	BAD_ELEMENT_CONNECTED_TO_ROOT,

	// Duplicated object ID in the file, connections will be wrong.
	DUPLICATE_OBJECT_ID,

	// Empty face has been removed.
	// Use `ufbx_load_opts.allow_empty_faces` if you want to allow them.
	EMPTY_FACE_REMOVED,

	// Unknown .obj file directive.
	UNKNOWN_OBJ_DIRECTIVE,

	// Warnings after this one are deduplicated.
	// See `ufbx_warning.count` for how many times they happened.
	// TYPE_FIRST_DEDUPLICATED = INDEX_CLAMPED,
}

Warning_Type_Count :: 9

// Warning about a non-fatal issue in the file.
// Often contains information about issues that ufbx has corrected about the
// file but it might indicate something is not working properly.
Warning :: struct {
	// Type of the warning.
	type: Warning_Type,
	// Description of the warning.
	description: String,
	// Number of times this warning was encountered.
	count: c.size_t,
}

Warning_List :: struct {
        data: [^]Warning,
        count: c.size_t,
}

// Miscellaneous data related to the loaded file
Metadata :: struct {
	// List of non-fatal warnings about the file.
	// If you need to only check whether a specific warning was triggered you
	// can use `ufbx_metadata.has_warning[]`.
	warnings: Warning_List,

	// FBX ASCII file format.
	ascii: c.bool,

	// FBX version in integer format, eg. 7400 for 7.4.
	version: u32,

	// File format of the source file.
	file_format: File_Format,

	// Index arrays may contain `UFBX_NO_INDEX` instead of a valid index
	// to indicate gaps.
	may_contain_no_index: c.bool,

	// May contain `ufbx_mesh_material` entries where `ufbx_mesh_material.material == NULL`.
	// NOTE: The corresponding `ufbx_node.material[]` will be empty in this case.
	may_contain_null_materials: c.bool,

	// May contain meshes with no defined vertex position.
	// NOTE: `ufbx_mesh.vertex_position.exists` may be `false`!
	may_contain_missing_vertex_position: c.bool,

	// Arrays may contain items with `NULL` element references.
	// See `ufbx_load_opts.connect_broken_elements`.
	may_contain_broken_elements: c.bool,

	// Some API guarantees do not apply (depending on unsafe options used).
	// Loaded with `ufbx_load_opts.allow_unsafe` enabled.
	is_unsafe: c.bool,

	// Flag for each possible warning type.
	// See `ufbx_metadata.warnings[]` for detailed warning information.
        has_warning: [Warning_Type_Count]c.bool,

	creator: String,
	big_endian: c.bool,

	filename: String,
	relative_root: String,

	raw_filename: Blob,
	raw_relative_root: Blob,

	exporter: Exporter,
	exporter_version: u32,

	scene_props: Props,

	original_application: Application,
	latest_application: Application,

	geometry_ignored: c.bool,
	animation_ignored: c.bool,
	embedded_ignored: c.bool,

	max_face_triangles: c.size_t,

	result_memory_used: c.size_t,
	temp_memory_used: c.size_t,
	result_allocs: c.size_t,
	temp_allocs: c.size_t,

	element_buffer_size: c.size_t,
	num_shader_textures: c.size_t,

	bone_prop_size_unit: Real,
	bone_prop_limb_length_relative: c.bool,
	ktime_to_sec: f64,

	original_file_path: String,
	raw_original_file_path: Blob,
}

Time_Mode :: enum c.int {
	DEFAULT,
	_120_FPS,
	_100_FPS,
	_60_FPS,
	_50_FPS,
	_48_FPS,
	_30_FPS,
	_30_FPS_DROP,
	NTSC_DROP_FRAME,
	NTSC_FULL_FRAME,
	PAL,
	_24_FPS,
	_1000_FPS,
	FILM_FULL_FRAME,
	CUSTOM,
	_96_FPS,
	_72_FPS,
	_59_94_FPS,
}

Time_Protocol :: enum c.int {
	SMPTE,
	FRAME_COUNT,
	DEFAULT,
}

Snap_Mode :: enum c.int {
	NONE,
	SNAP,
	PLAY,
	SNAP_AND_PLAY,
}

// Global settings: Axes and time/unit scales
Scene_Settings :: struct {
	props: Props,

	// Mapping of X/Y/Z axes to world-space directions.
	// HINT: Use `ufbx_load_opts.target_axes` to normalize this.
	// NOTE: This contains the _original_ axes even if you supply `ufbx_load_opts.target_axes`.
	axes: Coordinate_Axes,

	// How many meters does a single world-space unit represent.
	// FBX files usually default to centimeters, reported as `0.01` here.
	// HINT: Use `ufbx_load_opts.target_unit_meters` to normalize this.
	unit_meters: Real,

	frames_per_second: f64,

	ambient_color: Vec3,
	default_camera: String,

	time_mode: Time_Mode,
	time_protocol: Time_Protocol,
	snap_mode: Snap_Mode,

	// Original settings (?)
	original_axis_up: Coordinate_Axis,
	original_unit_meters: Real,
}

Scene :: struct {
	metadata: Metadata,

	// Global settings
	settings: Scene_Settings,

	// Node instances in the scene
	root_node: ^Node,

	// Default animation descriptor
	anim: Anim,

	// All animation stacks combined
	combined_anim: Anim,

        unknowns: Unknown_List,

        // Nodes
        nodes: Node_List,

        // Node attributes (common)
        meshes: Mesh_List,
        lights: Light_List,
        cameras: Camera_List,
        bones: Bone_List,
        empties: Empty_List,

        // Node attributes (curves/surfaces)
        line_curves: Line_Curve_List,
        nurbs_curves: Nurbs_Curve_List,
        nurbs_surfaces: Nurbs_Surface_List,
        nurbs_trim_surfaces: Nurbs_Trim_Surface_List,
        nurbs_trim_boundaries: Nurbs_Trim_Boundary_List,

        // Node attributes (advanced)
        procedural_geometries: Procedural_Geometry_List,
        stereo_cameras: Stereo_Camera_List,
        camera_switchers: Camera_Switcher_List,
        markers: Marker_List,
        lod_groups: Lod_Group_List,

        // Deformers
        skin_deformers: Skin_Deformer_List,
        skin_cluster: Skin_Cluster_List,
        blend_deformers: Blend_Deformer_List,
        blend_channels: Blend_Channel_List,
        blend_shapes: Blend_Shape_List,
        cache_deformers: Cache_Deformer_List,
        cache_files: Cache_File_List,

        // Materials
        materials: Material_List,
        textures: Texture_List,
        videos: Video_List,
        shaders: Shader_List,
        shader_bindings: Shader_Binding_List,

        // Animation
        anim_stacks: Anim_Stack_List,
        anim_layers: Anim_Layer_List,
        anim_values: Anim_Value_List,
        anim_curves: Anim_Curve_List,

        // Collections
        display_layers: Display_Layer_List,
        selection_sets: Selection_Set_List,
        selection_nodes: Selection_Node_List,

        // Constraints
        characters: Character_List,
        constraints: Constraint_List,

        // Miscellaneous
        poses: Pose_List,
        metadata_objects: Metadata_Object_List,
        
        // union ufbx_element_list elements_by_type[UFBX_ELEMENT_TYPE_COUNT];

	// Unique texture files referenced by the scene.
	texture_files: Texture_File_List,

	// All elements and connections in the whole file
	elements: Element_List,           // < Sorted by `id`
	connections_src: Connection_List, // < Sorted by `src,src_prop`
	connections_dst: Connection_List, // < Sorted by `dst,dst_prop`

	// Elements sorted by name, type
	elements_by_name: Name_Element_List,

	// Enabled if `ufbx_load_opts.retain_dom == true`.
	dom_root: ^Dom_Node,
}


// -- Curves

Curve_Point :: struct {
	valid: c.bool,
	position: Vec3,
	derivative: Vec3,
}

Surface_Point :: struct {
	valid: c.bool,
	position: Vec3,
	derivative_u: Vec3,
	derivative_v: Vec3,
}


// -- Mesh topology

Topo_Flag :: enum {
	NON_MANIFOLD = 0, // < Edge with three or more faces
}

Topo_Flags :: distinct bit_set[Topo_Flag; c.int]

Topo_Edge :: struct {
	index: u32, // < Starting index of the edge, always defined
	next: u32,  // < Ending index of the edge / next per-face `ufbx_topo_edge`, always defined
	prev: u32,  // < Previous per-face `ufbx_topo_edge`, always defined
	twin: u32,  // < `ufbx_topo_edge` on the opposite side, `UFBX_NO_INDEX` if not found
	face: u32,  // < Index into `mesh->faces[]`, always defined
	edge: u32,  // < Index into `mesh->edges[]`, `UFBX_NO_INDEX` if not found

	flags: Topo_Flags,
}

Vertex_Stream :: struct {
	data: rawptr,
	vertex_size: c.size_t,
}

// -- Memory callbacks

// You can optionally provide an allocator to ufbx, the default is to use the
// CRT malloc/realloc/free

// Allocate `size` bytes, must be at least 8 byte aligned
Alloc_Fn :: #type proc "c" (user: rawptr, size: c.size_t)

// Reallocate `old_ptr` from `old_size` to `new_size`
// NOTE: If omit `alloc_fn` and `free_fn` they will be translated to:
//   `alloc(size)` -> `realloc_fn(user, NULL, 0, size)`
//   `free_fn(ptr, size)` ->  `realloc_fn(user, ptr, size, 0)`
Realloc_Fn :: #type proc "c" (user: rawptr, old_ptr: rawptr, old_size: c.size_t, new_size: c.size_t)

// Free pointer `ptr` (of `size` bytes) returned by `alloc_fn` or `realloc_fn`
Free_Fn :: #type proc "c" (user: rawptr, ptr: rawptr, size: c.size_t)

// Free the allocator itself
Free_Allocator_Fn :: #type proc "c" (user: rawptr)

// Allocator callbacks and user context
// NOTE: The allocator will be stored to the loaded scene and will be called
// again from `ufbx_free_scene()` so make sure `user` outlives that!
// You can use `free_allocator_fn()` to free the allocator yourself.
Allocator :: struct {
	// Callback functions, see `typedef`s above for information
	alloc_fn: Alloc_Fn,
	realloc_fn: Realloc_Fn,
	free_fn: Free_Fn,
	free_allocator_fn: Free_Allocator_Fn,
	user: rawptr,
}

Allocator_Opts :: struct {
	// Allocator callbacks
	allocator: Allocator,

	// Maximum number of bytes to allocate before failing
	memory_limit: c.size_t,

	// Maximum number of allocations to attempt before failing
	allocation_limit: c.size_t,

	// Threshold to swap from batched allocations to individual ones
	// Defaults to 1MB if set to zero
	// NOTE: If set to `1` ufbx will allocate everything in the smallest
	// possible chunks which may be useful for debugging (eg. ASAN)
	huge_threshold: c.size_t,

	// Maximum size of a single allocation containing sub-allocations.
	// Defaults to 16MB if set to zero
	// The maximum amount of wasted memory depends on `max_chunk_size` and
	// `huge_threshold`: each chunk can waste up to `huge_threshold` bytes
	// internally and the last chunk might be incomplete. So for example
	// with the defaults we can waste around 1MB/16MB = 6.25% overall plus
	// up to 32MB due to the two incomplete blocks. The actual amounts differ
	// slightly as the chunks start out at 4kB and double in size each time,
	// meaning that the maximum fixed overhead (up to 32MB with defaults) is
	// at most ~30% of the total allocation size.
	max_chunk_size: c.size_t,
}

// -- IO callbacks

// Try to read up to `size` bytes to `data`, return the amount of read bytes.
// Return `SIZE_MAX` to indicate an IO error.
Read_Fn :: #type proc "c" (user: rawptr, data: rawptr, size: c.size_t) -> c.size_t

// Skip `size` bytes in the file.
Skip_Fn :: #type proc "c" (user: rawptr, size: c.size_t) -> c.bool

// Close the file
Close_Fn :: #type proc "c" (user: rawptr)

Stream :: struct {
	read_fn: Read_Fn,   // < Required
	skip_fn: Skip_Fn,   // < Optional: Will use `read_fn()` if missing
	close_fn: Close_Fn, // < Optional

	// Context passed to other functions
	user: rawptr,
}

Open_File_Type :: enum c.int {
	MAIN_MODEL,     // < Main model file
	GEOMETRY_CACHE, // < Unknown geometry cache file
	OBJ_MTL,        // < .mtl material library file
}

Open_File_Info :: struct {
	// Kind of file to load.
	type: Open_File_Type,

	// Temporary allocator to use.
	temp_allocator: Allocator,

	// Original filename in the file, not resolved or UTF-8 encoded.
	// NOTE: Not necessarily NULL-terminated!
	original_filename: Blob,
}

// Callback for opening an external file from the filesystem
Open_File_Fn :: #type proc "c" (
        user: rawptr, stream: ^Stream, path: cstring, path_len: c.size_t, info: ^Open_File_Info) -> c.bool

Open_File_Cb :: struct {
	fn: Open_File_Fn,
	user: rawptr,
}

// Memory stream options
Close_Memory_Fn :: #type proc "c" (user: rawptr, data: rawptr, data_size: c.size_t)

Close_Memory_Cb :: struct {
        fn: Close_Memory_Fn,
        user: rawptr,
}

// Options for `ufbx_open_memory()`.
Open_Memory_Opts :: struct {
	_begin_zero: u32,

	// Allocator to allocate the memory with.
	// NOTE: Used even if no copy is made to allocate a small metadata block.
	allocator: Allocator_Opts,

	// Do not copy the memory.
	// You can use `close_cb` to free the memory when the stream is closed.
	// NOTE: This means the provided data pointer is referenced after creating
	// the memory stream, make sure the data stays valid until the stream is closed!
	no_copy: c.bool,

	// Callback to free the memory blob.
	close_cb: Close_Memory_Cb,

	_end_zero: u32,
}

// Detailed error stack frame
Error_Frame :: struct {
	source_line: u32,
	function: String,
	description: String,
}

// Error causes (and `UFBX_ERROR_NONE` for no error).
Error_Type :: enum c.int {
	// No error, operation has been performed successfully.
	NONE,

	// Unspecified error, most likely caused by an invalid FBX file or a file
	// that contains something ufbx can't handle.
	UNKNOWN,

	// File not found.
	FILE_NOT_FOUND,

	// Out of memory (allocator returned `NULL`).
	OUT_OF_MEMORY,

	// `ufbx_allocator_opts.memory_limit` exhausted.
	MEMORY_LIMIT,

	// `ufbx_allocator_opts.allocation_limit` exhausted.
	ALLOCATION_LIMIT,

	// File ended abruptly.
	TRUNCATED_FILE,

	// IO read error.
	// eg. returning `SIZE_MAX` from `ufbx_stream.read_fn` or stdio `ferror()` condition.
	IO,

	// User cancelled the loading via `ufbx_load_opts.progress_cb` returning `UFBX_PROGRESS_CANCEL`.
	CANCELLED,

	// Could not detect file format from file data or filename.
	// HINT: You can supply it manually using `ufbx_load_opts.file_format` or use `ufbx_load_opts.filename`
	// when using `ufbx_load_memory()` to let ufbx guess the format from the extension.
	UNRECOGNIZED_FILE_FORMAT,

	// Options struct (eg. `ufbx_load_opts`) is not cleared to zero.
	// Make sure you initialize the structure to zero via eg.
	//   ufbx_load_opts opts = { 0 }; // C
	//   ufbx_load_opts opts = { }; // C++
	UNINITIALIZED_OPTIONS,

	// The vertex streams in `ufbx_generate_indices()` are empty.
	ZERO_VERTEX_SIZE,

	// Invalid UTF-8 encountered in a file when loading with `UFBX_UNICODE_ERROR_HANDLING_ABORT_LOADING`.
	INVALID_UTF8,

	// Feature needed for the operation has been compiled out.
	FEATURE_DISABLED,

	// Attempting to tessellate an invalid NURBS object.
	// See `ufbx_nurbs_basis.valid`.
	BAD_NURBS,

	// Out of bounds index in the file when loading with `UFBX_INDEX_ERROR_HANDLING_ABORT_LOADING`.
	BAD_INDEX,

	// Unsafe options specified without enabling `ufbx_load_opts.allow_unsafe`.
	UNSAFE_OPTIONS,
}

Error_Stack_Max_Depth :: 8
Error_Info_Length :: 256

// Error description with detailed stack trace
// HINT: You can use `ufbx_format_error()` for formatting the error
Error :: struct {
	type: Error_Type,
	description: String,
	stack_size: u32,
	stack: [Error_Stack_Max_Depth]Error_Frame,
	info_length: c.size_t,
	info: [Error_Info_Length]c.char,
}

// -- Progress callbacks

Progress :: struct {
	bytes_read: u64,
	bytes_total: u64,
}

Progress_Result :: enum c.int {
	CONTINUE = 0x100,
	CANCEL = 0x200,
}

// Called periodically with the current progress
// Return `false` to cancel further processing
Progress_Fn :: #type proc "c" (user: rawptr, progress: ^Progress) -> Progress_Result

Progress_Cb :: struct {
	fn: Progress_Fn,
	user: rawptr,
}

// -- Inflate

// Source data/stream to decompress with `ufbx_inflate()`
Inflate_Input :: struct {
	// Total size of the data in bytes
	total_size: c.size_t,

	// (optional) Initial or complete data chunk
	data: rawptr,
	data_size: c.size_t,

	// (optional) Temporary buffer, defaults to 256b stack buffer
	buffer: rawptr,
	buffer_size: c.size_t,

	// (optional) Streaming read function, concatenated after `data`
	read_fn: Read_Fn,
	read_user: rawptr,

	// (optional) Progress reporting
	progress_cb: Progress_Cb,
	progress_interval_hint: u64, // < Bytes between progress report calls

	// (optional) Change the progress scope
	progress_size_before: u64,
	progress_size_after: u64,

	// (optional) No the DEFLATE header
	no_header: c.bool,

	// (optional) No the Adler32 checksum
	no_checksum: c.bool,

	// (optional) Force internal fast lookup bit amount
	internal_fast_bits: c.size_t,
}

// Persistent data between `ufbx_inflate()` calls
// NOTE: You must set `initialized` to `false`, but `data` may be uninitialized
Inflate_Retain :: struct {
	initialized: c.bool,
	data: [1024]u64,
}

Index_Error_Handling :: enum c.int {
	// Clamp to a valid value.
	CLAMP,
	// Set bad indices to `UFBX_NO_INDEX`.
	// This is the recommended way if you need to deal with files with gaps in information.
	// HINT: If you use this `ufbx_get_vertex_TYPE()` functions will return zero
	// on invalid indices instead of failing.
	NO_INDEX,
	// Fail loading entierely when encountering a bad index.
	ABORT_LOADING,
	// Pass bad indices through as-is.
	// Requires `ufbx_load_opts.allow_unsafe`.
	// UNSAFE: Breaks any API guarantees regarding indexes being in bounds and makes
	// `ufbx_get_vertex_TYPE()` memory-unsafe to use.
	UNSAFE_IGNORE,
}

Unicode_Error_Handling :: enum c.int {
	// Replace errors with U+FFFD "Replacement Character"
	REPLACEMENT_CHARACTER,
	// Replace errors with '_' U+5F "Low Line"
	UNDERSCORE,
	// Replace errors with '?' U+3F "Question Mark"
	QUESTION_MARK,
	// Remove errors from the output
	REMOVE,
	// Fail loading on encountering an Unicode error
	ABORT_LOADING,
	// Ignore and pass-through non-UTF-8 string data.
	// Requires `ufbx_load_opts.allow_unsafe`.
	// UNSAFE: Breaks API guarantee that `ufbx_string` is UTF-8 encoded.
	UNSAFE_IGNORE,
}

// How to handle FBX node geometry transforms.
// FBX nodes can have "geometry transforms" that affect only the attached meshes,
// but not the children. This is not allowed in many scene representations so
// ufbx provides some ways to simplify them.
// Geometry transforms can also be used to transform any other attributes such
// as lights or cameras.
Geometry_Transform_Handling :: enum c.int {
	// Preserve the geometry transforms as-is.
	// To be correct for all files you have to use `ufbx_node.geometry_transform`,
	// `ufbx_node.geometry_to_node`, or `ufbx_node.geometry_to_world` to compensate
	// for any potential geometry transforms.
	PRESERVE,

	// Add helper nodes between the nodes and geometry where needed.
	// The created nodes have `ufbx_node.is_geometry_transform_helper` set and are
	// named `ufbx_load_opts.geometry_transform_helper_name`.
	HELPER_NODES,

	// Modify the geometry of meshes attached to nodes with geometry transforms.
	// Will add helper nodes like `HELPER_NODES` if
	// necessary, for example if there are multiple instances of the same mesh with
	// geometry transforms.
	MODIFY_GEOMETRY,

	// Modify the geometry of meshes attached to nodes with geometry transforms.
	// NOTE: This will not work correctly for instanced geometry.
	MODIFY_GEOMETRY_NO_FALLBACK,
}

// Specify how unit / coordinate system conversion should be performed.
// Affects how `ufbx_load_opts.target_axes` and `ufbx_load_opts.target_unit_meters` work,
// has no effect if neither is specified.
Space_Conversion :: enum c.int {
	// Store the space conversion transform in the root node.
	// Sets `ufbx_node.local_transform` of the root node.
	TRANSFORM_ROOT,

	// Perform the conversion by using "adjust" transforms.
	// Compensates for the transforms using `ufbx_node.adjust_pre_rotation` and
	// `ufbx_node.adjust_pre_scale`. You don't need to account for these unless
	// you are manually building transforms from `ufbx_props`.
	ADJUST_TRANSFORMS,
}

// -- Main API

// Options for `ufbx_load_file/memory/stream/stdio()`
// NOTE: Initialize to zero with `{ 0 }` (C) or `{ }` (C++)
Load_Opts :: struct {
	_begin_zero: u32,

	temp_allocator: Allocator_Opts,   // < Allocator used during loading
	result_allocator: Allocator_Opts, // < Allocator used for the final scene

	// Preferences
	ignore_geometry: c.bool,    // < Do not load geometry datsa (vertices, indices, etc)
	ignore_animation: c.bool,   // < Do not load animation curves
	ignore_embedded: c.bool,    // < Do not load embedded content
	ignore_all_content: c.bool, // < Do not load any content (geometry, animation, embedded)

	evaluate_skinning: c.bool, // < Evaluate skinning (see ufbx_mesh.skinned_vertices)
	evaluate_caches: c.bool,   // < Evaluate vertex caches (see ufbx_mesh.skinned_vertices)

	// Try to open external files referenced by the main file automatically.
	// Applies to geometry caches and .mtl files for OBJ.
	// NOTE: This may be risky for untrusted data as the input files may contain
	// references to arbitrary paths in the filesystem.
	// NOTE: This only applies to files *implicitly* referenced by the scene, if
	// you request additional files via eg. `ufbx_load_opts.obj_mtl_path` they
	// are still loaded.
	load_external_files: c.bool,

	// Don't fail loading if external files are not found.
	ignore_missing_external_files: c.bool,

	// Don't compute `ufbx_skin_deformer` `vertices` and `weights` arrays saving
	// a bit of memory and time if not needed
	skip_skin_vertices: c.bool,

	// Clean-up skin weights by removing negative, zero and NAN weights.
	clean_skin_weights: c.bool,

	// Don't adjust reading the FBX file depending on the detected exporter
	disable_quirks: c.bool,

	// Don't allow partially broken FBX files to load
	strict: c.bool,

	// UNSAFE: If enabled allows using unsafe options that may fundamentally
	// break the API guarantees.
	allow_unsafe: c.bool,

	// Specify how to handle broken indices.
	index_error_handling: Index_Error_Handling,

	// Connect related elements even if they are broken. If `false` (default)
	// `ufbx_skin_cluster` with a missing `bone` field are _not_ included in
	// the `ufbx_skin_deformer.clusters[]` array for example.
	connect_broken_elements: c.bool,

	// Allow nodes that are not connected in any way to the root. Conversely if
	// disabled, all lone nodes will be parented under `ufbx_scene.root_node`.
	allow_nodes_out_of_root: c.bool,

	// If a mesh does not have a material create a `ufbx_mesh_material` part
	// with a `NULL` material pointer. This can be more convenient if you need
	// to split models into parts per material.
	allow_null_material: c.bool,

	// Allow meshes with no vertex position attribute.
	// NOTE: If this is set `ufbx_mesh.vertex_position.exists` may be `false`.
	allow_missing_vertex_position: c.bool,

	// Allow faces with zero indices.
	allow_empty_faces: c.bool,

	// Generate vertex normals for a meshes that are missing normals.
	// You can see if the normals have been generated from `ufbx_mesh.generated_normals`.
	generate_missing_normals: c.bool,

	// Ignore `open_file_cb` when loading the main file.
	open_main_file_with_default: c.bool,

	// Path separator character, defaults to '\' on Windows and '/' otherwise.
	path_separator: c.char,

	// Estimated file size for progress reporting
	file_size_estimate: u64,

	// Buffer size in bytes to use for reading from files or IO callbacks
	read_buffer_size: c.size_t,

	// Filename to use as a base for relative file paths if not specified using
	// `ufbx_load_file()`. Use `length = SIZE_MAX` for NULL-terminated strings.
	// `raw_filename` will be derived from this if empty.
	filename: String,

	// Raw non-UTF8 filename. Does not support NULL termination.
	// `filename` will be derived from this if empty.
	raw_filename: Blob,

	// Progress reporting
	progress_cb: Progress_Cb,
	progress_interval_hint: u64, // < Bytes between progress report calls

	// External file callbacks (defaults to stdio.h)
	open_file_cb: Open_File_Cb,

	// How to handle geometry transforms in the nodes.
	// See `ufbx_geometry_transform_handling` for an explanation.
	geometry_transform_handling: Geometry_Transform_Handling,

	// How to perform space conversion by `target_axes` and `target_unit_meters`.
	// See `ufbx_space_conversion` for an explanation.
	space_conversion: Space_Conversion,

	// Apply an implicit root transformation to match axes.
	// Used if `ufbx_coordinate_axes_valid(target_axes)`.
	target_axes: Coordinate_Axes,

	// Scale the scene so that one world-space unit is `target_unit_meters` meters.
	// By default units are not scaled.
	target_unit_meters: Real,

	// Target space for camera.
	// By default FBX cameras point towards the positive X axis.
	// Used if `ufbx_coordinate_axes_valid(target_camera_axes)`.
	target_camera_axes: Coordinate_Axes,

	// Target space for directed lights.
	// By default FBX lights point towards the negative Y axis.
	// Used if `ufbx_coordinate_axes_valid(target_light_axes)`.
	target_light_axes: Coordinate_Axes,

	// Name for dummy geometry transform helper nodes.
	// See `UFBX_GEOMETRY_TRANSFORM_HANDLING_HELPER_NODES`.
	geometry_transform_helper_name: String,

	// Do not scale necessary properties curves with `target_unit_meters`.
	// Used only if `space_conversion == UFBX_SPACE_CONVERSION_TRANSFORM_ROOT`.
	no_prop_unit_scaling: c.bool,

	// Do not scale necessary animation curves with `target_unit_meters`.
	// Used only if `space_conversion == UFBX_SPACE_CONVERSION_TRANSFORM_ROOT`.
	no_anim_curve_unit_scaling: c.bool,

	// Normalize vertex normals.
	normalize_normals: c.bool,

	// Normalize tangents and bitangents.
	normalize_tangents: c.bool,

	// Override for the root transform
	use_root_transform: c.bool,
	root_transform: Transform,

	// Specify how to handle Unicode errors in strings.
	unicode_error_handling: Unicode_Error_Handling,

	// Retain the raw document structure using `ufbx_dom_node`.
	retain_dom: c.bool,

	// Force a specific file format instead of detecting it.
	file_format: File_Format,

	// How far to read into the file to determine the file format.
	// Default: 16kB
	file_format_lookahead: c.size_t,

	// Do not attempt to detect file format from file content.
	no_format_from_content: c.bool,

	// Do not attempt to detect file format from filename extension.
	// ufbx primarily detects file format from the file header,
	// this is just used as a fallback.
	no_format_from_extension: c.bool,

	// (.obj) Try to find .mtl file with matching filename as the .obj file.
	// Used if the file specified `mtllib` line is not found, eg. for a file called
	// `model.obj` that contains the line `usemtl materials.mtl`, ufbx would first
	// try to open `materials.mtl` and if that fails it tries to open `model.mtl`.
	obj_search_mtl_by_filename: c.bool,

	// (.obj) Don't split geometry into meshes by object.
	obj_merge_objects: c.bool,

	// (.obj) Don't split geometry into meshes by groups.
	obj_merge_groups: c.bool,

	// (.obj) Force splitting groups even on object boundaries.
	obj_split_groups: c.bool,

	// (.obj) Path to the .mtl file.
	// Use `length = SIZE_MAX` for NULL-terminated strings.
	// NOTE: This is used _instead_ of the one in the file even if not found
	// and sidesteps `load_external_files` as it's _explicitly_ requested.
	obj_mtl_path: String,

	// (.obj) Data for the .mtl file.
	obj_mtl_data: Blob,

	_end_zero: u32,
}

// Options for `ufbx_evaluate_scene()`
// NOTE: Initialize to zero with `{ 0 }` (C) or `{ }` (C++)
Evaluate_Opts :: struct {
	_begin_zero: u32,

	temp_allocator: Allocator_Opts,   // < Allocator used during evaluation
	result_allocator: Allocator_Opts, // < Allocator used for the final scene

	evaluate_skinning: c.bool, // < Evaluate skinning (see ufbx_mesh.skinned_vertices)
	evaluate_caches: c.bool,   // < Evaluate vertex caches (see ufbx_mesh.skinned_vertices)

	// WARNING: Potentially unsafe! Try to open external files such as geometry caches
	load_external_files: c.bool,

	// External file callbacks (defaults to stdio.h)
	open_file_cb: Open_File_Cb,

	_end_zero: u32,
}

// Options for `ufbx_tessellate_nurbs_curve()`
// NOTE: Initialize to zero with `{ 0 }` (C) or `{ }` (C++)
Tessellate_Curve_Opts :: struct {
	_begin_zero: u32,

	temp_allocator: Allocator_Opts,   // < Allocator used during tessellation
	result_allocator: Allocator_Opts, // < Allocator used for the final line curve

	// How many segments tessellate each step in `ufbx_nurbs_basis.steps`.
	span_subdivision: u32,

	_end_zero: u32,
}

// Options for `ufbx_tessellate_nurbs_surface()`
// NOTE: Initialize to zero with `{ 0 }` (C) or `{ }` (C++)
Tessellate_Surface_Opts :: struct {
	_begin_zero: u32,

	temp_allocator: Allocator_Opts,   // < Allocator used during tessellation
	result_allocator: Allocator_Opts, // < Allocator used for the final mesh

	// How many segments tessellate each step in `ufbx_nurbs_basis.steps`.
	// NOTE: Default is `4`, _not_ `ufbx_nurbs_surface.span_subdivision_u/v` as that
	// would make it easy to create an FBX file with an absurdly high subdivision
	// rate (similar to mesh subdivision). Please enforce copy the value yourself
	// enforcing whatever limits you deem reasonable.
	span_subdivision_u: u32,
	span_subdivision_v: u32,

	_end_zero: u32,
}

// Options for `ufbx_subdivide_mesh()`
// NOTE: Initialize to zero with `{ 0 }` (C) or `{ }` (C++)
Subdivide_Opts :: struct {
	_begin_zero: u32,

	temp_allocator: Allocator_Opts,   // < Allocator used during subdivision
	result_allocator: Allocator_Opts, // < Allocator used for the final mesh

	boundary: Subdivision_Boundary,
	uv_boundary: Subdivision_Boundary,

	// Do not generate normals
	ignore_normals: c.bool,

	// Interpolate existing normals using the subdivision rules
	// instead of generating new normals
	interpolate_normals: c.bool,

	// Subdivide also tangent attributes
	interpolate_tangents: c.bool,

	// Map subdivided vertices into weighted original vertices.
	// NOTE: May be O(n^2) if `max_source_vertices` is not specified!
	evaluate_source_vertices: c.bool,

	// Limit source vertices per subdivided vertex.
	max_source_vertices: c.size_t,

	// Calculate bone influences over subdivided vertices (if applicable).
	// NOTE: May be O(n^2) if `max_skin_weights` is not specified!
	evaluate_skin_weights: c.bool,

	// Limit bone influences per subdivided vertex.
	max_skin_weights: c.size_t,

	// Index of the skin deformer to use for `evaluate_skin_weights`.
	skin_deformer_index: c.size_t,

	_end_zero: u32,
}

// Options for `ufbx_load_geometry_cache()`
// NOTE: Initialize to zero with `{ 0 }` (C) or `{ }` (C++)
Geometry_Cache_Opts :: struct {
	_begin_zero: u32,

	temp_allocator: Allocator_Opts,   // < Allocator used during loading
	result_allocator: Allocator_Opts, // < Allocator used for the final scene

	// External file callbacks (defaults to stdio.h)
	open_file_cb: Open_File_Cb,

	// FPS value for converting frame times to seconds
	frames_per_second: f64,

	_end_zero: u32,
}

// Options for `ufbx_read_geometry_cache_*()`
// NOTE: Initialize to zero with `{ 0 }` (C) or `{ }` (C++)
Geometry_Cache_Data_Opts :: struct {
	_begin_zero: u32,

	// External file callbacks (defaults to stdio.h)
	open_file_cb: Open_File_Cb,

	additive: c.bool,
	use_weight: c.bool,
	weight: Real,

	_end_zero: u32,
}

Panic_Message_Length :: 128

Panic :: struct {
	did_panic: c.bool,
	message_length: c.size_t,
	message: [Panic_Message_Length]c.char,
}

when ODIN_OS == .Linux {
	foreign import ufbx_lib "ufbx.a"
}
when ODIN_OS == .Darwin {
	foreign import ufbx_lib "ufbx.dylib"
}
when ODIN_OS == .Windows {
	foreign import ufbx_lib "ufbx.lib"
}

@(default_calling_convention="c")
@(link_prefix="ufbx_")
foreign ufbx_lib {
// Practically always `true` (see below), if not you need to be careful with threads.
//
// Guaranteed to be `true` in _any_ of the following conditions:
// - ufbx.c has been compiled using: GCC / Clang / MSVC / ICC / EMCC / TCC
// - ufbx.c has been compiled as C++11 or later
// - ufbx.c has been compiled as C11 or later with `<stdatomic.h>` support
//
// If `false` you can't call the following functions concurrently:
//   ufbx_evaluate_scene()
//   ufbx_free_scene()
//   ufbx_subdivide_mesh()
//   ufbx_tessellate_nurbs_surface()
//   ufbx_free_mesh()
is_thread_safe :: proc() -> c.bool ---

// Load a scene from a `size` byte memory buffer at `data`
load_memory :: proc(data: rawptr, data_size: c.size_t, opts: ^Load_Opts, error: ^Error) -> ^Scene ---

// Load a scene by opening a file named `filename`
load_file :: proc(filename: cstring, opts: ^Load_Opts, error: ^Error) -> ^Scene ---
load_file_len :: proc(filename: cstring, filename_len: c.size_t, opts: ^Load_Opts, error: ^Error) -> ^Scene ---

// Load a scene by reading from an `FILE *file` stream
// NOTE: `file` is passed as a `void` pointer to avoid including <stdio.h>
load_stdio :: proc(file: rawptr, opts: ^Load_Opts, error: ^Error) -> ^Scene ---

// Load a scene by reading from an `FILE *file` stream with a prefix
// NOTE: `file` is passed as a `void` pointer to avoid including <stdio.h>
load_stdio_prefix :: proc(file: rawptr, prefix: rawptr, prefix_size: c.size_t, opts: ^Load_Opts, error: ^Error) -> ^Scene ---

// Load a scene from a user-specified stream
load_stream :: proc(stream: ^Stream, opts: ^Load_Opts, error: ^Error) -> ^Scene ---

// Load a scene from a user-specified stream with a prefix
load_stream_prefix :: proc(stream: ^Stream, prefix: rawptr, prefix_size: c.size_t, opts: ^Load_Opts, error: ^Error) -> ^Scene ---

// Free a previously loaded or evaluated scene
free_scene :: proc(scene: ^Scene) ---

// Increment `scene` refcount
retain_scene :: proc(scene: ^Scene) ---

// Format a textual description of `error`.
// Always produces a NULL-terminated string to `char dst[dst_size]`, truncating if
// necessary. Returns the number of characters written not including the NULL terminator.
format_error :: proc(dst: cstring, dst_size: c.size_t, error: ^Error) -> c.size_t ---

// Query

// Find a property `name` from `props`, returns `NULL` if not found.
// Searches through `ufbx_props.defaults` as well.
find_prop_len :: proc(props: ^Props, name: cstring, name_len: c.size_t) -> Prop ---

// Utility functions for finding the value of a property, returns `def` if not found.
// NOTE: For `ufbx_string` you need to ensure the lifetime of the default is
// sufficient as no copy is made.
find_real_len :: proc(props: ^Props, name : cstring, name_len: c.size_t, def: Real) -> Real ---
find_vec3_len :: proc(props: ^Props, name : cstring, name_len: c.size_t, def: Vec3) -> Vec3 ---
find_int_len :: proc(props: ^Props, name : cstring, name_len: c.size_t, def: i64) -> i64 ---
find_bool_len :: proc(props: ^Props, name : cstring, name_len: c.size_t, def: c.bool) -> c.bool ---
find_string_len :: proc(props: ^Props, name : cstring, name_len: c.size_t, def: String) -> String ---
find_blob_len :: proc(props: ^Props, name : cstring, name_len: c.size_t, def: Blob) -> Blob ---

// Find property in `props` with concatendated `parts[num_parts]`.
find_prop_concat :: proc(props: ^Props, parts: [^]String, num_parts: c.size_t) -> ^Prop ---

// Get an element connected to a property.
get_prop_element :: proc(element: ^Element, prop: ^Prop, type: Element_Type) -> ^Element ---

// Find any element of type `type` in `scene` by `name`.
// For example if you want to find `ufbx_material` named `Mat`:
//   (ufbx_material*)ufbx_find_element(scene, UFBX_ELEMENT_MATERIAL, "Mat");
find_element_len :: proc(scene: ^Scene, type: Element_Type, name: cstring, name_len: c.size_t) -> ^Element ---

// Find node in `scene` by `name` (shorthand for `ufbx_find_element(UFBX_ELEMENT_NODE)`).
find_node_len :: proc(scene: ^Scene, name: cstring, name_len: c.size_t) -> ^Node ---

// Find an animation stack in `scene` by `name` (shorthand for `ufbx_find_element(UFBX_ELEMENT_ANIM_STACK)`)
find_anim_stack_len :: proc(scene: ^Scene, name: cstring, name_len: c.size_t) -> ^Anim_Stack ---

// Find a material in `scene` by `name` (shorthand for `ufbx_find_element(UFBX_ELEMENT_MATERIAL)`).
find_material_len :: proc(scene: ^Scene, name: cstring, name_len: c.size_t) -> ^Material ---

// Find a single animated property `prop` of `element` in `layer`.
// Returns `NULL` if not found.
find_anim_prop_len :: proc(layer: ^Anim_Layer, element: ^Element, prop: cstring, prop_len: c.size_t) -> ^Anim_Prop ---

// Find all animated properties of `element` in `layer`.
find_anim_props :: proc(layer: ^Anim_Layer, element: ^Element) -> Anim_Prop_List ---

// Get a matrix that transforms normals in the same way as Autodesk software.
// NOTE: The resulting normals are slightly incorrect as this function deliberately
// inverts geometric transformation wrong. For better results use
// `ufbx_matrix_for_normals(&node->geometry_to_world)`.
get_compatible_matrix_for_normals :: proc(node: ^Node) -> Matrix ---

// Utility

// Decompress a DEFLATE compressed buffer.
// Returns the decompressed size or a negative error code (see source for details).
// NOTE: You must supply a valid `retain` with `ufbx_inflate_retain.initialized == false`
// but the rest can be uninitialized.
inflate :: proc(dst: rawptr, dst_size: c.size_t, input: ^Inflate_Input, retain: ^Inflate_Retain) -> c.ptrdiff_t ---

// Open a `ufbx_stream` from a file.
// Use `path_len == SIZE_MAX` for NULL terminated string.
open_file :: proc(stream: ^Stream, path: cstring, path_len: c.size_t) -> c.bool ---

// Same as `ufbx_open_file()` but compatible with the callback in `ufbx_open_file_fn`.
// The `user` parameter is actually not used here.
default_open_file :: proc(user: rawptr, stream: ^Stream, path: cstring, path_len: c.size_t, info: ^Open_File_Info) -> c.bool ---

// NOTE: Uses the default ufbx allocator!
open_memory :: proc(stream: ^Stream, data: rawptr, data_size: c.size_t, opts: ^Open_Memory_Opts, error: ^Error) -> c.bool ---

// Animation evaluation

// Evaluate a single animation `curve` at a `time`.
// Returns `default_value` only if `curve == NULL` or it has no keyframes.
evaluate_curve :: proc(curve: ^Anim_Curve, time: f64, default_value: Real) -> Real ---

// Evaluate a value from bundled animation curves.
evaluate_anim_value_real :: proc(anim_value: ^Anim_Value, time: f64) -> Real ---
evaluate_anim_value_vec2 :: proc(anim_value: ^Anim_Value, time: f64) -> Vec2 ---
evaluate_anim_value_vec3 :: proc(anim_value: ^Anim_Value, time: f64) -> Vec3 ---

// Evaluate an animated property `name` from `element` at `time`.
// NOTE: If the property is not found it will have the flag `UFBX_PROP_FLAG_NOT_FOUND`.
evaluate_prop_len :: proc(anim: ^Anim, element: ^Element, name: cstring, name_len: c.size_t, time: f64) -> Prop ---

// Evaluate all _animated_ properties of `element`.
// HINT: This function returns an `ufbx_props` structure with the original properties as
// `ufbx_props.defaults`. This lets you use `ufbx_find_prop/value()` for the results.
evaluate_props :: proc(anim: ^Anim, element: ^Element, time: f64, buffer: [^]Prop, buffer_size: c.size_t) -> Props ---

evaluate_transform :: proc(anim: ^Anim, node: ^Node, time: f64) -> Transform ---
evaluate_blend_weight :: proc(anim: ^Anim, channel: ^Blend_Channel, time: f64) -> Real ---

prepare_prop_overrides :: proc(overrides: [^]Prop_Override, num_overrides: c.size_t) -> Prop_Override_List ---

// Evaluate the whole `scene` at a specific `time` in the animation `anim`.
// The returned scene behaves as if it had been exported at a specific time
// in the specified animation, except that animated elements' properties contain
// only the animated values, the original ones are in `props->defaults`.
//
// NOTE: The returned scene refers to the original `scene` so the original
// scene cannot be freed until all evaluated scenes are freed.
evaluate_scene :: proc(scene: ^Scene, anim: ^Anim, time: f64, opts: ^Evaluate_Opts, error: ^Error) -> ^Scene ---

// Materials
find_prop_texture_len :: proc(material: ^Material, name: cstring, name_len: c.size_t) -> ^Texture ---

find_shader_prop_len :: proc(shader: ^Shader, name: cstring, name_len: c.size_t) -> String ---

find_shader_prop_bindings_len :: proc(shader: ^Shader, name: cstring, name_len: c.size_t) -> Shader_Prop_Binding_List ---

find_shader_texture_input_len :: proc(shader: ^Shader, name: cstring, name_len: c.size_t) -> Shader_Texture_Input ---

// Math

coordinate_axes_valid :: proc(axes: Coordinate_Axes) -> c.bool ---

quat_dot :: proc(a: Quat, b: Quat) -> Real ---
quat_mul :: proc(a: Quat, b: Quat) -> Quat ---
quat_normalize :: proc(q: Quat) -> Quat ---
quat_fix_antipodal :: proc(q: Quat, reference: Quat) -> Quat ---
quat_slerp :: proc(a: Quat, b: Quat, t: Real) -> Quat ---
quat_rotate_vec3 :: proc(q: Quat, v: Vec3) -> Vec3 ---
quat_to_euler :: proc(q: Quat, order: Rotation_Order) -> Vec3 ---
euler_to_quat :: proc(v: Vec3, order: Rotation_Order) -> Quat ---

matrix_mul :: proc(a: ^Matrix, b: ^Matrix) -> Matrix ---
matrix_determinant :: proc(m: ^Matrix) -> Real ---
matrix_invert :: proc(m: ^Matrix) -> Matrix ---
matrix_for_normals :: proc(m: ^Matrix) -> Matrix ---
transform_position :: proc(m: ^Matrix, v: Vec3) -> Vec3 ---
transform_direction :: proc(m: ^Matrix, v: Vec3) ->  Vec3 ---
transform_to_matrix :: proc(t: ^Transform) -> Matrix ---
matrix_to_transform :: proc(m: ^Matrix) -> Transform ---

// Skinning

catch_get_skin_vertex_matrix :: proc(panic: ^Panic, skin: ^Skin_Deformer, vertex: c.size_t, fallback: ^Matrix) -> Matrix ---

get_blend_shape_vertex_offset :: proc(shape: ^Blend_Shape, vertex: c.size_t) -> Vec3 ---
get_blend_vertex_offset :: proc(blend: ^Blend_Deformer, vertex: c.size_t) -> Vec3 ---

add_blend_shape_vertex_offsets :: proc(shape: ^Blend_Shape, vertices: [^]Vec3, num_vertices: c.size_t, weight: Real) ---
add_blend_vertex_offsets :: proc(blend: ^Blend_Deformer, vertices: [^]Vec3, num_vertices: c.size_t, weight: Real) ---

// Curves/surfaces
evaluate_nurbs_basis :: proc(basis: ^Nurbs_Basis, u: Real, weights: [^]Real, num_weights: c.size_t, derivatives: [^]Real, num_derivates: c.size_t) -> c.size_t ---

evaluate_nurbs_curve :: proc(curve: ^Nurbs_Curve, u: Real) -> Curve_Point ---
evalaute_nurbs_surface :: proc(surface: ^Nurbs_Surface, u: Real, v: Real) -> Surface_Point ---

tessellate_nurbs_curve :: proc(curve: ^Nurbs_Curve, opts: ^Tessellate_Curve_Opts, error: ^Error) -> Line_Curve ---
tessellate_nurbs_surface :: proc(surface: ^Nurbs_Surface, opts: ^Tessellate_Surface_Opts, error: ^Error) -> Mesh ---

free_line_curve :: proc(curve: ^Line_Curve) ---
retain_line_curve :: proc(curve: ^Line_Curve) ---

// Mesh Topology

catch_triangulate_face :: proc(panic: ^Panic, indices: [^]u32, num_indices: c.size_t, mesh: ^Mesh, face: Face) -> u32 ---

// Generate the half-edge representation of `mesh` to `topo[mesh->num_indices]`
catch_compute_topology :: proc(panic: ^Panic, mesh: ^Mesh, topo: [^]Topo_Edge, num_topo: c.size_t) ---

// Get the next/previous edge around a vertex
// NOTE: Does not return the half-edge on the opposite side (ie. `topo[index].twin`)
catch_topo_next_vertex_edge :: proc(panic: ^Panic, topo: [^]Topo_Edge, num_topo: c.size_t, index: u32) -> u32 ---

catch_topo_prev_vertex_edge :: proc(panic: ^Panic, topo: [^]Topo_Edge, num_topo: c.size_t, index: u32) -> u32 ---

catch_get_weighted_face_normal :: proc(panic: ^Panic, positions: [^]Vec3, face: Face) -> Vec3 ---

catch_generate_normal_mapping :: proc(panic: ^Panic, mesh: ^Mesh, topo: [^]Topo_Edge, num_topo: c.size_t, normal_indices: [^]u32, num_normal_indices: c.size_t, assume_smooth: c.bool) -> c.size_t ---
generate_normal_mapping :: proc(mesh: ^Mesh, topo: [^]Topo_Edge, num_topo: c.size_t, normal_indices: [^]u32, num_normal_indices: c.size_t, assume_smooth: c.bool) -> c.size_t ---

catch_compute_normals :: proc(panic: ^Panic, mesh: ^Mesh, positions: [^]Vec3, normal_indices: [^]u32, num_normal_indices: c.size_t, normals: [^]Vec3, num_normals: c.size_t) ---
compute_normals :: proc(mesh: ^Mesh, positions: [^]Vec3, normal_indices: [^]u32, num_normal_indices: c.size_t, normals: [^]Vec3, num_normals: c.size_t) ---

subdivide_mesh :: proc(mesh: ^Mesh, level: c.size_t, opts: ^Subdivide_Opts, error: ^Error) -> ^Mesh ---

free_mesh :: proc(mesh: ^Mesh) ---
retain_mesh :: proc(mesh: ^Mesh) ---

// Geometry caches

load_geometry_cache :: proc(filename: cstring, opts: ^Geometry_Cache_Opts, error: ^Error) -> ^Geometry_Cache ---
load_geometry_cache_len :: proc(filename: cstring, filename_len: c.size_t, opts: ^Geometry_Cache_Opts, error: ^Error) -> ^Geometry_Cache ---

free_geometry_cache :: proc(cache: ^Geometry_Cache) ---
retain_geometry_cache :: proc(cache: ^Geometry_Cache) ---

read_geometry_cache_real :: proc(frame: ^Cache_Frame, data: [^]Real, num_data: c.size_t, opts: ^Geometry_Cache_Data_Opts) -> c.size_t ---
sample_geometry_cache_real :: proc(channel: ^Cache_Channel, time: f64, data: [^]Real, num_data: c.size_t, opts: ^Geometry_Cache_Data_Opts) -> c.size_t ---
read_geometry_cache_vec3 :: proc(frame: ^Cache_Frame, data: [^]Vec3, num_data: c.size_t, opts: ^Geometry_Cache_Data_Opts) -> c.size_t ---
sample_geometry_cache_vec3 :: proc(channel: ^Cache_Channel, time: f64, data: [^]Vec3, num_data: c.size_t, opts: ^Geometry_Cache_Data_Opts) -> c.size_t ---

// DOM

dom_find_len :: proc(parent: ^Dom_Node, name: cstring, name_len: c.size_t) -> ^Dom_Node ---

// Utility

generate_indices :: proc(streams: [^]Vertex_Stream, num_streams: c.size_t, indices: [^]u32, num_indices: c.size_t, allocator: ^Allocator_Opts, error: ^Error) -> c.size_t ---

// -- Inline API

catch_get_vertex_real :: proc(panic: ^Panic, v: ^Vertex_Real, index: c.size_t) -> Real ---
catch_get_vertex_vec2 :: proc(panic: ^Panic, v: ^Vertex_Vec2, index: c.size_t) -> Vec2 ---
catch_get_vertex_vec3 :: proc(panic: ^Panic, v: ^Vertex_Vec3, index: c.size_t) -> Vec3 ---
catch_get_vertex_vec4 :: proc(panic: ^Panic, v: ^Vertex_Vec4, index: c.size_t) -> Vec4 ---

get_triangulate_face_num_indices :: proc(face: Face) -> c.size_t ---

as_unknown :: proc(element: ^Element) -> ^Unknown ---
as_node :: proc(element: ^Element) -> ^Node ---
as_mesh :: proc(element: ^Element) -> ^Mesh ---
as_light :: proc(element: ^Element) -> ^Light ---
as_camera :: proc(element: ^Element) -> ^Camera ---
as_bone :: proc(element: ^Element) -> ^Bone ---
as_empty :: proc(element: ^Element) -> ^Empty ---
as_line_curve :: proc(element: ^Element) -> ^Line_Curve ---
as_nurbs_curve :: proc(element: ^Element) -> ^Nurbs_Curve ---
as_nurbs_surface :: proc(element: ^Element) -> ^Nurbs_Surface ---
as_nurbs_trim_surface :: proc(element: ^Element) -> ^Nurbs_Trim_Surface ---
as_nurbs_trim_boundary :: proc(element: ^Element) -> ^Nurbs_Trim_Boundary ---
as_procedural_geometry :: proc(element: ^Element) -> ^Procedural_Geometry ---
as_stereo_camera :: proc(element: ^Element) -> ^Stereo_Camera ---
as_camera_switcher :: proc(element: ^Element) -> ^Camera_Switcher ---
as_marker :: proc(element: ^Element) -> ^Marker ---
as_lod_group :: proc(element: ^Element) -> ^Lod_Group ---
as_skin_deformer :: proc(element: ^Element) -> ^Skin_Deformer ---
as_skin_cluster :: proc(element: ^Element) -> ^Skin_Cluster ---
as_blend_deformer :: proc(element: ^Element) -> ^Blend_Deformer ---
as_blend_channel :: proc(element: ^Element) -> ^Blend_Channel ---
as_blend_shape :: proc(element: ^Element) -> ^Blend_Shape ---
as_cache_deformer :: proc(element: ^Element) -> ^Cache_Deformer ---
as_cache_file :: proc(element: ^Element) -> ^Cache_File ---
as_material :: proc(element: ^Element) -> ^Material ---
as_texture :: proc(element: ^Element) -> ^Texture ---
as_video :: proc(element: ^Element) -> ^Video ---
as_shader :: proc(element: ^Element) -> ^Shader ---
as_shader_binding :: proc(element: ^Element) -> ^Shader_Binding ---
as_anim_stack :: proc(element: ^Element) -> ^Anim_Stack ---
as_anim_layer :: proc(element: ^Element) -> ^Anim_Layer ---
as_anim_value :: proc(element: ^Element) -> ^Anim_Value ---
as_anim_curve :: proc(element: ^Element) -> ^Anim_Curve ---
as_display_layer :: proc(element: ^Element) -> ^Display_Layer ---
as_selection_set :: proc(element: ^Element) -> ^Selection_Set ---
as_selection_node :: proc(element: ^Element) -> ^Selection_Node ---
as_character :: proc(element: ^Element) -> ^Character ---
as_constraint :: proc(element: ^Element) -> ^Constraint ---
as_pose :: proc(element: ^Element) -> ^Pose ---
as_metadata_object :: proc(element: ^Element) -> ^Metadata_Object ---

// -- FFI API

// ufbx_abi void ufbx_ffi_find_int_len(int64_t *retval, const ufbx_props *props, const char *name, size_t name_len, const int64_t *def);
// ufbx_abi void ufbx_ffi_find_vec3_len(ufbx_vec3 *retval, const ufbx_props *props, const char *name, size_t name_len, const ufbx_vec3 *def);
// ufbx_abi void ufbx_ffi_find_string_len(ufbx_string *retval, const ufbx_props *props, const char *name, size_t name_len, const ufbx_string *def);
// ufbx_abi void ufbx_ffi_find_anim_props(ufbx_anim_prop_list *retval, const ufbx_anim_layer *layer, const ufbx_element *element);
// ufbx_abi void ufbx_ffi_get_compatible_matrix_for_normals(ufbx_matrix *retval, const ufbx_node *node);
// ufbx_abi void ufbx_ffi_evaluate_anim_value_vec2(ufbx_vec2 *retval, const ufbx_anim_value *anim_value, double time);
// ufbx_abi void ufbx_ffi_evaluate_anim_value_vec3(ufbx_vec3 *retval, const ufbx_anim_value *anim_value, double time);
// ufbx_abi void ufbx_ffi_evaluate_prop_len(ufbx_prop *retval, const ufbx_anim *anim, const ufbx_element *element, const char *name, size_t name_len, double time);
// ufbx_abi void ufbx_ffi_evaluate_props(ufbx_props *retval, const ufbx_anim *anim, ufbx_element *element, double time, ufbx_prop *buffer, size_t buffer_size);
// ufbx_abi void ufbx_ffi_evaluate_transform(ufbx_transform *retval, const ufbx_anim *anim, const ufbx_node *node, double time);
// ufbx_abi ufbx_real ufbx_ffi_evaluate_blend_weight(const ufbx_anim *anim, const ufbx_blend_channel *channel, double time);
// ufbx_abi void ufbx_ffi_prepare_prop_overrides(ufbx_const_prop_override_list *retval, ufbx_prop_override *overrides, size_t num_overrides);
// ufbx_abi void ufbx_ffi_quat_mul(ufbx_quat *retval, const ufbx_quat *a, const ufbx_quat *b);
// ufbx_abi void ufbx_ffi_quat_normalize(ufbx_quat *retval, const ufbx_quat *q);
// ufbx_abi void ufbx_ffi_quat_fix_antipodal(ufbx_quat *retval, const ufbx_quat *q, const ufbx_quat *reference);
// ufbx_abi void ufbx_ffi_quat_slerp(ufbx_quat *retval, const ufbx_quat *a, const ufbx_quat *b, ufbx_real t);
// ufbx_abi void ufbx_ffi_quat_rotate_vec3(ufbx_vec3 *retval, const ufbx_quat *q, const ufbx_vec3 *v);
// ufbx_abi void ufbx_ffi_quat_to_euler(ufbx_vec3 *retval, const ufbx_quat *q, ufbx_rotation_order order);
// ufbx_abi void ufbx_ffi_euler_to_quat(ufbx_quat *retval, const ufbx_vec3 *v, ufbx_rotation_order order);
// ufbx_abi void ufbx_ffi_matrix_mul(ufbx_matrix *retval, const ufbx_matrix *a, const ufbx_matrix *b);
// ufbx_abi void ufbx_ffi_matrix_invert(ufbx_matrix *retval, const ufbx_matrix *m);
// ufbx_abi void ufbx_ffi_matrix_for_normals(ufbx_matrix *retval, const ufbx_matrix *m);
// ufbx_abi void ufbx_ffi_transform_position(ufbx_vec3 *retval, const ufbx_matrix *m, const ufbx_vec3 *v);
// ufbx_abi void ufbx_ffi_transform_direction(ufbx_vec3 *retval, const ufbx_matrix *m, const ufbx_vec3 *v);
// ufbx_abi void ufbx_ffi_transform_to_matrix(ufbx_matrix *retval, const ufbx_transform *t);
// ufbx_abi void ufbx_ffi_matrix_to_transform(ufbx_transform *retval, const ufbx_matrix *m);
// ufbx_abi void ufbx_ffi_get_skin_vertex_matrix(ufbx_matrix *retval, const ufbx_skin_deformer *skin, size_t vertex, const ufbx_matrix *fallback);
// ufbx_abi void ufbx_ffi_get_blend_shape_vertex_offset(ufbx_vec3 *retval, const ufbx_blend_shape *shape, size_t vertex);
// ufbx_abi void ufbx_ffi_get_blend_vertex_offset(ufbx_vec3 *retval, const ufbx_blend_deformer *blend, size_t vertex);
// ufbx_abi void ufbx_ffi_evaluate_nurbs_curve(ufbx_curve_point *retval, const ufbx_nurbs_curve *curve, ufbx_real u);
// ufbx_abi void ufbx_ffi_evaluate_nurbs_surface(ufbx_surface_point *retval, const ufbx_nurbs_surface *surface, ufbx_real u, ufbx_real v);
// ufbx_abi void ufbx_ffi_get_weighted_face_normal(ufbx_vec3 *retval, const ufbx_vertex_vec3 *positions, const ufbx_face *face);
// ufbx_abi size_t ufbx_ffi_get_triangulate_face_num_indices(const ufbx_face *face);
// ufbx_abi uint32_t ufbx_ffi_triangulate_face(uint32_t *indices, size_t num_indices, const ufbx_mesh *mesh, const ufbx_face *face);

}        

// -- Properties

// Names of common properties in `ufbx_props`.
// Some of these differ from ufbx interpretations.

// Local translation.
// Used by: `ufbx_node`
Lcl_Translation :: "Lcl Translation"

// Local rotation expressed in Euler degrees.
// Used by: `ufbx_node`
// The rotation order is defined by the `UFBX_RotationOrder` property.
Lcl_Rotation :: "Lcl Rotation"

// Local scaling factor, 3D vector.
// Used by: `ufbx_node`
Lcl_Scaling :: "Lcl Scaling"

// Euler rotation interpretation, used by `UFBX_Lcl_Rotation`.
// Used by: `ufbx_node`, enum value `ufbx_rotation_order`.
RotationOrder :: "RotationOrder"

// Scaling pivot: point around which scaling is performed.
// Used by: `ufbx_node`.
ScalingPivot :: "ScalingPivot"

// Scaling pivot: point around which rotation is performed.
// Used by: `ufbx_node`.
RotationPivot :: "RotationPivot"

// Scaling offset: translation added after scaling is performed.
// Used by: `ufbx_node`.
ScalingOffset :: "ScalingOffset"

// Rotation offset: translation added after rotation is performed.
// Used by: `ufbx_node`.
RotationOffset :: "RotationOffset"

// Pre-rotation: Rotation applied _after_ `ufbxi_Lcl_Rotation`.
// Used by: `ufbx_node`.
// Affected by `UFBX_RotationPivot` but not `UFBX_RotationOrder`.
PreRotation :: "PreRotation"

// Post-rotation: Rotation applied _before_ `ufbxi_Lcl_Rotation`.
// Used by: `ufbx_node`.
// Affected by `UFBX_RotationPivot` but not `UFBX_RotationOrder`.
PostRotation :: "PostRotation"

// Controls whether the node should be displayed or not.
// Used by: `ufbx_node`.
Visibility :: "Visibility"

// Weight of an animation layer in percentage (100.0 being full).
// Used by: `ufbx_anim_layer`.
Weight :: "Weight"
