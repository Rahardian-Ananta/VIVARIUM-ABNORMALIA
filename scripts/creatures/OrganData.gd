class_name OrganData
extends Resource

enum SocketType {
    CRANIAL,
    MANDIBLE_L,
    MANDIBLE_R,
    DORSAL,
    LOCOMOTION,
    CAUDAL
}

@export var organ_id: String = ""
@export var organ_name: String = ""
@export var socket: SocketType = SocketType.DORSAL
@export var mass_kg: float = 0.5
@export var atp_upkeep_per_sec: float = 0.3
@export var local_position: Vector3 = Vector3.ZERO
@export var max_health: float = 50.0
@export var current_health: float = 50.0
@export var origin_tag: String = "[Congenital]"
@export var is_somatic: bool = false
@export var rarity_rating: float = 1.0 # Multiplier for specimen jar value
@export var combat_value: float = 10.0
@export var defense_value: float = 0.0
@export var special_tag: String = ""
@export var color_tint: Color = Color(0.75, 0.65, 0.5, 1.0)
@export var scale_factor: Vector3 = Vector3.ONE

func get_socket_name() -> String:
    match socket:
        SocketType.CRANIAL: return "CRANIAL"
        SocketType.MANDIBLE_L: return "MANDIBLE_L"
        SocketType.MANDIBLE_R: return "MANDIBLE_R"
        SocketType.DORSAL: return "DORSAL"
        SocketType.LOCOMOTION: return "LOCOMOTION"
        SocketType.CAUDAL: return "CAUDAL"
    return "UNKNOWN"

