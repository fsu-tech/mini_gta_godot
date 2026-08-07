extends Node3D

const DAMAGEABLE_BUILDING := preload("res://scripts/damageable_building.gd")

@export var generate_collisions := true

func _ready() -> void:
    if not generate_collisions:
        return
    for child in find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := child as MeshInstance3D
        if mesh_instance and mesh_instance.mesh:
            mesh_instance.create_trimesh_collision()
            for body in mesh_instance.find_children("*", "StaticBody3D", true, false):
                var static_body := body as StaticBody3D
                if static_body and static_body.get_script() == null:
                    static_body.set_script(DAMAGEABLE_BUILDING)
