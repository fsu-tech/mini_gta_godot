extends Node3D

@onready var mission_label: Label = $UI/MissionLabel
@onready var marker: Area3D = $MissionMarker
@onready var player = $Player
@onready var car = $Car
@onready var help_label: Label = $UI/HelpLabel

var current_vehicle

func _ready() -> void:
    marker.completed.connect(_on_mission_completed)
    mission_label.text = "MISIÓN: ve al marcador amarillo"

func _process(_delta: float) -> void:
    if current_vehicle:
        help_label.text = "FLECHAS/WASD: conducir  |  E: salir"
        if Input.is_action_just_pressed("interact"):
            _exit_car()
        return

    var distance: float = player.global_position.distance_to(car.global_position)
    help_label.text = "E: entrar en el coche (después usa flechas o WASD)" if distance < car.interaction_distance else "FLECHAS/WASD: andar  |  Shift: correr  |  Espacio: saltar"
    if distance < car.interaction_distance and Input.is_action_just_pressed("interact"):
        _enter_car()


func _enter_car() -> void:
    current_vehicle = car
    player.enter_vehicle()
    car.set_controlled(true)

func _exit_car() -> void:
    var exit_position: Vector3 = car.global_position + car.global_transform.basis.x * 2.2 + Vector3.UP * 0.6
    var car_forward: Vector3 = -car.global_transform.basis.z
    car.set_controlled(false)
    player.exit_vehicle(exit_position, car_forward)
    current_vehicle = null

func _on_mission_completed() -> void:
    mission_label.text = "MISIÓN COMPLETADA  +$500"
