class_name RiftRegionMap
extends Node3D

signal exit_reached

const HALF_WIDTH := 34.0
const NORTH_EDGE := -150.0
const SOUTH_EDGE := 150.0
const REGION_LENGTH := 300.0
const REGION_SEED := 9102026

const CHUNK_LENGTH := 20.0
const CHUNK_COUNT := 15
const ACTIVE_CHUNK_RADIUS := 2
const TERRAIN_X_SEGMENTS := 17
const TERRAIN_Z_SEGMENTS := 5
const ROAD_SAMPLES_PER_CHUNK := 10

const MAP_ZONES := [
    {"id": "camp", "name": "南方營地", "north": 100.0, "south": 150.0},
    {"id": "forest", "name": "森林", "north": 50.0, "south": 100.0},
    {"id": "ruins", "name": "遺跡", "north": 5.0, "south": 50.0},
    {"id": "marsh", "name": "沼澤", "north": -45.0, "south": 5.0},
    {"id": "canyon", "name": "峽谷", "north": -100.0, "south": -45.0},
    {"id": "rift", "name": "裂隙區", "north": -150.0, "south": -100.0},
]

var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _chunk_root: Node3D
var _loaded_chunks: Dictionary = {}
var _stream_center := -999

func build() -> void:
    name = "Region01_ShatteredMarch"
    _rng.seed = REGION_SEED
    _make_materials()
    _build_ground_contract()
    _init_terrain_streaming()
    _build_regions()
    _build_boundaries()
    _build_region_exit()

func clamp_player(position: Vector3) -> Vector3:
    position.x = clampf(position.x, -HALF_WIDTH + 1.5, HALF_WIDTH - 1.5)
    position.z = clampf(position.z, NORTH_EDGE + 2.0, SOUTH_EDGE - 2.0)
    position.y = surface_height(position.x, position.z)
    return position

func spawn_position() -> Vector3:
    var pos := Vector3(0, 0, 128)
    pos.y = surface_height(pos.x, pos.z)
    return pos

func enemy_spawn_position(slot: int, serial: int, elite: bool = false) -> Vector3:
    var zones := [122.0, 76.0, 30.0, -20.0, -70.0, -122.0]
    var zone_index := zones.size() - 1 if elite else posmod(slot, zones.size())
    var z: float = zones[zone_index] + _rng.randf_range(-9.0, 9.0)
    var road_center := _road_x(z)
    var side := -1.0 if (slot + serial) % 2 == 0 else 1.0
    var x := clampf(road_center + side * _rng.randf_range(5.0, 14.0), -29.0, 29.0)
    return Vector3(x, surface_height(x, z), z)

func road_center_x(z: float) -> float:
    return _road_x(z)

func surface_height(x: float, z: float) -> float:
    var longitudinal := sin(z * 0.031) * 0.16 + sin(z * 0.071) * 0.07
    var road_distance := absf(x - _road_x(z))
    var lateral_mix := clampf((road_distance - 4.5) / 11.0, 0.0, 1.0)
    lateral_mix = _smooth01(lateral_mix)
    var lateral := (
        sin(x * 0.17 + z * 0.043) * 0.20
        + cos(x * 0.11 - z * 0.052) * 0.12
    ) * lateral_mix
    if z > 100.0:
        lateral *= 0.35
    elif z < -45.0 and z > -100.0:
        lateral += sin((x - _road_x(z)) * 0.10) * 0.16 * lateral_mix
    elif z <= -100.0:
        lateral += cos(x * 0.13 + z * 0.08) * 0.10 * lateral_mix
    return longitudinal + lateral

func update_streaming(player_position: Vector3) -> void:
    var center := _chunk_index_for_z(player_position.z)
    if center == _stream_center:
        return
    _stream_center = center

    var wanted: Dictionary = {}
    var first := maxi(0, center - ACTIVE_CHUNK_RADIUS)
    var last := mini(CHUNK_COUNT - 1, center + ACTIVE_CHUNK_RADIUS)
    for index in range(first, last + 1):
        wanted[index] = true
        if not _loaded_chunks.has(index):
            _loaded_chunks[index] = _build_chunk(index)

    for key in _loaded_chunks.keys():
        var index := int(key)
        if not wanted.has(index):
            var chunk := _loaded_chunks[index] as Node3D
            if is_instance_valid(chunk):
                chunk.queue_free()
            _loaded_chunks.erase(index)

