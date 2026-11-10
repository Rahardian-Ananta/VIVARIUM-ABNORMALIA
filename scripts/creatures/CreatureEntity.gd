class_name CreatureEntity
extends CharacterBody3D

enum State {
    WANDER,
    GRAZE,
    STALK,
    COMBAT,
    GRAFT_ORGAN,
    TUMBLE_OVERTURNED,
    CORDYCEPS_CLIMB,
    MATE,
    HELD_BY_TWEEZERS
}

# Genome & Biological stats
@export var genome: GenomeData
var current_health: float = 100.0
var max_health: float = 100.0
var atp_energy: float = 85.0
var max_atp_energy: float = 100.0
var total_mass: float = 2.0
var atp_burn_rate: float = 1.0
var center_of_mass_offset: Vector3 = Vector3.ZERO

# Complication flags
var is_nose_dragging: bool = false
var is_crab_limping: bool = false
var is_hyper_metabolic: bool = false
var has_biolume_curse: bool = false
var cordyceps_stage: int = 0 # 0: none, 1: infected, 2: mature hijacked
var cordyceps_timer: float = 0.0
var autophagy_timer: float = 25.0
var tumble_timer: float = 0.0

# State machine
var current_state: State = State.WANDER
var state_timer: float = 0.0
var target_entity: Node3D = null
var target_organ_chunk: SeveredOrganChunk = null
var wander_target: Vector3 = Vector3.ZERO
var aggro_level: float = 0.0
var time_alive: float = 0.0

# Physics & Complication tilt angles
var dynamic_pitch_angle: float = 0.0
var dynamic_roll_angle: float = 0.0
var gravity: float = 9.8

# Visual & IK references
@onready var anatomy: ProceduralAnatomy = $ProceduralAnatomy
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var dirt_particles: CPUParticles3D = $DirtParticles

func _ready() -> void:
    collision_layer = 2 # Living Creature Hulls
    collision_mask = 1 | 2 | 4 # Terrain, Creatures, Organs
    
    if not genome:
        genome = _generate_default_genome()
    
    anatomy.build_anatomy(self, genome)
    recalculate_physics_and_complications()
    
    GameManager.register_creature(self)
    wander_target = global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
    
    _setup_selection_ring()

func _exit_tree() -> void:
    GameManager.unregister_creature(self)

func _setup_selection_ring() -> void:
    if not selection_ring:
        selection_ring = MeshInstance3D.new()
        selection_ring.name = "SelectionRing"
        add_child(selection_ring)
        
    var torus = TorusMesh.new()
    torus.inner_radius = 0.75
    torus.outer_radius = 0.85
    selection_ring.mesh = torus
    
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.84, 0.0, 0.8)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.84, 0.0)
    selection_ring.material_override = mat
    selection_ring.position.y = -0.4
    selection_ring.visible = false

func set_selected(selected: bool) -> void:
    if selection_ring:
        selection_ring.visible = selected

func recalculate_physics_and_complications() -> void:
    total_mass = genome.calculate_total_mass()
    atp_burn_rate = genome.calculate_atp_burn_rate()
    center_of_mass_offset = genome.calculate_center_of_mass_offset()
    
    # 1. Anterior Overweight / Nose-Dragging
    # If CoM is shifted forward by -0.35 or more along Z axis
    is_nose_dragging = (center_of_mass_offset.z < -0.35)
    dynamic_pitch_angle = deg_to_rad(32.0) if is_nose_dragging else 0.0
    if dirt_particles:
        dirt_particles.emitting = is_nose_dragging
    
    # 2. Bilateral Asymmetry / Crab-Limping
    is_crab_limping = (absf(center_of_mass_offset.x) > 0.25)
    dynamic_roll_angle = deg_to_rad(20.0 * signf(center_of_mass_offset.x)) if is_crab_limping else 0.0
    
    # 3. Hyper-Metabolic Starvation
    is_hyper_metabolic = (atp_burn_rate > 4.5)
    if is_hyper_metabolic:
        anatomy.set_fever_glow(1.0)
    else:
        anatomy.set_fever_glow(0.0)
        
    # 4. Bioluminescent Beacon Curse
    var dorsal = genome.dorsal_organ
    has_biolume_curse = (dorsal != null and dorsal.special_tag == "BIOLUME")
    
    # 5. Cordyceps Status
    var cranial = genome.cranial_organ
    if cranial and cranial.special_tag == "CORDYCEPS":
        if cordyceps_stage == 0:
            cordyceps_stage = 1
    else:
        cordyceps_stage = 0

