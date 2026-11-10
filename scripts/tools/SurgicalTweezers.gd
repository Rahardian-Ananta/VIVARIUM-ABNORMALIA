class_name SurgicalTweezers
extends Node3D

var held_creature: CreatureEntity = null
var held_organ_chunk: SeveredOrganChunk = null
var grab_spring_k: float = 35.0
var grab_damping: float = 5.0
var target_grab_position: Vector3 = Vector3.ZERO
var is_active_drag: bool = false

# Surgery mode tension tracking
var surgery_drag_start: Vector2 = Vector2.ZERO
var surgery_target_socket: OrganData.SocketType = OrganData.SocketType.CRANIAL
var surgery_tension_threshold: float = 60.0 # Screen pixels drag threshold to rip organ

func handle_interaction(ray_hit: Dictionary, button_index: int, is_drag: bool, screen_pos: Vector2 = Vector2.ZERO) -> void:
    if button_index != MOUSE_BUTTON_LEFT:
        return
        
    if not is_drag and ray_hit.is_empty():
        release()
        return
        
    # Drag update
    if is_drag:
        if not ray_hit.is_empty():
            target_grab_position = ray_hit.position + Vector3(0, 1.2, 0)
            
        # If in surgery mode and holding creature, check tension threshold
        if GameManager.surgery_mode_active and held_creature:
            var dist_drag = screen_pos.distance_to(surgery_drag_start)
            if dist_drag > surgery_tension_threshold:
                _execute_amputation()
        return

    # Fresh Click (Pressed or Released)
    if not is_drag:
        # Check click down
        if not ray_hit.is_empty():
            var collider = ray_hit.collider
            if collider is CreatureEntity:
                var creature: CreatureEntity = collider
                GameManager.select_specimen(creature)
                
                if GameManager.surgery_mode_active:
                    # Target closest socket to hit position
                    surgery_drag_start = screen_pos
                    surgery_target_socket = _determine_closest_socket(creature, ray_hit.position)
                    held_creature = creature
                else:
                    # Relocate Mode
                    grab_creature(creature, ray_hit.position + Vector3(0, 1.2, 0))
            elif collider is SeveredOrganChunk:
                grab_chunk(collider, ray_hit.position + Vector3(0, 0.8, 0))
        else:
            release()

func grab_creature(creature: CreatureEntity, grab_pos: Vector3) -> void:
    held_creature = creature
    target_grab_position = grab_pos
    is_active_drag = true
    held_creature.current_state = CreatureEntity.State.HELD_BY_TWEEZERS
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("insect_chirp", 1.2, -1.0)

func grab_chunk(chunk: SeveredOrganChunk, grab_pos: Vector3) -> void:
    held_organ_chunk = chunk
    target_grab_position = grab_pos
    is_active_drag = true
    chunk.freeze = true

func release() -> void:
    if held_creature:
        # Check if dropped in Breeding Chamber (Upper right canopy or Isolator area)
        if target_grab_position.x > 3.0 and target_grab_position.y > 3.5:
            if not GameManager.breeding_chamber_creatures.has(held_creature):
                GameManager.breeding_chamber_creatures.append(held_creature)
                GameManager.post_notification("Placed %s in Breeding Isolator!" % held_creature.genome.species_name)
        else:
            GameManager.breeding_chamber_creatures.erase(held_creature)
            
        held_creature.current_state = CreatureEntity.State.WANDER
        held_creature = null
        
    if held_organ_chunk:
        held_organ_chunk.freeze = false
        held_organ_chunk.apply_central_impulse(Vector3(0, -1, 0))
        held_organ_chunk = null
        
    is_active_drag = false

func _physics_process(delta: float) -> void:
    if is_active_drag and held_creature:
        # Spring physics towards target_grab_position
        var displacement = target_grab_position - held_creature.global_position
        var spring_force = displacement * grab_spring_k
        var damp_force = -held_creature.velocity * grab_damping
        var total_accel = (spring_force + damp_force) / maxf(held_creature.total_mass, 0.5)
        
        held_creature.velocity += total_accel * delta
        held_creature.move_and_slide()
        
    elif is_active_drag and held_organ_chunk:
        held_organ_chunk.global_position = held_organ_chunk.global_position.lerp(target_grab_position, 12.0 * delta)

func _determine_closest_socket(creature: CreatureEntity, hit_point: Vector3) -> OrganData.SocketType:
    var local_hit = creature.global_transform.affine_inverse() * hit_point
    
    # Check Z forward/back and Y top/bottom
    if local_hit.y > 0.4:
        return OrganData.SocketType.DORSAL
    elif local_hit.z < -0.4:
        if local_hit.y > 0.2:
            return OrganData.SocketType.CRANIAL
        elif local_hit.x < 0:
            return OrganData.SocketType.MANDIBLE_L
        else:
            return OrganData.SocketType.MANDIBLE_R
    elif local_hit.z > 0.4:
        return OrganData.SocketType.CAUDAL
    elif local_hit.y < -0.1:
        return OrganData.SocketType.LOCOMOTION
        
    return OrganData.SocketType.DORSAL

func _execute_amputation() -> void:
    if not held_creature:
        return
        
    var organ = held_creature.amputate_organ(surgery_target_socket)
    if organ:
        GameManager.post_notification("AMPUTATED %s!" % organ.organ_name, true)
        
    release()

