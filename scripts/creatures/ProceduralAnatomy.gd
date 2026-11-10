class_name ProceduralAnatomy
extends Node3D

var creature_owner: CharacterBody3D
var thorax_mesh: MeshInstance3D
var leg_ik: ProceduralLegIK
var sockets: Dictionary = {}
var socket_visuals: Dictionary = {}
var hemolymph_particles: CPUParticles3D
var biolume_light: OmniLight3D = null

func build_anatomy(owner_body: CharacterBody3D, genome: GenomeData) -> void:
    creature_owner = owner_body
    
    # Clear existing children
    for child in get_children():
        child.queue_free()
    sockets.clear()
    socket_visuals.clear()
    
    _create_sockets()
    _build_thorax(genome)
    _create_hemolymph_emitter()
    
    # Create Leg IK
    leg_ik = ProceduralLegIK.new()
    leg_ik.name = "LegIK"
    add_child(leg_ik)
    
    # Configure legs from locomotion organ
    var leg_count = 6
    if genome.locomotion_organ:
        if genome.locomotion_organ.organ_id == "legs_spider_8":
            leg_count = 8
        elif genome.locomotion_organ.organ_id == "legs_heavy_strider":
            leg_count = 4
    leg_ik.setup_legs(creature_owner, leg_count)
    
    # Attach all initial organs from genome
    for sock in [
        OrganData.SocketType.CRANIAL,
        OrganData.SocketType.MANDIBLE_L,
        OrganData.SocketType.MANDIBLE_R,
        OrganData.SocketType.DORSAL,
        OrganData.SocketType.CAUDAL
    ]:
        var organ = genome.get_organ_in_socket(sock)
        if organ:
            attach_organ(sock, organ, false)

func _create_sockets() -> void:
    sockets[OrganData.SocketType.CRANIAL] = _make_socket("Socket_Cranial", Vector3(0, 0.28, -0.65))
    sockets[OrganData.SocketType.MANDIBLE_L] = _make_socket("Socket_Mandible_L", Vector3(-0.35, -0.1, -0.75))
    sockets[OrganData.SocketType.MANDIBLE_R] = _make_socket("Socket_Mandible_R", Vector3(0.35, -0.1, -0.75))
    sockets[OrganData.SocketType.DORSAL] = _make_socket("Socket_Dorsal", Vector3(0, 0.42, 0))
    sockets[OrganData.SocketType.LOCOMOTION] = _make_socket("Socket_Locomotion", Vector3(0, -0.2, 0))
    sockets[OrganData.SocketType.CAUDAL] = _make_socket("Socket_Caudal", Vector3(0, 0.15, 0.8))

func _make_socket(socket_name: String, local_pos: Vector3) -> Node3D:
    var node = Node3D.new()
    node.name = socket_name
    node.position = local_pos
    add_child(node)
    return node

func _build_thorax(genome: GenomeData) -> void:
    thorax_mesh = MeshInstance3D.new()
    thorax_mesh.name = "ThoraxMesh"
    
    # Stylized segmented beetle thorax using CapsuleMesh
    var capsule = CapsuleMesh.new()
    capsule.radius = 0.45
    capsule.height = 1.35
    thorax_mesh.mesh = capsule
    thorax_mesh.rotation.x = deg_to_rad(90) # Orient along Z axis (forward/back)
    
    var mat = _create_toon_material(genome.base_body_color)
    thorax_mesh.material_override = mat
    add_child(thorax_mesh)

func _create_hemolymph_emitter() -> void:
    hemolymph_particles = CPUParticles3D.new()
    hemolymph_particles.name = "HemolymphParticles"
    hemolymph_particles.emitting = false
    hemolymph_particles.one_shot = true
    hemolymph_particles.explosiveness = 0.85
    hemolymph_particles.amount = 24
    hemolymph_particles.lifetime = 0.6
    hemolymph_particles.initial_velocity_min = 2.0
    hemolymph_particles.initial_velocity_max = 4.5
    hemolymph_particles.direction = Vector3.UP
    hemolymph_particles.spread = 60.0
    
    # Toxic green hemolymph droplets
    var sphere = SphereMesh.new()
    sphere.radius = 0.04
    sphere.height = 0.08
    var p_mat = StandardMaterial3D.new()
    p_mat.albedo_color = Color(0.2, 0.9, 0.1, 0.9)
    p_mat.emission_enabled = true
    p_mat.emission = Color(0.1, 0.7, 0.1)
    sphere.material = p_mat
    hemolymph_particles.mesh = sphere
    add_child(hemolymph_particles)

