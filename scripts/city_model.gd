extends Node3D

const DAMAGEABLE_BUILDING := preload("res://scripts/damageable_building.gd")

@export var generate_collisions := true
@export var generate_invisible_limits := true
@export var limit_margin := 2.0
@export var limit_height := 20.0
@export var limit_thickness := 2.0

func _ready() -> void:
    var meshes := find_children("*", "MeshInstance3D", true, false)
    if generate_collisions:
        for child in meshes:
            var mesh_instance := child as MeshInstance3D
            if mesh_instance and mesh_instance.mesh:
                mesh_instance.create_trimesh_collision()
                for body in mesh_instance.find_children("*", "StaticBody3D", true, false):
                    var static_body := body as StaticBody3D
                    if static_body and static_body.get_script() == null:
                        static_body.set_script(DAMAGEABLE_BUILDING)
    if generate_invisible_limits:
        _create_invisible_limits(meshes)

func _create_invisible_limits(meshes: Array[Node]) -> void:
    var bounds := AABB()
    var has_bounds := false
    for child in meshes:
        var mesh_instance := child as MeshInstance3D
        if mesh_instance and mesh_instance.mesh:
            var global_box := mesh_instance.global_transform * mesh_instance.get_aabb()
            bounds = bounds.merge(global_box) if has_bounds else global_box
            has_bounds = true
    if not has_bounds:
        return

    var min_x := bounds.position.x - limit_margin
    var max_x := bounds.end.x + limit_margin
    var min_z := bounds.position.z - limit_margin
    var max_z := bounds.end.z + limit_margin
    var center_y := bounds.position.y + limit_height * 0.5
    _add_limit(Vector3(min_x, center_y, (min_z + max_z) * 0.5), Vector3(limit_thickness, limit_height, max_z - min_z))
    _add_limit(Vector3(max_x, center_y, (min_z + max_z) * 0.5), Vector3(limit_thickness, limit_height, max_z - min_z))
    _add_limit(Vector3((min_x + max_x) * 0.5, center_y, min_z), Vector3(max_x - min_x, limit_height, limit_thickness))
    _add_limit(Vector3((min_x + max_x) * 0.5, center_y, max_z), Vector3(max_x - min_x, limit_height, limit_thickness))

func _add_limit(world_position: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = "InvisibleCityLimit"
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    get_tree().current_scene.add_child.call_deferred(body)
    body.global_position = world_position