func streaming_state() -> Dictionary:
    var active: Array[int] = []
    for key in _loaded_chunks.keys():
        active.append(int(key))
    active.sort()
    return {
        "chunk_length": CHUNK_LENGTH,
        "chunk_total": CHUNK_COUNT,
        "active_radius": ACTIVE_CHUNK_RADIUS,
        "loaded": active.size(),
        "active": active,
        "center": _stream_center,
    }

func terrain_visual_state() -> Dictionary:
    var spawn_color := _terrain_color(0.0, 128.0)
    var forest_color := _terrain_color(12.0, 76.0)
    return {
        "spawn_color": spawn_color,
        "forest_color": forest_color,
        "spawn_luminance": spawn_color.r * 0.2126 + spawn_color.g * 0.7152 + spawn_color.b * 0.0722,
    }

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
    var terrain := StandardMaterial3D.new()
    terrain.albedo_color = Color.WHITE
    terrain.roughness = 0.94
    terrain.metallic = 0.0
    terrain.vertex_color_use_as_albedo = true
    _materials["terrain"] = terrain
    _materials["earth"] = _material(Color(0.24, 0.28, 0.17), 1.0)
    _materials["road"] = _material(Color(0.36, 0.27, 0.15), 0.98)
    _materials["grass"] = _material(Color(0.18, 0.32, 0.13), 1.0)
    _materials["marsh"] = _material(Color(0.11, 0.22, 0.19), 0.92)
    _materials["rock"] = _material(Color(0.27, 0.25, 0.22), 0.96)
    _materials["ruin"] = _material(Color(0.36, 0.33, 0.28), 0.94)
    _materials["rift"] = _material(Color(0.27, 0.09, 0.14), 0.9, Color(0.22, 0.025, 0.06))
    _materials["water"] = _material(Color(0.055, 0.24, 0.30, 0.78), 0.30)
    _materials["fire"] = _material(Color(0.58, 0.20, 0.035), 0.65, Color(1.0, 0.30, 0.035))

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

func _build_ground_contract() -> void:
    var body := StaticBody3D.new()
    body.name = "Ground"
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(HALF_WIDTH * 2.0, 0.5, REGION_LENGTH)
    shape_node.shape = shape
    body.position = Vector3(0, -0.40, 0)
    body.add_child(shape_node)
    add_child(body)

func _init_terrain_streaming() -> void:
    _chunk_root = Node3D.new()
    _chunk_root.name = "TerrainChunks"
    add_child(_chunk_root)
    update_streaming(spawn_position())

func _chunk_index_for_z(z: float) -> int:
    return clampi(int(floor((SOUTH_EDGE - z) / CHUNK_LENGTH)), 0, CHUNK_COUNT - 1)

func _chunk_south(index: int) -> float:
    return SOUTH_EDGE - float(index) * CHUNK_LENGTH

func _chunk_north(index: int) -> float:
    return maxf(NORTH_EDGE, _chunk_south(index) - CHUNK_LENGTH)

func _build_chunk(index: int) -> Node3D:
    var chunk := Node3D.new()
    chunk.name = "Chunk_%02d" % index
    _chunk_root.add_child(chunk)
    var south := _chunk_south(index)
    var north := _chunk_north(index)
    _build_terrain_mesh(chunk, index, north, south)
    _build_road_mesh(chunk, index, north, south)
    _build_chunk_scatter(chunk, index, north, south)
    return chunk

func _build_terrain_mesh(chunk: Node3D, index: int, north: float, south: float) -> void:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()

    for row in range(TERRAIN_Z_SEGMENTS + 1):
        var z := lerpf(south, north, float(row) / float(TERRAIN_Z_SEGMENTS))
        for col in range(TERRAIN_X_SEGMENTS + 1):
            var x := lerpf(-HALF_WIDTH, HALF_WIDTH, float(col) / float(TERRAIN_X_SEGMENTS))
            var y := surface_height(x, z)
            vertices.append(Vector3(x, y, z))
            normals.append(_terrain_normal(x, z))
            colors.append(_terrain_color(x, z))

    var stride := TERRAIN_X_SEGMENTS + 1
    for row in range(TERRAIN_Z_SEGMENTS):
        for col in range(TERRAIN_X_SEGMENTS):
            var a := row * stride + col
            var b := a + 1
            var c := (row + 1) * stride + col
            var d := c + 1
            indices.append_array(PackedInt32Array([a, b, c, b, d, c]))

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    mesh.surface_set_material(0, _materials["terrain"])

    var mesh_node := MeshInstance3D.new()
    mesh_node.name = "Terrain_%02d" % index
    mesh_node.mesh = mesh
    chunk.add_child(mesh_node)

