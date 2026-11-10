class_name ClimateController
extends Node

@export var heat_lamp: SpotLight3D
@export var base_temp: float = 26.5
@export var base_humidity: float = 62.0
@export var base_toxicity: float = 12.0

var current_temp: float = 26.5
var current_humidity: float = 62.0
var current_toxicity: float = 12.0
var spore_decay_rate: float = 0.5

func _ready() -> void:
    current_temp = base_temp
    current_humidity = base_humidity
    current_toxicity = base_toxicity

func _process(delta: float) -> void:
    # Modulate heat lamp by day-night cycle
    var cycle_sun = sin(GameManager.day_cycle_time * TAU)
    var lamp_intensity = clampf(cycle_sun * 0.5 + 0.65, 0.2, 1.2)
    
    if heat_lamp:
        heat_lamp.light_energy = lamp_intensity * 2.8
        
    current_temp = base_temp + cycle_sun * 6.5
    current_humidity = clampf(base_humidity - cycle_sun * 8.0, 20.0, 95.0)
    
    # Natural spore decay
    GameManager.spore_density = maxf(GameManager.spore_density - spore_decay_rate * delta, 5.0)
    
    GameManager.update_climate(current_temp, current_humidity, current_toxicity, GameManager.spore_density)

