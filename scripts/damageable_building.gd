extends StaticBody3D

@export var max_health := 500.0
var health := 500.0

func _ready() -> void:
    health = max_health
    set_meta("impact_material", "concrete")

func take_damage(amount: float) -> void:
    health = maxf(health - amount, 0.0)
    set_meta("damaged", true)

