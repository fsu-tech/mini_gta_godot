extends CharacterBody3D

@export var max_speed := 22.0
@export var reverse_speed := 9.0
@export var acceleration := 14.0
@export var braking := 24.0
@export var steering_speed := 0.9
@export var steering_response := 2.2
@export var interaction_distance := 3.5
@export var max_health := 180.0
@export var ramp_jump_min_speed := 7.5
@export var ramp_jump_threshold := 0.055
@export var ramp_jump_strength := 0.55
@export var ramp_jump_max_velocity := 0.8
@export var ramp_min_climb_distance := 1.4
@export var ramp_max_incline := 0.22
@export var fall_recovery_distance := 0.65

@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var car_model: Node3D = $Model

var controlled := false
var gravity := 18.0
var forward_speed := 0.0
var current_steering := 0.0
var wheel_nodes: Array[Node3D] = []
var health := 180.0
var damage_smoke: GPUParticles3D
var previous_uphill_amount := 0.0
var ramp_climb_distance := 0.0
var last_safe_position: Vector3
var last_safe_rotation_y := 0.0
var has_safe_position := false
var model_base_position: Vector3
var visual_bounce_height := 0.0
var visual_bounce_velocity := 0.0

func _ready() -> void:
	health = max_health
	set_meta("impact_material", "metal")
	model_base_position = car_model.position
	# Un ajuste corto absorbe irregularidades pequeñas, pero permite despegar
	# cuando el coche corona una elevación a suficiente velocidad.
	floor_snap_length = 1.0
	# Las pendientes normales son suelo; bordillos y laterales pronunciados son paredes.
	floor_max_angle = deg_to_rad(22.0)
	# Un coche aparcado no debe deslizarse por la pendiente de la calle.
	floor_stop_on_slope = true
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

func apply_mobile_look(relative: Vector2, sensitivity: float) -> void:
	camera_pivot.rotate_y(-relative.x * sensitivity)
	camera_pivot.rotate_x(-relative.y * sensitivity)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-35.0), deg_to_rad(20.0))

func _physics_process(delta: float) -> void:
	var forward := -global_transform.basis.z
	var was_on_floor := is_on_floor()
	var uphill_amount := 0.0
	var floor_normal_y := 1.0
	if was_on_floor:
		var floor_normal := get_floor_normal()
		floor_normal_y = floor_normal.y
		uphill_amount = maxf(-forward.dot(floor_normal), 0.0)
	var gentle_road_ramp := (
		was_on_floor
		and uphill_amount >= ramp_jump_threshold
		and uphill_amount <= ramp_max_incline
		and floor_normal_y >= 0.95
	)
	var reached_ramp_crest := (
		was_on_floor
		and absf(forward_speed) >= ramp_jump_min_speed
		and ramp_climb_distance >= ramp_min_climb_distance
		and previous_uphill_amount >= ramp_jump_threshold
		and uphill_amount < previous_uphill_amount * 0.42
		and floor_normal_y >= 0.985
	)
	if gentle_road_ramp:
		ramp_climb_distance += absf(forward_speed) * delta
	elif not reached_ramp_crest:
		ramp_climb_distance = 0.0
	if reached_ramp_crest:
		# El bote es visual: el collider nunca abandona la carretera.
		visual_bounce_velocity = minf(absf(forward_speed) * ramp_jump_strength * 0.1, ramp_jump_max_velocity)
		ramp_climb_distance = 0.0
	elif not was_on_floor:
		velocity.y -= gravity * delta
	else:
		velocity.y = -4.0
		floor_snap_length = 1.0
	previous_uphill_amount = uphill_amount

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

		var speed_ratio: float = clamp(abs(forward_speed) / maxf(max_speed, 0.001), 0.0, 1.0)
		if speed_ratio > 0.03:
			var direction_sign: float = signf(forward_speed)
			rotate_y(current_steering * steering_speed * direction_sign * (0.25 + speed_ratio * 0.75) * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, braking * delta)
		current_steering = move_toward(current_steering, 0.0, steering_response * delta)
		if was_on_floor:
			velocity = Vector3.ZERO

	velocity.x = forward.x * forward_speed
	velocity.z = forward.z * forward_speed
	move_and_slide()
	_damage_vehicle_targets()
	if is_on_floor() and get_floor_normal().y >= 0.92:
		last_safe_position = global_position
		last_safe_rotation_y = rotation.y
		has_safe_position = true
	var fell_below_safe_road := has_safe_position and global_position.y < last_safe_position.y - fall_recovery_distance
	var fell_before_first_safe_point := not has_safe_position and global_position.y < -1.0
	if fell_below_safe_road or fell_before_first_safe_point:
		_recover_from_fall()
		return
	if velocity.y <= 0.0:
		apply_floor_snap()
	visual_bounce_velocity -= 3.8 * delta
	visual_bounce_height = maxf(visual_bounce_height + visual_bounce_velocity * delta, 0.0)
	if is_zero_approx(visual_bounce_height) and visual_bounce_velocity < 0.0:
		visual_bounce_velocity = 0.0
	car_model.position = model_base_position + Vector3.UP * visual_bounce_height
	var target_visual_pitch := 0.0
	var target_visual_roll := 0.0
	if is_on_floor():
		var local_floor_normal := global_transform.basis.inverse() * get_floor_normal()
		target_visual_pitch = clampf(atan2(local_floor_normal.z, local_floor_normal.y), -0.22, 0.22)
		target_visual_roll = clampf(-atan2(local_floor_normal.x, local_floor_normal.y), -0.16, 0.16)
	else:
		target_visual_pitch = clampf(velocity.y * 0.035, -0.14, 0.14)
	car_model.rotation.x = lerp_angle(car_model.rotation.x, target_visual_pitch, clampf(6.0 * delta, 0.0, 1.0))
	car_model.rotation.z = lerp_angle(car_model.rotation.z, target_visual_roll, clampf(7.5 * delta, 0.0, 1.0))
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

func _damage_vehicle_targets() -> void:
	var impact_speed := absf(forward_speed)
	if impact_speed < 2.5:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider()
		if collider and collider.has_method("take_vehicle_hit"):
			collider.take_vehicle_hit(impact_speed)

func _recover_from_fall() -> void:
	if has_safe_position:
		global_position = last_safe_position + Vector3.UP * 0.45
		rotation = Vector3(0.0, last_safe_rotation_y, 0.0)
	else:
		global_position = Vector3(-190.72, 2.0, -119.35)
		rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	forward_speed = 0.0
	current_steering = 0.0
	floor_snap_length = 1.0
	visual_bounce_height = 0.0
	visual_bounce_velocity = 0.0
	car_model.position = model_base_position

func _animate_wheels(delta: float) -> void:
	var spin_amount := forward_speed * delta / 0.25
	for wheel in wheel_nodes:
		wheel.rotate_object_local(Vector3.RIGHT, spin_amount)
