class_name SpecimenInspectorCard
extends Control

@onready var panel_container: PanelContainer = $ParchmentPanel
@onready var title_label: Label = $ParchmentPanel/Margin/VBox/TitleLabel
@onready var subtitle_label: Label = $ParchmentPanel/Margin/VBox/SubtitleLabel
@onready var hp_bar: ProgressBar = $ParchmentPanel/Margin/VBox/HPBar
@onready var atp_bar: ProgressBar = $ParchmentPanel/Margin/VBox/ATPBar
@onready var com_label: Label = $ParchmentPanel/Margin/VBox/COMLabel
@onready var burn_rate_label: Label = $ParchmentPanel/Margin/VBox/BurnRateLabel
@onready var organs_container: VBoxContainer = $ParchmentPanel/Margin/VBox/OrgansScroll/OrgansList
@onready var complications_container: VBoxContainer = $ParchmentPanel/Margin/VBox/ComplicationsList

var inspected_creature: CreatureEntity = null

func _ready() -> void:
    GameManager.specimen_selected.connect(inspect_specimen)
    visible = false

func inspect_specimen(creature: Node) -> void:
    if creature is CreatureEntity and is_instance_valid(creature):
        inspected_creature = creature
        visible = true
        _refresh_display()
    else:
        inspected_creature = null
        visible = false

func _process(_delta: float) -> void:
    if visible and inspected_creature and is_instance_valid(inspected_creature):
        _refresh_live_stats()
    elif visible and (not inspected_creature or not is_instance_valid(inspected_creature)):
        visible = false

func _refresh_display() -> void:
    if not inspected_creature:
        return
        
    var g = inspected_creature.genome
    title_label.text = "%s [%s]" % [g.species_name, g.specimen_id]
    subtitle_label.text = "Generation: %d | Total Mass: %.2f kg" % [g.generation, inspected_creature.total_mass]
    
    # Organs list
    for child in organs_container.get_children():
        child.queue_free()
        
    for organ in g.get_all_organs():
        var hbox = HBoxContainer.new()
        
        var name_lbl = Label.new()
        name_lbl.text = "• %s (%s)" % [organ.organ_name, organ.get_socket_name()]
        name_lbl.add_theme_color_override("font_color", Color(0.18, 0.14, 0.1))
        name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hbox.add_child(name_lbl)
        
        var tag_lbl = Label.new()
        tag_lbl.text = organ.origin_tag
        if organ.is_somatic:
            tag_lbl.add_theme_color_override("font_color", Color(0.7, 0.15, 0.15))
        else:
            tag_lbl.add_theme_color_override("font_color", Color(0.2, 0.45, 0.2))
        hbox.add_child(tag_lbl)
        
        organs_container.add_child(hbox)
        
    _refresh_complications()

func _refresh_live_stats() -> void:
    if not inspected_creature:
        return
        
    hp_bar.value = (inspected_creature.current_health / inspected_creature.max_health) * 100.0
    atp_bar.value = (inspected_creature.atp_energy / inspected_creature.max_atp_energy) * 100.0
    
    var com = inspected_creature.center_of_mass_offset
    com_label.text = "Center-of-Mass Offset: (X:%.2f, Z:%.2f)" % [com.x, com.z]
    burn_rate_label.text = "ATP Upkeep: %.2f / sec" % inspected_creature.atp_burn_rate

func _refresh_complications() -> void:
    for child in complications_container.get_children():
        child.queue_free()
        
    if not inspected_creature:
        return
        
    # Check each complication
    if inspected_creature.is_nose_dragging:
        _add_warning("⚠ ANTERIOR OVERWEIGHT: Nose-Dragging (-45% Spd, Tumble Hazard)")
        
    if inspected_creature.is_crab_limping:
        _add_warning("⚠ BILATERAL ASYMMETRY: Crab-Limping (Drift Vector Navigation)")
        
    if inspected_creature.is_hyper_metabolic:
        _add_warning("⚠ HYPER-METABOLIC STARVATION: Ravenous Autophagy Risk!")
        
    if inspected_creature.has_biolume_curse:
        _add_warning("⚠ BIOLUMINESCENT BEACON: +250% Aggro Detection Magnet")
        
    if inspected_creature.cordyceps_stage == 1:
        _add_warning("⚠ CORDYCEPS STAGE 1: Spore Infiltration in Cranium")
    elif inspected_creature.cordyceps_stage >= 2:
        _add_warning("⚠ CORDYCEPS STAGE 2: Neural Hijack! Amputate Immediately!")

func _add_warning(text: String) -> void:
    var lbl = Label.new()
    lbl.text = text
    lbl.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1))
    complications_container.add_child(lbl)

