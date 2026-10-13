extends SceneTree
## Autoria offline com renderer ativo (sem --headless), para gravar MultiMeshes.
## Não altera nenhum recurso do terreno aprovado.

const OUT = "res://assets/environment/extreme_extension/"
const STEP = 2.0
const NX = 71
const NZ = 81
const MIN_X = -250.0
const MIN_Z = -90.0
const WATER_Y = 24.0
const LAKE = Vector2(-211, -20)
const RADII = Vector2(30, 26)
var original: Array
var heights = PackedFloat32Array()
var lake_edge = PackedVector2Array()


func _initialize() -> void:
	build.call_deferred()


func old_height(x: float, z: float) -> float:
	var gx = clampf((x + 110) / 2.0, 0, 109.999)
	var gz = clampf((z + 110) / 2.0, 0, 109.999)
	var ix = floori(gx)
	var iz = floori(gz)
	var u = gx - ix
	var v = gz - iz
	var points: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
	var a = points[iz * 111 + ix].y
	var b = points[iz * 111 + ix + 1].y
	var c = points[(iz + 1) * 111 + ix].y
	var d = points[(iz + 1) * 111 + ix + 1].y
	return a + u * (b - a) + v * (c - a) if u + v <= 1 else d + (1-u) * (c-d) + (1-v) * (b-d)


func ridge(u: float) -> float:
	var points = [Vector2(0,32),Vector2(18,37),Vector2(28,38),Vector2(36,39.6),Vector2(40,37.8),Vector2(54,29),Vector2(68,26),Vector2(140,27)]
	for i in range(points.size()-1):
		if u <= points[i+1].x:
			return lerpf(points[i].y,points[i+1].y,(u-points[i].x)/(points[i+1].x-points[i].x))
	return 27.0


func sculpt(x: float, z: float) -> float:
	var u = -110 - x
	var base = 27.0 + 1.2*sin(u/21) + 1.3*cos(z/19)
	base += 9.0*exp(-((u-48)*(u-48)+(z-40)*(z-40))/700.0)
	var h = lerpf(base,ridge(u),exp(-pow((z+34)/24.0,2)))
	var r = ((Vector2(x,z)-LAKE)/RADII).length()
	var basin = 22.95 + 1.05*r*r
	h = lerpf(h,basin,1.0-smoothstep(1.0,1.4,r))
	var edge = old_height(-110,z)
	var slope = (edge-old_height(-108,z))/2.0
	# Altura e tangente copiadas da borda física, sem área sobreposta.
	return lerpf(edge+slope*u,h,smoothstep(0,22,u))


func terrain_height(x: float,z: float) -> float:
	var gx = clampf((x-MIN_X)/STEP,0,NX-1.001)
	var gz = clampf((z-MIN_Z)/STEP,0,NZ-1.001)
	var ix = floori(gx)
	var iz = floori(gz)
	var u = gx-ix
	var v = gz-iz
	var a = heights[iz*NX+ix]
	var b = heights[iz*NX+ix+1]
	var c = heights[(iz+1)*NX+ix]
	var d = heights[(iz+1)*NX+ix+1]
	return a+u*(b-a)+v*(c-a) if u+v<=1 else d+(1-u)*(c-d)+(1-v)*(b-d)


func soil_color(x: float,z: float) -> Color:
	var p = Vector2(x,z)
	var r = ((p-LAKE)/RADII).length()
	var grass = Color(0.34,0.43,0.22).lerp(Color(0.45,0.49,0.29),0.5+0.5*sin(x/11)*cos(z/17))
	var road = (1-smoothstep(3,6,absf(z+34)))*(1-smoothstep(36,55,-110-x))
	var shore_r = r+0.045*sin(x/6)*cos(z/5)+0.025*sin((x+z)/11)
	var mud = (1-smoothstep(1.18,1.5,shore_r))*smoothstep(0.93,1.04,shore_r)
	return grass.lerp(Color(0.49,0.34,0.19),road).lerp(Color(0.28,0.19,0.105),mud)


func mesh_from(vertices: PackedVector3Array,normals: PackedVector3Array,colors: PackedColorArray,indices: PackedInt32Array,material: Material) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,material)
	return mesh


