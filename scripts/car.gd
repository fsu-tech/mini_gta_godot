extends CharacterBody3D

@export var max_speed := 22.0
@export var reverse_speed := 9.0
@export var acceleration := 14.0
@export var braking := 24.0
@export var steering_speed := 0.9
@export var steering_response := 2.2
@export var interaction_distance := 3.5
@export var max_health := 180.0

@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var controlled := false
var gravity := 18.0
var forward_speed := 0.0
var current_steering := 0.0
var wheel_nodes: Array[Node3D] = []
var health := 180.0
var damage_smoke: GPUParticles3D

func _ready() -> void:
	health = max_health
	set_meta("impact_material", "metal")
	# Mantiene el vehículo pegado a pendientes y pequeños desniveles.
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(55.0)
	floor_stop_on_slope = false
	for child in $Model.find_children("*", "Node3D", true, false):
		var wheel := child as Node3D
		if wheel and String(wheel.name) in ["rear wheel", "rear wheel.001", "rear wheel.002", "rear wheel.003"]:
			wheel_nodes.append(wheel)

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= max_health * 0.5 and not damage_smoke:
		_create_damage_smoke()
	if health <= 0.0:
		forward_speed = 0.0
		max_speed = 0.0
		acceleration = 0.0

func _create_damage_smoke() -> void:
	damage_smoke = GPUParticles3D.new()
	damage_smoke.name = "DamageSmoke"
	damage_smoke.position = Vector3(0.0, 1.0, -1.1)
	damage_smoke.amount = 28
	damage_smoke.lifetime = 2.4
	damage_smoke.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 7, 6))
	var smoke_material := StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_material.albedo_color = Color(0.07, 0.07, 0.065, 0.48)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	quad.material = smoke_material
	damage_smoke.draw_pass_1 = quad
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 24.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.25
	process.gravity = Vector3(0.0, 0.22, 0.0)
	process.scale_min = 0.45
	process.scale_max = 1.3
	damage_smoke.process_material = process
	add_child(damage_smoke)

func set_controlled(value: bool) -> void:
	controlled = value
	if value:
		camera.current = true

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -4.0

	if controlled:
		var steering_input := Input.get_axis("move_right", "move_left") + float(Input.is_key_pressed(KEY_LEFT)) - float(Input.is_key_pressed(KEY_RIGHT))
		steering_input = clampf(steering_input, -1.0, 1.0)
		current_steering = move_toward(current_steering, steering_input, steering_response * delta)

		var throttle := Input.get_axis("move_back", "move_forward") + float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))
		throttle = clampf(throttle, -1.0, 1.0)
		# Control arcade: izquierda/derecha también arrancan el coche.
		if is_zero_approx(throttle) and not is_zero_approx(steering_input):
			throttle = 0.55

		var target_speed := throttle * (max_speed if throttle >= 0.0 else reverse_speed)
		var rate := braking if is_zero_approx(throttle) else acceleration
		forward_speed = move_toward(forward_speed, target_speed, rate * delta)

		var speed_ratio: float = clamp(abs(forward_speed) / max_speed, 0.0, 1.0)
		if speed_ratio > 0.03:
			var direction_sign: float = signf(forward_speed)
			rotate_y(current_steering * steering_speed * direction_sign * (0.25 + speed_ratio * 0.75) * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, braking * delta)
		current_steering = move_toward(current_steering, 0.0, steering_response * delta)

	var forward := -global_transform.basis.z
	velocity.x = forward.x * forward_speed
	velocity.z = forward.z * forward_speed
	move_and_slide()
	apply_floor_snap()
	_animate_wheels(delta)

	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collision_normal := collision.get_normal()
		if absf(collision_normal.y) < 0.5:
			# Conserva la velocidad y orienta el coche para deslizarse junto al obstáculo.
			var slide_direction := forward.slide(collision_normal).normalized()
			if slide_direction.is_zero_approx():
				var turn_side := signf(current_steering) if not is_zero_approx(current_steering) else 1.0
				slide_direction = Vector3(-collision_normal.z, 0.0, collision_normal.x) * turn_side
			var target_rotation := atan2(-slide_direction.x, -slide_direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, clampf(8.0 * delta, 0.0, 1.0))
			break

func _animate_wheels(delta: float) -> void:
	var spin_amount := forward_speed * delta / 0.25
	for wheel in wheel_nodes:
		wheel.rotate_object_local(Vector3.RIGHT, spin_amount)
