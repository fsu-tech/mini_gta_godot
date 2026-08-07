extends Node3D

@onready var idle_model: Node3D = $IdleModel
@onready var walking_model: Node3D = $WalkingModel
@onready var running_model: Node3D = $RunningModel

var models: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var current_state := -1

func _ready() -> void:
    scale = Vector3.ONE * 0.25
    position.y = -0.6
    rotation.y = PI
    models = [idle_model, walking_model, running_model]

    for model in models:
        var animation_player := _find_animation_player(model)
        players.append(animation_player)
        if animation_player:
            var animation_name := _first_animation(animation_player)
            if animation_name != "":
                var animation := animation_player.get_animation(animation_name)
                _make_in_place(animation)
                animation.loop_mode = Animation.LOOP_LINEAR
                animation_player.play(animation_name)
        else:
            push_warning("No se encontró AnimationPlayer en " + model.name)

    _set_state(0)

func set_motion(is_moving: bool, is_running: bool) -> void:
    if not is_moving:
        _set_state(0)
    elif is_running:
        _set_state(2)
    else:
        _set_state(1)

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