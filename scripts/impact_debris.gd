extends Node3D

var pieces: Array[MeshInstance3D] = []
var velocities: Array[Vector3] = []
var remaining := 0.85

func setup(surface_normal: Vector3, material_type: String) -> void:
    var random := RandomNumberGenerator.new()
    random.randomize()
    var color := Color(0.42, 0.4, 0.37)
    var piece_count := 9
    if material_type == "metal":
        color = Color(1.0, 0.55, 0.12)
        piece_count = 12
    elif material_type == "dirt":
        color = Color(0.28, 0.2, 0.12)
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    if material_type == "metal":
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 2.5
    for index in piece_count:
        var piece := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        var size := random.randf_range(0.018, 0.045)
        mesh.size = Vector3(size, size * random.randf_range(0.35, 1.0), size)
        mesh.material = material
        piece.mesh = mesh
        add_child(piece)
        pieces.append(piece)
        var tangent := Vector3(random.randf_range(-1.0, 1.0), random.randf_range(-0.2, 1.0), random.randf_range(-1.0, 1.0))
        velocities.append((surface_normal * random.randf_range(1.2, 3.2) + tangent).normalized() * random.randf_range(1.4, 3.8))

func _process(delta: float) -> void:
    remaining -= delta
    for index in pieces.size():
        velocities[index] += Vector3.DOWN * 7.5 * delta
        pieces[index].position += velocities[index] * delta
        pieces[index].rotate_x(delta * (index + 2) * 2.4)
        pieces[index].rotate_z(delta * (index + 3) * 1.7)
    if remaining <= 0.0:
        queue_free()

