class_name TerrariumBuilder
extends Node3D

@export var width: float = 12.0
@export var depth: float = 8.0
@export var height: float = 8.0

var glass_material: ShaderMaterial
var water_material: ShaderMaterial
var brass_material: ShaderMaterial
var earth_material: ShaderMaterial
var moss_material: ShaderMaterial
var deadwood_material: ShaderMaterial

var glass_panels: Array[MeshInstance3D] = []
var heat_lamp: SpotLight3D
var shockwave_elapsed: float = 99.0

func _ready() -> void:
    _init_materials()
    _build_stratified_terrain()
    _build_canopy_deadwood()
    _build_putrid_sump()
    _build_glass_enclosure_and_frame()
    _build_heat_lamp()
    
    GameManager.shockwave_triggered.connect(_on_shockwave_triggered)

func _process(delta: float) -> void:
    # Update glass shockwave ripple decay
    if shockwave_elapsed < 4.0:
        shockwave_elapsed += delta
        if glass_material:
            glass_material.set_shader_parameter("tap_elapsed", shockwave_elapsed)

func _init_materials() -> void:
    # 1. Glass Shockwave material
    glass_material = ShaderMaterial.new()
    glass_material.shader = load("res://shaders/glass_shockwave.gdshader")
    glass_material.set_shader_parameter("glass_tint", Color(0.85, 0.94, 0.98, 0.12))
    glass_material.set_shader_parameter("shockwave_intensity", 0.0)
    glass_material.set_shader_parameter("tap_elapsed", 99.0)
    
    # 2. Murky Water Pond material
    water_material = ShaderMaterial.new()
    water_material.shader = load("res://shaders/murky_water_pond.gdshader")
    water_material.set_shader_parameter("water_deep", Color(0.06, 0.18, 0.09, 0.92))
    water_material.set_shader_parameter("water_shallow", Color(0.22, 0.48, 0.25, 0.78))
    
    # 3. Victorian Brass material
    brass_material = ShaderMaterial.new()
    brass_material.shader = load("res://shaders/comic_cel_toon.gdshader")
    brass_material.set_shader_parameter("albedo_color", Color(0.72, 0.55, 0.22))
    brass_material.set_shader_parameter("metallic", 0.65)
    brass_material.set_shader_parameter("roughness", 0.35)
    var brass_outline = ShaderMaterial.new()
    brass_outline.shader = load("res://shaders/inverted_hull_outline.gdshader")
    brass_outline.set_shader_parameter("outline_width", 0.035)
    brass_material.next_pass = brass_outline
    
    # 4. Earth / Loam material
    earth_material = ShaderMaterial.new()
    earth_material.shader = load("res://shaders/comic_cel_toon.gdshader")
    earth_material.set_shader_parameter("albedo_color", Color(0.36, 0.26, 0.18))
    earth_material.set_shader_parameter("roughness", 0.8)
    var earth_outline = ShaderMaterial.new()
    earth_outline.shader = load("res://shaders/inverted_hull_outline.gdshader")
    earth_outline.set_shader_parameter("outline_width", 0.03)
    earth_material.next_pass = earth_outline
    
    # 5. Bioluminescent Moss material
    moss_material = ShaderMaterial.new()
    moss_material.shader = load("res://shaders/comic_cel_toon.gdshader")
    moss_material.set_shader_parameter("albedo_color", Color(0.25, 0.52, 0.28))
    moss_material.set_shader_parameter("biolume_cyan_rim", Vector3(0.2, 0.9, 0.4))
    
    # 6. Deadwood material
    deadwood_material = ShaderMaterial.new()
    deadwood_material.shader = load("res://shaders/comic_cel_toon.gdshader")
    deadwood_material.set_shader_parameter("albedo_color", Color(0.22, 0.18, 0.14))
    deadwood_material.set_shader_parameter("roughness", 0.7)

