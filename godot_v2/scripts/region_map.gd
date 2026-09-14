class_name RiftRegionMap
extends Node3D

signal exit_reached

const HALF_WIDTH := 34.0
const NORTH_EDGE := -150.0
const SOUTH_EDGE := 150.0
const REGION_LENGTH := 300.0

const MAP_ZONES := [
    {"id": "camp", "name": "南方營地", "north": 100.0, "south": 150.0},
    {"id": "forest", "name": "森林", "north": 50.0, "south": 100.0},
    {"id": "ruins", "name": "遺跡", "north": 5.0, "south": 50.0},
    {"id": "marsh", "name": "沼澤", "north": -45.0, "south": 5.0},
    {"id": "canyon", "name": "峽谷", "north": -100.0, "south": -45.0},
    {"id": "rift", "name": "裂隙區", "north": -150.0, "south": -100.0},
]

var _materials: Dictionary = {}

func build() -> void:
    name = "Region01_ShatteredMarch"
    _make_materials()
    _build_ground()
    _build_main_road()
    _build_regions()
    _build_boundaries()
    _build_region_exit()

func clamp_player(position: Vector3) -> Vector3:
    position.x = clampf(position.x, -HALF_WIDTH + 1.5, HALF_WIDTH - 1.5)
    position.z = clampf(position.z, NORTH_EDGE + 2.0, SOUTH_EDGE - 2.0)
    return position

func spawn_position() -> Vector3:
    return Vector3(0, 0, 128)

func enemy_spawn_position(slot: int, serial: int, elite: bool = false) -> Vector3:
    var zones := [122.0, 76.0, 30.0, -20.0, -70.0, -122.0]
    var zone_index := zones.size() - 1 if elite else posmod(slot, zones.size())
    var z: float = zones[zone_index] + randf_range(-9.0, 9.0)
    var road_center := _road_x(z)
    var side := -1.0 if (slot + serial) % 2 == 0 else 1.0
    return Vector3(clampf(road_center + side * randf_range(5.0, 14.0), -29.0, 29.0), 0, z)

func road_center_x(z: float) -> float:
    return _road_x(z)

func map_bounds() -> Dictionary:
    return {
        "half_width": HALF_WIDTH,
        "north": NORTH_EDGE,
        "south": SOUTH_EDGE,
        "length": REGION_LENGTH,
    }

func map_zones() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for zone in MAP_ZONES:
        result.append((zone as Dictionary).duplicate(true))
    return result

func map_landmarks() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    result.append({"name": "南方營火", "position": Vector3(_road_x(128.0), 0, 128.0)})
    result.append({"name": "林間石碑", "position": Vector3(_road_x(76.0) + 10.0, 0, 76.0)})
    result.append({"name": "斷垣石門", "position": Vector3(_road_x(30.0) - 10.0, 0, 30.0)})
    result.append({"name": "沼澤信標", "position": Vector3(_road_x(-20.0) + 11.0, 0, -20.0)})
    result.append({"name": "峽谷關口", "position": Vector3(_road_x(-70.0), 0, -70.0)})
    result.append({"name": "裂隙心核", "position": Vector3(_road_x(-124.0) - 9.0, 0, -124.0)})
    result.append({"name": "北方出口", "position": Vector3(_road_x(-145.0), 0, -145.0)})
    return result

func _make_materials() -> void:
    _materials["earth"] = _material(Color(0.055, 0.075, 0.060), 1.0)
    _materials["road"] = _material(Color(0.19, 0.155, 0.105), 1.0)
    _materials["grass"] = _material(Color(0.075, 0.13, 0.075), 1.0)
    _materials["marsh"] = _material(Color(0.045, 0.095, 0.09), 0.92)
    _materials["rock"] = _material(Color(0.12, 0.115, 0.105), 0.96)
    _materials["ruin"] = _material(Color(0.21, 0.19, 0.16), 0.94)
    _materials["rift"] = _material(Color(0.16, 0.045, 0.075), 0.9, Color(0.34, 0.02, 0.08))
    _materials["water"] = _material(Color(0.025, 0.13, 0.17, 0.72), 0.32)
    _materials["fire"] = _material(Color(0.34, 0.11, 0.025), 0.7, Color(1.0, 0.26, 0.03))

