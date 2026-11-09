extends Node

## Apresenta o equipamento ativo no painel da antena.
const RepairEquipment = preload("res://scripts/repair_antenna.gd")

@export var antenna_path: NodePath = NodePath("../RepairAntenna")
@export var session_controller_path: NodePath

var _active_repair: RepairEquipment
var _call_text: String = "Chamado: reparar a antena."
var _marker_name: String = "ANTENA"
var _marker_height: float = 13.0
var _service_number: int = 1
var _completion_remaining: float = 0.0

@onready var _antenna: RepairEquipment = get_node_or_null(antenna_path) as RepairEquipment
@onready var _van: RigidBody3D = get_node_or_null("../VanPrototype") as RigidBody3D
@onready var _content: Node = _antenna.get_node_or_null("MissionUI/Panel/Margin/Content") if _antenna != null else null
@onready var _message: Label = _content.get_node_or_null("Message") as Label if _content != null else null
@onready var _hint: Label = _content.get_node_or_null("Hint") as Label if _content != null else null
@onready var _status: Label = _content.get_node_or_null("Status") as Label if _content != null else null
@onready var _progress: ProgressBar = _content.get_node_or_null("Progress") as ProgressBar if _content != null else null
@onready var _marker: Label = get_node_or_null("../ObjectiveUI/ObjectiveMarker") as Label
@onready var _driving_hud_panel: Control = get_node_or_null("../DrivingHUD/Panel") as Control


func _ready() -> void:
	var required_nodes: Dictionary = {
		"antenna_path": _antenna,
		"VanPrototype": _van,
		"MissionUI/Panel/Margin/Content/Message": _message,
		"MissionUI/Panel/Margin/Content/Hint": _hint,
		"MissionUI/Panel/Margin/Content/Status": _status,
		"MissionUI/Panel/Margin/Content/Progress": _progress,
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
	if session_controller_path.is_empty():
		_antenna.repair_completed.connect(_on_repair_completed)
	else:
		var controller := get_node_or_null(session_controller_path)
		if controller == null or not controller.has_signal("objective_changed"):
			push_error("AntennaMissionUI: session_controller_path deve apontar para o controlador da sessão.")
			set_process(false)
			return
		controller.objective_changed.connect(_on_objective_changed)
	_active_repair = _antenna
	_message.text = _call_text
	_hint.text = "Siga a estrada até a antena no mirante."
	_status.visible = false
	_progress.visible = false


func _process(delta: float) -> void:
	if _active_repair.repaired:
		_on_repair_completed()
		return
	if _completion_remaining > 0.0:
		_completion_remaining -= delta
	var nearby: bool = _active_repair.is_van_nearby()
	var instruction: String = "Pare a van e segure E para reparar." if nearby else _call_text
	_message.text = "Serviço concluído!" if _completion_remaining > 0.0 and not nearby else instruction
	_hint.visible = not nearby
	_progress.visible = nearby
	_progress.value = _active_repair.get_repair_progress()
	_update_marker(nearby)


func _on_objective_changed(objective: Node3D, service_number: int, total_services: int) -> void:
	_active_repair = objective as RepairEquipment
	_service_number = service_number
	var equipment_name: String = objective.get_meta("mission_equipment", "a antena")
	_call_text = ("Novo chamado" if service_number > 1 else "Chamado") + ": reparar %s." % equipment_name
	_hint.text = objective.get_meta("mission_hint", "Siga a estrada até a antena no mirante.")
	_marker_name = objective.get_meta("mission_marker", "ANTENA")
	_marker_height = objective.get_meta("mission_marker_height", 13.0)
	_status.text = "Serviço %d/%d" % [service_number, total_services]
	_status.visible = total_services > 1
	_completion_remaining = 1.25 if service_number > 1 else 0.0
	_progress.hide()
	_marker.hide()


func _update_marker(nearby: bool) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or nearby:
		_marker.hide()
		return
	var target: Vector3 = _active_repair.global_position + Vector3.UP * _marker_height
	var behind: bool = camera.is_position_behind(target)
	if behind and _service_number == 1:
		_marker.hide()
		return
	var distance: int = roundi(_van.global_position.distance_to(_active_repair.global_position))
	var marker_text: String = "%s · %d m" % [_marker_name, distance]
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var projected: Vector2
	if behind:
		var on_right: bool = camera.to_local(target).x >= 0.0
		marker_text = marker_text + " ›" if on_right else "‹ " + marker_text
		projected = Vector2(screen.x if on_right else 0.0, screen.y * 0.5)
	else:
		projected = camera.unproject_position(target)
	if _marker.text != marker_text:
		_marker.text = marker_text
		_marker.reset_size()
	_marker.show()
	projected.x -= _marker.size.x * 0.5
	_marker.position = Vector2(
		clampf(projected.x, 24.0, maxf(24.0, screen.x - _marker.size.x - 24.0)),
		clampf(projected.y, 120.0, maxf(120.0, screen.y - _marker.size.y - 24.0))
	)
	if is_instance_valid(_driving_hud_panel) and _driving_hud_panel.is_visible_in_tree():
		var reserved: Rect2 = _driving_hud_panel.get_global_rect().grow(18.0)
		if _marker.get_global_rect().intersects(reserved):
			_marker.position.y = maxf(120.0, reserved.position.y - _marker.size.y)


func _on_repair_completed() -> void:
	_message.text = "Serviço concluído!"
	_hint.visible = false
	_status.visible = false
	_progress.visible = false
	_marker.visible = false
	set_process(false)
