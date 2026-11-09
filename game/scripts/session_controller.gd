extends Node
## Ciclo de vida da sessão, do preparo ao relatório dos serviços concluídos.
signal objective_changed(objective: Node3D, service_number: int, total_services: int)

const VanController = preload("res://scripts/van_controller.gd")
const RepairEquipment = preload("res://scripts/repair_antenna.gd")
const SessionStats = preload("res://scripts/session_stats.gd")
enum State { PREPARATION, COUNTDOWN, RUNNING, FINISHED, RESULTS }

@export var repair_objective_path: NodePath = NodePath("../RepairAntenna")
@export var repair_objective_paths: Array[NodePath] = []

var state: State = State.PREPARATION
## Instante monotônico; o tempo acumulado abaixo acompanha os passos de física.
var session_started_at_usec: int = 0
var elapsed_time: float = 0.0
var _repair_objectives: Array[RepairEquipment] = []
var _completed_services: int = 0
var _repair_was_active: bool = false
var _monitor_was_processing: bool = false
var _countdown_tween: Tween
var _stats: SessionStats = SessionStats.new()

@onready var _prop_tracker: Node = get_node_or_null("../PropImpactTracker")
@onready var _results_ui: CanvasLayer = get_node_or_null("../SessionResults") as CanvasLayer
@onready var _van: VanController = get_node_or_null("../VanPrototype") as VanController
@onready var _monitor: Node = get_node_or_null("../StuntRewards/StuntMonitor")
@onready var _countdown: CenterContainer = get_node_or_null("../SessionUI/Center") as CenterContainer
@onready var _panel: PanelContainer = get_node_or_null("../SessionUI/Center/Panel") as PanelContainer
@onready var _label: Label = get_node_or_null("../SessionUI/Center/Panel/Margin/Message") as Label


func _ready() -> void:
	var required_nodes: Dictionary = {
		"VanPrototype": _van,
		"SessionResults": _results_ui,
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
	var paths: Array[NodePath] = repair_objective_paths
	if paths.is_empty():
		paths = [repair_objective_path]
	for path in paths:
		var objective := get_node_or_null(path) as RepairEquipment
		if objective == null or _repair_objectives.has(objective):
			push_error("SessionController: objetivo de reparo inválido ou duplicado: %s" % path)
			set_physics_process(false)
			return
		_repair_objectives.append(objective)

	# Amostra após o monitor (prioridade 100), sem alterar a ordem da física.
	process_physics_priority = 200
	_monitor.stunt_landed.connect(_on_stunt_landed)
	if _prop_tracker != null:
		_prop_tracker.prop_hit.connect(_on_prop_hit)
	_results_ui.restart_requested.connect(_restart_session)
	_repair_was_active = _repair_objectives[0].active
	for objective in _repair_objectives:
		objective.set_active(false)
		objective.repair_completed.connect(_on_repair_completed.bind(objective))
	for source in get_parent().find_children("*", "Node3D", true, false):
		if source.has_signal("tree_broken"):
			source.tree_broken.connect(_on_tree_broken.bind(source.get_instance_id()))
	_van.set_player_input_enabled(false)
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
	if _prop_tracker != null:
		_prop_tracker.start()
	_van.set_player_input_enabled(true)
	_monitor.set_physics_process(_monitor_was_processing)
	_activate_current_objective(_repair_was_active)


func _activate_current_objective(enabled: bool = true) -> void:
	var objective: RepairEquipment = _repair_objectives[_completed_services]
	objective.set_active(enabled)
	objective_changed.emit(objective, _completed_services + 1, _repair_objectives.size())


func _on_repair_completed(objective: RepairEquipment) -> void:
	if state != State.RUNNING or not objective.repaired or objective != _repair_objectives[_completed_services]:
		return
	_completed_services += 1
	if _completed_services == _repair_objectives.size():
		_finish_session()
	else:
		_activate_current_objective()


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
	var result: Dictionary = _stats.get_snapshot()
	if _repair_objectives.size() > 1:
		result = result.duplicate()
		result["services_completed"] = _completed_services
		result["services_total"] = _repair_objectives.size()
		result.make_read_only()
	return result


func _finish_session() -> void:
	if state != State.RUNNING:
		return
	state = State.FINISHED
	if _prop_tracker != null:
		_prop_tracker.stop()
	# Só resultados já emitidos entram no fechamento. Um pouso ainda pendente
	# não concede recompensa tardia, nem exige alterar a detecção do monitor.
	_monitor.set_physics_process(false)
	_stats.finish(elapsed_time)
	_van.set_player_input_enabled(false)
	if _countdown_tween != null and _countdown_tween.is_valid():
		_countdown_tween.kill()
	_countdown.hide()
	# Encerra as apresentações de gameplay antes de abrir o relatório.
	get_node("../StuntRewards")._hide_panel()
	for path in ["../StuntRewards", "../DrivingHUD", "../ObjectiveUI"]:
		var layer := get_node_or_null(path) as CanvasLayer
		if layer != null:
			layer.hide()
	var repair_ui := _repair_objectives[0].get_node_or_null("MissionUI") as CanvasLayer
	if repair_ui != null:
		repair_ui.hide()
	var result: Dictionary = get_results()
	print("\n=======================================\nVAN 4X4 — SESSÃO ENCERRADA\n=======================================")
	if result.has("services_total"):
		print("Serviços concluídos: %d/%d" % [result.services_completed, result.services_total])
	print("Tempo total: %.2f s\nDistância percorrida: %.2f m" % [result.elapsed_time, result.distance])
	print("\nSaltos: %d\nMaior salto: %.2f m\nMaior tempo no ar: %.2f s\nTempo total no ar: %.2f s" % [result.jumps, result.longest_jump, result.longest_air_time, result.total_air_time])
	print("\nGiros frontais: %d\nGiros laterais: %d\nGiros totais: %d" % [result.pitch_rotations, result.roll_rotations, result.rotations])
	print("\nPousos limpos: %d\nPousos brutais: %d\nCapotamentos após salto: %d" % [result.clean_landings, result.brutal_landings, result.rollovers])
	print("\nÁrvores derrubadas: %d\nCaixas atingidas: %d\nBarris atingidos: %d\nCones atingidos: %d\nProps únicos: %d" % [result.trees_broken, result.crates_hit, result.barrels_hit, result.cones_hit, result.props_hit])
	print("\nPontos de façanhas: %d\nPontos de árvores: %d\nPontos de props: %d\nPONTOS TOTAIS: %d\nEstrelas acumuladas: %d\n=======================================" % [result.points, result.tree_points, result.prop_points, result.total_points, result.stars])
	_results_ui.present(result)
	state = State.RESULTS


func _restart_session() -> void:
	if state != State.RESULTS:
		return
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		push_error("SessionController: não foi possível reiniciar a sessão: " + error_string(error))
		_results_ui.present(get_results())
		_results_ui.show_all()