func terrain_mesh() -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	for iz in NZ:
		for ix in NX:
			var x = MIN_X+ix*STEP
			var z = MIN_Z+iz*STEP
			var h = sculpt(x,z)
			if ix == NX-1:
				h = original[Mesh.ARRAY_VERTEX][roundi((z+110)/2)*111].y
			heights.append(h)
			vertices.append(Vector3(x,h,z))
			var n = Vector3(sculpt(x-0.5,z)-sculpt(x+0.5,z),1,sculpt(x,z-0.5)-sculpt(x,z+0.5)).normalized()
			var c = soil_color(x,z)
			var edge_color: Color = original[Mesh.ARRAY_COLOR][roundi((z+110)/2)*111]
			c = edge_color.lerp(c,smoothstep(0,24,-110-x))
			if ix == NX-1:
				n = original[Mesh.ARRAY_NORMAL][roundi((z+110)/2)*111]
				c = original[Mesh.ARRAY_COLOR][roundi((z+110)/2)*111]
			normals.append(n)
			colors.append(c)
			if ix<NX-1 and iz<NZ-1:
				var a = iz*NX+ix
				indices.append_array(PackedInt32Array([a,a+1,a+NX,a+1,a+NX+1,a+NX]))
	return mesh_from(vertices,normals,colors,indices,load("res://assets/environment/terrain_showcase/ground_surface.tres"))


func access_mesh() -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	var old_v: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
	var old_i: PackedInt32Array = original[Mesh.ARRAY_INDEX]
	for i in range(0,old_i.size(),3):
		var center = (old_v[old_i[i]]+old_v[old_i[i+1]]+old_v[old_i[i+2]])/3
		var path_z = lerpf(-34,-28,clampf((center.x+110)/28,0,1))
		if center.x < -110 or center.x > -81 or absf(center.z-path_z)>6.0: continue
		for j in 3:
			var idx = old_i[i+j]
			var p = old_v[idx]
			var width = absf(p.z-lerpf(-34,-28,clampf((p.x+110)/28,0,1)))
			vertices.append(p+Vector3.UP*0.025)
			normals.append(original[Mesh.ARRAY_NORMAL][idx])
			colors.append(original[Mesh.ARRAY_COLOR][idx].lerp(Color(0.49,0.34,0.19),1-smoothstep(3,6,width)))
			indices.append(indices.size())
	# Continua apenas a marcação visual pelos primeiros metros da seção nova.
	for iz in range(NZ-1):
		for ix in range(NX-13,NX-1):
			for offsets in [[0,1,NX],[1,NX+1,NX]]:
				var ids = [iz*NX+ix+offsets[0],iz*NX+ix+offsets[1],iz*NX+ix+offsets[2]]
				var z = MIN_Z+(iz+0.5)*STEP
				if absf(z+34)>6: continue
				for idx in ids:
					var p = Vector3(MIN_X+(idx%NX)*STEP,heights[idx]+0.025,MIN_Z+floori(float(idx)/NX)*STEP)
					vertices.append(p)
					normals.append(Vector3(sculpt(p.x-0.5,p.z)-sculpt(p.x+0.5,p.z),1,sculpt(p.x,p.z-0.5)-sculpt(p.x,p.z+0.5)).normalized())
					var edge_color: Color=original[Mesh.ARRAY_COLOR][roundi((p.z+110)/2)*111]
					var base_color=edge_color.lerp(soil_color(p.x,p.z),smoothstep(0,24,-110-p.x))
					colors.append(base_color.lerp(Color(0.49,0.34,0.19),1-smoothstep(3,6,absf(p.z+34))))
					indices.append(indices.size())
	return mesh_from(vertices,normals,colors,indices,load("res://assets/environment/terrain_showcase/ground_surface.tres"))