func _material(color: Color, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    if color.a < 0.99:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if emission != Color.BLACK:
        mat.emission_enabled = true
        mat.emission = emission
        mat.emission_energy_multiplier = 1.8
    return mat

func _build_ground() -> void:
    _box("Ground", Vector3(0, -0.16, 0), Vector3(HALF_WIDTH * 2.0, 0.30, REGION_LENGTH), _materials["earth"], true)

func _build_main_road() -> void:
    for z in range(int(NORTH_EDGE) + 3, int(SOUTH_EDGE) - 2, 6):
        var z0 := float(z)
        var z1 := minf(z0 + 6.0, SOUTH_EDGE - 2.0)
        var x0 := _road_x(z0)
        var x1 := _road_x(z1)
        var center_z := (z0 + z1) * 0.5
        var center_x := (x0 + x1) * 0.5
        var width := 8.2 + sin(center_z * 0.07) * 1.1
        var length := Vector2(x1 - x0, z1 - z0).length() + 0.55
        var road := _box("Road_%d" % z, Vector3(center_x, 0.025, center_z), Vector3(width, 0.05, length), _materials["road"])
        road.rotation.y = atan2(x1 - x0, z1 - z0)

func _road_x(z: float) -> float:
    return sin(z * 0.038) * 7.0 + sin(z * 0.091) * 2.2

func _build_regions() -> void:
    _camp_region()
    _forest_region()
    _ruins_region()
    _marsh_region()
    _canyon_region()
    _rift_region()

func _camp_region() -> void:
    for p in [Vector3(-10,0.5,132), Vector3(10,0.5,128), Vector3(-14,0.5,116), Vector3(13,0.5,112)]:
        _box("CampProp", p, Vector3(2.4, 1.0, 2.4), _materials["ruin"], true)
    _box("CampGateL", Vector3(-5.8,1.5,101), Vector3(1.2,3.0,1.2), _materials["ruin"], true)
    _box("CampGateR", Vector3(5.8,1.5,101), Vector3(1.2,3.0,1.2), _materials["ruin"], true)
    _cylinder("SouthCampfire", Vector3(_road_x(128.0), 0.20, 128.0), 0.75, 0.22, _materials["fire"])

func _forest_region() -> void:
    for i in range(42):
        var z := randf_range(52.0, 98.0)
        var center := _road_x(z)
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := center + side * randf_range(8.0, 29.0)
        _tree(Vector3(x, 0, z), randf_range(0.8, 1.45))
    var shrine_x := _road_x(76.0) + 10.0
    _box("ForestShrine", Vector3(shrine_x, 1.35, 76.0), Vector3(1.5, 2.7, 1.0), _materials["ruin"], true)

func _ruins_region() -> void:
    for i in range(18):
        var z := randf_range(8.0, 48.0)
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := _road_x(z) + side * randf_range(9.0, 25.0)
        _box("Ruin_%d" % i, Vector3(x, randf_range(0.5,1.2), z), Vector3(randf_range(1.2,3.8), randf_range(1.0,2.4), randf_range(1.0,3.0)), _materials["ruin"], true)
    _box("Bridge", Vector3(_road_x(7), 0.22, 4), Vector3(10,0.4,10), _materials["ruin"], true)
    var gate_x := _road_x(30.0) - 10.0
    _box("RuinLandmarkL", Vector3(gate_x - 2.5, 2.0, 30.0), Vector3(1.2, 4.0, 1.2), _materials["ruin"], true)
    _box("RuinLandmarkR", Vector3(gate_x + 2.5, 2.0, 30.0), Vector3(1.2, 4.0, 1.2), _materials["ruin"], true)

func _marsh_region() -> void:
    for i in range(13):
        var z := randf_range(-42.0, 2.0)
        var x := randf_range(-28.0, 28.0)
        if absf(x - _road_x(z)) < 6.5:
            continue
        _box("Pool_%d" % i, Vector3(x,-0.03,z), Vector3(randf_range(3.5,8.0),0.04,randf_range(3.0,7.0)), _materials["water"])
    for i in range(24):
        var z := randf_range(-42.0, 2.0)
        _rock(Vector3(randf_range(-30,30),0,z), randf_range(0.5,1.3))
    var beacon_x := _road_x(-20.0) + 11.0
    _cylinder("MarshBeacon", Vector3(beacon_x, 0.65, -20.0), 0.7, 1.3, _materials["rift"], true)

func _canyon_region() -> void:
    for z in range(-96, -44, 7):
        var center := _road_x(float(z))
        _rock(Vector3(center - randf_range(12,19),0,float(z)), randf_range(1.5,2.8), true)
        _rock(Vector3(center + randf_range(12,19),0,float(z)), randf_range(1.5,2.8), true)
    var gate_center := _road_x(-70.0)
    _rock(Vector3(gate_center - 8.5, 0, -70.0), 2.7, true)
    _rock(Vector3(gate_center + 8.5, 0, -70.0), 2.7, true)

func _rift_region() -> void:
    for i in range(22):
        var z := randf_range(-143.0, -101.0)
        var x := randf_range(-29.0, 29.0)
        if absf(x - _road_x(z)) < 5.0:
            continue
        _rock(Vector3(x,0,z), randf_range(0.8,2.0))
    for i in range(8):
        var z := -108.0 - float(i) * 4.2
        _box("RiftSpire_%d" % i, Vector3(_road_x(z) + (-1 if i%2==0 else 1) * randf_range(7,14), randf_range(1.4,2.8), z), Vector3(randf_range(0.7,1.4), randf_range(2.8,5.6), randf_range(0.7,1.4)), _materials["rift"], true)
    var heart_x := _road_x(-124.0) - 9.0
    _cylinder("RiftHeartAltar", Vector3(heart_x, 0.20, -124.0), 3.1, 0.38, _materials["rift"], true)
    _box("RiftHeart", Vector3(heart_x, 1.8, -124.0), Vector3(1.4, 3.6, 1.4), _materials["rift"], true)

func _build_boundaries() -> void:
    for z in range(int(NORTH_EDGE), int(SOUTH_EDGE) + 1, 8):
        _rock(Vector3(-HALF_WIDTH - 1.2,0,float(z)), randf_range(1.4,2.6), true)
        _rock(Vector3(HALF_WIDTH + 1.2,0,float(z)), randf_range(1.4,2.6), true)

func _build_region_exit() -> void:
    var z := -145.0
    var center := _road_x(z)
    _box("NorthExitPillarL", Vector3(center - 5.3, 2.4, z), Vector3(1.4, 4.8, 1.4), _materials["rift"], true)
    _box("NorthExitPillarR", Vector3(center + 5.3, 2.4, z), Vector3(1.4, 4.8, 1.4), _materials["rift"], true)
    _box("NorthExitLintel", Vector3(center, 4.6, z), Vector3(12.0, 1.0, 1.4), _materials["rift"], true)

    var area := Area3D.new()
    area.name = "Region02Exit"
    area.position = Vector3(center, 1.1, z + 2.0)
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(10.0, 2.2, 5.0)
    shape_node.shape = shape
    area.add_child(shape_node)
    area.body_entered.connect(_on_exit_body_entered)
    add_child(area)

func _on_exit_body_entered(body: Node3D) -> void:
    if body.name == "Player":
        exit_reached.emit()

func _tree(pos: Vector3, scale_value: float) -> void:
    _box("Tree", pos + Vector3(0,1.0*scale_value,0), Vector3(0.7,2.0,0.7)*scale_value, _materials["rock"], true)
    var crown := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.2 * scale_value
    mesh.bottom_radius = 1.7 * scale_value
    mesh.height = 3.4 * scale_value
    crown.mesh = mesh
    crown.position = pos + Vector3(0,3.0*scale_value,0)
    crown.material_override = _materials["grass"]
    add_child(crown)

func _rock(pos: Vector3, scale_value: float, collision := false) -> void:
    var size := Vector3(1.4, randf_range(1.0,2.0), 1.2) * scale_value
    _box("Rock", pos + Vector3(0,size.y*0.5,0), size, _materials["rock"], collision)

func _cylinder(node_name: String, pos: Vector3, radius: float, height: float, material: Material, collision := false) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh_node.mesh = mesh
    mesh_node.position = pos
    mesh_node.material_override = material
    add_child(mesh_node)
    if collision:
        var body := StaticBody3D.new()
        var shape_node := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = radius
        shape.height = height
        shape_node.shape = shape
        body.position = pos
        body.add_child(shape_node)
        add_child(body)
    return mesh_node

func _box(node_name: String, pos: Vector3, size: Vector3, material: Material, collision := false) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.position = pos
    mesh_node.material_override = material
    add_child(mesh_node)
    if collision:
        var body := StaticBody3D.new()
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.position = pos
        body.add_child(shape_node)
        add_child(body)
    return mesh_node