func attach_organ(socket_type: OrganData.SocketType, organ: OrganData, animate: bool = true) -> void:
    detach_organ(socket_type, false)
    
    if not sockets.has(socket_type):
        return
        
    var socket_node: Node3D = sockets[socket_type]
    var visual = _generate_organ_mesh(organ)
    if not visual:
        return
        
    socket_node.add_child(visual)
    socket_visuals[socket_type] = visual
    
    # Extra mechanics for special organs
    if organ.special_tag == "BIOLUME":
        if not biolume_light:
            biolume_light = OmniLight3D.new()
            biolume_light.light_color = Color(0.2, 1.0, 0.85)
            biolume_light.light_energy = 2.5
            biolume_light.omni_range = 6.0
            socket_node.add_child(biolume_light)
    
    if animate:
        # Visceral scale-bounce tween on somatic graft
        visual.scale = Vector3(0.2, 0.2, 0.2)
        var tw = create_tween()
        tw.tween_property(visual, "scale", Vector3(1.3, 1.3, 1.3), 0.18).set_trans(Tween.TRANS_BACK)
        tw.tween_property(visual, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SPRING)
        
        # Squelch audio & hemolymph burst
        hemolymph_particles.global_position = socket_node.global_position
        hemolymph_particles.restart()
        if GameManager.audio_synth:
            GameManager.audio_synth.play_sfx("organ_graft", randf_range(0.9, 1.1), 1.0)

func detach_organ(socket_type: OrganData.SocketType, emit_particles: bool = true) -> void:
    if socket_visuals.has(socket_type):
        var vis = socket_visuals[socket_type]
        if is_instance_valid(vis):
            if emit_particles:
                hemolymph_particles.global_position = vis.global_position
                hemolymph_particles.restart()
            vis.queue_free()
        socket_visuals.erase(socket_type)
        
    if socket_type == OrganData.SocketType.DORSAL and biolume_light:
        biolume_light.queue_free()
        biolume_light = null

