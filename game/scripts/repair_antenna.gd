extends Node3D

signal repair_completed

@export var van_path: NodePath
@export_range(0.5, 5.0) var repair_duration: float = 2.0
@export_range(0.1, 1.0) var stopped_speed: float = 0.5
@export var active: bool = true

var repaired: bool = false
var _repair_elapsed: float = 0.0

@onready var _van: RigidBody3D = get_node_or_null(van_path) as RigidBody3D
@onready var _area: Area3D = $InteractionArea
@onready var _indicator_material: StandardMaterial3D = $Indicator.material_override


func _ready() -> void:
	if _van == null:
		push_error("Equipamento reparável: van_path deve apontar para a van.")
	set_physics_process(active and _van != null)


func set_active(enabled: bool) -> void:
	active = enabled and not repaired
	_repair_elapsed = 0.0
	set_physics_process(active and _van != null)


func is_van_nearby() -> bool:
	return _van != null and _area.overlaps_body(_van)


func get_repair_progress() -> float:
	return _repair_elapsed / repair_duration * 100.0


func _physics_process(delta: float) -> void:
	if repaired or not active:
		return

	var can_repair: bool = (
		is_van_nearby() and _van.linear_velocity.length_squared() <= stopped_speed * stopped_speed
		and Input.is_action_pressed("interact")
	)
	if can_repair:
		_repair_elapsed = minf(_repair_elapsed + delta, repair_duration)
	else:
		_repair_elapsed = 0.0
	if _repair_elapsed >= repair_duration:
		_complete_repair()


func _complete_repair() -> void:
	repaired = true
	active = false
	_indicator_material.albedo_color = Color(0.1, 0.9, 0.25)
	_indicator_material.emission = Color(0.1, 0.9, 0.25)
	set_physics_process(false)
	repair_completed.emit()
