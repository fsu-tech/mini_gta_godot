extends CharacterBody3D

@export var fall_recovery_distance := 8.0

var last_safe_position: Vector3
var last_safe_rotation_y := 0.0
var has_safe_position := false

const CROSSHAIR_SCRIPT := preload("res://scripts/crosshair.gd")
const IMPACT_DEBRIS := preload("res://scripts/impact_debris.gd")

@export var walk_speed := 2.4
@export var run_speed := 4.8
@export var acceleration := 12.0
@export var jump_velocity := 3.5
@export var mouse_sensitivity := 0.0025
@export var turn_speed := 4.0

@onready var pivot: Node3D = $CameraPivot
@onready var remy = $Remy
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var crosshair: Control = get_node("../UI/Crosshair")
@onready var ammo_label: Label = get_node("../UI/AmmoLabel")

@export var pistol_camera_forward := 0.35
@export var pistol_camera_lateral := 0.12
@export var pistol_camera_vertical := 0.045
@export var pistol_camera_pitch := -5.0
@export var pistol_camera_fov := 72.0
@export var camera_transition_time := 0.28
@export var weapon_range := 500.0
@export var weapon_damage := 34.0
@export var shot_interval := 0.42
@export var reload_time := 1.5

var gravity := 10.0
var controls_enabled := true
var mouse_look_time := 0.0
var camera_tween: Tween
var pistol_camera_active := false
var armed_run_camera_active := false
var third_person_pivot_position: Vector3
var third_person_spring_length: float
var third_person_camera_position: Vector3
var third_person_fov: float
var ammo := 6
var magazine_size := 6
var shot_cooldown := 0.0
var reload_remaining := 0.0
var shot_audio: AudioStreamPlayer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pivot.rotation.x = deg_to_rad(-7.0)
	third_person_pivot_position = pivot.position
	third_person_spring_length = spring_arm.spring_length
	third_person_camera_position = camera.position
	third_person_fov = camera.fov
	if not crosshair.has_method("set_damage_target"):
		crosshair.set_script(CROSSHAIR_SCRIPT)
	if crosshair is Label:
		(crosshair as Label).text = ""
	shot_audio = AudioStreamPlayer.new()
	shot_audio.name = "RevolverShotAudio"
	shot_audio.stream = _create_revolver_sound()
	shot_audio.volume_db = -2.0
	add_child(shot_audio)
	_update_ammo_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_shoot()
		return
	if event is InputEventMouseMotion:
		mouse_look_time = 0.8
		rotate_y(-event.relative.x * mouse_sensitivity)
		pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-55), deg_to_rad(45))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func apply_mobile_look(relative: Vector2, sensitivity: float) -> void:
	mouse_look_time = 0.8
	rotate_y(-relative.x * sensitivity)
	pivot.rotate_x(-relative.y * sensitivity)
	pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-55), deg_to_rad(45))

func mobile_toggle_pistol() -> void:
	if controls_enabled:
		_set_pistol_camera(remy.toggle_pistol())

func mobile_shoot() -> void:
	if controls_enabled:
		_try_shoot()

func _set_pistol_camera(equipped: bool) -> void:
	pistol_camera_active = equipped
	armed_run_camera_active = false
	crosshair.visible = equipped
	ammo_label.visible = equipped
	_transition_camera(equipped)

func _transition_camera(first_person: bool) -> void:
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	camera_tween = create_tween().set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if first_person:
		var eye_position: Vector3 = remy.get_pistol_eye_position(self)
		camera_tween.tween_property(pivot, "position", eye_position, camera_transition_time)
		camera_tween.tween_property(spring_arm, "spring_length", 0.0, camera_transition_time)
		camera_tween.tween_property(
			camera,
			"position",
			Vector3(pistol_camera_lateral, pistol_camera_vertical, -pistol_camera_forward),
			camera_transition_time
		)
		camera_tween.tween_property(camera, "fov", pistol_camera_fov, camera_transition_time)
		camera_tween.tween_property(pivot, "rotation:x", deg_to_rad(pistol_camera_pitch), camera_transition_time)
		camera_tween.tween_property(pivot, "rotation:y", 0.0, camera_transition_time)
		camera.near = 0.08
	else:
		camera_tween.tween_property(pivot, "position", third_person_pivot_position, camera_transition_time)
		camera_tween.tween_property(spring_arm, "spring_length", third_person_spring_length, camera_transition_time)
		camera_tween.tween_property(camera, "position", third_person_camera_position, camera_transition_time)
		camera_tween.tween_property(camera, "fov", third_person_fov, camera_transition_time)
		camera_tween.tween_property(pivot, "rotation:x", deg_to_rad(-7.0), camera_transition_time)
		camera_tween.tween_property(pivot, "rotation:y", 0.0, camera_transition_time)
		camera.near = 0.05

func _update_armed_run_camera(is_moving: bool, is_running: bool) -> void:
	if not pistol_camera_active:
		return
	var should_show_running := is_moving and is_running
	if should_show_running == armed_run_camera_active:
		return
	armed_run_camera_active = should_show_running
	_transition_camera(not armed_run_camera_active)

