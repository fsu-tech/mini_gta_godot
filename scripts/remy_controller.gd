extends Node3D

@onready var idle_model: Node3D = $IdleModel
@onready var walking_model: Node3D = $WalkingModel
@onready var running_model: Node3D = $RunningModel
@onready var pistol_idle_model: Node3D = $PistolIdleModel
@onready var pistol_run_model: Node3D = $PistolRunModel
@onready var shooting_model: Node3D = $ShootingModel
@onready var revolver: Node3D = $PistolIdleModel/Revolver

@export var revolver_grip_offset := Vector3(-0.14, 0.16, 0.10)
@export var revolver_rotation := Vector3(0.0, 0.0, -90.0)
@export var revolver_length := 0.75

var models: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var current_state := -1
var pistol_equipped := false
var pistol_revolver_attachment: BoneAttachment3D
var pistol_run_revolver_attachment: BoneAttachment3D
var shooting_revolver_attachment: BoneAttachment3D
var shooting := false
var shooting_time_remaining := 0.0
var last_is_moving := false
var last_is_running := false

func _ready() -> void:
    scale = Vector3.ONE * 0.25
    position.y = -0.6
    rotation.y = PI
    models = [idle_model, walking_model, running_model, pistol_idle_model, pistol_run_model, shooting_model]

    for model in models:
        var animation_player := _find_animation_player(model)
        players.append(animation_player)
        if animation_player:
            var animation_name := _first_animation(animation_player)
            if animation_name != "":
                var animation := animation_player.get_animation(animation_name)
                _make_in_place(animation)
                animation.loop_mode = Animation.LOOP_NONE if model == shooting_model else Animation.LOOP_LINEAR
                animation_player.play(animation_name)
        else:
            push_warning("No se encontró AnimationPlayer en " + model.name)

    _attach_revolver_to_hand()
    _set_state(0)

func set_motion(is_moving: bool, is_running: bool) -> void:
    last_is_moving = is_moving
    last_is_running = is_running
    if shooting:
        return
    if pistol_equipped:
        if is_moving and is_running:
            _move_revolver_to(pistol_run_revolver_attachment)
            _set_state(4)
        else:
            _move_revolver_to(pistol_revolver_attachment)
            _set_state(3)
    elif not is_moving:
        _set_state(0)
    elif is_running:
        _set_state(2)
    else:
        _set_state(1)

func toggle_pistol() -> bool:
    if shooting:
        return pistol_equipped
    pistol_equipped = not pistol_equipped
    if pistol_equipped:
        _move_revolver_to(pistol_revolver_attachment)
    _set_state(3 if pistol_equipped else 0)
    return pistol_equipped

func shoot() -> bool:
    if not pistol_equipped or shooting:
        return false
    shooting = true
    shooting_time_remaining = 0.32
    _move_revolver_to(shooting_revolver_attachment)
    _set_state(5)
    if players[5]:
        var animation_name := _first_animation(players[5])
        if animation_name != "":
            players[5].play(animation_name, 0.04)
    return true

func _process(delta: float) -> void:
    if not shooting:
        return
    shooting_time_remaining -= delta
    if shooting_time_remaining > 0.0:
        return
    shooting = false
    if last_is_moving and last_is_running:
        _move_revolver_to(pistol_run_revolver_attachment)
        _set_state(4)
    else:
        _move_revolver_to(pistol_revolver_attachment)
        _set_state(3)

func get_pistol_eye_position(player: Node3D) -> Vector3:
    var skeletons := pistol_idle_model.find_children("*", "Skeleton3D", true, false)
    if skeletons.is_empty():
        return Vector3(0.0, 0.34, 0.0)
    var skeleton := skeletons[0] as Skeleton3D
    var head_bone := skeleton.find_bone("mixamorig_Head")
    if head_bone < 0:
        return Vector3(0.0, 0.34, 0.0)
    var head_position := skeleton.to_global(skeleton.get_bone_global_pose(head_bone).origin)
    return player.to_local(head_position) + Vector3(0.0, 0.03, 0.0)