func _physics_process(delta: float) -> void:
    time_alive += delta
    _process_metabolism(delta)
    _process_cordyceps(delta)
    _process_sump_hazards(delta)
    
    # Skip AI navigation if grabbed by Overseer Tweezers
    if current_state == State.HELD_BY_TWEEZERS:
        if anatomy and anatomy.leg_ik:
            anatomy.leg_ik.update_ik(delta, Vector3.ZERO)
        return
        
    _process_state_machine(delta)
    _apply_movement_and_tilt(delta)
    _process_secondary_motion(delta)

func _process_metabolism(delta: float) -> void:
    atp_energy -= atp_burn_rate * delta
    
    # Hyper-metabolic fever starvation & Autophagy
    if is_hyper_metabolic:
        if atp_energy < 20.0:
            autophagy_timer -= delta
            if autophagy_timer <= 0.0:
                _trigger_autophagy()
                autophagy_timer = 25.0
    else:
        autophagy_timer = 25.0
        
    if atp_energy <= 0.0:
        atp_energy = 0.0
        take_damage(6.0 * delta, "Starvation")

func _trigger_autophagy() -> void:
    # Digests own dorsal or caudal organ to recover 30 ATP!
    var organ_to_eat: OrganData = null
    var sock_to_remove: OrganData.SocketType = OrganData.SocketType.DORSAL
    
    if genome.caudal_organ:
        sock_to_remove = OrganData.SocketType.CAUDAL
        organ_to_eat = genome.caudal_organ
    elif genome.dorsal_organ:
        sock_to_remove = OrganData.SocketType.DORSAL
        organ_to_eat = genome.dorsal_organ
        
    if organ_to_eat:
        genome.remove_organ_in_socket(sock_to_remove)
        anatomy.detach_organ(sock_to_remove, true)
        atp_energy = clampf(atp_energy + 35.0, 0.0, max_atp_energy)
        recalculate_physics_and_complications()
        GameManager.post_notification("AUTOPHAGY: %s digested its own %s to survive!" % [genome.species_name, organ_to_eat.organ_name], true)
        if GameManager.audio_synth:
            GameManager.audio_synth.play_sfx("wet_crunch", 1.2, 2.0)

func _process_cordyceps(delta: float) -> void:
    # Check bottom humid layer spore infection
    if global_position.y < 0.8 and cordyceps_stage == 0:
        if GameManager.spore_density > 25.0 or randf() < 0.005:
            cordyceps_stage = 1
            cordyceps_timer = 0.0
            GameManager.post_notification("⚠ CORDYCEPS INFECTION: %s inhaled fungal spores!" % genome.species_name, true)
            
    if cordyceps_stage == 1:
        cordyceps_timer += delta
        anatomy.set_rot_factor(clampf(cordyceps_timer / 30.0, 0.0, 1.0))
        if cordyceps_timer >= 30.0:
            cordyceps_stage = 2 # Mature neural hijack!
            var stalk = OrganData.create_organ("cordyceps_stalk", "[Parasitic Fungal Infiltration]")
            genome.set_organ_in_socket(OrganData.SocketType.CRANIAL, stalk)
            anatomy.attach_organ(OrganData.SocketType.CRANIAL, stalk, true)
            recalculate_physics_and_complications()
            current_state = State.CORDYCEPS_CLIMB
            GameManager.post_notification("⚠ CORDYCEPS STAGE 2: Neural hijack! Amputate immediately!", true)
            
    elif cordyceps_stage == 2:
        current_state = State.CORDYCEPS_CLIMB

