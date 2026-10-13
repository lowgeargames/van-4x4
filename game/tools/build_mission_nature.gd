extends SceneTree
## Autoria da natureza interativa e vegetação baixa; não gera nem altera terrenos.

const MODELS = "res://assets/environment/quaternius_nature/meshes/"
var source: Node3D
var original_arrays: Array
var extension_arrays: Array
var output: Node3D
var trunks: StaticBody3D
var contacts: Area3D
var rocks: StaticBody3D
var bindings: Array[Dictionary] = []
var rock_paths: Array[NodePath] = []
var tree_shapes: Dictionary = {}
var rock_shapes: Dictionary = {}
var anchors: Array[Vector2] = []
var cover: Dictionary = {}
var plant_count: int = 0
var tree_count: int = 0
var rock_count: int = 0
var rng = RandomNumberGenerator.new()


func _initialize() -> void:
	build.call_deferred()


func height_at(p: Vector2) -> float:
	var arrays = original_arrays if p.x >= -110 else extension_arrays
	var min_x = -110.0 if p.x >= -110 else -250.0
	var min_z = -110.0 if p.x >= -110 else -90.0
	var nx = 111 if p.x >= -110 else 71
	var nz = 111 if p.x >= -110 else 81
	var gx = clampf((p.x-min_x)/2,0,nx-1.001)
	var gz = clampf((p.y-min_z)/2,0,nz-1.001)
	var ix = floori(gx)
	var iz = floori(gz)
	var u = gx-ix
	var v = gz-iz
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var a = vertices[iz*nx+ix].y
	var b = vertices[iz*nx+ix+1].y
	var c = vertices[(iz+1)*nx+ix].y
	var d = vertices[(iz+1)*nx+ix+1].y
	return a+u*(b-a)+v*(c-a) if u+v<=1 else d+(1-u)*(c-d)+(1-v)*(b-d)


func trunk_shape(mesh: Mesh) -> Dictionary:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top = minf(3.4,mesh.get_aabb().size.y*0.42)
	var bounds = AABB()
	var first = true
	for v in vertices:
		if v.y < 0.2 or v.y > top: continue
		if first:
			bounds = AABB(v,Vector3.ZERO)
			first = false
		else: bounds = bounds.expand(v)
	var radius = clampf(maxf(bounds.size.x,bounds.size.z)*0.45,0.18,0.45)
	var shape = CapsuleShape3D.new()
	shape.radius = radius
	shape.height = top+0.2
	var detection = CapsuleShape3D.new()
	detection.radius = radius+0.06
	detection.height = shape.height+0.12
	var center = Vector3(bounds.get_center().x,top*0.5,bounds.get_center().z)
	return {"shape":shape,"detection":detection,"center":center}


func rock_shape(mesh: Mesh) -> ConvexPolygonShape3D:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var points = PackedVector3Array()
	# Apenas até 14 pontos reais de suporte: volume convexo simples, sem trimesh.
	for direction in [Vector3.UP,Vector3.DOWN,Vector3(1,-0.25,0),Vector3(-1,-0.25,0),Vector3(0,-0.25,1),Vector3(0,-0.25,-1),Vector3(1,0.7,0),Vector3(-1,0.7,0),Vector3(0,0.7,1),Vector3(0,0.7,-1),Vector3(1,0,1),Vector3(-1,0,1),Vector3(1,0,-1),Vector3(-1,0,-1)]:
		var best = vertices[0]
		for v in vertices:
			if v.dot(direction)>best.dot(direction): best=v
		if not points.has(best): points.append(best)
	var shape = ConvexPolygonShape3D.new()
	shape.points = points
	return shape