func _attach_revolver_to_hand() -> void:
    pistol_revolver_attachment = _create_hand_attachment(pistol_idle_model, "PistolRevolverAttachment")
    pistol_run_revolver_attachment = _create_hand_attachment(pistol_run_model, "PistolRunRevolverAttachment")
    shooting_revolver_attachment = _create_hand_attachment(shooting_model, "ShootingRevolverAttachment")
    if not pistol_revolver_attachment:
        return
    _move_revolver_to(pistol_revolver_attachment)
    _fit_weapon_size(revolver_length)

func _create_hand_attachment(model: Node3D, attachment_name: String) -> BoneAttachment3D:
    var skeletons := model.find_children("*", "Skeleton3D", true, false)
    if skeletons.is_empty():
        push_warning("No se encontró el esqueleto en " + model.name)
        return null
    var skeleton := skeletons[0] as Skeleton3D
    var hand_bone := _find_right_hand_bone(skeleton)
    if hand_bone == "":
        push_warning("No se encontró la mano derecha en " + model.name)
        return null
    var attachment := BoneAttachment3D.new()
    attachment.name = attachment_name
    attachment.bone_name = hand_bone
    skeleton.add_child(attachment)
    return attachment

func _move_revolver_to(attachment: BoneAttachment3D) -> void:
    if not attachment or revolver.get_parent() == attachment:
        return
    revolver.reparent(attachment, false)
    revolver.position = revolver_grip_offset
    revolver.rotation_degrees = revolver_rotation

func _find_right_hand_bone(skeleton: Skeleton3D) -> String:
    for index in skeleton.get_bone_count():
        var bone_name := skeleton.get_bone_name(index)
        var normalized := bone_name.to_lower().replace("_", "").replace("-", "")
        if "righthand" in normalized or ("hand" in normalized and ("right" in normalized or normalized.ends_with("rhand"))):
            return bone_name
    return ""

func _fit_weapon_size(target_length: float) -> void:
    var meshes := revolver.find_children("*", "MeshInstance3D", true, false)
    var bounds := AABB()
    var has_bounds := false
    for mesh_node in meshes:
        var mesh_instance := mesh_node as MeshInstance3D
        var local_bounds := mesh_instance.transform * mesh_instance.get_aabb()
        bounds = bounds.merge(local_bounds) if has_bounds else local_bounds
        has_bounds = true
    if has_bounds:
        var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
        if longest > 0.001:
            revolver.scale = Vector3.ONE * (target_length / longest)

func _set_state(state: int) -> void:
    if state == current_state:
        return
    current_state = state
    for index in models.size():
        models[index].visible = index == state
        if index == state and players[index]:
            var animation_name := _first_animation(players[index])
            if animation_name != "":
                players[index].play(animation_name, 0.12)


func _make_in_place(animation: Animation) -> void:
    for track_index in animation.get_track_count():
        if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
            continue
        var track_path := String(animation.track_get_path(track_index)).to_lower()
        if "hips" not in track_path:
            continue
        if animation.track_get_key_count(track_index) == 0:
            continue
        var origin := animation.track_get_key_value(track_index, 0) as Vector3
        for key_index in animation.track_get_key_count(track_index):
            var value := animation.track_get_key_value(track_index, key_index) as Vector3
            value.x = origin.x
            value.z = origin.z
            animation.track_set_key_value(track_index, key_index, value)
func _find_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    var animation_players := root.find_children("*", "AnimationPlayer", true, false)
    return animation_players[0] as AnimationPlayer if not animation_players.is_empty() else null

func _first_animation(animation_player: AnimationPlayer) -> String:
    for animation_name in animation_player.get_animation_list():
        if "mixamo" in String(animation_name).to_lower():
            return animation_name
    return ""