func opened_background() -> ArrayMesh:
	var source: ArrayMesh = load("res://assets/environment/terrain_showcase/background_mesh.res")
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	# Contorno da união das duas seções, fechado também nas reentrâncias.
	var corners = PackedVector2Array([Vector2(-110,-110),Vector2(110,-110),Vector2(110,110),Vector2(-110,110),Vector2(-110,70),Vector2(-250,70),Vector2(-250,-90),Vector2(-110,-90)])
	var perimeter = PackedVector2Array()
	for i in corners.size():
		var start = corners[i]
		var end = corners[(i+1)%corners.size()]
		var steps = ceili(start.distance_to(end)/12)
		for j in steps: perimeter.append(start.lerp(end,float(j)/steps))
	var count = perimeter.size()
	var center = Vector2(-70,0)
	for ring in 8:
		var t = float(ring)/7
		for edge in perimeter:
			var direction = (edge-center).normalized()
			var p = center+direction*lerpf(edge.distance_to(center),440,t)
			var edge_height = old_height(edge.x,edge.y) if edge.x>=-110 else terrain_height(edge.x,edge.y)
			var hills = 46.0+12*sin(p.x/41)*cos(p.y/53)+6*sin((p.x-p.y)/29)
			hills += 42*exp(-pow((p.x+305)/72,2)-pow((p.y+72)/110,2))
			hills += 38*exp(-pow((p.x-20)/140,2)-pow((p.y+230)/75,2))
			var h = lerpf(edge_height-0.5,hills,smoothstep(0,0.5,t))
			vertices.append(Vector3(p.x,h,p.y))
			normals.append(Vector3.UP)
			colors.append(Color(0.31,0.39,0.3).lerp(Color(0.46,0.51,0.5),smoothstep(25,85,h)))
	for ring in 7:
		for i in count:
			var a = ring*count+i
			var b = ring*count+(i+1)%count
			indices.append_array(PackedInt32Array([a,a+count,b,b,a+count,b+count]))
	return mesh_from(vertices,normals,colors,indices,source.surface_get_material(0))


func water_mesh() -> ArrayMesh:
	var vertices = PackedVector3Array([Vector3(LAKE.x,WATER_Y,LAKE.y)])
	var normals = PackedVector3Array([Vector3.UP])
	var colors = PackedColorArray([Color(0.055,0.21,0.23)])
	var indices = PackedInt32Array()
	for i in 64:
		var direction = Vector2(cos(i*TAU/64),sin(i*TAU/64))*RADII
		var lo=0.7
		var hi=1.3
		for j in 18:
			var mid=(lo+hi)/2
			var p=LAKE+direction*mid
			if terrain_height(p.x,p.y)<WATER_Y: lo=mid
			else: hi=mid
		var p=LAKE+direction*lo
		lake_edge.append(p)
	for radius in [0.42,0.72,0.91,1.0]:
		for i in 64:
			var p=LAKE.lerp(lake_edge[i],radius)
			vertices.append(Vector3(p.x,WATER_Y,p.y))
			normals.append(Vector3.UP)
			var shallow=smoothstep(0.6,1.0,radius)
			var color=Color(0.055,0.21,0.23).lerp(Color(0.19,0.34,0.27),shallow)
			colors.append(color*Color(1+0.035*sin(i*0.7),1+0.045*cos(i*0.45),1,1))
	for i in 64: indices.append_array(PackedInt32Array([0,i+1,(i+1)%64+1]))
	for ring in 3:
		for i in 64:
			var a=1+ring*64+i
			var b=1+ring*64+(i+1)%64
			indices.append_array(PackedInt32Array([a,a+64,b,b,a+64,b+64]))
	# Algumas pequenas marcas claras na faixa rasa, sem camadas transparentes.
	for i in range(5,64,8):
		var p=LAKE.lerp(lake_edge[i],0.965)
		var tangent=(lake_edge[(i+1)%64]-lake_edge[(i+63)%64]).normalized()
		var across=Vector2(-tangent.y,tangent.x)*0.09
		var along=tangent*0.55
		var start=vertices.size()
		for offset in [-along-across,along-across,-along+across,along+across]:
			vertices.append(Vector3(p.x+offset.x,WATER_Y+0.018,p.y+offset.y))
			normals.append(Vector3.UP)
			colors.append(Color(0.4,0.51,0.42))
		indices.append_array(PackedInt32Array([start,start+1,start+2,start+1,start+3,start+2]))
	var material=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=0.82
	material.metallic_specular=0.0
	return mesh_from(vertices,normals,colors,indices,material)


func add_visual(parent: Node3D,name_text: String,mesh: Mesh) -> MeshInstance3D:
	var visual=MeshInstance3D.new()
	visual.name=name_text
	visual.mesh=mesh
	parent.add_child(visual)
	return visual


