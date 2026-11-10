class_name GameManagerClass
extends Node

enum OverseerTool {
    NONE = 0,
    FEED = 1,
    MUTAGEN = 2,
    TWEEZERS = 3,
    GLASS_TAP = 4,
    JAR_SCOOP = 5
}

signal research_points_changed(new_rp: int)
signal population_changed(current: int, max_limit: int)
signal tool_changed(tool: OverseerTool)
signal surgery_mode_toggled(active: bool)
signal specimen_selected(specimen: Node)
signal climate_changed(temperature: float, humidity: float, toxicity: float, spore_density: float)
signal shockwave_triggered(world_pos: Vector3)
signal notification_posted(text: String, is_alert: bool)
signal specimen_amputated(creature: Node, organ: OrganData)

# Economy & Population
var research_points: int = 65
const MAX_POPULATION: int = 20
var active_creatures: Array[Node] = []

# Tool states
var current_tool: OverseerTool = OverseerTool.TWEEZERS
var surgery_mode_active: bool = false
var selected_specimen: Node = null

# Climate state
var tank_temperature: float = 26.5 # Celsius
var tank_humidity: float = 62.0    # %
var tank_toxicity: float = 12.0    # %
var spore_density: float = 8.0     # %
var day_cycle_time: float = 0.0    # 0.0 to 1.0

# Breeding isolator chamber
var breeding_chamber_creatures: Array[Node] = []
var isolator_has_egg: bool = false

# Audio Synthesizer reference
var audio_synth: AudioSynthesizer = null

func _ready() -> void:
    # Initialize procedural audio synthesizer node
    audio_synth = AudioSynthesizer.new()
    audio_synth.name = "AudioSynthesizer"
    add_child(audio_synth)

func _process(delta: float) -> void:
    # Gentle day-night cycle progression (60 seconds full cycle)
    day_cycle_time = fmod(day_cycle_time + delta * 0.016, 1.0)

func register_creature(creature: Node) -> void:
    if not active_creatures.has(creature):
        active_creatures.append(creature)
        population_changed.emit(active_creatures.size(), MAX_POPULATION)

func unregister_creature(creature: Node) -> void:
    if active_creatures.has(creature):
        active_creatures.erase(creature)
        population_changed.emit(active_creatures.size(), MAX_POPULATION)
    if selected_specimen == creature:
        select_specimen(null)
    if breeding_chamber_creatures.has(creature):
        breeding_chamber_creatures.erase(creature)

func select_specimen(creature: Node) -> void:
    selected_specimen = creature
    specimen_selected.emit(creature)

func set_tool(tool: OverseerTool) -> void:
    current_tool = tool
    tool_changed.emit(tool)
    if tool != OverseerTool.TWEEZERS:
        set_surgery_mode(false)

func set_surgery_mode(active: bool) -> void:
    surgery_mode_active = active
    surgery_mode_toggled.emit(active)
    if active:
        post_notification("SURGERY MODE: Click-drag organs to amputate live!", true)

func add_research_points(amount: int) -> void:
    research_points += amount
    research_points_changed.emit(research_points)

func can_afford(cost: int) -> bool:
    return research_points >= cost

func spend_research_points(cost: int) -> bool:
    if can_afford(cost):
        research_points -= cost
        research_points_changed.emit(research_points)
        return true
    post_notification("Insufficient Research Points!", true)
    return false

func trigger_shockwave(hit_pos: Vector3) -> void:
    shockwave_triggered.emit(hit_pos)
    if audio_synth:
        audio_synth.play_sfx("glass_tap", randf_range(0.9, 1.1), 3.0)

func post_notification(text: String, is_alert: bool = false) -> void:
    notification_posted.emit(text, is_alert)

func update_climate(temp: float, humid: float, tox: float, spore: float) -> void:
    tank_temperature = temp
    tank_humidity = humid
    tank_toxicity = tox
    spore_density = spore
    climate_changed.emit(temp, humid, tox, spore)

