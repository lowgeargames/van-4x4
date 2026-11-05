extends Node
## Observador exclusivo da sessão: lê contatos, nunca aplica forças.
signal prop_hit(instance_id: int, category: String, approach_speed: float)

const CATEGORIES = {
	"res://scenes/physics_crate.tscn": "crate",
	"res://scenes/physics_barrel.tscn": "barrel",
	"res://scenes/physics_cone.tscn": "cone",
}
@export_range(0.5, 15.0, 0.5) var minimum_impact_speed: float = 3.0
@export var van_path: NodePath = NodePath("../VanPrototype")
var _props: Array[Dictionary] = []
var _seen: Dictionary = {}
var _active: bool = false
var _has_sample: bool = false
var _van_position: Vector3
var _van_velocity: Vector3
var _reset_grace: float = 0.0
@onready var _van: RigidBody3D = get_node_or_null(van_path) as RigidBody3D

func _ready() -> void:
	process_physics_priority = 150
	set_physics_process(false)
	if _van == null:
		push_error("PropImpactTracker: van_path inválido.")
		return
	for body in get_parent().find_children("*", "RigidBody3D", true, false):
		if CATEGORIES.has(body.scene_file_path):
			var category: String = CATEGORIES[body.scene_file_path]
			_props.append({"body": body, "category": category, "contacts": body.max_contacts_reported,
				"position": body.global_position, "velocity": body.linear_velocity})

func start() -> void:
	if _active or _van == null:
		return
	_active = true
	_has_sample = false
	for entry in _props:
		var body: RigidBody3D = entry.body
		# Só amplia o relatório de contatos; não muda monitor/contatos da van.
		body.max_contacts_reported = maxi(entry.contacts, 8)
	set_physics_process(true)

func stop() -> void:
	_active = false
	set_physics_process(false)
	for entry in _props:
		if is_instance_valid(entry.body):
			entry.body.max_contacts_reported = entry.contacts

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_reset_grace = maxf(0.0, _reset_grace - delta)
	var reset: bool = Input.is_action_pressed("reset_vehicle") or _van._reset_requested
	if _has_sample:
		var budget: float = maxf(3.0, maxf(_van_velocity.length(), _van.linear_velocity.length()) * delta * 2.0)
		reset = reset or _van.global_position.distance_to(_van_position) > budget
	if reset:
		_reset_grace = 0.5
	var eligible: bool = _has_sample and _reset_grace == 0.0 and not _van.freeze
	for entry in _props:
		var body: RigidBody3D = entry.body
		if not is_instance_valid(body) or _seen.has(body.get_instance_id()):
			continue
		if eligible:
			var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
			if state != null:
				for i in state.get_contact_count():
					if state.get_contact_collider_id(i) != _van.get_instance_id():
						continue
					# Aproximação linear entre centros na amostra anterior à resposta.
					# É uma estimativa conservadora, não impulso nem velocidade pós-impacto.
					var direction: Vector3 = (entry.position - _van_position).normalized()
					var approach: float = (_van_velocity - entry.velocity).dot(direction)
					if _van_velocity.dot(direction) > 0.0 and approach >= minimum_impact_speed:
						var id: int = body.get_instance_id()
						_seen[id] = true
						prop_hit.emit(id, entry.category, approach)
						break
		entry.position = body.global_position
		entry.velocity = body.linear_velocity
	_van_position = _van.global_position
	_van_velocity = _van.linear_velocity
	_has_sample = true

func _exit_tree() -> void:
	stop()