func _process_sump_hazards(delta: float) -> void:
    # Sump basin: Y < 0.2
    if global_position.y < 0.2:
        if total_mass > genome.buoyancy_limit_kg:
            # Sinks and drowns!
            velocity.x *= 0.2
            velocity.z *= 0.2
            take_damage(12.0 * delta, "Toxic Sump Drowning")
            if randf() < 0.04 and GameManager.audio_synth:
                GameManager.audio_synth.play_sfx("acid_sizzle", 0.8, -2.0)

func _process_state_machine(delta: float) -> void:
    state_timer -= delta
    
    match current_state:
        State.WANDER:
            if global_position.distance_to(wander_target) < 1.0 or state_timer <= 0.0:
                wander_target = global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
                wander_target.x = clampf(wander_target.x, -5.2, 5.2)
                wander_target.z = clampf(wander_target.z, -3.2, 3.2)
                state_timer = randf_range(3.0, 6.0)
                
            # Seek food if hungry
            if atp_energy < 50.0 or is_hyper_metabolic:
                _seek_nearest_food_or_prey()
                
            # Seek severed organ to graft
            _seek_nearest_severed_organ()
            
        State.GRAZE:
            if target_entity and is_instance_valid(target_entity):
                wander_target = target_entity.global_position
                if global_position.distance_to(target_entity.global_position) < 1.2:
                    _consume_food(target_entity)
            else:
                current_state = State.WANDER
                
        State.GRAFT_ORGAN:
            if target_organ_chunk and is_instance_valid(target_organ_chunk):
                wander_target = target_organ_chunk.global_position
                if global_position.distance_to(target_organ_chunk.global_position) < 1.2:
                    _perform_cannibal_graft(target_organ_chunk)
            else:
                current_state = State.WANDER
                
        State.STALK, State.COMBAT:
            if target_entity and is_instance_valid(target_entity):
                wander_target = target_entity.global_position
                aggro_level = 1.0
                if global_position.distance_to(target_entity.global_position) < 1.4:
                    _attack_target(target_entity, delta)
            else:
                aggro_level = 0.0
                current_state = State.WANDER
                
        State.TUMBLE_OVERTURNED:
            tumble_timer -= delta
            velocity.x = 0
            velocity.z = 0
            rotation.z = PI # Upside down flailing!
            if tumble_timer <= 0.0:
                rotation.z = dynamic_roll_angle
                current_state = State.WANDER
                
        State.CORDYCEPS_CLIMB:
            # Zombie climbs to highest canopy point directly under heat lamp (Y > 4.5, X: 0, Z: 0)
            wander_target = Vector3(0, 5.2, 0)
            if global_position.y > 4.2:
                # Thorax burst event! Spores rain!
                _burst_cordyceps_spores()

func _apply_movement_and_tilt(delta: float) -> void:
    if current_state == State.TUMBLE_OVERTURNED:
        return
        
    # Gravity
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0
        
    var dir = (wander_target - global_position)
    dir.y = 0
    
    var speed = genome.base_move_speed
    if is_nose_dragging:
        speed *= 0.55 # -45% movement speed penalty
    if total_mass > genome.buoyancy_limit_kg and global_position.y < 0.4:
        speed *= 0.25 # Mud sump bog down
        
    if dir.length_squared() > 0.04:
        var move_vec = dir.normalized() * speed
        
        # Crab-Limping navigation drift toward heavy side
        if is_crab_limping:
            var drift_angle = (center_of_mass_offset.x) * 1.8 * delta
            move_vec = move_vec.rotated(Vector3.UP, drift_angle)
            
        velocity.x = move_vec.x
        velocity.z = move_vec.z
        
        # Orient smoothly towards movement vector
        var target_rot_y = atan2(-move_vec.x, -move_vec.z)
        rotation.y = lerp_angle(rotation.y, target_rot_y, 4.0 * delta)
        
        # Trip & tumble hazard for nose draggers while sprinting
        if is_nose_dragging and (current_state == State.COMBAT or current_state == State.STALK):
            if randf() < 0.20 * delta:
                current_state = State.TUMBLE_OVERTURNED
                tumble_timer = 4.0
                GameManager.post_notification("TRIPPED! %s nose-dragged and tumbled overturned!" % genome.species_name)
    else:
        velocity.x = movef_towards(velocity.x, 0.0, speed * delta * 4.0)
        velocity.z = movef_towards(velocity.z, 0.0, speed * delta * 4.0)
        
    # Apply CoM pitch & roll tilts
    rotation.x = lerp_angle(rotation.x, dynamic_pitch_angle, 6.0 * delta)
    rotation.z = lerp_angle(rotation.z, dynamic_roll_angle, 6.0 * delta)
    
    move_and_slide()
    
    # Update Procedural Leg IK
    if anatomy and anatomy.leg_ik:
        anatomy.leg_ik.update_ik(delta, velocity)