func _build_stratified_terrain() -> void:
    var terrain_body = StaticBody3D.new()
    terrain_body.name = "StratifiedTerrain"
    terrain_body.collision_layer = 1
    terrain_body.collision_mask = 0
    add_child(terrain_body)
    
    # Main ground slab (Middle layer Y: 0.5 to 1.5)
    _add_static_box(terrain_body, Vector3(2.5, 0.4, 0.0), Vector3(7.0, 1.2, 7.6), earth_material)
    
    # Terraced dirt mounds & ramps
    _add_static_box(terrain_body, Vector3(3.2, 1.3, 1.5), Vector3(4.5, 0.9, 4.0), moss_material)
    _add_static_box(terrain_body, Vector3(4.0, 2.0, -1.2), Vector3(3.2, 0.8, 3.5), moss_material)
    _add_static_box(terrain_body, Vector3(1.2, 1.0, -2.0), Vector3(3.0, 0.8, 2.5), earth_material)
    
    # Sump basin foundation (depressed corner)
    _add_static_box(terrain_body, Vector3(-3.8, -0.6, -1.5), Vector3(4.2, 0.6, 4.8), earth_material)
    _add_static_box(terrain_body, Vector3(-3.8, 0.2, 2.2), Vector3(4.2, 1.0, 3.2), moss_material)

func _build_canopy_deadwood() -> void:
    var canopy_root = StaticBody3D.new()
    canopy_root.name = "CanopyDeadwood"
    canopy_root.collision_layer = 1
    add_child(canopy_root)
    
    # Twisted archway branches bridging upper layer (Y: 3.5 to 5.2)
    var branch1 = _make_cylinder_branch(Vector3(-2.5, 3.6, -1.0), Vector3(2.5, 4.4, 1.0), 0.28)
    canopy_root.add_child(branch1)
    
    var branch2 = _make_cylinder_branch(Vector3(2.0, 4.3, 1.0), Vector3(4.5, 2.4, -2.0), 0.22)
    canopy_root.add_child(branch2)
    
    var branch3 = _make_cylinder_branch(Vector3(-4.0, 2.0, 1.5), Vector3(-2.2, 3.8, -0.8), 0.24)
    canopy_root.add_child(branch3)

func _make_cylinder_branch(start_pos: Vector3, end_pos: Vector3, radius: float) -> Node3D:
    var container = Node3D.new()
    var dir = end_pos - start_pos
    var len = dir.length()
    
    var mesh_inst = MeshInstance3D.new()
    var cyl = CylinderMesh.new()
    cyl.top_radius = radius * 0.75
    cyl.bottom_radius = radius
    cyl.height = len
    mesh_inst.mesh = cyl
    mesh_inst.material_override = deadwood_material
    
    var col = CollisionShape3D.new()
    var cyl_shape = CylinderShape3D.new()
    cyl_shape.radius = radius
    cyl_shape.height = len
    col.shape = cyl_shape
    
    container.position = (start_pos + end_pos) * 0.5
    var up = dir.normalized()
    var right = up.cross(Vector3.FORWARD).normalized()
    if right.length_squared() < 0.01:
        right = Vector3.RIGHT
    var fwd = right.cross(up).normalized()
    container.basis = Basis(right, up, fwd)
    
    container.add_child(mesh_inst)
    container.add_child(col)
    return container

func _build_putrid_sump() -> void:
    # Acid water pond surface (Corner: X: -3.8, Z: -1.5, Y: 0.15)
    var pond = MeshInstance3D.new()
    pond.name = "PutridSumpWater"
    var plane = PlaneMesh.new()
    plane.size = Vector2(4.2, 4.8)
    pond.mesh = plane
    pond.material_override = water_material
    pond.position = Vector3(-3.8, 0.15, -1.5)
    add_child(pond)
    
    # Toxic Area3D hazard trigger
    var sump_area = Area3D.new()
    sump_area.name = "AcidSumpArea"
    sump_area.collision_layer = 1
    sump_area.collision_mask = 2 | 4
    var col = CollisionShape3D.new()
    var box = BoxShape3D.new()
    box.size = Vector3(4.2, 1.2, 4.8)
    col.shape = box
    sump_area.position = Vector3(-3.8, -0.4, -1.5)
    sump_area.add_child(col)
    add_child(sump_area)