func _terrain_normal(x: float, z: float) -> Vector3:
    var step := 0.35
    var left := surface_height(x - step, z)
    var right := surface_height(x + step, z)
    var north := surface_height(x, z - step)
    var south := surface_height(x, z + step)
    return Vector3(left - right, step * 2.0, north - south).normalized()

func _terrain_color(x: float, z: float) -> Color:
    var camp := Color(0.30, 0.37, 0.20)
    var forest := Color(0.16, 0.30, 0.14)
    var ruins := Color(0.31, 0.28, 0.20)
    var marsh := Color(0.12, 0.24, 0.21)
    var canyon := Color(0.32, 0.23, 0.15)
    var rift := Color(0.24, 0.11, 0.17)
    var base := camp
    if z >= 125.0:
        base = camp
    elif z >= 75.0:
        base = camp.lerp(forest, _smooth01((125.0 - z) / 50.0))
    elif z >= 27.5:
        base = forest.lerp(ruins, _smooth01((75.0 - z) / 47.5))
    elif z >= -20.0:
        base = ruins.lerp(marsh, _smooth01((27.5 - z) / 47.5))
    elif z >= -72.5:
        base = marsh.lerp(canyon, _smooth01((-20.0 - z) / 52.5))
    elif z >= -125.0:
        base = canyon.lerp(rift, _smooth01((-72.5 - z) / 52.5))
    else:
        base = rift

    var variation := sin(x * 0.31 + z * 0.073) * 0.055 + cos(x * 0.17 - z * 0.113) * 0.035
    var road_distance := absf(x - _road_x(z))
    var shoulder := 1.0 - _smooth01(clampf((road_distance - 4.0) / 8.0, 0.0, 1.0))
    var dirt := Color(0.34, 0.27, 0.16)
    base = base.lerp(dirt, shoulder * 0.18)
    var brightness := 1.0 + variation
    return Color(
        clampf(base.r * brightness, 0.0, 1.0),
        clampf(base.g * brightness, 0.0, 1.0),
        clampf(base.b * brightness, 0.0, 1.0),
        1.0
    )

func _build_road_mesh(chunk: Node3D, index: int, north: float, south: float) -> void:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()

    for sample in range(ROAD_SAMPLES_PER_CHUNK + 1):
        var t := float(sample) / float(ROAD_SAMPLES_PER_CHUNK)
        var z := lerpf(south, north, t)
        var center_x := _road_x(z)
        var prev_z := minf(SOUTH_EDGE, z + 0.5)
        var next_z := maxf(NORTH_EDGE, z - 0.5)
        var forward := Vector2(_road_x(next_z) - _road_x(prev_z), next_z - prev_z).normalized()
        var side := Vector2(-forward.y, forward.x)
        var width := 8.2 + sin(z * 0.07) * 1.1
        var left_x := center_x - side.x * width * 0.5
        var left_z := z - side.y * width * 0.5
        var right_x := center_x + side.x * width * 0.5
        var right_z := z + side.y * width * 0.5
        vertices.append(Vector3(left_x, surface_height(left_x, left_z) + 0.035, left_z))
        vertices.append(Vector3(right_x, surface_height(right_x, right_z) + 0.035, right_z))
        normals.append(Vector3.UP)
        normals.append(Vector3.UP)
        colors.append(Color.WHITE)
        colors.append(Color.WHITE)

    for sample in range(ROAD_SAMPLES_PER_CHUNK):
        var a := sample * 2
        var b := a + 1
        var c := (sample + 1) * 2
        var d := c + 1
        indices.append_array(PackedInt32Array([a, b, c, b, d, c]))

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    mesh.surface_set_material(0, _materials["road"])

    var road := MeshInstance3D.new()
    road.name = "Road_%02d" % index
    road.mesh = mesh
    chunk.add_child(road)

