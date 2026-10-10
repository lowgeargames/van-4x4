extends Node3D

@export var van_path: NodePath
@export_range(0.5, 5.0) var repair_duration: float = 2.0
@export_range(0.1, 1.0) var stopped_speed: float = 0.5

var repaired: bool = false
var _repair_elapsed: float = 0.0

@onready var _van: RigidBody3D = get_node_or_null(van_path) as RigidBody3D
@onready var _area: Area3D = $InteractionArea
@onready var _message: Label = $MissionUI/Panel/Margin/Content/Message
@onready var _hint: Label = $MissionUI/Panel/Margin/Content/Hint
@onready var _progress: ProgressBar = $MissionUI/Panel/Margin/Content/Progress
@onready var _indicator_material: StandardMaterial3D = $Indicator.material_override


func _ready() -> void:
	if _van == null:
		push_error("RepairAntenna: van_path deve apontar para a van.")
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if repaired:
		return

	var nearby: bool = _area.overlaps_body(_van)
	_message.text = "Pare a van e segure E para reparar." if nearby else "Chamado: reparar a antena."
	_hint.visible = not nearby
	_progress.visible = nearby
	var can_repair: bool = (
		nearby and _van.linear_velocity.length_squared() <= stopped_speed * stopped_speed
		and Input.is_action_pressed("interact")
	)
	if can_repair:
		_repair_elapsed = minf(_repair_elapsed + delta, repair_duration)
	else:
		_repair_elapsed = 0.0
	_progress.value = _repair_elapsed / repair_duration * 100.0
	if _repair_elapsed >= repair_duration:
		_complete_repair()


func _complete_repair() -> void:
	repaired = true
	_indicator_material.albedo_color = Color(0.1, 0.9, 0.25)
	_indicator_material.emission = Color(0.1, 0.9, 0.25)
	_message.text = "Serviço concluído!"
	_hint.visible = false
	_progress.visible = false
	set_physics_process(false)
