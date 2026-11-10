class_name ProceduralLegIK
extends Node3D

class LegChain:
    var index: int
    var hip_socket: Node3D
    var femur_mesh: MeshInstance3D
    var tibia_mesh: MeshInstance3D
    var foot_mesh: MeshInstance3D
    var raycast: RayCast3D
    var current_foot_pos: Vector3
    var target_foot_pos: Vector3
    var step_start_pos: Vector3
    var step_progress: float = 1.0
    var is_stepping: bool = false
    var side: float = 1.0 # 1.0 = right, -1.0 = left
    var femur_len: float = 0.55
    var tibia_len: float = 0.65

var legs: Array[LegChain] = []
var step_stride_length: float = 0.55
var step_height: float = 0.25
var step_duration: float = 0.18 # seconds
var time_accumulator: float = 0.0
var creature_owner: CharacterBody3D

# Gait groups: Group A (0, 3, 4), Group B (1, 2, 5) for hexapods
var gait_group_active: int = 0

func setup_legs(owner_body: CharacterBody3D, leg_count: int = 6, scale_mul: float = 1.0) -> void:
    creature_owner = owner_body
    # Clear any previous leg nodes
    for child in get_children():
        child.queue_free()
    legs.clear()

    var mat_toon = _get_toon_material(Color(0.28, 0.22, 0.18))
    var pairs = int(ceil(leg_count / 2.0))
    
    for i in range(leg_count):
        var leg = LegChain.new()
        leg.index = i
        var side_sign = 1.0 if (i % 2 == 0) else -1.0
        leg.side = side_sign
        
        var pair_idx = int(i / 2)
        var z_offset = lerpf(-0.4, 0.4, float(pair_idx) / maxf(1.0, float(pairs - 1)))
        var hip_local = Vector3(side_sign * 0.45 * scale_mul, -0.15 * scale_mul, z_offset * scale_mul)
        
        var hip_node = Node3D.new()
        hip_node.name = "Hip_%d" % i
        hip_node.position = hip_local
        add_child(hip_node)
        leg.hip_socket = hip_node
        
        leg.femur_len = 0.5 * scale_mul
        leg.tibia_len = 0.6 * scale_mul
        
        # Raycast for ground detection
        var ray = RayCast3D.new()
        ray.target_position = Vector3(side_sign * 0.4, -1.8 * scale_mul, 0.1)
        ray.collision_mask = 1 # Terrarium terrain
        ray.enabled = true
        hip_node.add_child(ray)
        leg.raycast = ray
        
        # Femur visual
        var f_mesh = MeshInstance3D.new()
        var f_cylinder = CylinderMesh.new()
        f_cylinder.top_radius = 0.05 * scale_mul
        f_cylinder.bottom_radius = 0.035 * scale_mul
        f_cylinder.height = leg.femur_len
        f_mesh.mesh = f_cylinder
        f_mesh.material_override = mat_toon
        add_child(f_mesh)
        leg.femur_mesh = f_mesh
        
        # Tibia visual
        var t_mesh = MeshInstance3D.new()
        var t_cylinder = CylinderMesh.new()
        t_cylinder.top_radius = 0.035 * scale_mul
        t_cylinder.bottom_radius = 0.015 * scale_mul
        t_cylinder.height = leg.tibia_len
        t_mesh.mesh = t_cylinder
        t_mesh.material_override = mat_toon
        add_child(t_mesh)
        leg.tibia_mesh = t_mesh
        
        # Small claw / foot tip
        var foot = MeshInstance3D.new()
        var sphere = SphereMesh.new()
        sphere.radius = 0.04 * scale_mul
        sphere.height = 0.08 * scale_mul
        foot.mesh = sphere
        foot.material_override = mat_toon
        add_child(foot)
        leg.foot_mesh = foot
        
        # Default initial foot position in world space
        var rest_foot = hip_node.global_position + Vector3(side_sign * 0.55 * scale_mul, -0.6 * scale_mul, 0)
        leg.current_foot_pos = rest_foot
        leg.target_foot_pos = rest_foot
        leg.step_start_pos = rest_foot
        
        legs.append(leg)

func update_ik(delta: float, velocity: Vector3) -> void:
    time_accumulator += delta
    var is_moving = velocity.length_squared() > 0.01
    
    # Toggle gait groups periodically when moving
    if is_moving:
        if fmod(time_accumulator, step_duration * 1.6) < delta:
            gait_group_active = (gait_group_active + 1) % 2
            
    for leg in legs:
        _update_single_leg(leg, delta, velocity, is_moving)

