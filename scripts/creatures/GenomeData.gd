class_name GenomeData
extends Resource

@export var specimen_id: String = "Specimen-01"
@export var species_name: String = "Abnormalia Beetle"
@export var generation: int = 1
@export var base_body_color: Color = Color(0.35, 0.45, 0.3)
@export var base_thorax_mass: float = 1.8 # kg
@export var base_metabolism: float = 0.8 # ATP / sec
@export var base_move_speed: float = 2.4
@export var buoyancy_limit_kg: float = 5.2 # If total_mass exceeds this, it sinks in peat sump!

# Organ slots
@export var cranial_organ: OrganData = null
@export var mandible_l_organ: OrganData = null
@export var mandible_r_organ: OrganData = null
@export var dorsal_organ: OrganData = null
@export var locomotion_organ: OrganData = null
@export var caudal_organ: OrganData = null

func get_all_organs() -> Array[OrganData]:
    var list: Array[OrganData] = []
    if cranial_organ: list.append(cranial_organ)
    if mandible_l_organ: list.append(mandible_l_organ)
    if mandible_r_organ: list.append(mandible_r_organ)
    if dorsal_organ: list.append(dorsal_organ)
    if locomotion_organ: list.append(locomotion_organ)
    if caudal_organ: list.append(caudal_organ)
    return list

func get_organ_in_socket(socket: OrganData.SocketType) -> OrganData:
    match socket:
        OrganData.SocketType.CRANIAL: return cranial_organ
        OrganData.SocketType.MANDIBLE_L: return mandible_l_organ
        OrganData.SocketType.MANDIBLE_R: return mandible_r_organ
        OrganData.SocketType.DORSAL: return dorsal_organ
        OrganData.SocketType.LOCOMOTION: return locomotion_organ
        OrganData.SocketType.CAUDAL: return caudal_organ
    return null

func set_organ_in_socket(socket: OrganData.SocketType, organ: OrganData) -> void:
    match socket:
        OrganData.SocketType.CRANIAL: cranial_organ = organ
        OrganData.SocketType.MANDIBLE_L: mandible_l_organ = organ
        OrganData.SocketType.MANDIBLE_R: mandible_r_organ = organ
        OrganData.SocketType.DORSAL: dorsal_organ = organ
        OrganData.SocketType.LOCOMOTION: locomotion_organ = organ
        OrganData.SocketType.CAUDAL: caudal_organ = organ

func remove_organ_in_socket(socket: OrganData.SocketType) -> OrganData:
    var existing = get_organ_in_socket(socket)
    set_organ_in_socket(socket, null)
    return existing

func calculate_total_mass() -> float:
    var total = base_thorax_mass
    for organ in get_all_organs():
        total += organ.mass_kg
    return total

func calculate_atp_burn_rate() -> float:
    var rate = base_metabolism
    for organ in get_all_organs():
        rate += organ.atp_upkeep_per_sec
    return rate

func calculate_center_of_mass_offset() -> Vector3:
    var total_mass = calculate_total_mass()
    if total_mass <= 0.001:
        return Vector3.ZERO
    
    var weighted_pos = Vector3.ZERO
    for organ in get_all_organs():
        weighted_pos += organ.local_position * organ.mass_kg
    
    return weighted_pos / total_mass

func count_grafted_organs() -> int:
    var count = 0
    for organ in get_all_organs():
        if organ.is_somatic:
            count += 1
    return count

func clone() -> GenomeData:
    var g = GenomeData.new()
    g.specimen_id = specimen_id
    g.species_name = species_name
    g.generation = generation
    g.base_body_color = base_body_color
    g.base_thorax_mass = base_thorax_mass
    g.base_metabolism = base_metabolism
    g.base_move_speed = base_move_speed
    g.buoyancy_limit_kg = buoyancy_limit_kg
    if cranial_organ: g.cranial_organ = cranial_organ.clone()
    if mandible_l_organ: g.mandible_l_organ = mandible_l_organ.clone()
    if mandible_r_organ: g.mandible_r_organ = mandible_r_organ.clone()
    if dorsal_organ: g.dorsal_organ = dorsal_organ.clone()
    if locomotion_organ: g.locomotion_organ = locomotion_organ.clone()
    if caudal_organ: g.caudal_organ = caudal_organ.clone()
    return g

# Epigenetic Graft Inheritance:
# 50/50 Mendelian base traits from both parents,
# PLUS 40% chance to congenitally inherit somatic organs stolen via cannibalism!
func reproduce_with(partner: GenomeData) -> GenomeData:
    var child = GenomeData.new()
    child.generation = max(generation, partner.generation) + 1
    child.specimen_id = "Gen%d-%02d" % [child.generation, randi() % 100]
    
    # 50/50 blend for base traits
    child.base_body_color = base_body_color.lerp(partner.base_body_color, randf_range(0.3, 0.7))
    child.base_thorax_mass = (base_thorax_mass + partner.base_thorax_mass) * 0.5 * randf_range(0.9, 1.1)
    child.base_metabolism = (base_metabolism + partner.base_metabolism) * 0.5
    child.base_move_speed = (base_move_speed + partner.base_move_speed) * 0.5
    
    # Generate hybrid scientific name
    var p1_first = species_name.split(" ")[0]
    var p2_last = partner.species_name.split(" ")[-1]
    child.species_name = "%s-%s" % [p1_first, p2_last]
    
    # Sockets inheritance
    var sockets = [
        OrganData.SocketType.CRANIAL,
        OrganData.SocketType.MANDIBLE_L,
        OrganData.SocketType.MANDIBLE_R,
        OrganData.SocketType.DORSAL,
        OrganData.SocketType.LOCOMOTION,
        OrganData.SocketType.CAUDAL
    ]
    
    for sock in sockets:
        var organ_a = get_organ_in_socket(sock)
        var organ_b = partner.get_organ_in_socket(sock)
        var chosen: OrganData = null
        
        # Check somatic inheritance bonus (40% chance to inherit somatic organ congenitally!)
        if organ_a and organ_a.is_somatic and randf() < 0.4:
            chosen = organ_a.clone()
            chosen.origin_tag = "[Congenital Inherited]"
            chosen.is_somatic = false
        elif organ_b and organ_b.is_somatic and randf() < 0.4:
            chosen = organ_b.clone()
            chosen.origin_tag = "[Congenital Inherited]"
            chosen.is_somatic = false
        else:
            # 50/50 Mendelian choice
            if organ_a and organ_b:
                chosen = (organ_a if randf() < 0.5 else organ_b).clone()
            elif organ_a:
                chosen = organ_a.clone() if randf() < 0.7 else null
            elif organ_b:
                chosen = organ_b.clone() if randf() < 0.7 else null
            
            if chosen:
                chosen.origin_tag = "[Congenital]"
                chosen.is_somatic = false
        
        child.set_organ_in_socket(sock, chosen)
        
    return child

