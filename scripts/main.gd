extends Node3D

@onready var mission_label: Label = $UI/MissionLabel
@onready var marker: Area3D = $MissionMarker
@onready var player = $Player
@onready var car = $Car
@onready var help_label: Label = $UI/HelpLabel
@onready var mission_end: Control = $UI/MissionEnd
@onready var mission_end_panel: PanelContainer = $UI/MissionEnd/Panel
@onready var mobile_controls = $MobileControls
@onready var ch26_target = $Ch26Target

var current_vehicle
var mission_finished := false
var mission_phase := 1

func _ready() -> void:
    marker.completed.connect(_on_mission_completed)
    ch26_target.defeated.connect(_on_ch26_defeated)
    mission_label.text = "MISIÓN: ve al marcador amarillo"

func _mobile_mode_active() -> bool:
    return mobile_controls.mobile_active

func _process(_delta: float) -> void:
    if mission_finished:
        return
    if current_vehicle:
        if mission_phase == 2:
            help_label.text = "SALIR: baja para buscar a Ch26" if _mobile_mode_active() else "E: salir y buscar a Ch26"
        else:
            help_label.text = "JOYSTICK: conducir  |  SALIR: abandonar coche" if _mobile_mode_active() else "FLECHAS/WASD: conducir  |  E: salir"
        if Input.is_action_just_pressed("interact"):
            _exit_car()
        return

    var distance: float = player.global_position.distance_to(car.global_position)
    if mission_phase == 2:
        help_label.text = "ARMA: equipar  |  DISPARO: elimina a Ch26" if _mobile_mode_active() else "R: equipar revólver  |  Clic izq.: dispara a Ch26"
        if distance < car.interaction_distance and Input.is_action_just_pressed("interact"):
            _enter_car()
        return
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
    if mission_finished or mission_phase != 1:
        return
    mission_phase = 2
    var patrol: Dictionary = _find_marker_street_route()
    ch26_target.activate_at(patrol.position, patrol.direction)
    mission_label.text = "MISIÓN 2: sigue el radar, encuentra y elimina a Ch26"
    help_label.text = "Busca el punto rojo del radar  |  R: equipar revólver"

func _find_marker_street_route() -> Dictionary:
    var origin_hit: Dictionary = _street_floor(marker.global_position)
    var origin: Vector3 = origin_hit.position if not origin_hit.is_empty() else marker.global_position - Vector3.UP
    var best_distance := 0.0
    var best_direction := Vector3.FORWARD
    var best_end: Vector3 = origin
    for direction_index in 64:
        var angle := TAU * float(direction_index) / 64.0
        var direction := Vector3(sin(angle), 0.0, cos(angle)).normalized()
        var previous_height: float = origin.y
        for step in range(2, 102, 2):
            var hit: Dictionary = _street_floor(origin + direction * float(step))
            if hit.is_empty() or absf(hit.position.y - previous_height) > 0.8:
                break
            previous_height = hit.position.y
            if float(step) > best_distance:
                best_distance = float(step)
                best_direction = direction
                best_end = hit.position
    # Empieza en el extremo lejano y camina de vuelta hacia el marcador.
    return {"position": best_end + Vector3.UP * 0.85, "direction": -best_direction}

func _street_floor(position: Vector3) -> Dictionary:
    var from := Vector3(position.x, 30.0, position.z)
    var to := Vector3(position.x, -10.0, position.z)
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [player.get_rid(), car.get_rid(), ch26_target.get_rid()]
    return get_world_3d().direct_space_state.intersect_ray(query)

func _on_ch26_defeated() -> void:
    if mission_finished or mission_phase != 2:
        return
    _finish_missions()

func _finish_missions() -> void:
    mission_finished = true
    mission_label.text = "MISIONES COMPLETADAS  +$1000"
    help_label.text = ""
    if current_vehicle:
        car.set_controlled(false)
    player.controls_enabled = false
    mobile_controls.set_controls_enabled(false)
    player.velocity = Vector3.ZERO
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    $UI/MissionEnd/Panel/Content/Title.text = "MISIONES COMPLETADAS"
    $UI/MissionEnd/Panel/Content/Message.text = "Has llegado al punto de encuentro y eliminado a Ch26."
    $UI/MissionEnd/Panel/Content/Reward.text = "+ $1000"
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
