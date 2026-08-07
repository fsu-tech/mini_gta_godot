extends Node3D

@export var generate_collisions := true

func _ready() -> void:
    if not generate_collisions:
        return
    for child in find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := child as MeshInstance3D
        if mesh_instance and mesh_instance.mesh:
            mesh_instance.create_trimesh_collision()