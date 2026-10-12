extends CanvasLayer

const StuntMonitor = preload("res://scripts/stunt_monitor.gd")

const MESSAGES: Dictionary = {
	"jump": ["A VAN TEM ASAS?!", "DESTINO: ÓRBITA!", "DECOLAGEM NÃO AUTORIZADA!", "ENTREGA EXPRESSA!", "VOOU LONGE!"],
	"spin": ["NEWTON NÃO APROVOU!", "360° DE PURA COMPETÊNCIA!", "ISSO NÃO TAVA NO MANUAL!", "TÁ TUDO SOB CONTROLE...", "PIRUETA DE DUAS TONELADAS!"],
	"clean": ["COMO SE NADA TIVESSE ACONTECIDO!", "POUSO DE PROFISSIONAL!", "NEM ARRANHOU A PINTURA!", "ATERRISSAGEM CINEMATOGRÁFICA!", "TUDO CALCULADO!"],
	"brutal": ["POUSO TECNICAMENTE REALIZADO!", "A SUSPENSÃO AGRADECE!", "FOI QUASE BONITO!", "O CHÃO VEIO MUITO RÁPIDO!", "AINDA TÁ INTEIRA!"],
	"rollover": ["O SEGURO NÃO COBRE!", "O MECÂNICO VAI CHORAR!", "A OFICINA VAI TER TRABALHO!", "ERA PRA SER ASSIM?", "CADÊ O LADO DE CIMA?!"],
}
const LANDING_LABELS: Array[String] = ["POUSO LIMPO", "POUSO BRUTAL", "CAPOTAMENTO"]

@export_range(1.0, 5.0, 0.1) var result_duration: float = 2.5
@export var mission_panel_path: NodePath = NodePath("../RepairAntenna/MissionUI/Panel")
@export var objective_marker_path: NodePath = NodePath("../ObjectiveUI/ObjectiveMarker")
@export var driving_hud_panel_path: NodePath = NodePath("../DrivingHUD/Panel")

var _tween: Tween
var _last_messages: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _protected_controls: Array[Control] = []
@onready var _monitor: StuntMonitor = $StuntMonitor
@onready var _panel: PanelContainer = $Reward
@onready var _title: Label = $Reward/Margin/Content/Title
@onready var _distance: Label = $Reward/Margin/Content/Distance
@onready var _stars: Label = $Reward/Margin/Content/Stars
@onready var _total: Label = $Reward/Margin/Content/Total
@onready var _stats: Label = $Reward/Margin/Content/Stats
@onready var _landing: Label = $Reward/Margin/Content/Landing


func _ready() -> void:
	_rng.randomize()
	for path in [mission_panel_path, objective_marker_path, driving_hud_panel_path]:
		var control: Control = get_node_or_null(path) as Control
		if control != null:
			_protected_controls.append(control)
	_monitor.flight_updated.connect(_show_flight)
	_monitor.flight_cancelled.connect(_hide_reward)
	_monitor.stunt_landed.connect(_show_result)
	_panel.resized.connect(_update_pivot)
	_update_pivot()
	set_process(false)


func _process(_delta: float) -> void:
	# Só verifica sobreposição enquanto a recompensa está visível.
	var occupied: Rect2 = _panel.get_global_rect().grow(18.0)
	for control in _protected_controls:
		if is_instance_valid(control) and control.is_visible_in_tree() and occupied.intersects(control.get_global_rect()):
			_place_reward()
			break


func _place_reward() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var bottom: float = screen.y - _panel.size.y - 24.0
	var right: float = maxf(24.0, screen.x - _panel.size.x - 24.0)
	for position_now in [Vector2(24, bottom), Vector2(right, bottom), Vector2(right, 24), Vector2(24, 24)]:
		var available: bool = true
		for control in _protected_controls:
			if is_instance_valid(control) and control.is_visible_in_tree() and Rect2(position_now, _panel.size).grow(18.0).intersects(control.get_global_rect()):
				available = false
				break
		if available:
			_panel.position = position_now
			return


func _update_pivot() -> void:
	_panel.pivot_offset = _panel.size * 0.5


func _stop_animation() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_panel.scale = Vector2.ONE
	_panel.modulate.a = 1.0


func _show_flight(distance: float, air_time: float, pitch_rotations: int, roll_rotations: int) -> void:
	if not _panel.visible or _stars.visible:
		_stop_animation()
		_panel.offset_top = -145.0
		_panel.offset_bottom = -24.0
		_panel.show()
		set_process(true)
		_title.text = "SALTO"
		_stars.hide()
		_total.hide()
		_landing.hide()
		_distance.add_theme_font_size_override("font_size", 30)
	var rotations: int = pitch_rotations + roll_rotations
	_stats.visible = rotations > 0
	_stats.text = "%d giros · %d frontal / %d lateral" % [rotations, pitch_rotations, roll_rotations]
	_distance.text = ("%.1f m | %.1f s" % [distance, air_time]).replace(".", ",")


func _show_result(result: Dictionary) -> void:
	_stop_animation()
	_panel.offset_top = -280.0
	_panel.offset_bottom = -24.0
	_panel.show()
	set_process(true)
	_title.text = _choose_message(_message_category(result))
	_stats.text = ("%.1f m | %.1f s | %d giros" % [result.distance, result.air_time, result.rotations]).replace(".", ",")
	_stats.show()
	_landing.text = LANDING_LABELS[result.landing]
	_landing.show()
	_distance.add_theme_font_size_override("font_size", 38)
	_distance.text = "+%s PTS" % _format_points(result.points)
	_stars.text = "★ ".repeat(result.stars).strip_edges()
	_stars.show()
	_total.text = "SESSÃO: %s PTS · %d ★" % [_format_points(result.session_points), result.session_stars]
	_total.show()
	_panel.scale = Vector2.ONE * 0.85
	_tween = create_tween()
	_tween.tween_property(_panel, "scale", Vector2.ONE * 1.08, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.12)
	_tween.tween_interval(maxf(0.0, result_duration - 0.54))
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(_hide_panel)


func _message_category(result: Dictionary) -> String:
	if result.landing == StuntMonitor.Landing.ROLLOVER:
		return "rollover"
	if result.rotations > 0:
		return "spin"
	if result.stars >= 2 or result.air_time >= 1.4:
		return "jump"
	return "clean" if result.landing == StuntMonitor.Landing.CLEAN else "brutal"


func _choose_message(category: String) -> String:
	var options: Array = MESSAGES[category]
	var previous: int = _last_messages.get(category, -1)
	var index: int = _rng.randi_range(0, options.size() - 1)
	if previous >= 0:
		index = (previous + 1 + _rng.randi_range(0, options.size() - 2)) % options.size()
	_last_messages[category] = index
	return options[index]


func _format_points(points: int) -> String:
	var text: String = str(points)
	var index: int = text.length() - 3
	while index > 0:
		text = text.insert(index, ".")
		index -= 3
	return text


func _hide_panel() -> void:
	_panel.hide()
	set_process(false)


func _hide_reward() -> void:
	# Uma oscilação inválida não apaga o resultado anterior antes dos dois segundos.
	if _stars.visible:
		return
	_stop_animation()
	_hide_panel()