func _build_chunk_scatter(chunk: Node3D, index: int, north: float, south: float) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = REGION_SEED + index * 7919
    var grass_transforms: Array[Transform3D] = []
    var pebble_transforms: Array[Transform3D] = []

    for attempt in range(72):
        var z := rng.randf_range(north + 0.5, south - 0.5)
        var x := rng.randf_range(-HALF_WIDTH + 1.0, HALF_WIDTH - 1.0)
        if absf(x - _road_x(z)) < 6.0:
            continue
        var zone_id := _zone_id_for_z(z)
        var pos := Vector3(x, surface_height(x, z), z)
        var angle := rng.randf_range(0.0, TAU)
        if zone_id == "forest" or zone_id == "camp" or zone_id == "marsh":
            if grass_transforms.size() < 24:
                var basis := Basis(Vector3.UP, angle).scaled(Vector3(rng.randf_range(0.75, 1.3), rng.randf_range(0.7, 1.5), rng.randf_range(0.75, 1.3)))
                grass_transforms.append(Transform3D(basis, pos + Vector3(0, 0.10, 0)))
        elif pebble_transforms.size() < 18:
            var pebble_basis := Basis(Vector3.UP, angle).scaled(Vector3(rng.randf_range(0.6, 1.5), rng.randf_range(0.45, 0.9), rng.randf_range(0.6, 1.5)))
            pebble_transforms.append(Transform3D(pebble_basis, pos + Vector3(0, 0.055, 0)))

    if not grass_transforms.is_empty():
        var grass_mesh := BoxMesh.new()
        grass_mesh.size = Vector3(0.10, 0.20, 0.10)
        _add_multimesh(chunk, "GrassScatter", grass_mesh, _materials["grass"], grass_transforms)
    if not pebble_transforms.is_empty():
        var pebble_mesh := BoxMesh.new()
        pebble_mesh.size = Vector3(0.28, 0.11, 0.22)
        _add_multimesh(chunk, "PebbleScatter", pebble_mesh, _materials["rock"], pebble_transforms)

