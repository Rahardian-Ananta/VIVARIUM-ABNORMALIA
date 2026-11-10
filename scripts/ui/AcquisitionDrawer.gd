class_name AcquisitionDrawer
extends Control

@onready var drawer_panel: PanelContainer = $DrawerPanel
@onready var toggle_btn: Button = $ToggleDrawerBtn
@onready var trap_status_label: Label = $DrawerPanel/Margin/VBox/TrapsSection/TrapStatus
@onready var isolator_status_label: Label = $DrawerPanel/Margin/VBox/BreedingSection/IsolatorStatus
@onready var breed_button: Button = $DrawerPanel/Margin/VBox/BreedingSection/BreedBtn

var is_open: bool = false
var active_trap_time: float = 0.0
var active_trap_type: String = ""

func _ready() -> void:
    drawer_panel.visible = false
    toggle_btn.pressed.connect(_on_toggle_pressed)
    _setup_market_buttons()
    _setup_trap_buttons()
    breed_button.pressed.connect(_on_breed_pressed)

func _process(delta: float) -> void:
    if active_trap_time > 0.0:
        active_trap_time -= delta
        trap_status_label.text = "Expedition [%s]: %.1fs remaining..." % [active_trap_type, active_trap_time]
        if active_trap_time <= 0.0:
            _resolve_trap_catch()
            
    # Update isolator status
    var count = GameManager.breeding_chamber_creatures.size()
    isolator_status_label.text = "Isolator Occupants: %d / 2" % count
    breed_button.disabled = (count < 2)

func _on_toggle_pressed() -> void:
    is_open = not is_open
    drawer_panel.visible = is_open
    toggle_btn.text = "▲ CLOSE ACQUISITION DRAWER" if is_open else "▼ SPECIMEN ACQUISITION DRAWER"

func _setup_trap_buttons() -> void:
    var carcass_btn: Button = $DrawerPanel/Margin/VBox/TrapsSection/HBox/CarcassTrapBtn
    var sap_btn: Button = $DrawerPanel/Margin/VBox/TrapsSection/HBox/SapTrapBtn
    var spore_btn: Button = $DrawerPanel/Margin/VBox/TrapsSection/HBox/SporeTrapBtn
    
    carcass_btn.pressed.connect(func(): _deploy_trap("Rotten Carcass", 10.0))
    sap_btn.pressed.connect(func(): _deploy_trap("Fermented Sap", 10.0))
    spore_btn.pressed.connect(func(): _deploy_trap("Cave Spores", 10.0))

func _deploy_trap(trap_name: String, duration: float) -> void:
    if active_trap_time > 0.0:
        GameManager.post_notification("Expedition already underway!")
        return
    active_trap_type = trap_name
    active_trap_time = duration
    GameManager.post_notification("Deployed Wild Trap [%s]!" % trap_name)

func _resolve_trap_catch() -> void:
    trap_status_label.text = "Trap retrieved! Specimen captured."
    GameManager.post_notification("Trap expedition returned with wild specimen!", true)
    
    var g = GenomeData.new()
    g.specimen_id = "Wild-%02d" % randi_range(1, 99)
    g.generation = 1
    g.locomotion_organ = OrganData.create_organ("legs_insectoid_6")
    
    match active_trap_type:
        "Rotten Carcass":
            g.species_name = "Putrid Necrophage"
            g.mandible_l_organ = OrganData.create_organ("crusher_mandibles_l")
            g.dorsal_organ = OrganData.create_organ("calcified_armor")
        "Fermented Sap":
            g.species_name = "Sap Mantid"
            g.mandible_r_organ = OrganData.create_organ("mantis_scythe_r")
            g.caudal_organ = OrganData.create_organ("counterbalance_tail")
        "Cave Spores":
            g.species_name = "Subterranean Fungal Stalker"
            g.cranial_organ = OrganData.create_organ("thermal_pits")
            g.dorsal_organ = OrganData.create_organ("spore_pustules")
            
    _spawn_creature_in_tank(g, Vector3(randf_range(-2, 2), 2.5, randf_range(-1, 1)))