func _build_glass_enclosure_and_frame() -> void:
    var half_w = width * 0.5
    var half_d = depth * 0.5
    var half_h = height * 0.5
    var center_y = 2.5
    
    # Glass planes (Front, Back, Left, Right, Ceiling)
    _create_glass_wall(Vector3(0, center_y, half_d), Vector2(width, height), Vector3.ZERO) # Front
    _create_glass_wall(Vector3(0, center_y, -half_d), Vector2(width, height), Vector3(0, deg_to_rad(180), 0)) # Back
    _create_glass_wall(Vector3(-half_w, center_y, 0), Vector2(depth, height), Vector3(0, deg_to_rad(90), 0)) # Left
    _create_glass_wall(Vector3(half_w, center_y, 0), Vector2(depth, height), Vector3(0, deg_to_rad(-90), 0)) # Right
    
    # Brass Victorian Framework (Pillars & Struts)
    var frame_root = Node3D.new()
    frame_root.name = "VictorianBrassFrame"
    add_child(frame_root)
    
    # 4 Corner Pillars
    for x in [-half_w, half_w]:
        for z in [-half_d, half_d]:
            _add_brass_beam(frame_root, Vector3(x, center_y, z), Vector3(0.25, height, 0.25))
            
    # Horizontal rims top & bottom
    _add_brass_beam(frame_root, Vector3(0, center_y + half_h, half_d), Vector3(width, 0.2, 0.2))
    _add_brass_beam(frame_root, Vector3(0, center_y + half_h, -half_d), Vector3(width, 0.2, 0.2))
    _add_brass_beam(frame_root, Vector3(-half_w, center_y + half_h, 0), Vector3(0.2, 0.2, depth))
    _add_brass_beam(frame_root, Vector3(half_w, center_y + half_h, 0), Vector3(0.2, 0.2, depth))
    
    _add_brass_beam(frame_root, Vector3(0, center_y - half_h, half_d), Vector3(width, 0.35, 0.35))
    _add_brass_beam(frame_root, Vector3(0, center_y - half_h, -half_d), Vector3(width, 0.35, 0.35))
    _add_brass_beam(frame_root, Vector3(-half_w, center_y - half_h, 0), Vector3(0.35, 0.35, depth))
    _add_brass_beam(frame_root, Vector3(half_w, center_y - half_h, 0), Vector3(0.35, 0.35, depth))

func _create_glass_wall(pos: Vector3, size: Vector2, rot: Vector3) -> void:
    var mesh_inst = MeshInstance3D.new()
    var quad = QuadMesh.new()
    quad.size = size
    mesh_inst.mesh = quad
    mesh_inst.material_override = glass_material
    mesh_inst.position = pos
    mesh_inst.rotation = rot
    add_child(mesh_inst)
    glass_panels.append(mesh_inst)
    
    # Glass Area3D for Raycast interception (Layer 16: Bit 4)
    var area = Area3D.new()
    area.collision_layer = 16
    area.collision_mask = 0
    var col = CollisionShape3D.new()
    var box = BoxShape3D.new()
    box.size = Vector3(size.x, size.y, 0.15)
    col.shape = box
    area.add_child(col)
    area.position = pos
    area.rotation = rot
    add_child(area)

func _add_brass_beam(parent: Node3D, pos: Vector3, size: Vector3) -> void:
    var mesh = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = brass_material
    mesh.position = pos
    parent.add_child(mesh)

func _build_heat_lamp() -> void:
    heat_lamp = SpotLight3D.new()
    heat_lamp.name = "HeatLamp"
    heat_lamp.light_color = Color(1.0, 0.65, 0.3)
    heat_lamp.light_energy = 3.2
    heat_lamp.spot_range = 14.0
    heat_lamp.spot_angle = 55.0
    heat_lamp.position = Vector3(0, 6.2, 0)
    heat_lamp.rotation.x = deg_to_rad(-90)
    add_child(heat_lamp)

func _add_static_box(parent: StaticBody3D, pos: Vector3, size: Vector3, mat: Material) -> void:
    var mesh = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = mat
    mesh.position = pos
    parent.add_child(mesh)
    
    var col = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    col.shape = shape
    col.position = pos
    parent.add_child(col)

func _on_shockwave_triggered(hit_pos: Vector3) -> void:
    if glass_material:
        glass_material.set_shader_parameter("tap_world_pos", hit_pos)
        glass_material.set_shader_parameter("tap_elapsed", 0.0)
        glass_material.set_shader_parameter("shockwave_intensity", 1.0)

