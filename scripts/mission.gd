extends Area3D

signal completed
var done := false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if done:
        return
    if body.name == "Player" or body.name == "Car":
        done = true
        completed.emit()
        visible = false
        monitoring = false
