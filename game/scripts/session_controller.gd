extends Node
## Inicialização exclusiva do ensaio; não encerra a sessão ao concluir o reparo.

const VanController = preload("res://scripts/van_controller.gd")
const RepairEquipment = preload("res://scripts/repair_antenna.gd")
enum State { PREPARATION, COUNTDOWN, RUNNING }

var state: State = State.PREPARATION
## Instante monotônico; o tempo acumulado abaixo acompanha os passos de física.
var session_started_at_usec: int = 0
var elapsed_time: float = 0.0
var _repair_was_active: bool = false
var _monitor_was_processing: bool = false
var _countdown_tween: Tween

@onready var _van: VanController = get_node_or_null("../VanPrototype") as VanController
@onready var _antenna: RepairEquipment = get_node_or_null("../RepairAntenna") as RepairEquipment
@onready var _monitor: Node = get_node_or_null("../StuntRewards/StuntMonitor")
@onready var _countdown: CenterContainer = get_node_or_null("../SessionUI/Center") as CenterContainer
@onready var _panel: PanelContainer = get_node_or_null("../SessionUI/Center/Panel") as PanelContainer
@onready var _label: Label = get_node_or_null("../SessionUI/Center/Panel/Margin/Message") as Label


func _ready() -> void:
	var required_nodes: Dictionary = {
		"VanPrototype": _van,
		"RepairAntenna": _antenna,
		"StuntRewards/StuntMonitor": _monitor,
		"SessionUI/Center": _countdown,
		"SessionUI/Center/Panel": _panel,
		"SessionUI/Center/Panel/Margin/Message": _label,
	}
	var valid: bool = true
	for path in required_nodes:
		if not is_instance_valid(required_nodes[path]):
			push_error("SessionController: nó obrigatório ausente ou de tipo incorreto: " + path)
			valid = false
	if not valid:
		set_physics_process(false)
		return

	_van.set_player_input_enabled(false)
	_repair_was_active = _antenna.active
	_antenna.set_active(false)
	_monitor_was_processing = _monitor.is_physics_processing()
	_monitor.set_physics_process(false)
	_countdown.show()
	state = State.COUNTDOWN
	_show_countdown("PREPARE-SE!", 48)
	_countdown_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_countdown_tween.tween_interval(1.0)
	for number in ["3", "2", "1"]:
		_countdown_tween.tween_callback(_show_countdown.bind(number, 84))
		_countdown_tween.tween_interval(1.0)
	_countdown_tween.tween_callback(_start_session)
	_countdown_tween.tween_interval(0.55)
	_countdown_tween.tween_property(_panel, "modulate:a", 0.0, 0.2)
	_countdown_tween.tween_callback(_countdown.hide)


func _physics_process(delta: float) -> void:
	if state == State.RUNNING:
		elapsed_time += delta


func _show_countdown(message: String, font_size: int) -> void:
	_label.text = message
	_label.add_theme_font_size_override("font_size", font_size)


func _start_session() -> void:
	if state != State.COUNTDOWN:
		return
	_show_countdown("VAI!", 64)
	session_started_at_usec = Time.get_ticks_usec()
	elapsed_time = 0.0
	state = State.RUNNING
	_van.set_player_input_enabled(true)
	_antenna.set_active(_repair_was_active)
	_monitor.set_physics_process(_monitor_was_processing)
