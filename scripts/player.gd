extends CharacterBody3D

@export var walk_speed := 2.4
@export var run_speed := 4.8
@export var acceleration := 12.0
@export var jump_velocity := 3.5
@export var mouse_sensitivity := 0.0025
@export var turn_speed := 4.0

@onready var pivot: Node3D = $CameraPivot
@onready var remy = $Remy

var gravity := 10.0
var controls_enabled := true
var mouse_look_time := 0.0

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    pivot.rotation.x = deg_to_rad(-7.0)

func _unhandled_input(event: InputEvent) -> void:
    if not controls_enabled:
        return
    if event is InputEventMouseMotion:
        mouse_look_time = 0.8
        rotate_y(-event.relative.x * mouse_sensitivity)
        pivot.rotate_x(-event.relative.y * mouse_sensitivity)
        pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-55), deg_to_rad(45))
    elif event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    mouse_look_time = maxf(mouse_look_time - delta, 0.0)
    if not controls_enabled:
        velocity = Vector3.ZERO
        return
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity

    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    input_vec += _arrow_input()
    # Movimiento relativo a lo que ve la camara. De este modo el personaje
    # puede girar hacia su desplazamiento sin alterar el sentido de las teclas.
    var camera_forward := -pivot.global_transform.basis.z
    var camera_right := pivot.global_transform.basis.x
    camera_forward.y = 0.0
    camera_right.y = 0.0
    camera_forward = camera_forward.normalized()
    camera_right = camera_right.normalized()
    var dir := (camera_right * input_vec.x + camera_forward * -input_vec.y).normalized()
    if not is_zero_approx(input_vec.length()):
        if is_zero_approx(mouse_look_time):
            pivot.rotation.x = lerp_angle(pivot.rotation.x, deg_to_rad(-7.0), clampf(2.5 * delta, 0.0, 1.0))
        var movement_heading := atan2(-dir.x, -dir.z)
        rotation.y = lerp_angle(rotation.y, movement_heading, clampf(turn_speed * delta, 0.0, 1.0))
        pivot.rotation.y = lerp_angle(pivot.rotation.y, 0.0, clampf(8.0 * delta, 0.0, 1.0))

    var is_running := Input.is_key_pressed(KEY_SHIFT)
    var movement_speed := run_speed if is_running else walk_speed
    var target_x := dir.x * movement_speed
    var target_z := dir.z * movement_speed
    velocity.x = move_toward(velocity.x, target_x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target_z, acceleration * delta)

    move_and_slide()
    remy.set_motion(not is_zero_approx(input_vec.length()), is_running)

func enter_vehicle() -> void:
    controls_enabled = false
    visible = false
    $CollisionShape3D.set_deferred("disabled", true)

func exit_vehicle(exit_position: Vector3, facing_direction: Vector3) -> void:
    global_position = exit_position
    velocity = Vector3.ZERO
    # Al salir, descarta el angulo de camara que tenia el jugador antes de
    # entrar y coloca la vista detras del personaje, mirando hacia delante.
    var flat_facing := Vector3(facing_direction.x, 0.0, facing_direction.z).normalized()
    if not flat_facing.is_zero_approx():
        rotation.y = atan2(-flat_facing.x, -flat_facing.z)
    pivot.rotation.y = 0.0
    pivot.rotation.x = deg_to_rad(-7.0)
    mouse_look_time = 0.0
    visible = true
    $CollisionShape3D.set_deferred("disabled", false)
    controls_enabled = true
    $CameraPivot/SpringArm3D/Camera3D.current = true

func _arrow_input() -> Vector2:
    var arrows := Vector2.ZERO
    arrows.x = float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
    arrows.y = float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
    return arrows.normalized() if arrows.length() > 1.0 else arrows