func add_interactions(multi: MultiMeshInstance3D) -> void:
	var model = str(multi.name)
	var mesh: Mesh = multi.multimesh.mesh
	var is_tree = "Tree" in model or "Pine" in model
	var is_rock = "Rock" in model
	if not is_tree and not is_rock: return
	if is_tree and not tree_shapes.has(model): tree_shapes[model]=trunk_shape(mesh)
	if is_rock and not rock_shapes.has(model): rock_shapes[model]=rock_shape(mesh)
	if is_rock: rock_paths.append(NodePath("../"+str(source.get_path_to(multi))))
	for i in multi.multimesh.instance_count:
		var world = multi.global_transform * multi.multimesh.get_instance_transform(i)
		if world.origin.x < -250 or world.origin.x > 110 or world.origin.z < -110 or world.origin.z > 110: continue
		anchors.append(Vector2(world.origin.x,world.origin.z))
		if is_tree:
			var data: Dictionary=tree_shapes[model]
			var transform_value=world*Transform3D(Basis.IDENTITY,data.center)
			var collider=CollisionShape3D.new()
			collider.name="Tree_%03d"%tree_count
			collider.shape=data.shape
			collider.transform=transform_value
			trunks.add_child(collider)
			var detector=CollisionShape3D.new()
			detector.name=collider.name
			detector.shape=data.detection
			detector.transform=transform_value
			detector.set_meta("tree_index",tree_count)
			contacts.add_child(detector)
			bindings.append({"path":NodePath("../"+str(source.get_path_to(multi))),"instance":i,"transform":multi.multimesh.get_instance_transform(i)})
			tree_count+=1
		else:
			# Pedras quase totalmente enterradas são detalhes, não obstáculos invisíveis.
			var exposed_height=-INF
			for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var p: Vector3=world*vertex
				exposed_height=maxf(exposed_height,p.y-height_at(Vector2(p.x,p.z)))
			if exposed_height<0.65:
				print("DECORATIVE ROCK: ",world.origin," visible height=",exposed_height)
				continue
			var collider=CollisionShape3D.new()
			collider.name="Rock_%03d"%rock_count
			collider.shape=rock_shapes[model]
			collider.transform=world
			rocks.add_child(collider)
			rock_count+=1


func plant(p: Vector2,model: String) -> void:
	if p.x < -245 or p.x > 104 or p.y < -104 or p.y > (64 if p.x < -110 else 104): return
	if p.distance_to(Vector2(-75,94))<10 or p.distance_to(Vector2(-14,0))<10: return
	if ((p-Vector2(-211,-20))/Vector2(30,26)).length()<1.12: return
	var position_now=Vector3(p.x,height_at(p),p.y)
	for path in [source.get_node("RouteGuide"),source.get_node("ExtremeExtension/AccessGuide")]:
		var nearest: Vector3=path.curve.sample_baked(path.curve.get_closest_offset(position_now),true)
		if Vector2(nearest.x-p.x,nearest.z-p.y).length()<5.4: return
	var zone = str(floori((p.x+250)/80))+"_"+str(floori((p.y+110)/80))
	var key=model+"_"+zone
	if not cover.has(key): cover[key]={"model":model,"transforms":[]}
	var size_value=rng.randf_range(0.65,1.05) if model=="Grass_Common_Short" else rng.randf_range(0.4,0.65)
	var normal=Vector3(height_at(p-Vector2(0.5,0))-height_at(p+Vector2(0.5,0)),1,height_at(p-Vector2(0,0.5))-height_at(p+Vector2(0,0.5))).normalized()
	var basis=Basis(Quaternion(Vector3.UP,Vector3.UP.slerp(normal,0.35)))*Basis(Vector3.UP,rng.randf_range(0,TAU))*Basis.from_scale(Vector3.ONE*size_value)
	cover[key].transforms.append(Transform3D(basis,position_now-Vector3.UP*0.035))
	plant_count+=1


