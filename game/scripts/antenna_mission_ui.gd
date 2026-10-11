extends Node

## Somente apresentação da missão única; o reparo usa repair_antenna.gd.
const RepairEquipment = preload("res://scripts/repair_antenna.gd")

@onready var _antenna: RepairEquipment = get_node_or_null("../RepairAntenna") as RepairEquipment
@onready var _van: RigidBody3D = get_node_or_null("../VanPrototype") as RigidBody3D
@onready var _message: Label = get_node_or_null("../RepairAntenna/MissionUI/Panel/Margin/Content/Message") as Label
@onready var _hint: Label = get_node_or_null("../RepairAntenna/MissionUI/Panel/Margin/Content/Hint") as Label
@onready var _status: Label = get_node_or_null("../RepairAntenna/MissionUI/Panel/Margin/Content/Status") as Label
@onready var _progress: ProgressBar = get_node_or_null("../RepairAntenna/MissionUI/Panel/Margin/Content/Progress") as ProgressBar
@onready var _marker: Label = get_node_or_null("../ObjectiveUI/ObjectiveMarker") as Label


func _ready() -> void:
	var required_nodes: Dictionary = {
		"RepairAntenna": _antenna,
		"VanPrototype": _van,
		"RepairAntenna/MissionUI/Panel/Margin/Content/Message": _message,
		"RepairAntenna/MissionUI/Panel/Margin/Content/Hint": _hint,
		"RepairAntenna/MissionUI/Panel/Margin/Content/Status": _status,
		"RepairAntenna/MissionUI/Panel/Margin/Content/Progress": _progress,
		"ObjectiveUI/ObjectiveMarker": _marker,
	}
	var valid: bool = true
	for path in required_nodes:
		if not is_instance_valid(required_nodes[path]):
			push_error("AntennaMissionUI: nó obrigatório ausente ou de tipo incorreto: " + path)
			valid = false
	if not valid:
		set_process(false)
		return
	_antenna.repair_completed.connect(_on_repair_completed)
	_message.text = "Chamado: reparar a antena."
	_hint.text = "Siga a estrada até a antena no mirante."
	_status.visible = false
	_progress.visible = false


func _process(_delta: float) -> void:
	var nearby: bool = _antenna.is_van_nearby()
	_message.text = "Pare a van e segure E para reparar." if nearby else "Chamado: reparar a antena."
	_hint.visible = not nearby
	_progress.visible = nearby
	_progress.value = _antenna.get_repair_progress()
	_update_marker(nearby)


func _update_marker(nearby: bool) -> void:
	var camera = get_viewport().get_camera_3d()
	var target = _antenna.global_position + Vector3.UP * 13.0
	_marker.visible = camera != null and not nearby and not camera.is_position_behind(target)
	if not _marker.visible:
		return
	var distance: int = roundi(_van.global_position.distance_to(_antenna.global_position))
	_marker.text = "ANTENA · %d m" % distance
	var screen = get_viewport().get_visible_rect().size
	var projected = camera.unproject_position(target) - Vector2(_marker.size.x * 0.5, 0)
	_marker.position = Vector2(
		clampf(projected.x, 24.0, maxf(24.0, screen.x - _marker.size.x - 24.0)),
		clampf(projected.y, 120.0, maxf(120.0, screen.y - _marker.size.y - 24.0))
	)


func _on_repair_completed() -> void:
	_message.text = "Serviço concluído!"
	_hint.visible = false
	_status.visible = false
	_progress.visible = false
	_marker.visible = false
	set_process(false)
