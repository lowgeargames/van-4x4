extends SceneTree
## Ferramenta de autoria: gera somente os recursos da cena experimental.
## Executar manualmente com --script; não é anexada a nenhuma cena de gameplay.

const DIR = "res://assets/environment/terrain_showcase/"
const SIZE = 220.0
const STEP = 2.0
const GRID = 111
const NATURE = "res://assets/environment/quaternius_nature/meshes/"
var route: Curve3D
var samples: PackedVector3Array
var heights: PackedFloat32Array
var distances: PackedFloat32Array
var foliage_count: int = 0
var road_length: float = 0.0


func _initialize() -> void:
	build.call_deferred()


func make_route() -> Curve3D:
	var points: Array[Vector3] = [
		Vector3(-75, 2, 94), Vector3(-75, 2.4, 58), Vector3(-62, 3, 44),
		Vector3(-35, 4, 37), Vector3(-5, 7, 47), Vector3(20, 11, 67),
		Vector3(46, 13, 78), Vector3(73, 12, 68), Vector3(84, 10, 43),
		Vector3(79, 7, 16), Vector3(52, 6, 4), Vector3(23, 6, 5),
		Vector3(3, 9, -11), Vector3(12, 13, -36), Vector3(40, 16, -48),
		Vector3(69, 18, -42), Vector3(85, 18, -60), Vector3(78, 15, -83),
		Vector3(48, 12, -92), Vector3(14, 10, -86), Vector3(-16, 12, -68),
		Vector3(-41, 15, -59), Vector3(-66, 18, -47), Vector3(-82, 20, -23),
		Vector3(-66, 21, -3), Vector3(-42, 23, 2), Vector3(-19, 24, -3)
	]
	var result = Curve3D.new()
	result.bake_interval = 0.5
	for i in points.size():
		var tangent = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]) * 0.18
		result.add_point(points[i], -tangent, tangent)
	return result


func natural_height(x: float, z: float) -> float:
	var h = 8.0 + 3.2 * sin(x / 31.0) + 2.7 * cos(z / 38.0) + 1.8 * sin((x + z) / 24.0)
	h += 17.0 * exp(-((x + 34.0) ** 2 + (z + 26.0) ** 2) / 1450.0)
	h += 11.0 * exp(-((x - 38.0) ** 2 + (z - 37.0) ** 2) / 1250.0)
	h -= 5.0 * exp(-((x + 42.0) ** 2 + (z - 72.0) ** 2) / 1200.0)
	h += 19.0 * pow(maxf(absf(x), absf(z)) / 110.0, 4.0)
	return h


func sculpt(x: float, z: float) -> Vector2:
	# Soma suave de influências evita descontinuidades entre voltas vizinhas.
	var numerator = natural_height(x, z) * 0.12
	var denominator = 0.12
	var closest = INF
	for i in samples.size():
		var p = samples[i]
		var d2 = (x - p.x) ** 2 + (z - p.z) ** 2
		closest = minf(closest, d2)
		if d2 > 625.0:
			continue
		var weight = exp(-d2 / 40.5)
		var t = float(i) / float(samples.size() - 1)
		var uneven = (0.12 * sin(float(i) * 0.9) + 0.06 * cos(float(i) * 1.7)) * smoothstep(0.34, 0.4, t) * (1.0 - smoothstep(0.5, 0.58, t))
		numerator += (p.y + uneven) * weight
		denominator += weight
	var h = numerator / denominator
	h = lerpf(h, 2.0, 1.0 - smoothstep(10.0, 18.0, Vector2(x + 75.0, z - 94.0).length()))
	h = lerpf(h, 24.0, 1.0 - smoothstep(9.0, 17.0, Vector2(x + 19.0, z + 3.0).length()))
	return Vector2(h, sqrt(closest))


func grid_height(ix: int, iz: int) -> float:
	return heights[clampi(iz, 0, GRID - 1) * GRID + clampi(ix, 0, GRID - 1)]


func terrain_height(x: float, z: float) -> float:
	# Mesma triangulação do mesh, inclusive para assentar a vegetação.
	var gx = clampf((x + 110.0) / STEP, 0.0, GRID - 1.001)
	var gz = clampf((z + 110.0) / STEP, 0.0, GRID - 1.001)
	var ix = floori(gx)
	var iz = floori(gz)
	var u = gx - ix
	var v = gz - iz
	if u + v <= 1.0:
		return grid_height(ix, iz) + u * (grid_height(ix + 1, iz) - grid_height(ix, iz)) + v * (grid_height(ix, iz + 1) - grid_height(ix, iz))
	return grid_height(ix + 1, iz + 1) + (1.0 - u) * (grid_height(ix, iz + 1) - grid_height(ix + 1, iz + 1)) + (1.0 - v) * (grid_height(ix + 1, iz) - grid_height(ix + 1, iz + 1))


