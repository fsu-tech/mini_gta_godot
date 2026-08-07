extends Control

var damage_target := false

func set_damage_target(value: bool) -> void:
    if damage_target == value:
        return
    damage_target = value
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var color := Color(1.0, 0.22, 0.16, 0.98) if damage_target else Color(1.0, 1.0, 1.0, 0.95)
    var shadow := Color(0.0, 0.0, 0.0, 0.85)
    draw_circle(center, 3.0, shadow)
    draw_circle(center, 1.7, color)
    draw_arc(center, 10.0, 0.0, TAU, 32, shadow, 4.0, true)
    draw_arc(center, 10.0, 0.0, TAU, 32, color, 1.8, true)
    for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
        draw_line(center + direction * 13.0, center + direction * 18.0, shadow, 4.0, true)
        draw_line(center + direction * 13.0, center + direction * 18.0, color, 1.8, true)
