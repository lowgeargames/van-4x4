extends Node
## Ciclo de vida exclusivo do ensaio; a conclusão não interfere nas cenas originais.

const VanController = preload("res://scripts/van_controller.gd")
const RepairEquipment = preload("res://scripts/repair_antenna.gd")
const SessionStats = preload("res://scripts/session_stats.gd")
enum State { PREPARATION, COUNTDOWN, RUNNING, FINISHED }

var state: State = State.PREPARATION
## Instante monotônico; o tempo acumulado abaixo acompanha os passos de física.
var session_started_at_usec: int = 0
var elapsed_time: float = 0.0
var _repair_was_active: bool = false
var _monitor_was_processing: bool = false
var _countdown_tween: Tween
var _stats: SessionStats = SessionStats.new()

@onready var _prop_tracker: Node = get_node_or_null("../PropImpactTracker")
@onready var _van: VanController = get_node_or_null("../VanPrototype") as VanController
@onready var _antenna: RepairEquipment = get_node_or_null("../RepairAntenna") as RepairEquipment
@onready var _monitor: Node = get_node_or_null("../StuntRewards/StuntMonitor")
@onready var _countdown: CenterContainer = get_node_or_null("../SessionUI/Center") as CenterContainer
@onready var _panel: PanelContainer = get_node_or_null("../SessionUI/Center/Panel") as PanelContainer
@onready var _label: Label = get_node_or_null("../SessionUI/Center/Panel/Margin/Message") as Label


func _ready() -> void:
	var required_nodes: Dictionary = {
		"VanPrototype": _van,
		"PropImpactTracker": _prop_tracker,
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

	# Amostra após o monitor (prioridade 100), sem alterar a ordem da física.
	process_physics_priority = 200
	_monitor.stunt_landed.connect(_on_stunt_landed)
	_prop_tracker.prop_hit.connect(_on_prop_hit)
	_antenna.repair_completed.connect(_finish_session)
	for source in get_parent().find_children("*", "Node3D", true, false):
		if source.has_signal("tree_broken"):
			source.tree_broken.connect(_on_tree_broken.bind(source.get_instance_id()))
	_van.set_player_input_enabled(false)
	_repair_was_active = _antenna.active
	_antenna.set_active(false)
	_monitor_was_processing = _monitor.is_physics_processing()
	_monitor.set_physics_process(false)
	_countdown.hide()
	var warmup: Node = get_node_or_null("../VisualWarmup")
	if warmup != null and not warmup.is_prepared:
		await warmup.prepared
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
		_stats.sample_motion(_van, delta, Input.is_action_just_pressed("reset_vehicle") or _van._reset_requested)


func _show_countdown(message: String, font_size: int) -> void:
	_label.text = message
	_label.add_theme_font_size_override("font_size", font_size)


func _start_session() -> void:
	if state != State.COUNTDOWN:
		return
	_show_countdown("VAI!", 64)
	session_started_at_usec = Time.get_ticks_usec()
	elapsed_time = 0.0
	_stats.start(_van, _monitor.total_points, _monitor.total_stars)
	state = State.RUNNING
	_prop_tracker.start()
	_van.set_player_input_enabled(true)
	_antenna.set_active(_repair_was_active)
	_monitor.set_physics_process(_monitor_was_processing)


func _on_stunt_landed(result: Dictionary) -> void:
	if state == State.RUNNING:
		_stats.record_stunt(result)


func _on_tree_broken(index: int, _impact_speed: float, source_id: int) -> void:
	if state == State.RUNNING:
		_stats.record_tree(source_id, index)


func _on_prop_hit(instance_id: int, category: String, _approach_speed: float) -> void:
	if state == State.RUNNING:
		_stats.record_prop(instance_id, category)


func get_results() -> Dictionary:
	return _stats.get_snapshot()


func _finish_session() -> void:
	if state != State.RUNNING:
		return
	state = State.FINISHED
	_prop_tracker.stop()
	# Só resultados já emitidos entram no fechamento. Um pouso ainda pendente
	# não concede recompensa tardia, nem exige alterar a detecção do monitor.
	_monitor.set_physics_process(false)
	_stats.finish(elapsed_time)
	var result: Dictionary = get_results()
	print("\n=======================================\nVAN 4X4 — SESSÃO ENCERRADA\n=======================================")
	print("Tempo total: %.2f s\nDistância percorrida: %.2f m" % [result.elapsed_time, result.distance])
	print("\nSaltos: %d\nMaior salto: %.2f m\nMaior tempo no ar: %.2f s\nTempo total no ar: %.2f s" % [result.jumps, result.longest_jump, result.longest_air_time, result.total_air_time])
	print("\nGiros frontais: %d\nGiros laterais: %d\nGiros totais: %d" % [result.pitch_rotations, result.roll_rotations, result.rotations])
	print("\nPousos limpos: %d\nPousos brutais: %d\nCapotamentos após salto: %d" % [result.clean_landings, result.brutal_landings, result.rollovers])
	print("\nÁrvores derrubadas: %d\nCaixas atingidas: %d\nBarris atingidos: %d\nCones atingidos: %d\nProps únicos: %d" % [result.trees_broken, result.crates_hit, result.barrels_hit, result.cones_hit, result.props_hit])
	print("\nPontos de façanhas: %d\nPontos de árvores: %d\nPontos de props: %d\nPONTOS TOTAIS: %d\nEstrelas acumuladas: %d\n=======================================" % [result.points, result.tree_points, result.prop_points, result.total_points, result.stars])
