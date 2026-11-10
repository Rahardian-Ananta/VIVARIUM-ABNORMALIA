class_name SporeCloud
extends Area3D

var drift_direction: Vector3 = Vector3(0.5, 0.1, 0.2)
var drift_speed: float = 0.4
var lifetime: float = 45.0
@onready var particles: CPUParticles3D = $CPUParticles3D

func _ready() -> void:
    collision_layer = 8 # Pellets, baits, spores
    collision_mask = 2 # Creature hulls
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    global_position += drift_direction * drift_speed * delta
    
    # Boundary bounce inside tank
    if absf(global_position.x) > 5.0:
        drift_direction.x *= -1.0
    if absf(global_position.z) > 3.0:
        drift_direction.z *= -1.0
    if global_position.y > 5.5 or global_position.y < 0.2:
        drift_direction.y *= -1.0
        
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node3D) -> void:
    if body is CreatureEntity:
        var creature: CreatureEntity = body
        if creature.cordyceps_stage == 0:
            creature.cordyceps_stage = 1
            creature.cordyceps_timer = 0.0
            GameManager.post_notification("⚠ SPORE CLOUD: %s infected with fungal spores!" % creature.genome.species_name, true)

