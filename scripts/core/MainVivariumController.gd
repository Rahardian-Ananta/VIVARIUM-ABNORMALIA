class_name MainVivariumController
extends Node3D

@onready var creatures_root: Node3D = $Creatures
@onready var terrarium_builder: TerrariumBuilder = $TerrariumBuilder
@onready var climate_controller: ClimateController = $ClimateController
@onready var input_router: InputRouter = $InputRouter
@onready var tool_controller: OverseerToolController = $OverseerToolController

func _ready() -> void:
    # Link climate heat lamp
    if terrarium_builder and climate_controller:
        climate_controller.heat_lamp = terrarium_builder.heat_lamp
        
    _spawn_initial_diverse_ecosystem()
    _spawn_ambient_spore_clouds()

func _spawn_initial_diverse_ecosystem() -> void:
    # 1. Apex Mantis Predator
    var g1 = GenomeData.new()
    g1.specimen_id = "Specimen-01"
    g1.species_name = "Vorax-Mantid"
    g1.base_body_color = Color(0.2, 0.45, 0.25)
    g1.mandible_l_organ = OrganData.create_organ("mantis_scythe_l")
    g1.mandible_r_organ = OrganData.create_organ("mantis_scythe_r")
    g1.cranial_organ = OrganData.create_organ("stalker_eyes")
    g1.locomotion_organ = OrganData.create_organ("legs_insectoid_6")
    _instantiate_creature(g1, Vector3(2.5, 1.8, 1.0))

    # 2. Balanced Rhino-Crusher (Heavy tail counterbalancing jaws)
    var g2 = GenomeData.new()
    g2.specimen_id = "Specimen-02"
    g2.species_name = "Pachy-Goliath"
    g2.base_body_color = Color(0.45, 0.35, 0.22)
    g2.mandible_l_organ = OrganData.create_organ("crusher_mandibles_l")
    g2.mandible_r_organ = OrganData.create_organ("crusher_mandibles_r")
    g2.caudal_organ = OrganData.create_organ("counterbalance_tail") # Prevents nose drag!
    g2.locomotion_organ = OrganData.create_organ("legs_heavy_strider")
    _instantiate_creature(g2, Vector3(3.8, 2.4, -1.0))

    # 3. Complication Showcase: Nose-Dragger (Crushers with NO tail)
    var g3 = GenomeData.new()
    g3.specimen_id = "Specimen-03"
    g3.species_name = "Rostrum-Scraper"
    g3.base_body_color = Color(0.55, 0.25, 0.18)
    g3.mandible_l_organ = OrganData.create_organ("crusher_mandibles_l")
    g3.mandible_r_organ = OrganData.create_organ("crusher_mandibles_r")
    # No tail -> CoM offset < -0.35 -> nose-dragging & dirt particles!
    g3.locomotion_organ = OrganData.create_organ("legs_insectoid_6")
    _instantiate_creature(g3, Vector3(0.5, 1.2, 0.5))

    # 4. Complication Showcase: Bilateral Asymmetry / Crab-Limping (Heavy claw ONLY on left)
    var g4 = GenomeData.new()
    g4.specimen_id = "Specimen-04"
    g4.species_name = "Lurch-Brachyura"
    g4.base_body_color = Color(0.6, 0.42, 0.25)
    g4.mandible_l_organ = OrganData.create_organ("crusher_mandibles_l") # Unbalanced X mass!
    g4.locomotion_organ = OrganData.create_organ("legs_insectoid_6")
    _instantiate_creature(g4, Vector3(1.5, 1.2, -1.8))

    # 5. Complication Showcase: Bioluminescent Siren (+250% Aggro Magnet)
    var g5 = GenomeData.new()
    g5.specimen_id = "Specimen-05"
    g5.species_name = "Lucent-Phantasm"
    g5.base_body_color = Color(0.15, 0.35, 0.45)
    g5.dorsal_organ = OrganData.create_organ("biolume_sac")
    g5.cranial_organ = OrganData.create_organ("thermal_pits")
    g5.locomotion_organ = OrganData.create_organ("legs_spider_8")
    _instantiate_creature(g5, Vector3(-1.8, 1.2, 1.5))

    # 6. Complication Showcase: Cordyceps Parasite Carrier (Climbs to canopy!)
    var g6 = GenomeData.new()
    g6.specimen_id = "Specimen-06"
    g6.species_name = "Fungus-Vessel"
    g6.base_body_color = Color(0.4, 0.38, 0.25)
    g6.cranial_organ = OrganData.create_organ("cordyceps_stalk", "[Parasitic Infection]")
    g6.dorsal_organ = OrganData.create_organ("spore_pustules")
    g6.locomotion_organ = OrganData.create_organ("legs_spider_8")
    var c6 = _instantiate_creature(g6, Vector3(-2.8, 1.6, -1.0))
    c6.cordyceps_stage = 2
    c6.current_state = CreatureEntity.State.CORDYCEPS_CLIMB

func _instantiate_creature(genome_data: GenomeData, spawn_pos: Vector3) -> CreatureEntity:
    var scene = load("res://scenes/CreatureBase.tscn")
    var creature: CreatureEntity = scene.instantiate()
    creature.genome = genome_data
    creature.position = spawn_pos
    creatures_root.add_child(creature)
    return creature

func _spawn_ambient_spore_clouds() -> void:
    var hazards_root = $SporeHazards
    for i in range(2):
        var cloud = SporeCloud.new()
        cloud.name = "SporeCloud_%d" % i
        cloud.position = Vector3(randf_range(-3, 3), randf_range(1, 3.5), randf_range(-2, 2))
        
        var shape = CollisionShape3D.new()
        var sp = SphereShape3D.new()
        sp.radius = 1.2
        shape.shape = sp
        cloud.add_child(shape)
        
        var particles = CPUParticles3D.new()
        particles.amount = 32
        particles.lifetime = 1.5
        particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
        particles.emission_sphere_radius = 1.0
        particles.direction = Vector3.UP
        particles.gravity = Vector3(0, 0.2, 0)
        particles.initial_velocity_min = 0.2
        particles.initial_velocity_max = 0.6
        
        var p_mesh = SphereMesh.new()
        p_mesh.radius = 0.05
        p_mesh.height = 0.1
        var p_mat = StandardMaterial3D.new()
        p_mat.albedo_color = Color(0.85, 0.65, 0.15, 0.7)
        p_mat.emission_enabled = true
        p_mat.emission = Color(0.9, 0.7, 0.1)
        p_mesh.material = p_mat
        particles.mesh = p_mesh
        cloud.add_child(particles)
        
        hazards_root.add_child(cloud)