func ground_cover(parent: Node3D) -> void:
	rng.seed=703191
	var route: Curve3D=source.get_node("RouteGuide").curve
	for s in range(16,int(route.get_baked_length())-16,16):
		if rng.randf()>0.65: continue
		var p=route.sample_baked(s,true)
		var tangent=(route.sample_baked(s+1,true)-route.sample_baked(s-1,true)).slide(Vector3.UP).normalized()
		var side=Vector2(tangent.z,-tangent.x)
		for sign_value in [-1,1]:
			var anchor=Vector2(p.x,p.z)+side*sign_value*rng.randf_range(7,10)
			for i in 6:
				plant(anchor+Vector2(rng.randf_range(-2.5,2.5),rng.randf_range(-2.5,2.5)),"Fern_1" if i==4 else ("Bush_Common_Flowers" if i==5 and s%3==0 else "Grass_Common_Short"))
	for anchor in anchors:
		if rng.randf()>0.45: continue
		for i in 4:
			var angle=rng.randf_range(0,TAU)
			plant(anchor+Vector2(cos(angle),sin(angle))*rng.randf_range(2,4),"Fern_1" if i==3 else "Grass_Common_Short")
	for i in 12:
		var angle=i*TAU/12
		var anchor=Vector2(-211,-20)+Vector2(cos(angle)*30,sin(angle)*26)*1.23
		for j in 5:
			plant(anchor+Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2)),"Bush_Common_Flowers" if j==4 else "Grass_Common_Short")
	for key in cover:
		var data: Dictionary=cover[key]
		var center=Vector3.ZERO
		for t in data.transforms: center+=t.origin
		center/=data.transforms.size()
		var multi=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=load(MODELS+data.model+".res")
		multi.instance_count=data.transforms.size()
		for i in multi.instance_count:
			var t: Transform3D=data.transforms[i]
			t.origin-=center
			multi.set_instance_transform(i,t)
		var node=MultiMeshInstance3D.new()
		node.name=key
		node.position=center
		node.multimesh=multi
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end=110.0
		parent.add_child(node)


func own(parent: Node) -> void:
	for child in parent.get_children():
		child.owner=output
		own(child)


func build() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Execute com renderer ativo para preparar os MultiMeshes.")
		quit(1)
		return
	source=load("res://scenes/mission_level.tscn").instantiate()
	root.add_child(source)
	if source.has_node("NatureInteractions"): source.get_node("NatureInteractions").free()
	original_arrays=load("res://assets/environment/terrain_showcase/terrain_mesh.res").surface_get_arrays(0)
	extension_arrays=load("res://assets/environment/extreme_extension/terrain_mesh.res").surface_get_arrays(0)
	output=Node3D.new()
	output.name="NatureInteractions"
	output.set_script(load("res://scripts/nature_interactions.gd"))
	trunks=StaticBody3D.new()
	trunks.name="StandingTrunks"
	output.add_child(trunks)
	contacts=Area3D.new()
	contacts.name="TreeContacts"
	contacts.collision_layer=0
	output.add_child(contacts)
	rocks=StaticBody3D.new()
	rocks.name="SolidRocks"
	output.add_child(rocks)
	for multi in source.find_children("*","MultiMeshInstance3D",true,false): add_interactions(multi)
	output.tree_bindings=bindings
	output.rock_multimeshes=rock_paths
	var plants=Node3D.new()
	plants.name="GroundCover"
	output.add_child(plants)
	ground_cover(plants)
	var fragments_scene=load("res://scenes/tree_break_fragments.tscn").instantiate()
	output.add_child(fragments_scene)
	own(output)
	await RenderingServer.frame_post_draw
	for node in plants.get_children(): assert(node.multimesh.buffer.size()==node.multimesh.instance_count*12)
	var packed=PackedScene.new()
	var pack_error: Error = packed.pack(output)
	if pack_error != OK:
		push_error("Falha ao empacotar res://scenes/mission_nature_interactions.tscn (%s)" % error_string(pack_error))
		output.free()
		source.free()
		quit(1)
		return
	var scene_save_error: Error = ResourceSaver.save(packed,"res://scenes/mission_nature_interactions.tscn")
	if scene_save_error != OK:
		push_error("Falha ao salvar res://scenes/mission_nature_interactions.tscn (%s)" % error_string(scene_save_error))
		output.free()
		source.free()
		quit(1)
		return
	print("NATURE: ",tree_count," breakable trees; ",rock_count," static rocks; ",plant_count," new ground plants in ",plants.get_child_count()," MultiMeshes")
	output.free()
	source.free()
	quit()