func _process_secondary_motion(delta: float) -> void:
    # Breathing thorax expansion
    var breath = sin(time_alive * 3.5) * 0.03
    if anatomy and anatomy.thorax_mesh:
        anatomy.thorax_mesh.scale = Vector3(1.0 + breath, 1.0 + breath, 1.0 - breath * 0.5)

func _seek_nearest_food_or_prey() -> void:
    # Search for consumable pellets or weaker creatures
    var space_state = get_world_3d().direct_space_state
    var sphere = SphereShape3D.new()
    sphere.radius = 7.0 if not has_biolume_curse else 12.0
    
    var query = PhysicsShapeQueryParameters3D.new()
    query.shape = sphere
    query.transform = global_transform
    query.collision_mask = 2 | 8 # Creatures & Pellets
    
    var results = space_state.intersect_shape(query)
    for res in results:
        var collider = res.collider
        if collider == self:
            continue
        if collider.is_in_group("consumable_pellet"):
            target_entity = collider
            current_state = State.GRAZE
            return
        elif collider is CreatureEntity and is_hyper_metabolic:
            # Ravenous attack!
            target_entity = collider
            current_state = State.COMBAT
            return

func _seek_nearest_severed_organ() -> void:
    var space_state = get_world_3d().direct_space_state
    var sphere = SphereShape3D.new()
    sphere.radius = 6.0
    var query = PhysicsShapeQueryParameters3D.new()
    query.shape = sphere
    query.transform = global_transform
    query.collision_mask = 4 # Severed organs layer
    
    var results = space_state.intersect_shape(query)
    for res in results:
        if res.collider is SeveredOrganChunk:
            var chunk: SeveredOrganChunk = res.collider
            if _evaluate_graft_desire(chunk.organ_data) > 0.0:
                target_organ_chunk = chunk
                current_state = State.GRAFT_ORGAN
                return

func _evaluate_graft_desire(organ: OrganData) -> float:
    if not organ: return 0.0
    var current_in_socket = genome.get_organ_in_socket(organ.socket)
    if not current_in_socket:
        return 10.0 # High desire if socket is empty!
    if organ.combat_value > current_in_socket.combat_value + 5.0:
        return 5.0 # Better weapon!
    if organ.defense_value > current_in_socket.defense_value + 10.0:
        return 5.0 # Better armor!
    return 0.0

func _perform_cannibal_graft(chunk: SeveredOrganChunk) -> void:
    if not chunk or not is_instance_valid(chunk):
        current_state = State.WANDER
        return
        
    var new_organ = chunk.organ_data.clone()
    new_organ.origin_tag = "[Stolen from carcass]"
    new_organ.is_somatic = true
    
    # Amputate / drop existing organ if present
    var existing = genome.get_organ_in_socket(new_organ.socket)
    if existing:
        _spawn_severed_chunk(existing)
        
    genome.set_organ_in_socket(new_organ.socket, new_organ)
    anatomy.attach_organ(new_organ.socket, new_organ, true)
    recalculate_physics_and_complications()
    
    chunk.queue_free()
    target_organ_chunk = null
    current_state = State.WANDER
    
    GameManager.post_notification("SOMATIC GRAFT! %s grafted %s!" % [genome.species_name, new_organ.organ_name])

