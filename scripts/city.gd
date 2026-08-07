extends Node3D

var asphalt := StandardMaterial3D.new()
var sidewalk := StandardMaterial3D.new()
var line_white := StandardMaterial3D.new()
var line_yellow := StandardMaterial3D.new()
var building_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
    asphalt.albedo_color = Color("252a30")
    asphalt.roughness = 0.92
    sidewalk.albedo_color = Color("aeb4b8")
    line_white.albedo_color = Color("eeeeea")
    line_yellow.albedo_color = Color("f2c94c")

    for color in ["7189a6", "b97864", "8e9b78", "9a82a8", "c09a68", "697887"]:
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(color)
        material.roughness = 0.8
        building_materials.append(material)

    _create_roads()
    _create_city_blocks()

func _create_roads() -> void:
    _add_box("RoadNorthSouth", Vector3(12.0, 0.08, 100.0), Vector3(0, 0.02, 0), asphalt)
    _add_box("RoadEastWest", Vector3(100.0, 0.08, 12.0), Vector3(0, 0.025, 0), asphalt)
    _add_box("RoadWest", Vector3(10.0, 0.08, 100.0), Vector3(-30, 0.02, 0), asphalt)
    _add_box("RoadEast", Vector3(10.0, 0.08, 100.0), Vector3(30, 0.02, 0), asphalt)

    for z in range(-45, 46, 8):
        if abs(z) > 8:
            _add_box("CenterLine", Vector3(0.18, 0.035, 4.2), Vector3(0, 0.09, z), line_yellow)
            _add_box("WestLine", Vector3(0.15, 0.035, 4.2), Vector3(-30, 0.09, z), line_white)
            _add_box("EastLine", Vector3(0.15, 0.035, 4.2), Vector3(30, 0.09, z), line_white)

    for x in range(-45, 46, 8):
        if abs(x) > 8:
            _add_box("CrossLine", Vector3(4.2, 0.035, 0.18), Vector3(x, 0.095, 0), line_yellow)

    for x in [-36.0, -24.0, -6.8, 6.8, 24.0, 36.0]:
        _add_box("Sidewalk", Vector3(1.5, 0.22, 100.0), Vector3(x, 0.11, 0), sidewalk)
    for z in [-6.8, 6.8]:
        _add_box("Sidewalk", Vector3(100.0, 0.22, 1.5), Vector3(0, 0.12, z), sidewalk)

func _create_city_blocks() -> void:
    var lots := [
        Vector3(-43, 0, -34), Vector3(-18, 0, -35), Vector3(17, 0, -35), Vector3(43, 0, -34),
        Vector3(-43, 0, -17), Vector3(-18, 0, -18), Vector3(18, 0, -18), Vector3(43, 0, -17),
        Vector3(-43, 0, 17), Vector3(-18, 0, 18), Vector3(18, 0, 18), Vector3(43, 0, 17),
        Vector3(-43, 0, 36), Vector3(-18, 0, 35), Vector3(18, 0, 35), Vector3(43, 0, 36)
    ]
    var heights := [10.0, 16.0, 12.0, 20.0, 14.0, 9.0, 18.0, 12.0, 17.0, 22.0, 11.0, 15.0, 13.0, 19.0, 14.0, 21.0]

    for index in lots.size():
        var width := 9.0 if index % 3 == 0 else 11.0
        var depth := 10.0 if index % 2 == 0 else 8.0
        _add_building("Building_%02d" % index, lots[index], Vector3(width, heights[index], depth), building_materials[index % building_materials.size()])

func _add_building(node_name: String, ground_position: Vector3, size: Vector3, material: Material) -> void:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = ground_position + Vector3.UP * size.y * 0.5
    add_child(body)

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    mesh_instance.mesh = mesh
    body.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

    var roof := MeshInstance3D.new()
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(size.x * 0.35, 0.8, size.z * 0.35)
    roof_mesh.material = sidewalk
    roof.mesh = roof_mesh
    roof.position.y = size.y * 0.5 + 0.4
    body.add_child(roof)

func _add_box(node_name: String, size: Vector3, position_3d: Vector3, material: Material) -> void:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    mesh_instance.position = position_3d
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    mesh_instance.mesh = mesh
    add_child(mesh_instance)