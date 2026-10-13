extends Node3D
## Uma leitura de velocidade por passo; as árvores reagem por sinais de contato.

signal tree_broken(index: int, impact_speed: float)

@export var van_path: NodePath = NodePath("../VanPrototype")
@export_range(2.0, 20.0) var break_speed: float = 7.0
@export_range(0.2, 1.0) var fall_duration: float = 0.45
@export var tree_bindings: Array[Dictionary] = []
@export var rock_multimeshes: Array[NodePath] = []

var broken_count: int = 0
var _recent_velocity: Vector3 = Vector3.ZERO
var _previous_velocity: Vector3 = Vector3.ZERO
var _reset_grace: float = 0.0
var _multis: Array[MultiMeshInstance3D] = []
var _original_transforms: Array[Transform3D] = []
var _broken = PackedByteArray()
@onready var _van: RigidBody3D = get_node_or_null(van_path) as RigidBody3D
@onready var _detector: Area3D = $TreeContacts
@onready var _trunks: StaticBody3D = $StandingTrunks
@onready var _fragments: GPUParticles3D = $BreakFragments
@onready var _leaves: GPUParticles3D = $BreakFragments/Leaves


func _ready() -> void:
	if _van == null:
		push_error("NatureInteractions: van_path deve apontar para a van.")
		set_physics_process(false)
		return
	var copied: Dictionary = {}
	_broken.resize(tree_bindings.size())
	for binding in tree_bindings:
		var multi: MultiMeshInstance3D = get_node(binding.path) as MultiMeshInstance3D
		# Obstáculos sólidos não podem desaparecer por distância do grupo visual.
		multi.visibility_range_end = 0.0
		# Não alterar recursos compartilhados com terrain_showcase ou outras partidas.
		if not copied.has(multi):
			multi.multimesh = multi.multimesh.duplicate() as MultiMesh
			copied[multi] = true
		_multis.append(multi)
		_original_transforms.append(binding.transform)
	for path in rock_multimeshes:
		get_node(path).visibility_range_end = 0.0
	_detector.body_shape_entered.connect(_on_tree_contact)


func _physics_process(delta: float) -> void:
	_reset_grace = maxf(0.0, _reset_grace - delta)
	_previous_velocity = _recent_velocity
	_recent_velocity = _van.linear_velocity
	if Input.is_action_pressed("reset_vehicle"):
		_reset_grace = 0.5
		_previous_velocity = Vector3.ZERO
		_recent_velocity = Vector3.ZERO


func _on_tree_contact(_rid: RID, body: Node3D, _body_shape: int, local_shape: int) -> void:
	if body != _van or _reset_grace > 0.0 or _van.freeze:
		return
	var shape: CollisionShape3D = _detector.shape_owner_get_owner(_detector.shape_find_owner(local_shape)) as CollisionShape3D
	var index: int = int(shape.get_meta("tree_index"))
	if _broken[index] != 0:
		return
	var world: Transform3D = _multis[index].global_transform * _original_transforms[index]
	var direction: Vector3 = (world.origin - _van.global_position).slide(Vector3.UP).normalized()
	# Recupera a aproximação anterior à resposta do contato sólido, sem devolver impulso.
	var speed: float = maxf(_van.linear_velocity.dot(direction), maxf(_recent_velocity.dot(direction), _previous_velocity.dot(direction)))
	if speed >= break_speed:
		_break_tree(index, world, direction, speed)


func _break_tree(index: int, world: Transform3D, direction: Vector3, speed: float) -> void:
	_broken[index] = 1
	broken_count += 1
	_trunks.get_child(index).set_deferred("disabled", true)
	_detector.get_child(index).set_deferred("disabled", true)
	var hidden: Transform3D = _original_transforms[index]
	hidden.basis = hidden.basis.scaled(Vector3.ONE * 0.0001)
	_multis[index].multimesh.set_instance_transform(tree_bindings[index].instance, hidden)
	# Só a árvore atingida vira um visual temporário; nenhuma física de pedaços.
	var falling = MeshInstance3D.new()
	falling.mesh = _multis[index].multimesh.mesh
	add_child(falling)
	falling.global_transform = world
	var axis = Vector3.UP.cross(direction).normalized()
	var tween = create_tween()
	tween.tween_method(_fall_pose.bind(falling, world, axis), 0.0, PI * 0.48, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.35)
	tween.tween_property(falling, "scale", Vector3.ONE * 0.01, 0.3)
	tween.tween_callback(falling.queue_free)
	# Fragmentos visuais próximos ao contato da frente da van com o tronco.
	_fragments.global_position = world.origin - direction * 0.3 + Vector3.UP * 1.9
	_fragments.emitting = true
	_fragments.restart()
	_leaves.emitting = true
	_leaves.restart()
	tree_broken.emit(index, speed)


func _fall_pose(angle: float, visual: Node3D, world: Transform3D, axis: Vector3) -> void:
	visual.global_transform = Transform3D(Basis(axis, angle) * world.basis, world.origin)