func _consume_food(pellet: Node3D) -> void:
    atp_energy = clampf(atp_energy + 40.0, 0.0, max_atp_energy)
    current_health = clampf(current_health + 20.0, 0.0, max_health)
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("wet_crunch", 1.1, 1.0)
    pellet.queue_free()
    target_entity = null
    current_state = State.WANDER

func _attack_target(victim: Node3D, delta: float) -> void:
    var damage = 18.0
    if genome.mandible_l_organ: damage += genome.mandible_l_organ.combat_value
    if genome.mandible_r_organ: damage += genome.mandible_r_organ.combat_value
    
    if victim is CreatureEntity:
        victim.take_damage(damage * delta, genome.species_name)
        if GameManager.audio_synth and randf() < 0.15:
            GameManager.audio_synth.play_sfx("wet_crunch", 0.9, 1.5)

func take_damage(amount: float, source: String = "") -> void:
    var defense = 0.0
    if genome.dorsal_organ:
        defense = genome.dorsal_organ.defense_value
    var actual_damage = maxf(amount * (1.0 - defense / 100.0), 1.0)
    current_health -= actual_damage
    
    if current_health <= 0.0:
        die(source)

func die(killer: String = "") -> void:
    GameManager.post_notification("FATALITY: %s perished (%s)!" % [genome.species_name, killer], true)
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("creature_screech", 0.85, 3.0)
        
    # Break apart into 2 to 3 SeveredOrganChunk rigid bodies!
    var dropped = 0
    for organ in genome.get_all_organs():
        if dropped < 3:
            _spawn_severed_chunk(organ)
            dropped += 1
            
    queue_free()

func _spawn_severed_chunk(organ: OrganData) -> void:
    var chunk_scene = load("res://scenes/SeveredOrganChunk.tscn")
    var chunk: SeveredOrganChunk = chunk_scene.instantiate()
    chunk.organ_data = organ.clone()
    chunk.position = global_position + Vector3(randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4))
    get_parent().add_child(chunk)
    # Apply impulse so it rolls down terrain slopes
    chunk.apply_central_impulse(Vector3(randf_range(-2, 2), 3.0, randf_range(-2, 2)))

func amputate_organ(socket_type: OrganData.SocketType) -> OrganData:
    var organ = genome.remove_organ_in_socket(socket_type)
    if not organ:
        return null
        
    anatomy.detach_organ(socket_type, true)
    recalculate_physics_and_complications()
    
    # Creature takes 15% HP damage, screeches, drops severed chunk
    take_damage(max_health * 0.15, "Surgical Amputation")
    _spawn_severed_chunk(organ)
    
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("organ_rip", randf_range(0.95, 1.05), 3.0)
        GameManager.audio_synth.play_sfx("creature_screech", 1.2, 2.0)
        
    GameManager.post_notification("SURGERY: %s amputated from %s!" % [organ.organ_name, genome.species_name], true)
    GameManager.specimen_amputated.emit(self, organ)
    return organ

func _burst_cordyceps_spores() -> void:
    GameManager.spore_density = clampf(GameManager.spore_density + 35.0, 0.0, 100.0)
    GameManager.post_notification("⚠ SPORE BURST! %s detonated cordyceps canopy hazard!" % genome.species_name, true)
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("organ_rip", 0.7, 4.0)
    die("Cordyceps Spore Detonation")

func movef_towards(from: float, to: float, delta: float) -> float:
    if absf(to - from) <= delta:
        return to
    return from + signf(to - from) * delta

func _generate_default_genome() -> GenomeData:
    var g = GenomeData.new()
    g.specimen_id = "Specimen-%02d" % randi_range(1, 99)
    g.species_name = "Abnormalia Beetloid"
    g.locomotion_organ = OrganData.create_organ("legs_insectoid_6")
    g.cranial_organ = OrganData.create_organ("stalker_eyes")
    return g