func _update_single_leg(leg: LegChain, delta: float, velocity: Vector3, is_moving: bool) -> void:
    var hip_world = leg.hip_socket.global_position
    
    # Check if leg belongs to currently allowed stepping gait group
    var leg_group = 0 if (leg.index % 2 == 0 && (leg.index / 2) % 2 == 0) || (leg.index % 2 == 1 && (leg.index / 2) % 2 == 1) else 1
    var can_step = (leg_group == gait_group_active) || not is_moving
    
    # Ground target position based on raycast or rest offset
    var desired_foot = hip_world + Vector3(leg.side * 0.55, -0.65, 0)
    if leg.raycast.is_colliding():
        desired_foot = leg.raycast.get_collision_point()
    
    # Add lookahead velocity lead
    if is_moving:
        desired_foot += velocity.normalized() * (step_stride_length * 0.5)
    
    # Trigger new step if distance exceeded
    var dist = leg.current_foot_pos.distance_to(desired_foot)
    if dist > step_stride_length and not leg.is_stepping and can_step:
        leg.is_stepping = true
        leg.step_progress = 0.0
        leg.step_start_pos = leg.current_foot_pos
        leg.target_foot_pos = desired_foot
    
    # Advance stepping coroutine/lerp
    if leg.is_stepping:
        leg.step_progress += delta / step_duration
        if leg.step_progress >= 1.0:
            leg.step_progress = 1.0
            leg.is_stepping = false
            leg.current_foot_pos = leg.target_foot_pos
        else:
            var t = leg.step_progress
            var horizontal_pos = leg.step_start_pos.lerp(leg.target_foot_pos, t)
            var vertical_lift = sin(t * PI) * step_height
            leg.current_foot_pos = horizontal_pos + Vector3(0, vertical_lift, 0)
    
    # Analytical 2-Bone IK solving
    _solve_two_bone_ik(hip_world, leg.current_foot_pos, leg)

func _solve_two_bone_ik(hip: Vector3, foot: Vector3, leg: LegChain) -> void:
    var to_foot = foot - hip
    var dist = to_foot.length()
    var l1 = leg.femur_len
    var l2 = leg.tibia_len
    
    # Clamp distance within reachable envelope
    dist = clampf(dist, 0.05, (l1 + l2) * 0.98)
    
    # Law of Cosines for knee and hip angle offsets
    var cos_knee = (l1 * l1 + l2 * l2 - dist * dist) / (2.0 * l1 * l2)
    cos_knee = clampf(cos_knee, -1.0, 1.0)
    var angle_knee = acos(cos_knee)
    
    var cos_hip = (l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist)
    cos_hip = clampf(cos_hip, -1.0, 1.0)
    var angle_hip_offset = acos(cos_hip)
    
    # Knee pole direction: outwards away from body and slightly up
    var outward = (leg.hip_socket.global_transform.basis.x * leg.side).normalized()
    var forward = -leg.hip_socket.global_transform.basis.z
    var pole = (outward * 0.8 + forward * 0.2 + Vector3.UP * 0.4).normalized()
    
    var dir_to_foot = to_foot.normalized()
    var bend_axis = dir_to_foot.cross(pole).normalized()
    if bend_axis.length_squared() < 0.01:
        bend_axis = Vector3.UP
    
    var femur_dir = dir_to_foot.rotated(bend_axis, angle_hip_offset * leg.side)
    var knee_pos = hip + femur_dir * l1
    
    # Position and orient femur
    _position_bone(leg.femur_mesh, hip, knee_pos)
    # Position and orient tibia
    _position_bone(leg.tibia_mesh, knee_pos, foot)
    # Position foot
    leg.foot_mesh.global_position = foot

func _position_bone(bone: MeshInstance3D, start: Vector3, finish: Vector3) -> void:
    var mid = (start + finish) * 0.5
    var dir = finish - start
    var length = dir.length()
    if length < 0.001:
        return
    
    bone.global_position = mid
    var up = dir.normalized()
    var temp_forward = Vector3.FORWARD
    if abs(up.dot(temp_forward)) > 0.95:
        temp_forward = Vector3.RIGHT
    var right = up.cross(temp_forward).normalized()
    var forward = right.cross(up).normalized()
    
    bone.global_basis = Basis(right, up, forward)

func _get_toon_material(color: Color) -> ShaderMaterial:
    var mat = ShaderMaterial.new()
    mat.shader = load("res://shaders/comic_cel_toon.gdshader")
    mat.set_shader_parameter("albedo_color", color)
    mat.set_shader_parameter("roughness", 0.5)
    
    # Next pass outline
    var outline_mat = ShaderMaterial.new()
    outline_mat.shader = load("res://shaders/inverted_hull_outline.gdshader")
    outline_mat.set_shader_parameter("outline_width", 0.025)
    mat.next_pass = outline_mat
    return mat

