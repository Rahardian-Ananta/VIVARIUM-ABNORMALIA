class_name SeveredOrganChunk
extends RigidBody3D

@export var organ_data: OrganData
@onready var visual_root: Node3D = $VisualRoot
@onready var detection_area: Area3D = $DetectionArea

var decay_timer: float = 60.0 # Stays in tank for 60s before fully decomposing

func _ready() -> void:
    collision_layer = 4 # Layer 3: Severed Organs
    collision_mask = 1 | 4 # Collide with Terrain and other Organs
    
    if organ_data:
        setup_chunk(organ_data)

func setup_chunk(data: OrganData) -> void:
    organ_data = data
    mass = data.mass_kg
    
    # Build a preview mesh
    for child in visual_root.get_children():
        child.queue_free()
        
    var mesh_inst = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.22 * data.mass_kg * 0.4 + 0.15
    sphere.height = sphere.radius * 2.0
    mesh_inst.mesh = sphere
    
    var mat = ShaderMaterial.new()
    mat.shader = load("res://shaders/comic_cel_toon.gdshader")
    mat.set_shader_parameter("albedo_color", data.color_tint)
    mat.set_shader_parameter("rot_factor", 0.3)
    
    var outline_mat = ShaderMaterial.new()
    outline_mat.shader = load("res://shaders/inverted_hull_outline.gdshader")
    outline_mat.set_shader_parameter("outline_width", 0.035)
    mat.next_pass = outline_mat
    
    mesh_inst.material_override = mat
    visual_root.add_child(mesh_inst)

func _physics_process(delta: float) -> void:
    decay_timer -= delta
    if decay_timer <= 0:
        queue_free()

