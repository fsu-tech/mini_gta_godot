extends CharacterBody3D

signal defeated

@export var max_health := 100.0
@export var walking_speed := 1.5
@export var character_height := 1.3
@export var waypoint_offsets := PackedVector3Array([
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.0, 0.0, -18.0),
	Vector3(12.0, 0.0, -18.0),
	Vector3(12.0, 0.0, 0.0),
])

@onready var model: Node3D = $Model
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var objective_marker: Label3D = $ObjectiveMarker
@onready var walk_animation_source: Node3D = $WalkAnimationSource

var health := 100.0
var active := false
var waypoint_index := 1
var patrol_origin := Vector3.ZERO
var gravity := 10.0
var last_safe_position := Vector3.ZERO
var skeleton: Skeleton3D
var source_skeleton: Skeleton3D
var bone_map: Dictionary = {}
var vehicle_hit_cooldown := 0.0

func _ready() -> void:
	health = max_health
	patrol_origin = global_position
	last_safe_position = global_position
	visible = false
	collision.disabled = true
	# Ch26 se mueve por un carril controlado y no debe engancharse en bordillos.
	collision_mask = 0
	set_physics_process(false)
	set_meta("impact_material", "flesh")
	_prepare_animation()

func activate_at(spawn_position: Vector3, street_direction: Vector3) -> void:
	global_position = spawn_position
	patrol_origin = spawn_position
	last_safe_position = spawn_position
	var flat_direction := Vector3(street_direction.x, 0.0, street_direction.z).normalized()
	if flat_direction.is_zero_approx():
		flat_direction = Vector3.FORWARD
	waypoint_offsets = PackedVector3Array([
		Vector3.ZERO,
		flat_direction * 50.0,
	])
	waypoint_index = 1
	active = true
	health = max_health
	visible = true
	collision.set_deferred("disabled", false)
	set_physics_process(true)

func take_damage(amount: float) -> void:
	if not active:
		return
	health = maxf(health - amount, 0.0)
	if health > 0.0:
		return
	active = false
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", true)
	set_physics_process(false)
	visible = false
	defeated.emit()

func take_vehicle_hit(speed: float) -> void:
	if not active or vehicle_hit_cooldown > 0.0 or speed < 2.5:
		return
	vehicle_hit_cooldown = 0.8
	var impact_damage := clampf(speed * 7.0, 18.0, 100.0)
	take_damage(impact_damage)

func _physics_process(delta: float) -> void:
	vehicle_hit_cooldown = maxf(vehicle_hit_cooldown - delta, 0.0)
	_copy_walking_pose()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		player = get_node_or_null("../Player") as Node3D
	if player:
		objective_marker.visible = global_position.distance_to(player.global_position) < 25.0
	var target := patrol_origin + waypoint_offsets[waypoint_index]
	var difference := target - global_position
	difference.y = 0.0
	if difference.length() < 1.0:
		waypoint_index = (waypoint_index + 1) % waypoint_offsets.size()
		target = patrol_origin + waypoint_offsets[waypoint_index]
		difference = target - global_position
		difference.y = 0.0

	var direction := difference.normalized()
	if not direction.is_zero_approx():
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(delta * 5.0, 0.0, 1.0))
	var next_position := global_position + direction * walking_speed * delta
	var ground_hit := _ground_below(next_position)
	if ground_hit.is_empty():
		# No hay calle ni acera delante: invierte el recorrido antes del vacío.
		waypoint_index = (waypoint_index + 1) % waypoint_offsets.size()
		return
	global_position = ground_hit.position + Vector3.UP * 0.85

func _ground_below(position: Vector3) -> Dictionary:
	var from := Vector3(position.x, global_position.y + 5.0, position.z)
	var to := Vector3(position.x, global_position.y - 8.0, position.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var player := get_node_or_null("../Player") as CollisionObject3D
	var car := get_node_or_null("../Car") as CollisionObject3D
	if player:
		query.exclude.append(player.get_rid())
	if car:
		query.exclude.append(car.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var current_floor_height := global_position.y - 0.85
	return hit if absf(hit.position.y - current_floor_height) <= 0.8 else {}

func _prepare_animation() -> void:
	model.scale = Vector3.ONE
	model.position = Vector3.ZERO
	model.rotation.y = PI
	_fit_model_height()
	var players := model.find_children("*", "AnimationPlayer", true, false)
	for player_node in players:
		(player_node as AnimationPlayer).stop()
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	skeleton = skeletons[0] as Skeleton3D
	_prepare_walking_source()

func _fit_model_height() -> void:
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var has_bounds := false
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		var relative_transform := model.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds := relative_transform * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	if not has_bounds or bounds.size.y < 0.001:
		model.scale = Vector3.ONE * 0.25
		model.position.y = -0.6
		return
	var uniform_scale := character_height / bounds.size.y
	model.scale = Vector3.ONE * uniform_scale
	# El origen del CharacterBody está en el centro; coloca los pies en su base.
	model.position.y = -0.72 - bounds.position.y * uniform_scale

func _prepare_walking_source() -> void:
	var source_skeletons := walk_animation_source.find_children("*", "Skeleton3D", true, false)
	var source_players := walk_animation_source.find_children("*", "AnimationPlayer", true, false)
	if source_skeletons.is_empty() or source_players.is_empty():
		return
	source_skeleton = source_skeletons[0] as Skeleton3D
	var source_by_name: Dictionary = {}
	for source_index in source_skeleton.get_bone_count():
		source_by_name[_normalized_bone_name(source_skeleton.get_bone_name(source_index))] = source_index
	for target_index in skeleton.get_bone_count():
		var normalized := _normalized_bone_name(skeleton.get_bone_name(target_index))
		if source_by_name.has(normalized):
			bone_map[target_index] = source_by_name[normalized]
	var animation_player := source_players[0] as AnimationPlayer
	for animation_name in animation_player.get_animation_list():
		if "mixamo" in String(animation_name).to_lower():
			var animation := animation_player.get_animation(animation_name)
			animation.loop_mode = Animation.LOOP_LINEAR
			animation_player.play(animation_name)
			break

func _copy_walking_pose() -> void:
	if not skeleton or not source_skeleton:
		return
	for target_index in bone_map:
		var source_index: int = bone_map[target_index]
		skeleton.set_bone_pose_rotation(target_index, source_skeleton.get_bone_pose_rotation(source_index))

func _normalized_bone_name(bone_name: StringName) -> String:
	var normalized := String(bone_name).to_lower()
	if ":" in normalized:
		normalized = normalized.get_slice(":", normalized.get_slice_count(":") - 1)
	return normalized.replace("mixamorig1", "").replace("mixamorig", "").replace("_", "").replace("-", "")