func _generate_organ_mesh(organ: OrganData) -> Node3D:
    var container = Node3D.new()
    container.name = "Visual_" + organ.organ_id
    
    var mat = _create_toon_material(organ.color_tint)
    
    match organ.organ_id:
        "crusher_mandibles_l", "crusher_mandibles_r":
            var is_left = (organ.socket == OrganData.SocketType.MANDIBLE_L)
            var pincer = MeshInstance3D.new()
            var prism = PrismMesh.new()
            prism.size = Vector3(0.22, 0.7, 0.12)
            pincer.mesh = prism
            pincer.material_override = mat
            pincer.rotation.z = deg_to_rad(-70 if is_left else 70)
            pincer.rotation.x = deg_to_rad(-30)
            pincer.position = Vector3(0, 0, -0.3)
            container.add_child(pincer)
            
        "mantis_scythe_l", "mantis_scythe_r":
            var is_left = (organ.socket == OrganData.SocketType.MANDIBLE_L)
            var scythe = MeshInstance3D.new()
            var cyl = CylinderMesh.new()
            cyl.top_radius = 0.02
            cyl.bottom_radius = 0.08
            cyl.height = 0.85
            scythe.mesh = cyl
            scythe.material_override = mat
            scythe.rotation.x = deg_to_rad(65)
            scythe.rotation.z = deg_to_rad(-45 if is_left else 45)
            container.add_child(scythe)
            
        "acid_sprayer_l", "acid_sprayer_r":
            var tube = MeshInstance3D.new()
            var cyl = CylinderMesh.new()
            cyl.top_radius = 0.07
            cyl.bottom_radius = 0.05
            cyl.height = 0.45
            tube.mesh = cyl
            tube.material_override = mat
            tube.rotation.x = deg_to_rad(80)
            container.add_child(tube)
            
        "cordyceps_stalk":
            # Segmented twisted orange parasitic stalk
            for seg in range(4):
                var part = MeshInstance3D.new()
                var cyl = CylinderMesh.new()
                cyl.top_radius = 0.04 - seg * 0.006
                cyl.bottom_radius = 0.05 - seg * 0.005
                cyl.height = 0.28
                part.mesh = cyl
                part.material_override = mat
                part.position = Vector3(sin(seg * 0.8) * 0.08, seg * 0.24, cos(seg * 0.8) * 0.06)
                part.rotation.z = deg_to_rad(seg * 12.0)
                container.add_child(part)
            # Spore head bulb
            var bulb = MeshInstance3D.new()
            var sp = SphereMesh.new()
            sp.radius = 0.14
            sp.height = 0.26
            bulb.mesh = sp
            bulb.position = Vector3(0.12, 1.0, 0.08)
            bulb.material_override = mat
            container.add_child(bulb)
            
        "biolume_sac":
            var sac = MeshInstance3D.new()
            var sp = SphereMesh.new()
            sp.radius = 0.32
            sp.height = 0.45
            sac.mesh = sp
            mat.set_shader_parameter("biolume_cyan_rim", Vector3(0.3, 1.0, 0.9))
            sac.material_override = mat
            container.add_child(sac)
            
        "calcified_armor":
            # Heavy faceted plates
            for p in range(3):
                var plate = MeshInstance3D.new()
                var box = BoxMesh.new()
                box.size = Vector3(0.85 - p * 0.1, 0.15, 0.4)
                plate.mesh = box
                plate.material_override = mat
                plate.position = Vector3(0, 0.1 + p * 0.08, -0.3 + p * 0.35)
                container.add_child(plate)
                
        "spore_pustules":
            # Blister cluster
            for b in range(5):
                var blister = MeshInstance3D.new()
                var sp = SphereMesh.new()
                sp.radius = 0.1 + randf() * 0.08
                sp.height = sp.radius * 2.0
                blister.mesh = sp
                blister.material_override = mat
                blister.position = Vector3(randf_range(-0.25, 0.25), 0.1, randf_range(-0.3, 0.3))
                container.add_child(blister)
                
        "counterbalance_tail":
            var tail = MeshInstance3D.new()
            var capsule = CapsuleMesh.new()
            capsule.radius = 0.28
            capsule.height = 0.9
            tail.mesh = capsule
            tail.material_override = mat
            tail.rotation.x = deg_to_rad(80)
            container.add_child(tail)
            
        "scorpion_stinger":
            # Arched tail segments + sharp venom barb
            for seg in range(4):
                var part = MeshInstance3D.new()
                var cyl = CylinderMesh.new()
                cyl.top_radius = 0.09 - seg * 0.015
                cyl.bottom_radius = 0.1 - seg * 0.015
                cyl.height = 0.32
                part.mesh = cyl
                part.material_override = mat
                part.position = Vector3(0, 0.15 + seg * 0.22, 0.15 + seg * 0.15)
                part.rotation.x = deg_to_rad(30 + seg * 20)
                container.add_child(part)
            var barb = MeshInstance3D.new()
            var prism = PrismMesh.new()
            prism.size = Vector3(0.08, 0.3, 0.08)
            barb.mesh = prism
            barb.material_override = mat
            barb.position = Vector3(0, 1.05, 0.6)
            barb.rotation.x = deg_to_rad(-120)
            container.add_child(barb)
            
        "stalker_eyes", "thermal_pits":
            for eye in [-1.0, 1.0]:
                var ocular = MeshInstance3D.new()
                var sp = SphereMesh.new()
                sp.radius = 0.12
                sp.height = 0.24
                ocular.mesh = sp
                ocular.material_override = mat
                ocular.position = Vector3(eye * 0.22, 0.08, -0.15)
                container.add_child(ocular)
                
        _:
            # Generic organ mesh representation
            var generic = MeshInstance3D.new()
            var box = BoxMesh.new()
            box.size = Vector3(0.3, 0.3, 0.3)
            generic.mesh = box
            generic.material_override = mat
            container.add_child(generic)
            
    return container

func _create_toon_material(color: Color) -> ShaderMaterial:
    var mat = ShaderMaterial.new()
    mat.shader = load("res://shaders/comic_cel_toon.gdshader")
    mat.set_shader_parameter("albedo_color", color)
    mat.set_shader_parameter("roughness", 0.45)
    
    var outline_mat = ShaderMaterial.new()
    outline_mat.shader = load("res://shaders/inverted_hull_outline.gdshader")
    outline_mat.set_shader_parameter("outline_width", 0.03)
    mat.next_pass = outline_mat
    return mat

func set_fever_glow(intensity: float) -> void:
    if thorax_mesh and thorax_mesh.material_override is ShaderMaterial:
        (thorax_mesh.material_override as ShaderMaterial).set_shader_parameter("fever_glow", intensity)

func set_rot_factor(factor: float) -> void:
    if thorax_mesh and thorax_mesh.material_override is ShaderMaterial:
        (thorax_mesh.material_override as ShaderMaterial).set_shader_parameter("rot_factor", factor)

