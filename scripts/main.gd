extends Node3D

@onready var mission_label: Label = $UI/MissionLabel
@onready var marker: Area3D = $MissionMarker
@onready var player = $Player
@onready var car = $Car
@onready var help_label: Label = $UI/HelpLabel
@onready var mission_end: Control = $UI/MissionEnd
@onready var mission_end_panel: PanelContainer = $UI/MissionEnd/Panel
@onready var mobile_controls = $MobileControls

var current_vehicle
var mission_finished := false

func _ready() -> void:
    marker.completed.connect(_on_mission_completed)
    mission_label.text = "MISIÓN: ve al marcador amarillo"

func _mobile_mode_active() -> bool:
    return mobile_controls.mobile_active

func _process(_delta: float) -> void:
    if mission_finished:
        return
    if current_vehicle:
        help_label.text = "JOYSTICK: conducir  |  SALIR: abandonar coche" if _mobile_mode_active() else "FLECHAS/WASD: conducir  |  E: salir"
        if Input.is_action_just_pressed("interact"):
            _exit_car()
        return

    var distance: float = player.global_position.distance_to(car.global_position)
    if _mobile_mode_active():
        help_label.text = "ACCIÓN: entrar en el coche" if distance < car.interaction_distance else "JOYSTICK: moverse  |  Desliza a la derecha: cámara"
    else:
        help_label.text = "E: entrar en el coche (después usa flechas o WASD)" if distance < car.interaction_distance else "FLECHAS/WASD: andar  |  Shift: correr  |  Espacio: saltar"
    if distance < car.interaction_distance and Input.is_action_just_pressed("interact"):
        _enter_car()


func _enter_car() -> void:
    current_vehicle = car
    player.enter_vehicle()
    car.set_controlled(true)
    mobile_controls.set_vehicle_mode(true)

func _exit_car() -> void:
    var exit_position: Vector3 = car.global_position + car.global_transform.basis.x * 2.2 + Vector3.UP * 0.6
    var car_forward: Vector3 = -car.global_transform.basis.z
    car.set_controlled(false)
    player.exit_vehicle(exit_position, car_forward)
    current_vehicle = null
    mobile_controls.set_vehicle_mode(false)

func _on_mission_completed() -> void:
    if mission_finished:
        return
    mission_finished = true
    mission_label.text = "MISIÓN COMPLETADA  +$500"
    help_label.text = ""
    if current_vehicle:
        car.set_controlled(false)
    player.controls_enabled = false
    mobile_controls.set_controls_enabled(false)
    player.velocity = Vector3.ZERO
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    mission_end.visible = true
    mission_end.modulate.a = 0.0
    mission_end_panel.position.y += 35.0
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(mission_end, "modulate:a", 1.0, 0.55)
    tween.tween_property(mission_end_panel, "position:y", mission_end_panel.position.y - 35.0, 0.55)
    $UI/MissionEnd/Panel/Content/RestartButton.grab_focus()

func _on_restart_pressed() -> void:
    get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/start.tscn")