func _physics_process(delta: float) -> void:
	shot_cooldown = maxf(shot_cooldown - delta, 0.0)
	if reload_remaining > 0.0:
		reload_remaining -= delta
		if reload_remaining <= 0.0:
			ammo = magazine_size
			_update_ammo_ui()
	if pistol_camera_active and not armed_run_camera_active:
		_update_crosshair_target()
	mouse_look_time = maxf(mouse_look_time - delta, 0.0)
	if not controls_enabled:
		velocity = Vector3.ZERO
		return
	if Input.is_action_just_pressed("toggle_pistol"):
		mobile_toggle_pistol()
	if Input.is_action_just_pressed("shoot"):
		mobile_shoot()
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
			var first_person_armed := pistol_camera_active and not armed_run_camera_active
			var neutral_pitch := pistol_camera_pitch if first_person_armed else -7.0
			pivot.rotation.x = lerp_angle(pivot.rotation.x, deg_to_rad(neutral_pitch), clampf(2.5 * delta, 0.0, 1.0))
		var movement_heading := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, movement_heading, clampf(turn_speed * delta, 0.0, 1.0))
		pivot.rotation.y = lerp_angle(pivot.rotation.y, 0.0, clampf(8.0 * delta, 0.0, 1.0))

	var is_running := Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT)
	var is_moving := not is_zero_approx(input_vec.length())
	_update_armed_run_camera(is_moving, is_running)
	var movement_speed := run_speed if is_running else walk_speed
	var target_x := dir.x * movement_speed
	var target_z := dir.z * movement_speed
	velocity.x = move_toward(velocity.x, target_x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_z, acceleration * delta)

	move_and_slide()
	if is_on_floor() and get_floor_normal().y >= 0.9:
		last_safe_position = global_position
		last_safe_rotation_y = rotation.y
		has_safe_position = true
	var recovery_height := last_safe_position.y - fall_recovery_distance if has_safe_position else -8.0
	if global_position.y < recovery_height:
		_recover_from_fall()
		return
	remy.set_motion(is_moving, is_running)

func _recover_from_fall() -> void:
	global_position = last_safe_position + Vector3.UP * 0.5 if has_safe_position else Vector3(-193.09, 2.7, -118.55)
	rotation.y = last_safe_rotation_y if has_safe_position else 0.0
	velocity = Vector3.ZERO

func _try_shoot() -> void:
	if not pistol_camera_active or armed_run_camera_active or shot_cooldown > 0.0 or reload_remaining > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return
	if not remy.shoot():
		return
	ammo -= 1
	shot_cooldown = shot_interval
	_update_ammo_ui()
	_fire_hitscan()
	_create_muzzle_flash()
	_apply_recoil()
	shot_audio.pitch_scale = randf_range(0.97, 1.03)
	shot_audio.play()
	if ammo == 0:
		_start_reload()

func _start_reload() -> void:
	if reload_remaining > 0.0:
		return
	reload_remaining = reload_time
	ammo_label.text = "RECARGANDO..."

func _update_ammo_ui() -> void:
	ammo_label.text = "%d / %d" % [ammo, magazine_size]

func _fire_hitscan() -> void:
	var origin := camera.global_position
	var target := origin - camera.global_transform.basis.z * weapon_range
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider and collider.has_method("take_damage"):
		collider.take_damage(weapon_damage)
	var material_type := _impact_material_for(collider)
	_create_impact_mark(hit.position, hit.normal)
	_create_impact_debris(hit.position, hit.normal, material_type)

func _update_crosshair_target() -> void:
	var origin := camera.global_position
	var target := origin - camera.global_transform.basis.z * weapon_range
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var can_damage := false
	if not hit.is_empty():
		var collider = hit.get("collider")
		can_damage = collider != null and collider.has_method("take_damage")
	if crosshair.has_method("set_damage_target"):
		crosshair.call("set_damage_target", can_damage)

func _create_muzzle_flash() -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.55, 0.16)
	flash.light_energy = 5.0
	flash.omni_range = 3.0
	camera.add_child(flash)
	flash.position = Vector3(0.0, -0.12, -0.75)
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.07)
	tween.tween_callback(flash.queue_free)

func _create_impact_mark(position: Vector3, normal: Vector3) -> void:
	var mark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.035, 0.03)
	material.roughness = 1.0
	mesh.material = material
	mark.mesh = mesh
	var scene_root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(mark)
	mark.global_position = position + normal * 0.012
	var tween := create_tween()
	tween.tween_interval(8.0)
	tween.tween_callback(mark.queue_free)

func _impact_material_for(collider: Object) -> String:
	if collider and collider.has_meta("impact_material"):
		return String(collider.get_meta("impact_material"))
	if collider and ("ground" in String(collider.name).to_lower() or "road" in String(collider.name).to_lower()):
		return "dirt"
	return "concrete"

func _create_impact_debris(position: Vector3, normal: Vector3, material_type: String) -> void:
	var debris := IMPACT_DEBRIS.new()
	var scene_root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(debris)
	debris.global_position = position + normal * 0.025
	debris.setup(normal, material_type)

func _apply_recoil() -> void:
	pivot.rotation.x = clampf(pivot.rotation.x + deg_to_rad(2.4), deg_to_rad(-55.0), deg_to_rad(45.0))
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "rotation:x", deg_to_rad(pistol_camera_pitch), 0.18)

func _create_revolver_sound() -> AudioStreamWAV:
	const SAMPLE_RATE := 44100
	const DURATION := 0.62
	var sample_count := int(SAMPLE_RATE * DURATION)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 71991
	var previous_noise := 0.0
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var noise := random.randf_range(-1.0, 1.0)
		previous_noise = lerpf(previous_noise, noise, 0.22)
		var muzzle_blast := noise * exp(-time * 24.0) * 0.92
		var body_thump := sin(TAU * (92.0 - time * 48.0) * time) * exp(-time * 13.0) * 0.72
		var mechanical_crack := noise * exp(-time * 90.0) * 0.48
		var outdoor_tail := previous_noise * exp(-time * 5.8) * 0.24
		var sample := clampf(muzzle_blast + body_thump + mechanical_crack + outdoor_tail, -1.0, 1.0)
		pcm.encode_s16(index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream

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
