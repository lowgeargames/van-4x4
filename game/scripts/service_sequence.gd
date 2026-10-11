extends Node

const RepairEquipment = preload("res://scripts/repair_antenna.gd")

@export var antenna_path: NodePath
@export var pump_path: NodePath

var _active_repair: RepairEquipment
var _status_remaining: float = 0.0

@onready var _antenna: RepairEquipment = get_node(antenna_path)
@onready var _pump: RepairEquipment = get_node(pump_path)
# Uma única interface: reaproveita o painel que já existia na antena.
@onready var _message: Label = _antenna.get_node("MissionUI/Panel/Margin/Content/Message")
@onready var _status: Label = _antenna.get_node("MissionUI/Panel/Margin/Content/Status")
@onready var _hint: Label = _antenna.get_node("MissionUI/Panel/Margin/Content/Hint")
@onready var _progress: ProgressBar = _antenna.get_node("MissionUI/Panel/Margin/Content/Progress")


func _ready() -> void:
	_antenna.repair_completed.connect(_on_antenna_repaired)
	_pump.repair_completed.connect(_on_pump_repaired)
	_antenna.set_active(true)
	_pump.set_active(false)
	_active_repair = _antenna
	_message.text = "Serviço 1/2: reparar a antena."


func _process(delta: float) -> void:
	if _status_remaining > 0.0:
		_status_remaining = maxf(_status_remaining - delta, 0.0)
		_status.visible = _status_remaining > 0.0
	if _active_repair == null:
		return

	var nearby: bool = _active_repair.is_van_nearby()
	_progress.visible = nearby
	_progress.value = _active_repair.get_repair_progress()
	if nearby:
		_hint.text = "Pare a van e segure E para reparar."
	elif _active_repair == _antenna:
		_hint.text = (
			"Repare a antena antes de atender a bomba." if _pump.is_van_nearby()
			else "Procure a antena na lama, à esquerda."
		)
	else:
		_hint.text = "Atravesse a água; a bomba está na outra margem."


func _on_antenna_repaired() -> void:
	_status.text = "Serviço 1 concluído!"
	_status.visible = true
	_status_remaining = 3.0
	_pump.set_active(true)
	_active_repair = _pump
	_progress.value = 0.0
	_progress.visible = false
	_message.text = "Serviço 2/2: reparar a bomba d'água."


func _on_pump_repaired() -> void:
	_active_repair = null
	_status_remaining = 0.0
	_status.visible = false
	_progress.visible = false
	_message.text = "Todos os serviços concluídos!"
	_hint.text = "Partida concluída."
	set_process(false)