func ground_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	return mat


func terrain_mesh() -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	for iz in GRID:
		for ix in GRID:
			var x = -110.0 + ix * STEP
			var z = -110.0 + iz * STEP
			var sculpted = sculpt(x, z)
			heights.append(sculpted.x)
			distances.append(sculpted.y)
	for iz in GRID:
		for ix in GRID:
			var x = -110.0 + ix * STEP
			var z = -110.0 + iz * STEP
			var h = grid_height(ix, iz)
			vertices.append(Vector3(x, h, z))
			var dx = (grid_height(ix + 1, iz) - grid_height(ix - 1, iz)) / (STEP * (mini(ix + 1, GRID - 1) - maxi(ix - 1, 0)))
			var dz = (grid_height(ix, iz + 1) - grid_height(ix, iz - 1)) / (STEP * (mini(iz + 1, GRID - 1) - maxi(iz - 1, 0)))
			normals.append(Vector3(-dx, 1, -dz).normalized())
			var variation = 0.018 * sin(x * 0.09) * cos(z * 0.07)
			var grass = Color(0.32 + variation, 0.41 + variation, 0.25 + variation)
			grass = grass.lerp(Color(0.42, 0.4, 0.31), clampf((absf(dx) + absf(dz) - 0.4) * 0.3, 0, 0.45))
			var width = 4.1 + 0.22 * sin(x * 0.33 + z * 0.17)
			var dirt = 1.0 - smoothstep(width - 0.9, width + 2.0, distances[iz * GRID + ix])
			var clearing = maxf(1.0 - smoothstep(7.0, 13.0, Vector2(x + 75, z - 94).length()), 1.0 - smoothstep(6.0, 12.0, Vector2(x + 19, z + 3).length()))
			colors.append(grass.lerp(Color(0.43 + variation, 0.33 + variation, 0.22 + variation), maxf(dirt, clearing)))
			if ix < GRID - 1 and iz < GRID - 1:
				var a = iz * GRID + ix
				indices.append_array(PackedInt32Array([a, a + 1, a + GRID, a + 1, a + GRID + 1, a + GRID]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, ground_material())
	return mesh


func mountain_height(x: float, z: float) -> float:
	var outside = maxf(absf(x), absf(z)) - 110.0
	var peaks: Array[Vector3] = [Vector3(-175, 82, 65), Vector3(-170, 95, -155), Vector3(10, 108, -195), Vector3(180, 87, -130), Vector3(190, 80, 105), Vector3(15, 76, 185)]
	var h = 17.0 + 7.0 * sin(x / 24.0) * cos(z / 29.0) + 4.0 * sin((x - z) / 17.0)
	for peak in peaks:
		h += peak.y * exp(-((x - peak.x) ** 2 + (z - peak.z) ** 2) / 5400.0)
	return lerpf(natural_height(x, z), h, smoothstep(0.0, 60.0, outside))


func mountain_mesh() -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	const SECTORS = 96
	const RINGS = 10
	for ring in RINGS:
		for sector in SECTORS:
			var angle = float(sector) / SECTORS * TAU
			var direction = Vector2(cos(angle), sin(angle))
			var side_factor = maxf(absf(direction.x), absf(direction.y))
			var radius = 106.0 / side_factor if ring == 0 else lerpf(111.0 / side_factor, 340.0, float(ring - 1) / (RINGS - 2))
			var x = direction.x * radius
			var z = direction.y * radius
			var h = mountain_height(x, z)
			if ring < 2:
				# Pequeno avental abaixo da borda física fecha frestas visuais.
				h = terrain_height(clampf(x, -110, 110), clampf(z, -110, 110)) - (1.0 if ring == 0 else 0.5)
			vertices.append(Vector3(x, h, z))
			normals.append(Vector3(mountain_height(x - 1, z) - mountain_height(x + 1, z), 2, mountain_height(x, z - 1) - mountain_height(x, z + 1)).normalized())
			colors.append(Color(0.31, 0.39, 0.3).lerp(Color(0.42, 0.46, 0.45), smoothstep(25, 90, h)))
			if ring < RINGS - 1:
				var a = ring * SECTORS + sector
				var b = ring * SECTORS + (sector + 1) % SECTORS
				indices.append_array(PackedInt32Array([a, a + SECTORS, b, b, a + SECTORS, b + SECTORS]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, ground_material())
	return mesh


func add_group(parent: Node3D, group_name: String) -> Node3D:
	var node = Node3D.new()
	node.name = group_name
	parent.add_child(node)
	return node


func nature(parent: Node3D, zone_name: String, anchors: Array[Vector2], salt: int) -> void:
	var zone = add_group(parent, zone_name)
	var placements: Dictionary = {}
	var models = ["CommonTree_1", "CommonTree_3", "CommonTree_5", "Pine_1", "Pine_3", "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Bush_Common", "Bush_Common_Flowers", "Grass_Common_Short", "Fern_1"]
	for i in anchors.size():
		for j in range(7):
			var kind = (i + salt) % 5 if j < 2 else (5 + i % 3 if j == 2 else ((9 if i % 7 == 0 else 8) if j < 5 else (10 if j == 5 else 11)))
			var offset = [Vector2(-3,-2), Vector2(3,3), Vector2(5,-3), Vector2(-3,4), Vector2(1,-4), Vector2(-1,3), Vector2(4,0)][j]
			var point = anchors[i] + offset
			if absf(point.x) > 102 or absf(point.y) > 102:
				continue
			var sculpted = sculpt(point.x, point.y)
			if sculpted.y < (10.0 if j < 3 else 7.0) or point.distance_to(Vector2(-75,94)) < 17 or point.distance_to(Vector2(-19,-3)) < 16:
				continue
			var model_name = models[kind]
			var size_value = (1.2 if j < 2 else (1.4 if j < 5 else 0.65)) * (0.88 + float((i * 7 + j * 3 + salt) % 11) * 0.026)
			var transform_value = Transform3D(Basis(Vector3.UP, float(i * 17 + j * 11 + salt) * 0.37) * Basis.from_scale(Vector3.ONE * size_value), Vector3(point.x, terrain_height(point.x, point.y), point.y))
			if not placements.has(model_name):
				placements[model_name] = []
			placements[model_name].append(transform_value)
	for model_name in placements:
		var multi = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = load(NATURE + model_name + ".res")
		multi.instance_count = placements[model_name].size()
		for i in multi.instance_count:
			multi.set_instance_transform(i, placements[model_name][i])
		var instance = MultiMeshInstance3D.new()
		instance.name = model_name
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if model_name.begins_with("CommonTree") or model_name.begins_with("Pine") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 185.0 if model_name.begins_with("CommonTree") or model_name.begins_with("Pine") else 95.0
		zone.add_child(instance)
		foliage_count += multi.instance_count


func own_children(parent: Node, scene_root: Node) -> void:
	for child in parent.get_children():
		child.owner = scene_root
		if child.scene_file_path.is_empty():
			own_children(child, scene_root)


func save_resource(resource: Resource, path: String) -> void:
	assert(ResourceSaver.save(resource, path, ResourceSaver.FLAG_COMPRESS) == OK)
	resource.take_over_path(path)


func build() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	route = make_route()
	road_length = route.get_baked_length()
	for i in range(ceili(road_length / 2.0) + 1):
		samples.append(route.sample_baked(minf(float(i) * 2.0, road_length), true))
	print("Building 220x220 terrain; route: ", road_length, " m")
	var mesh = terrain_mesh()
	var collision = mesh.create_trimesh_shape()
	var mountains = mountain_mesh()
	save_resource(mesh, DIR + "terrain_mesh.res")
	save_resource(collision, DIR + "terrain_collision.res")
	save_resource(mountains, DIR + "background_mesh.res")
	assert(ResourceSaver.save(route, DIR + "route_curve.tres") == OK)
	route.take_over_path(DIR + "route_curve.tres")
	var scene = Node3D.new()
	scene.name = "TerrainShowcase"
	var ground = StaticBody3D.new()
	ground.name = "Terrain"
	scene.add_child(ground)
	var visual = MeshInstance3D.new()
	visual.name = "TerrainMesh"
	visual.mesh = mesh
	ground.add_child(visual)
	var shape = CollisionShape3D.new()
	shape.name = "TerrainCollision"
	shape.shape = collision
	ground.add_child(shape)
	var background = MeshInstance3D.new()
	background.name = "DistantRidges"
	background.mesh = mountains
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(background)
	var vegetation = add_group(scene, "NatureClusters")
	nature(vegetation, "FirstBendWoods", [Vector2(-94,66),Vector2(-96,40),Vector2(-85,28),Vector2(-62,24),Vector2(-48,20),Vector2(-22,26)], 1)
	nature(vegetation, "UphillPines", [Vector2(-16,68),Vector2(1,82),Vector2(23,89),Vector2(50,96),Vector2(66,87),Vector2(99,64),Vector2(65,44)], 3)
	nature(vegetation, "CentralHollow", [Vector2(98,16),Vector2(82,-6),Vector2(55,-16),Vector2(36,22),Vector2(17,26),Vector2(-11,-24),Vector2(-9,-44)], 5)
	nature(vegetation, "RidgePass", [Vector2(27,-66),Vector2(45,-68),Vector2(61,-67),Vector2(99,-52),Vector2(97,-81),Vector2(58,-103),Vector2(1,-101)], 7)
	nature(vegetation, "OutlookWoods", [Vector2(-25,-90),Vector2(-46,-79),Vector2(-71,-68),Vector2(-98,-41),Vector2(-94,-10),Vector2(-78,16),Vector2(-57,21),Vector2(-22,19)], 9)
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16,0.43,0.76)
	sky_material.sky_horizon_color = Color(0.73,0.85,0.91)
	sky_material.sky_curve = 0.2
	sky_material.ground_bottom_color = Color(0.34,0.39,0.25)
	sky_material.ground_horizon_color = Color(0.73,0.85,0.91)
	var sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var environment = WorldEnvironment.new()
	environment.name = "DaylightEnvironment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.78,0.85,0.95)
	environment.environment.ambient_light_energy = 0.5
	environment.environment.fog_enabled = true
	environment.environment.fog_density = 0.0009
	environment.environment.fog_light_color = Color(0.65,0.76,0.83)
	environment.environment.fog_sky_affect = 0.0
	scene.add_child(environment)
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50,-35,0)
	sun.light_color = Color(1,0.96,0.87)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_bias = 0.3
	sun.shadow_normal_bias = 3.0
	scene.add_child(sun)
	var van = load("res://scenes/van_prototype.tscn").instantiate()
	van.name = "VanPrototype"
	van.position = Vector3(-75, terrain_height(-75,94) + 1.3, 94)
	scene.add_child(van)
	var rig = add_group(scene, "CameraRig")
	rig.set_script(load("res://scripts/camera_follow.gd"))
	var camera = Camera3D.new()
	camera.name = "FollowCamera"
	var camera_block = RegEx.new()
	camera_block.compile('(?ms)\\[node name="FollowCamera"[^\\n]*\\ntransform = ([^\\n]+)')
	var original_camera = camera_block.search(FileAccess.get_file_as_string("res://scenes/driving_test.tscn"))
	assert(original_camera != null)
	camera.transform = str_to_var(original_camera.get_string(1))
	camera.far = 450.0
	camera.current = true
	rig.add_child(camera)
	var guide = Path3D.new()
	guide.name = "RouteGuide"
	guide.curve = route
	scene.add_child(guide)
	scene.set_meta("route_length_m", road_length)
	scene.set_meta("playable_size_m", SIZE)
	own_children(scene, scene)
	await RenderingServer.frame_post_draw
	var packed = PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/terrain_showcase.tscn") == OK)
	# A instância da van deve herdar os parâmetros físicos, sem cópias locais.
	var scene_text = FileAccess.get_file_as_string("res://scenes/terrain_showcase.tscn")
	var block = RegEx.new()
	block.compile('(?ms)(\\[node name="VanPrototype"[^\\n]*\\n)(.*?)(?=\\[node|\\z)')
	var matched = block.search(scene_text)
	if matched != null:
		var transform_line = matched.get_string(2).split("\n")[0]
		scene_text = block.sub(scene_text, matched.get_string(1) + transform_line + "\n\n")
		var output = FileAccess.open("res://scenes/terrain_showcase.tscn", FileAccess.WRITE)
		output.store_string(scene_text)
		output.close()
	print("SHOWCASE SAVED: 24200 terrain triangles / one static collider / ", foliage_count, " nature instances")
	scene.free()
	await process_frame
	finish.call_deferred()


func finish() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	quit()