func _setup_market_buttons() -> void:
    var scythe_btn: Button = $DrawerPanel/Margin/VBox/MarketSection/HBox/BuyScytheBtn
    var armor_btn: Button = $DrawerPanel/Margin/VBox/MarketSection/HBox/BuyArmorBtn
    var biolume_btn: Button = $DrawerPanel/Margin/VBox/MarketSection/HBox/BuyBiolumeBtn
    var mystery_btn: Button = $DrawerPanel/Margin/VBox/MarketSection/HBox/BuyMysteryBtn
    
    scythe_btn.pressed.connect(func(): _buy_market_specimen("Mantis Apex", 45, "scythe"))
    armor_btn.pressed.connect(func(): _buy_market_specimen("Armored Strider", 50, "armor"))
    biolume_btn.pressed.connect(func(): _buy_market_specimen("Biolume Stalker", 60, "biolume"))
    mystery_btn.pressed.connect(func(): _buy_unlabeled_seized_jar())

func _buy_market_specimen(specimen_title: String, cost: int, archetype: String) -> void:
    if not GameManager.spend_research_points(cost):
        return
        
    var g = GenomeData.new()
    g.specimen_id = "Boutique-%02d" % randi_range(1, 99)
    g.species_name = specimen_title
    
    match archetype:
        "scythe":
            g.locomotion_organ = OrganData.create_organ("legs_spider_8")
            g.mandible_l_organ = OrganData.create_organ("mantis_scythe_l")
            g.mandible_r_organ = OrganData.create_organ("mantis_scythe_r")
        "armor":
            g.locomotion_organ = OrganData.create_organ("legs_heavy_strider")
            g.dorsal_organ = OrganData.create_organ("calcified_armor")
            g.caudal_organ = OrganData.create_organ("counterbalance_tail")
        "biolume":
            g.locomotion_organ = OrganData.create_organ("legs_insectoid_6")
            g.dorsal_organ = OrganData.create_organ("biolume_sac")
            g.cranial_organ = OrganData.create_organ("thermal_pits")
            
    _spawn_creature_in_tank(g, Vector3(0, 3.0, 0))
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("jar_vacuum", 1.1, 1.0)
    GameManager.post_notification("Purchased %s (-%d RP)" % [specimen_title, cost])

func _buy_unlabeled_seized_jar() -> void:
    if not GameManager.spend_research_points(40):
        return
        
    # 50% chance ultra-rare apex mutant, 50% parasite swarm detonation!
    if randf() < 0.5:
        # Apex monstrosity
        var g = GenomeData.new()
        g.specimen_id = "ApexAbomination"
        g.species_name = "Giga-Chimera Apex"
        g.locomotion_organ = OrganData.create_organ("legs_spider_8")
        g.mandible_l_organ = OrganData.create_organ("crusher_mandibles_l")
        g.mandible_r_organ = OrganData.create_organ("mantis_scythe_r")
        g.dorsal_organ = OrganData.create_organ("calcified_armor")
        g.caudal_organ = OrganData.create_organ("scorpion_stinger")
        _spawn_creature_in_tank(g, Vector3(0, 3.5, 0))
        GameManager.post_notification("JACKPOT! Unlabeled jar contained an Apex Chimera!", true)
    else:
        # Parasite swarm detonation
        GameManager.spore_density = clampf(GameManager.spore_density + 50.0, 0.0, 100.0)
        GameManager.post_notification("DANGER! Seized jar ruptured into a Parasitic Spore Swarm!", true)
        if GameManager.audio_synth:
            GameManager.audio_synth.play_sfx("organ_rip", 0.8, 3.0)

func _on_breed_pressed() -> void:
    if GameManager.breeding_chamber_creatures.size() < 2:
        return
        
    var p_a: CreatureEntity = GameManager.breeding_chamber_creatures[0]
    var p_b: CreatureEntity = GameManager.breeding_chamber_creatures[1]
    
    var child_genome = p_a.genome.reproduce_with(p_b.genome)
    _spawn_creature_in_tank(child_genome, Vector3(3.5, 4.2, 0.0))
    
    GameManager.post_notification("HYBRID CLUTCH HATCHED: %s (Gen %d)!" % [child_genome.species_name, child_genome.generation], true)
    if GameManager.audio_synth:
        GameManager.audio_synth.play_sfx("organ_graft", 1.2, 2.0)

func _spawn_creature_in_tank(genome_data: GenomeData, spawn_pos: Vector3) -> void:
    var scene = load("res://scenes/CreatureBase.tscn")
    var creature: CreatureEntity = scene.instantiate()
    creature.genome = genome_data
    creature.position = spawn_pos
    
    var tank_root = get_tree().root.get_node("MainVivarium/Creatures")
    if tank_root:
        tank_root.add_child(creature)
    else:
        get_tree().current_scene.add_child(creature)