func vegetation(parent: Node3D) -> void:
	var placements: Dictionary={}
	var models=["Pine_1","CommonTree_3","Bush_Common","Bush_Common_Flowers","Grass_Common_Short","Fern_1","Rock_Medium_2"]
	var rng=RandomNumberGenerator.new()
	rng.seed=91874
	var anchors=[Vector2(-135,6),Vector2(-152,42),Vector2(-181,20),Vector2(-221,21),Vector2(-242,-59),Vector2(-180,-67)]
	for anchor in anchors:
		for i in 12:
			var p: Vector2=anchor+Vector2(rng.randf_range(-9,9),rng.randf_range(-8,8))
			if ((p-LAKE)/RADII).length()<1.13 or (absf(p.y+34)<11 and p.x>-185): continue
			var model: String=models[i%models.size()]
			var mesh: Mesh=load("res://assets/environment/quaternius_nature/meshes/"+model+".res")
			var scale_value = rng.randf_range(0.8,1.15) if i%7<2 else rng.randf_range(0.5,0.8)
			var basis=Basis(Vector3.UP,rng.randf_range(0,TAU))*Basis.from_scale(Vector3.ONE*scale_value)
			var y=terrain_height(p.x,p.y)
			if model.begins_with("Rock"):
				# Enterra a base de acordo com os vértices reais, evitando apoio por um ponto.
				var clearance=INF
				var base_limit=(mesh.get_aabb().position.y+mesh.get_aabb().size.y*0.2)*scale_value
				for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					var local: Vector3=basis*v
					if local.y>base_limit: continue
					clearance=minf(clearance,terrain_height(p.x+local.x,p.y+local.z)-local.y)
				y=clearance+0.12
			if not placements.has(model): placements[model]=[]
			placements[model].append(Transform3D(basis,Vector3(p.x,y,p.y)))
	for model in placements:
		var multi=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=load("res://assets/environment/quaternius_nature/meshes/"+model+".res")
		multi.instance_count=placements[model].size()
		var center=Vector3.ZERO
		for transform_value in placements[model]: center+=transform_value.origin
		center/=multi.instance_count
		for i in multi.instance_count:
			var transform_value: Transform3D=placements[model][i]
			transform_value.origin-=center
			multi.set_instance_transform(i,transform_value)
		var node=MultiMeshInstance3D.new()
		node.name=model
		node.position=center
		node.multimesh=multi
		node.visibility_range_end=180 if "Tree" in model or "Pine" in model else 95
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if "Tree" in model or "Pine" in model else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)


func own_children(parent: Node,scene: Node) -> void:
	for child in parent.get_children():
		child.owner=scene
		own_children(child,scene)


func save(resource: Resource,name_text: String) -> bool:
	var save_error: Error = ResourceSaver.save(resource,OUT+name_text,ResourceSaver.FLAG_COMPRESS)
	if save_error != OK:
		push_error("Falha ao salvar recurso: %s (%s)" % [OUT+name_text,error_string(save_error)])
		quit(1)
		return false
	resource.take_over_path(OUT+name_text)
	return true