static func create_organ(id: String, origin: String = "[Congenital]") -> OrganData:
    var organ = OrganData.new()
    organ.organ_id = id
    organ.origin_tag = origin
    organ.is_somatic = (origin != "[Congenital]")

    match id:
        "crusher_mandibles_l":
            organ.organ_name = "Crusher Mandible (L)"
            organ.socket = SocketType.MANDIBLE_L
            organ.mass_kg = 2.2 # Heavy anterior weight contributor!
            organ.atp_upkeep_per_sec = 0.6
            organ.local_position = Vector3(-0.35, -0.1, -0.85)
            organ.combat_value = 28.0
            organ.special_tag = "CRUSHER"
            organ.rarity_rating = 2.0
            organ.color_tint = Color(0.45, 0.2, 0.15)
        "crusher_mandibles_r":
            organ.organ_name = "Crusher Mandible (R)"
            organ.socket = SocketType.MANDIBLE_R
            organ.mass_kg = 2.2
            organ.atp_upkeep_per_sec = 0.6
            organ.local_position = Vector3(0.35, -0.1, -0.85)
            organ.combat_value = 28.0
            organ.special_tag = "CRUSHER"
            organ.rarity_rating = 2.0
            organ.color_tint = Color(0.45, 0.2, 0.15)
        "mantis_scythe_l":
            organ.organ_name = "Mantis Scythe (L)"
            organ.socket = SocketType.MANDIBLE_L
            organ.mass_kg = 1.4
            organ.atp_upkeep_per_sec = 0.7
            organ.local_position = Vector3(-0.4, 0.1, -0.75)
            organ.combat_value = 35.0
            organ.special_tag = "SCYTHE"
            organ.rarity_rating = 2.5
            organ.color_tint = Color(0.25, 0.45, 0.2)
        "mantis_scythe_r":
            organ.organ_name = "Mantis Scythe (R)"
            organ.socket = SocketType.MANDIBLE_R
            organ.mass_kg = 1.4
            organ.atp_upkeep_per_sec = 0.7
            organ.local_position = Vector3(0.4, 0.1, -0.75)
            organ.combat_value = 35.0
            organ.special_tag = "SCYTHE"
            organ.rarity_rating = 2.5
            organ.color_tint = Color(0.25, 0.45, 0.2)
        "acid_sprayer_l":
            organ.organ_name = "Acid Sprayer (L)"
            organ.socket = SocketType.MANDIBLE_L
            organ.mass_kg = 0.8
            organ.atp_upkeep_per_sec = 0.9
            organ.local_position = Vector3(-0.3, 0.0, -0.65)
            organ.combat_value = 22.0
            organ.special_tag = "ACID"
            organ.rarity_rating = 2.8
            organ.color_tint = Color(0.4, 0.8, 0.2)
        "acid_sprayer_r":
            organ.organ_name = "Acid Sprayer (R)"
            organ.socket = SocketType.MANDIBLE_R
            organ.mass_kg = 0.8
            organ.atp_upkeep_per_sec = 0.9
            organ.local_position = Vector3(0.3, 0.0, -0.65)
            organ.combat_value = 22.0
            organ.special_tag = "ACID"
            organ.rarity_rating = 2.8
            organ.color_tint = Color(0.4, 0.8, 0.2)
        "stalker_eyes":
            organ.organ_name = "Compound Stalker Eyes"
            organ.socket = SocketType.CRANIAL
            organ.mass_kg = 0.3
            organ.atp_upkeep_per_sec = 0.25
            organ.local_position = Vector3(0.0, 0.45, -0.55)
            organ.special_tag = "STALKER_EYES"
            organ.rarity_rating = 1.2
            organ.color_tint = Color(0.9, 0.1, 0.3)
        "thermal_pits":
            organ.organ_name = "Infrared Thermal Pits"
            organ.socket = SocketType.CRANIAL
            organ.mass_kg = 0.4
            organ.atp_upkeep_per_sec = 0.4
            organ.local_position = Vector3(0.0, 0.35, -0.6)
            organ.special_tag = "THERMAL_PITS"
            organ.rarity_rating = 2.2
            organ.color_tint = Color(0.85, 0.4, 0.1)
        "cordyceps_stalk":
            organ.organ_name = "Spore Cordyceps Stalk"
            organ.socket = SocketType.CRANIAL
            organ.mass_kg = 0.6
            organ.atp_upkeep_per_sec = 1.2 # Parasitic drain!
            organ.local_position = Vector3(0.0, 0.8, -0.3)
            organ.special_tag = "CORDYCEPS"
            organ.rarity_rating = 3.5
            organ.color_tint = Color(0.95, 0.45, 0.05)
        "calcified_armor":
            organ.organ_name = "Calcified Armor Plates"
            organ.socket = SocketType.DORSAL
            organ.mass_kg = 3.2 # Sump sinking hazard!
            organ.atp_upkeep_per_sec = 0.4
            organ.local_position = Vector3(0.0, 0.5, 0.0)
            organ.defense_value = 45.0
            organ.special_tag = "CALCIFIED_ARMOR"
            organ.rarity_rating = 2.1
            organ.color_tint = Color(0.82, 0.8, 0.72)
        "biolume_sac":
            organ.organ_name = "Bioluminescent Lure Sac"
            organ.socket = SocketType.DORSAL
            organ.mass_kg = 1.0
            organ.atp_upkeep_per_sec = 1.4 # High drain
            organ.local_position = Vector3(0.0, 0.6, -0.15)
            organ.special_tag = "BIOLUME"
            organ.rarity_rating = 3.0
            organ.color_tint = Color(0.1, 0.95, 0.85)
        "spore_pustules":
            organ.organ_name = "Fungal Spore Pustules"
            organ.socket = SocketType.DORSAL
            organ.mass_kg = 0.9
            organ.atp_upkeep_per_sec = 0.5
            organ.local_position = Vector3(0.0, 0.4, 0.2)
            organ.special_tag = "SPORE_PUSTULES"
            organ.rarity_rating = 2.6
            organ.color_tint = Color(0.6, 0.75, 0.15)
        "counterbalance_tail":
            organ.organ_name = "Counterbalance Fat Tail"
            organ.socket = SocketType.CAUDAL
            organ.mass_kg = 2.4 # Balances heavy mandibles
            organ.atp_upkeep_per_sec = 0.35
            organ.local_position = Vector3(0.0, 0.1, 1.1)
            organ.special_tag = "FAT_TAIL"
            organ.rarity_rating = 1.5
            organ.color_tint = Color(0.55, 0.38, 0.28)
        "scorpion_stinger":
            organ.organ_name = "Neurotoxic Scorpion Stinger"
            organ.socket = SocketType.CAUDAL
            organ.mass_kg = 1.6
            organ.atp_upkeep_per_sec = 0.8
            organ.local_position = Vector3(0.0, 0.7, 0.95)
            organ.combat_value = 24.0
            organ.special_tag = "STINGER"
            organ.rarity_rating = 2.7
            organ.color_tint = Color(0.3, 0.15, 0.35)
        "egg_ovipositor":
            organ.organ_name = "Egg Ovipositor"
            organ.socket = SocketType.CAUDAL
            organ.mass_kg = 0.9
            organ.atp_upkeep_per_sec = 0.5
            organ.local_position = Vector3(0.0, -0.1, 0.8)
            organ.special_tag = "OVIPOSITOR"
            organ.rarity_rating = 2.0
            organ.color_tint = Color(0.85, 0.6, 0.4)
        "legs_insectoid_6":
            organ.organ_name = "Hexapod Insectoid Legs"
            organ.socket = SocketType.LOCOMOTION
            organ.mass_kg = 1.2
            organ.atp_upkeep_per_sec = 0.5
            organ.local_position = Vector3(0.0, -0.3, 0.0)
            organ.special_tag = "LEGS_6"
            organ.rarity_rating = 1.0
            organ.color_tint = Color(0.35, 0.28, 0.22)
        "legs_spider_8":
            organ.organ_name = "Arachnid Canopy Climbers"
            organ.socket = SocketType.LOCOMOTION
            organ.mass_kg = 1.8
            organ.atp_upkeep_per_sec = 1.1
            organ.local_position = Vector3(0.0, -0.25, 0.0)
            organ.special_tag = "LEGS_SPIDER"
            organ.rarity_rating = 2.8
            organ.color_tint = Color(0.18, 0.15, 0.2)
        "legs_heavy_strider":
            organ.organ_name = "Quadruped Heavy Striders"
            organ.socket = SocketType.LOCOMOTION
            organ.mass_kg = 2.5
            organ.atp_upkeep_per_sec = 0.8
            organ.local_position = Vector3(0.0, -0.35, 0.0)
            organ.special_tag = "LEGS_HEAVY"
            organ.rarity_rating = 2.2
            organ.color_tint = Color(0.48, 0.42, 0.36)
        _:
            # Default generic organ
            organ.organ_name = id.capitalize()
            organ.socket = SocketType.DORSAL
            organ.mass_kg = 1.0
            organ.atp_upkeep_per_sec = 0.4
            organ.local_position = Vector3(0, 0.2, 0)
    
    return organ

func clone() -> OrganData:
    var c = OrganData.new()
    c.organ_id = organ_id
    c.organ_name = organ_name
    c.socket = socket
    c.mass_kg = mass_kg
    c.atp_upkeep_per_sec = atp_upkeep_per_sec
    c.local_position = local_position
    c.max_health = max_health
    c.current_health = current_health
    c.origin_tag = origin_tag
    c.is_somatic = is_somatic
    c.rarity_rating = rarity_rating
    c.combat_value = combat_value
    c.defense_value = defense_value
    c.special_tag = special_tag
    c.color_tint = color_tint
    c.scale_factor = scale_factor
    return c

