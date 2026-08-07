extends Control

@export var radar_range := 180.0
@export var player_path: NodePath
@export var car_path: NodePath
@export var marker_path: NodePath

@onready var player: Node3D = get_node(player_path)
@onready var car: Node3D = get_node(car_path)
@onready var marker: Node3D = get_node(marker_path)
@onready var distance_label: Label = $Distance
@onready var trend_label: Label = $Trend

const RADIUS := 78.0
const CENTER := Vector2(82, 82)

var previous_distance := -1.0
var sample_time := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _process(delta: float) -> void:
    _update_approach(delta)
    queue_redraw()

func _draw() -> void:
    draw_circle(CENTER, RADIUS + 4.0, Color(0.02, 0.03, 0.04, 0.9))
    draw_circle(CENTER, RADIUS, Color(0.08, 0.11, 0.13, 0.86))
    draw_arc(CENTER, RADIUS, 0.0, TAU, 64, Color(0.75, 0.8, 0.82, 0.9), 2.0)
    draw_arc(CENTER, RADIUS * 0.5, 0.0, TAU, 48, Color(0.35, 0.4, 0.42, 0.55), 1.0)
    draw_line(CENTER + Vector2(-RADIUS, 0), CENTER + Vector2(RADIUS, 0), Color(0.3, 0.35, 0.37, 0.45))
    draw_line(CENTER + Vector2(0, -RADIUS), CENTER + Vector2(0, RADIUS), Color(0.3, 0.35, 0.37, 0.45))
    draw_string(ThemeDB.fallback_font, CENTER + Vector2(-5, -RADIUS - 8), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

    var focus := car if not player.visible else player
    _draw_car(_radar_position(focus, car), car.global_rotation.y)
    if player.visible:
        _draw_dot(_radar_position(focus, player), Color.WHITE, 5.0)
    if marker.visible:
        var marker_position := _radar_position(focus, marker)
        var pulse := 10.0 + sin(Time.get_ticks_msec() * 0.008) * 3.0
        draw_line(CENTER, marker_position, Color(1.0, 0.82, 0.05, 0.38), 2.0)
        draw_circle(marker_position, pulse, Color(1.0, 0.72, 0.0, 0.24))
        _draw_dot(marker_position, Color(1.0, 0.82, 0.05), 5.0)


func _update_approach(delta: float) -> void:
    if not marker.visible:
        distance_label.text = "OBJETIVO COMPLETADO"
        trend_label.text = ""
        return

    var focus := car if not player.visible else player
    var difference := marker.global_position - focus.global_position
    var distance := Vector2(difference.x, difference.z).length()
    distance_label.text = "%d METROS" % roundi(distance)
    sample_time += delta
    if sample_time < 0.4:
        return

    if previous_distance >= 0.0:
        var change := previous_distance - distance
        if change > 0.25:
            trend_label.text = "ACERCÁNDOTE"
            trend_label.modulate = Color(0.25, 1.0, 0.38)
        elif change < -0.25:
            trend_label.text = "ALEJÁNDOTE"
            trend_label.modulate = Color(1.0, 0.3, 0.22)
        else:
            trend_label.text = "MISMA DISTANCIA"
            trend_label.modulate = Color(1.0, 0.82, 0.2)
    previous_distance = distance
    sample_time = 0.0
func _radar_position(focus: Node3D, target: Node3D) -> Vector2:
    var difference := target.global_position - focus.global_position
    var offset := Vector2(difference.x, difference.z) * (RADIUS / radar_range)
    if offset.length() > RADIUS - 7.0:
        offset = offset.normalized() * (RADIUS - 7.0)
    return CENTER + offset

func _draw_dot(position_2d: Vector2, color: Color, radius: float) -> void:
    draw_circle(position_2d, radius + 2.0, Color(0, 0, 0, 0.75))
    draw_circle(position_2d, radius, color)
func _draw_car(position_2d: Vector2, heading: float) -> void:
    var points := PackedVector2Array([
        position_2d + Vector2(0, -9).rotated(-heading),
        position_2d + Vector2(-6, 7).rotated(-heading),
        position_2d + Vector2(6, 7).rotated(-heading)
    ])
    draw_colored_polygon(points, Color(0.1, 0.65, 1.0))
    draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, 0.85), 2.0)