func _add_multimesh(parent: Node3D, node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    multimesh.instance_count = transforms.size()
    for i in range(transforms.size()):
        multimesh.set_instance_transform(i, transforms[i])
    var instance := MultiMeshInstance3D.new()
    instance.name = node_name
    instance.multimesh = multimesh
    instance.material_override = material
    parent.add_child(instance)

func _smooth01(value: float) -> float:
    var t := clampf(value, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

func _zone_id_for_z(z: float) -> String:
    for zone in MAP_ZONES:
        var data := zone as Dictionary
        if z <= float(data["south"]) and z >= float(data["north"]):
            return String(data["id"])
    return "rift" if z < NORTH_EDGE else "camp"

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
        var z := _rng.randf_range(52.0, 98.0)
        var center := _road_x(z)
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := center + side * _rng.randf_range(8.0, 29.0)
        _tree(Vector3(x, 0, z), _rng.randf_range(0.8, 1.45))
    var shrine_x := _road_x(76.0) + 10.0
    _box("ForestShrine", Vector3(shrine_x, 1.35, 76.0), Vector3(1.5, 2.7, 1.0), _materials["ruin"], true)

func _ruins_region() -> void:
    for i in range(18):
        var z := _rng.randf_range(8.0, 48.0)
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := _road_x(z) + side * _rng.randf_range(9.0, 25.0)
        _box("Ruin_%d" % i, Vector3(x, _rng.randf_range(0.5,1.2), z), Vector3(_rng.randf_range(1.2,3.8), _rng.randf_range(1.0,2.4), _rng.randf_range(1.0,3.0)), _materials["ruin"], true)
    _box("Bridge", Vector3(_road_x(7), 0.22, 4), Vector3(10,0.4,10), _materials["ruin"], true)
    var gate_x := _road_x(30.0) - 10.0
    _box("RuinLandmarkL", Vector3(gate_x - 2.5, 2.0, 30.0), Vector3(1.2, 4.0, 1.2), _materials["ruin"], true)
    _box("RuinLandmarkR", Vector3(gate_x + 2.5, 2.0, 30.0), Vector3(1.2, 4.0, 1.2), _materials["ruin"], true)

func _marsh_region() -> void:
    for i in range(13):
        var z := _rng.randf_range(-42.0, 2.0)
        var x := _rng.randf_range(-28.0, 28.0)
        if absf(x - _road_x(z)) < 6.5:
            continue
        _box("Pool_%d" % i, Vector3(x,-0.03,z), Vector3(_rng.randf_range(3.5,8.0),0.04,_rng.randf_range(3.0,7.0)), _materials["water"])
    for i in range(24):
        var z := _rng.randf_range(-42.0, 2.0)
        _rock(Vector3(_rng.randf_range(-30,30),0,z), _rng.randf_range(0.5,1.3))
    var beacon_x := _road_x(-20.0) + 11.0
    _cylinder("MarshBeacon", Vector3(beacon_x, 0.65, -20.0), 0.7, 1.3, _materials["rift"], true)

func _canyon_region() -> void:
    for z in range(-96, -44, 7):
        var center := _road_x(float(z))
        _rock(Vector3(center - _rng.randf_range(12,19),0,float(z)), _rng.randf_range(1.5,2.8), true)
        _rock(Vector3(center + _rng.randf_range(12,19),0,float(z)), _rng.randf_range(1.5,2.8), true)
    var gate_center := _road_x(-70.0)
    _rock(Vector3(gate_center - 8.5, 0, -70.0), 2.7, true)
    _rock(Vector3(gate_center + 8.5, 0, -70.0), 2.7, true)

func _rift_region() -> void:
    for i in range(22):
        var z := _rng.randf_range(-143.0, -101.0)
        var x := _rng.randf_range(-29.0, 29.0)
        if absf(x - _road_x(z)) < 5.0:
            continue
        _rock(Vector3(x,0,z), _rng.randf_range(0.8,2.0))
    for i in range(8):
        var z := -108.0 - float(i) * 4.2
        _box("RiftSpire_%d" % i, Vector3(_road_x(z) + (-1 if i%2==0 else 1) * _rng.randf_range(7,14), _rng.randf_range(1.4,2.8), z), Vector3(_rng.randf_range(0.7,1.4), _rng.randf_range(2.8,5.6), _rng.randf_range(0.7,1.4)), _materials["rift"], true)
    var heart_x := _road_x(-124.0) - 9.0
    _cylinder("RiftHeartAltar", Vector3(heart_x, 0.20, -124.0), 3.1, 0.38, _materials["rift"], true)
    _box("RiftHeart", Vector3(heart_x, 1.8, -124.0), Vector3(1.4, 3.6, 1.4), _materials["rift"], true)

func _build_boundaries() -> void:
    for z in range(int(NORTH_EDGE), int(SOUTH_EDGE) + 1, 8):
        _rock(Vector3(-HALF_WIDTH - 1.2,0,float(z)), _rng.randf_range(1.4,2.6), true)
        _rock(Vector3(HALF_WIDTH + 1.2,0,float(z)), _rng.randf_range(1.4,2.6), true)

func _build_region_exit() -> void:
    var z := -145.0
    var center := _road_x(z)
    _box("NorthExitPillarL", Vector3(center - 5.3, 2.4, z), Vector3(1.4, 4.8, 1.4), _materials["rift"], true)
    _box("NorthExitPillarR", Vector3(center + 5.3, 2.4, z), Vector3(1.4, 4.8, 1.4), _materials["rift"], true)
    _box("NorthExitLintel", Vector3(center, 4.6, z), Vector3(12.0, 1.0, 1.4), _materials["rift"], true)

    var area := Area3D.new()
    area.name = "Region02Exit"
    area.position = Vector3(center, surface_height(center, z + 2.0) + 1.1, z + 2.0)
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
    crown.position = pos + Vector3(0, surface_height(pos.x, pos.z) + 3.0*scale_value, 0)
    crown.material_override = _materials["grass"]
    add_child(crown)

func _rock(pos: Vector3, scale_value: float, collision := false) -> void:
    var size := Vector3(1.4, _rng.randf_range(1.0,2.0), 1.2) * scale_value
    _box("Rock", pos + Vector3(0,size.y*0.5,0), size, _materials["rock"], collision)

func _cylinder(node_name: String, pos: Vector3, radius: float, height: float, material: Material, collision := false) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh_node.mesh = mesh
    var placed := pos
    placed.y += surface_height(pos.x, pos.z)
    mesh_node.position = placed
    mesh_node.material_override = material
    add_child(mesh_node)
    if collision:
        var body := StaticBody3D.new()
        var shape_node := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = radius
        shape.height = height
        shape_node.shape = shape
        body.position = placed
        body.add_child(shape_node)
        add_child(body)
    return mesh_node

func _box(node_name: String, pos: Vector3, size: Vector3, material: Material, collision := false) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    var placed := pos
    placed.y += surface_height(pos.x, pos.z)
    mesh_node.position = placed
    mesh_node.material_override = material
    add_child(mesh_node)
    if collision:
        var body := StaticBody3D.new()
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.position = placed
        body.add_child(shape_node)
        add_child(body)
    return mesh_node
