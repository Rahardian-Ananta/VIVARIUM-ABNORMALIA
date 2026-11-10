class_name OverseerToolController
extends Node3D

@export var input_router: InputRouter
@export var tweezers: SurgicalTweezers

var glass_tap_cooldown: float = 0.0
const GLASS_TAP_INTERVAL: float = 3.0

func _ready() -> void:
    if input_router:
        input_router.raycast_interacted.connect(_on_raycast_interacted)
    if not tweezers:
        tweezers = SurgicalTweezers.new()
        tweezers.name = "SurgicalTweezers"
        add_child(tweezers)

func _process(delta: float) -> void:
    if glass_tap_cooldown > 0.0:
        glass_tap_cooldown -= delta
        
    _handle_keyboard_shortcuts()

func _handle_keyboard_shortcuts() -> void:
    if Input.is_action_just_pressed("ui_focus_next"): # Tab
        pass
    if Input.is_key_pressed(KEY_1):
        GameManager.set_tool(GameManagerClass.OverseerTool.FEED)
    elif Input.is_key_pressed(KEY_2):
        GameManager.set_tool(GameManagerClass.OverseerTool.MUTAGEN)
    elif Input.is_key_pressed(KEY_3):
        GameManager.set_tool(GameManagerClass.OverseerTool.TWEEZERS)
    elif Input.is_key_pressed(KEY_4):
        GameManager.set_tool(GameManagerClass.OverseerTool.GLASS_TAP)
    elif Input.is_key_pressed(KEY_5):
        GameManager.set_tool(GameManagerClass.OverseerTool.JAR_SCOOP)
        
    if Input.is_key_pressed(KEY_SHIFT):
        if not GameManager.surgery_mode_active and GameManager.current_tool == GameManagerClass.OverseerTool.TWEEZERS:
            GameManager.set_surgery_mode(true)
    elif not Input.is_key_pressed(KEY_SHIFT) and GameManager.surgery_mode_active:
        # Auto-release shift only if not clicked on UI toggle
        pass

func _on_raycast_interacted(hit: Dictionary, button_index: int, is_drag: bool) -> void:
    if button_index != MOUSE_BUTTON_LEFT:
        return
        
    match GameManager.current_tool:
        GameManagerClass.OverseerTool.FEED:
            if not is_drag and not hit.is_empty():
                _drop_nutrient_pellet(hit.position)
        GameManagerClass.OverseerTool.MUTAGEN:
            if not is_drag and not hit.is_empty():
                _drop_mutagenic_bait(hit.position)
        GameManagerClass.OverseerTool.TWEEZERS:
            var mouse_pos = get_viewport().get_mouse_position()
            tweezers.handle_interaction(hit, button_index, is_drag, mouse_pos)
        GameManagerClass.OverseerTool.GLASS_TAP:
            if not is_drag and not hit.is_empty():
                _trigger_glass_tap(hit.position)
        GameManagerClass.OverseerTool.JAR_SCOOP:
            if not is_drag and not hit.is_empty():
                _scoop_specimen(hit.collider)

func _drop_nutrient_pellet(world_pos: Vector3) -> void:
    if not GameManager.spend_research_points(5):
        return
        
    var pellet = RigidBody3D.new()
    pellet.name = "NutrientPellet"
    pellet.collision_layer = 8 # Pellets
    pellet.collision_mask = 1 | 8
    pellet.add_to_group("consumable_pellet")
    pellet.position = world_pos + Vector3(0, 1.5, 0)
    
    var mesh = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.22
    sphere.height = 0.44
    mesh.mesh = sphere
    
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.85, 0.55, 0.2)
    mesh.material_override = mat
    pellet.add_child(mesh)
    
    var col = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 0.22
    col.shape = shape
    pellet.add_child(col)
    
    get_parent().add_child(pellet)
    pellet.apply_central_impulse(Vector3(randf_range(-0.5, 0.5), -1.0, randf_range(-0.5, 0.5)))
    
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("pellet_drop", 1.0, 1.0)
    GameManager.post_notification("Dropped Nutrient Pellet (-5 RP)")

