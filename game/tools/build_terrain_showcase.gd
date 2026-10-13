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
var soil_patches: FastNoiseLite
var soil_grain: FastNoiseLite
var rock_vertices: Dictionary = {}
var fitted_rocks: int = 0
var relocated_rocks: int = 0
var tree_locations: Array[Vector2] = []


func setup_soil_colors() -> void:
	soil_patches = FastNoiseLite.new()
	soil_patches.seed = 41721
	soil_patches.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	soil_patches.frequency = 0.055
	soil_patches.fractal_octaves = 3
	soil_grain = FastNoiseLite.new()
	soil_grain.seed = 8365
	soil_grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	soil_grain.frequency = 0.24
	soil_grain.fractal_octaves = 2


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


func ground_material(textured: bool = false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	if textured:
		mat.albedo_texture = load(DIR + "ground_detail.png")
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 4.0
		mat.uv1_scale = Vector3.ONE * 0.22
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if not save_resource(mat, DIR + "ground_surface.tres"):
			return null
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
			# Somente cores: posições, normais e índices continuam inalterados.
			var patch = soil_patches.get_noise_2d(x, z)
			var grain = soil_grain.get_noise_2d(x, z)
			var variation = patch * 0.045 + grain * 0.012
			var grass = Color(0.32 + variation, 0.41 + variation * 1.25, 0.25 + variation * 0.7)
			var slope = Vector2(dx, dz).length()
			var exposed = smoothstep(0.35, 0.85, slope) * (0.2 + smoothstep(-0.2, 0.3, patch) * 0.23)
			exposed += smoothstep(0.12, 0.45, patch) * 0.28
			grass = grass.lerp(Color(0.4 + grain * 0.01, 0.365 + grain * 0.01, 0.255), minf(exposed, 0.48))
			var width = 4.1 + 0.22 * sin(x * 0.33 + z * 0.17)
			var dirt = 1.0 - smoothstep(width - 0.9, width + 2.0, distances[iz * GRID + ix])
			var clearing = maxf(1.0 - smoothstep(7.0, 13.0, Vector2(x + 75, z - 94).length()), 1.0 - smoothstep(6.0, 12.0, Vector2(x + 19, z + 3).length()))
			var road_variation = patch * 0.012 + grain * 0.008
			colors.append(grass.lerp(Color(0.43 + road_variation, 0.33 + road_variation, 0.22 + road_variation), maxf(dirt, clearing)))
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
	var material = ground_material(true)
	if material == null:
		return null
	mesh.surface_set_material(0, material)
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


func surface_normal(point: Vector2) -> Vector3:
	var dx = terrain_height(point.x + 0.5, point.y) - terrain_height(point.x - 0.5, point.y)
	var dz = terrain_height(point.x, point.y + 0.5) - terrain_height(point.x, point.y - 0.5)
	return Vector3(-dx, 1, -dz).normalized()


func rock_fit(model_name: String, point: Vector2, original_basis: Basis) -> Dictionary:
	if not rock_vertices.has(model_name):
		var mesh: ArrayMesh = load(NATURE + model_name + ".res")
		rock_vertices[model_name] = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vertices: PackedVector3Array = rock_vertices[model_name]
	var mesh: ArrayMesh = load(NATURE + model_name + ".res")
	var bounds = mesh.get_aabb()
	var normal = surface_normal(point)
	var angle = acos(clampf(normal.dot(Vector3.UP), -1, 1))
	var fitted_normal = Vector3.UP.slerp(normal, minf(1.0, deg_to_rad(20.0) / maxf(angle, 0.001)))
	var basis = Basis(Quaternion(Vector3.UP, fitted_normal)) * original_basis
	var minimum_support = INF
	var maximum_support = -INF
	# A faixa inferior representa a base real, não os cantos de uma caixa.
	for vertex in vertices:
		if vertex.y > bounds.position.y + bounds.size.y * 0.22:
			continue
		var local = basis * vertex
		var required_y = terrain_height(point.x + local.x, point.y + local.z) - local.y
		minimum_support = minf(minimum_support, required_y)
		maximum_support = maxf(maximum_support, required_y)
	var y = minimum_support - 0.06
	var visible_vertices = 0
	for vertex in vertices:
		var local = basis * vertex
		if y + local.y > terrain_height(point.x + local.x, point.y + local.z) + 0.02:
			visible_vertices += 1
	var visible_fraction = float(visible_vertices) / vertices.size()
	return {"transform": Transform3D(basis, Vector3(point.x, y, point.y)), "slope": angle, "span": maximum_support - minimum_support, "visible": visible_fraction}


func place_rock(model_name: String, point: Vector2, basis: Basis) -> Transform3D:
	var best: Dictionary = {}
	var best_score = INF
	var mesh: ArrayMesh = load(NATURE + model_name + ".res")
	var bounds = mesh.get_aabb()
	var radius_to_tree = (maxf(maxf(absf(bounds.position.x), absf(bounds.end.x)), maxf(absf(bounds.position.z), absf(bounds.end.z))) + bounds.size.y * 0.2) * basis.get_scale().x + 0.55
	# Busca local e determinística apenas durante a autoria.
	for radius in [0.0, 3.0, 6.0, 9.0, 12.0]:
		for direction in range(1 if radius == 0 else 8):
			var angle = float(direction) * TAU / 8.0
			var candidate = point + Vector2(cos(angle), sin(angle)) * radius
			if absf(candidate.x) > 102 or absf(candidate.y) > 102 or sculpt(candidate.x, candidate.y).y < 10.0:
				continue
			if candidate.distance_to(Vector2(-75,94)) < 17 or candidate.distance_to(Vector2(-19,-3)) < 16:
				continue
			var overlaps_trunk = false
			for tree in tree_locations:
				if candidate.distance_to(tree) < radius_to_tree:
					overlaps_trunk = true
					break
			if overlaps_trunk:
				continue
			var fit = rock_fit(model_name, candidate, basis)
			if fit.visible < 0.48 or fit.slope > deg_to_rad(32):
				continue
			var score = fit.span * 3.0 + fit.slope * 0.8 + radius * 0.09 + (1.0 - fit.visible) * 0.6
			if score < best_score:
				best_score = score
				best = fit
	assert(not best.is_empty(), "Nenhum apoio adequado para " + model_name + " em " + str(point))
	var result: Transform3D = best.transform
	fitted_rocks += 1
	if Vector2(result.origin.x, result.origin.z).distance_to(point) > 0.1:
		relocated_rocks += 1
	return result


func ground_cover(placements: Dictionary, zone_name: String, salt: int) -> void:
	var patches = {
		"FirstBendWoods": [Vector2(-89,72),Vector2(-80,32),Vector2(-46,24),Vector2(-26,24)],
		"UphillPines": [Vector2(-19,62),Vector2(8,79),Vector2(65,53)],
		"CentralHollow": [Vector2(89,3),Vector2(42,-11),Vector2(4,-32)],
		"RidgePass": [Vector2(48,-66),Vector2(72,-63),Vector2(22,-72)],
		"OutlookWoods": [Vector2(-38,-75),Vector2(-88,-37),Vector2(-64,12),Vector2(-34,20)]
	}
	var offsets = [Vector2(-0.85,0.35),Vector2(1.3,-0.4),Vector2(0.2,1.1),Vector2(-0.1,-1.0),Vector2(-1.5,-0.75),Vector2(1.8,0.75),Vector2(-0.65,-1.6)]
	var centers: Array = patches[zone_name]
	for i in centers.size():
		# Grupos com quantidades e espaçamentos distintos, deixando espaços vazios.
		for j in range(5 + (i + salt) % 3):
			var yaw = float(i * 13 + salt * 7) * 0.43
			var offset: Vector2 = offsets[j].rotated(yaw) * (0.85 + i % 3 * 0.2)
			var p: Vector2 = centers[i] + offset
			if sculpt(p.x, p.y).y < 6.8 or p.distance_to(Vector2(-75,94)) < 17 or p.distance_to(Vector2(-19,-3)) < 16:
				continue
			var model_name = "Fern_1" if j == 2 and i % 3 == 0 else "Grass_Common_Short"
			var scale_value = 0.5 + float((i * 3 + j + salt) % 5) * 0.055
			if j >= 5 and i % 3 == 0:
				model_name = "Bush_Common_Flowers"
				scale_value = 0.38 + float((i + j) % 3) * 0.035
			var tilt = Vector3.UP.slerp(surface_normal(p), 0.35)
			var basis = Basis(Quaternion(Vector3.UP, tilt)) * Basis(Vector3.UP, yaw + j) * Basis.from_scale(Vector3.ONE * scale_value)
			if not placements.has(model_name):
				placements[model_name] = []
			placements[model_name].append(Transform3D(basis, Vector3(p.x, terrain_height(p.x,p.y) - 0.04, p.y)))


func nature(parent: Node3D, zone_name: String, anchors: Array[Vector2], salt: int) -> void:
	var zone = add_group(parent, zone_name)
	var placements: Dictionary = {}
	var models = ["CommonTree_1", "CommonTree_3", "CommonTree_5", "Pine_1", "Pine_3", "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Bush_Common", "Bush_Common_Flowers", "Grass_Common_Short", "Fern_1"]
	# Antecipar os troncos da região impede que a busca de apoio os atravesse.
	for anchor in anchors:
		for offset in [Vector2(-3,-2), Vector2(3,3)]:
			var p: Vector2 = anchor + offset
			if absf(p.x) <= 102 and absf(p.y) <= 102 and sculpt(p.x,p.y).y >= 10.0 and p.distance_to(Vector2(-75,94)) >= 17 and p.distance_to(Vector2(-19,-3)) >= 16:
				tree_locations.append(p)
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
			if model_name.begins_with("Rock_"):
				transform_value = place_rock(model_name, point, transform_value.basis)
			if not placements.has(model_name):
				placements[model_name] = []
			placements[model_name].append(transform_value)
	ground_cover(placements, zone_name, salt)
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


func save_resource(resource: Resource, path: String) -> bool:
	var save_error: Error = ResourceSaver.save(resource, path, ResourceSaver.FLAG_COMPRESS)
	if save_error != OK:
		push_error("Falha ao salvar recurso: %s (%s)" % [path, error_string(save_error)])
		quit(1)
		return false
	resource.take_over_path(path)
	return true


func build() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	setup_soil_colors()
	route = make_route()
	road_length = route.get_baked_length()
	for i in range(ceili(road_length / 2.0) + 1):
		samples.append(route.sample_baked(minf(float(i) * 2.0, road_length), true))
	print("Building 220x220 terrain; route: ", road_length, " m")
	var mesh = terrain_mesh()
	if mesh == null:
		return
	if ResourceLoader.exists(DIR + "terrain_mesh.res"):
		var previous_mesh: ArrayMesh = load(DIR + "terrain_mesh.res")
		assert(mesh.get_faces() == previous_mesh.get_faces(), "Polimento não pode alterar a geometria aprovada")
	var collision: ConcavePolygonShape3D
	if ResourceLoader.exists(DIR + "terrain_collision.res"):
		collision = load(DIR + "terrain_collision.res")
		assert(mesh.get_faces() == collision.get_faces(), "Colisão aprovada diverge do visual")
	else:
		collision = mesh.create_trimesh_shape()
		if not save_resource(collision, DIR + "terrain_collision.res"):
			return
	var mountains: ArrayMesh
	if ResourceLoader.exists(DIR + "background_mesh.res"):
		mountains = load(DIR + "background_mesh.res")
	else:
		mountains = mountain_mesh()
		if not save_resource(mountains, DIR + "background_mesh.res"):
			return
	if not save_resource(mesh, DIR + "terrain_mesh.res"):
		return
	if ResourceLoader.exists(DIR + "route_curve.tres"):
		var previous_route: Curve3D = load(DIR + "route_curve.tres")
		assert(route.get_baked_points() == previous_route.get_baked_points(), "Traçado aprovado não pode mudar")
		route = previous_route
	else:
		var route_save_error: Error = ResourceSaver.save(route, DIR + "route_curve.tres")
		if route_save_error != OK:
			push_error("Falha ao salvar recurso: %s (%s)" % [DIR + "route_curve.tres", error_string(route_save_error)])
			quit(1)
			return
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
	var pack_error: Error = packed.pack(scene)
	if pack_error != OK:
		push_error("Falha ao empacotar res://scenes/terrain_showcase.tscn (%s)" % error_string(pack_error))
		scene.free()
		quit(1)
		return
	var scene_save_error: Error = ResourceSaver.save(packed, "res://scenes/terrain_showcase.tscn")
	if scene_save_error != OK:
		push_error("Falha ao salvar res://scenes/terrain_showcase.tscn (%s)" % error_string(scene_save_error))
		scene.free()
		quit(1)
		return
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
	print("ROCKS FITTED: ", fitted_rocks, " / RELOCATED: ", relocated_rocks)
	scene.free()
	await process_frame
	finish.call_deferred()


func finish() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	quit()