func build() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Gere a extensão sem --headless: a gravação de MultiMeshes precisa do renderer ativo.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	original=load("res://assets/environment/terrain_showcase/terrain_mesh.res").surface_get_arrays(0)
	var mesh=terrain_mesh()
	if ResourceLoader.exists(OUT+"terrain_mesh.res"):
		var approved: ArrayMesh=load(OUT+"terrain_mesh.res")
		assert(mesh.get_faces()==approved.get_faces(),"Polimento não pode mudar os triângulos físicos")
	if not save(mesh,"terrain_mesh.res"):
		return
	var collision: ConcavePolygonShape3D
	if ResourceLoader.exists(OUT+"terrain_collision.res"):
		collision=load(OUT+"terrain_collision.res")
		assert(mesh.get_faces()==collision.get_faces(),"Polimento não pode mudar a colisão aprovada")
	else:
		collision=mesh.create_trimesh_shape()
		if not save(collision,"terrain_collision.res"):
			return
	if not ResourceLoader.exists(OUT+"background_open_west.res"):
		if not save(opened_background(),"background_open_west.res"):
			return
	var scene=Node3D.new()
	scene.name="ExtremeExtension"
	var ground=StaticBody3D.new()
	ground.name="Terrain"
	scene.add_child(ground)
	add_visual(ground,"TerrainMesh",mesh)
	var shape=CollisionShape3D.new()
	shape.name="TerrainCollision"
	shape.shape=collision
	ground.add_child(shape)
	var access=access_mesh()
	if not save(access,"access_trail.res"):
		scene.free()
		return
	add_visual(scene,"AccessTrailVisual",access).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water=water_mesh()
	if not save(water,"water_mesh.res"):
		scene.free()
		return
	add_visual(scene,"LakeSurface",water).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var zone=Area3D.new()
	zone.name="WaterZone"
	zone.position.y=WATER_Y
	zone.collision_layer=0
	zone.set_script(load("res://scripts/water_zone.gd"))
	zone.align_splashes_to_surface=true
	var volume=PackedVector3Array()
	for p in lake_edge:
		# O corpo detectável fica ~0,85 m acima do apoio das rodas visuais.
		# Compensa esse afastamento, mantendo o contorno horizontal alagado.
		volume.append(Vector3(p.x,0.85,p.y))
		volume.append(Vector3(p.x,-2,p.y))
	var water_shape=ConvexPolygonShape3D.new()
	water_shape.points=volume
	var water_collision=CollisionShape3D.new()
	water_collision.name="WaterVolume"
	water_collision.shape=water_shape
	zone.add_child(water_collision)
	scene.add_child(zone)
	var mud=Area3D.new()
	mud.name="MudExit"
	mud.position=Vector3(-222,25,11)
	mud.collision_layer=0
	mud.set_script(load("res://scripts/mud_zone.gd"))
	var mud_shape=BoxShape3D.new()
	mud_shape.size=Vector3(30,4,12)
	var mud_collision=CollisionShape3D.new()
	mud_collision.name="MudVolume"
	mud_collision.shape=mud_shape
	mud.add_child(mud_collision)
	scene.add_child(mud)
	var nature=Node3D.new()
	nature.name="ShoreVegetation"
	scene.add_child(nature)
	vegetation(nature)
	# Guia de autoria e validação, sem lógica de gameplay.
	var path=Path3D.new()
	path.name="AccessGuide"
	path.curve=Curve3D.new()
	for p in [Vector2(-82,-28),Vector2(-94,-31),Vector2(-110,-34),Vector2(-130,-34),Vector2(-145,-34),Vector2(-175,-34),Vector2(-207,-34),Vector2(-223,-17),Vector2(-222,11),Vector2(-196,23),Vector2(-169,16),Vector2(-139,-2),Vector2(-111,-17),Vector2(-83,-24)]:
		path.curve.add_point(Vector3(p.x,old_height(p.x,p.y) if p.x>=-110 else terrain_height(p.x,p.y),p.y))
	scene.add_child(path)
	own_children(scene,scene)
	# Preserve também ajustes feitos no editor na cena já existente.
	if ResourceLoader.exists("res://scenes/extreme_extension.tscn"):
		scene.free()
		scene=load("res://scenes/extreme_extension.tscn").instantiate()
		scene.get_node("Terrain/TerrainMesh").mesh=mesh
		scene.get_node("AccessTrailVisual").mesh=access
		scene.get_node("LakeSurface").mesh=water
		nature=scene.get_node("ShoreVegetation")
		zone=scene.get_node("WaterZone")
	if not zone.has_node("ImpactSplash"):
		var splash=load("res://scenes/water_impact_splash.tscn").instantiate()
		zone.add_child(splash)
		splash.owner=scene
	await RenderingServer.frame_post_draw
	for node in nature.get_children():
		assert(node.multimesh.buffer.size()==node.multimesh.instance_count*12,"Buffer de vegetação não foi preparado")
	var packed=PackedScene.new()
	var pack_error: Error = packed.pack(scene)
	if pack_error != OK:
		push_error("Falha ao empacotar res://scenes/extreme_extension.tscn (%s)" % error_string(pack_error))
		scene.free()
		quit(1)
		return
	var scene_save_error: Error = ResourceSaver.save(packed,"res://scenes/extreme_extension.tscn")
	if scene_save_error != OK:
		push_error("Falha ao salvar res://scenes/extreme_extension.tscn (%s)" % error_string(scene_save_error))
		scene.free()
		quit(1)
		return
	print("EXTENSION: 140x160 m; ",mesh.get_faces().size()/3," triangles; exact west edge; lake depth ~1.05 m")
	scene.free()
	quit()