func _drop_mutagenic_bait(world_pos: Vector3) -> void:
    if not GameManager.spend_research_points(15):
        return
        
    var bait = RigidBody3D.new()
    bait.name = "MutagenicBait"
    bait.collision_layer = 8
    bait.collision_mask = 1 | 8
    bait.position = world_pos + Vector3(0, 1.5, 0)
    
    var mesh = MeshInstance3D.new()
    var prism = PrismMesh.new()
    prism.size = Vector3(0.35, 0.4, 0.35)
    mesh.mesh = prism
    
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.1, 0.95, 0.2)
    mat.emission_enabled = true
    mat.emission = Color(0.1, 0.8, 0.2)
    mesh.material_override = mat
    bait.add_child(mesh)
    
    var col = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = Vector3(0.35, 0.4, 0.35)
    col.shape = shape
    bait.add_child(col)
    
    # Area for triggering mutation on nearby creature
    var area = Area3D.new()
    area.collision_layer = 8
    area.collision_mask = 2
    var area_col = CollisionShape3D.new()
    var sp_shape = SphereShape3D.new()
    sp_shape.radius = 0.6
    area_col.shape = sp_shape
    area.add_child(area_col)
    bait.add_child(area)
    
    area.body_entered.connect(func(body: Node3D):
        if body is CreatureEntity:
            _apply_mutagen_to_creature(body, bait)
    )
    
    get_parent().add_child(bait)
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("acid_sizzle", 1.1, 1.0)
    GameManager.post_notification("Deployed Mutagenic Acid Bait (-15 RP)")

func _apply_mutagen_to_creature(creature: CreatureEntity, bait: Node3D) -> void:
    if not is_instance_valid(creature) or not is_instance_valid(bait):
        return
        
    bait.queue_free()
    
    # Poison check: take damage
    creature.take_damage(25.0, "Mutagenic Shock")
    if not is_instance_valid(creature) or creature.current_health <= 0:
        return
        
    # Survivor mutates: Calcified Armor OR Acid Sprayers!
    var mutate_armor = randf() < 0.5
    if mutate_armor:
        var armor = OrganData.create_organ("calcified_armor", "[Somatic Mutagen]")
        creature.genome.set_organ_in_socket(OrganData.SocketType.DORSAL, armor)
        creature.anatomy.attach_organ(OrganData.SocketType.DORSAL, armor, true)
        GameManager.post_notification("MUTATION: %s synthesized Calcified Armor Plates!" % creature.genome.species_name, true)
    else:
        var acid = OrganData.create_organ("acid_sprayer_r", "[Somatic Mutagen]")
        creature.genome.set_organ_in_socket(OrganData.SocketType.MANDIBLE_R, acid)
        creature.anatomy.attach_organ(OrganData.SocketType.MANDIBLE_R, acid, true)
        GameManager.post_notification("MUTATION: %s mutated a Corrosive Acid Sprayer!" % creature.genome.species_name, true)
        
    creature.recalculate_physics_and_complications()

func _trigger_glass_tap(pos: Vector3) -> void:
    if glass_tap_cooldown > 0.0:
        GameManager.post_notification("Glass Tap recharging (%.1fs)..." % glass_tap_cooldown)
        return
        
    glass_tap_cooldown = GLASS_TAP_INTERVAL
    GameManager.trigger_shockwave(pos)
    
    # Enrage apex predators or scatter herbivores
    for creature in GameManager.active_creatures:
        if creature is CreatureEntity:
            var dist = creature.global_position.distance_to(pos)
            if dist < 8.0:
                if creature.aggro_level > 0.4:
                    # Charge glass!
                    creature.wander_target = pos
                    creature.current_state = CreatureEntity.State.COMBAT
                    GameManager.post_notification("APEX ENRAGED! %s charges the glass!" % creature.genome.species_name, true)
                else:
                    # Scatter away from shockwave
                    var away = (creature.global_position - pos).normalized() * 4.0
                    creature.wander_target = creature.global_position + away
                    creature.current_state = CreatureEntity.State.WANDER

func _scoop_specimen(target: Node) -> void:
    if not (target is CreatureEntity):
        return
        
    var creature: CreatureEntity = target
    var base_value = 25.0
    var grafted_count = float(creature.genome.count_grafted_organs())
    var complications_count = 0.0
    if creature.is_nose_dragging: complications_count += 1.0
    if creature.is_crab_limping: complications_count += 1.0
    if creature.is_hyper_metabolic: complications_count += 1.0
    if creature.has_biolume_curse: complications_count += 1.0
    if creature.cordyceps_stage > 0: complications_count += 1.5
    
    # Formula: Value = BaseValue * (1 + 0.6 * GraftedCount) * (1 + 0.8 * ComplicationsCount)
    var final_value = int(base_value * (1.0 + 0.6 * grafted_count) * (1.0 + 0.8 * complications_count))
    GameManager.add_research_points(final_value)
    
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("jar_vacuum", 1.0, 2.0)
        
    GameManager.post_notification("HARVESTED %s for +%d RP! (Monstrosity Multiplier x%.1f)" % [creature.genome.species_name, final_value, (1.0 + 0.8 * complications_count)], true)
    creature.queue_free()

