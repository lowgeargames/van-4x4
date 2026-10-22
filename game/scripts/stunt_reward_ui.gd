extends CanvasLayer

const StuntMonitor = preload("res://scripts/stunt_monitor.gd")

const MESSAGES: Dictionary = {
	# Intensidade definida apenas pelas estrelas já calculadas pelo monitor.
	1: [
		"ISSO ERA PRA SER UM SALTO?", "ATÉ QUE SAIU DO CHÃO!",
		"O CHÃO JÁ SENTIU SAUDADE!", "TÁ PEGANDO O JEITO!",
		"QUASE UM VOO!", "FOI UM BOM COMEÇO!",
		"A VAN DEU UM PULINHO!", "TENTATIVA HONESTA!",
		"FOI QUASE BONITO!", "AINDA TÁ INTEIRA!",
		"ERA PRA SER ASSIM?", "POUSO TECNICAMENTE REALIZADO!",
	],
	2: [
		"AGORA SIM, UM SALTO!", "ENTREGA EXPRESSA!",
		"A SUSPENSÃO VAI RECLAMAR!", "NADA MAL PRA UMA VAN!",
		"O CAMINHO FICOU PRA TRÁS!", "ESSE POUSO VAI PRA CONTA!",
		"ISSO MERECE UM REPLAY!", "QUEM PRECISA DE ESTRADA?",
		"VOOU LONGE!", "ISSO NÃO TAVA NO MANUAL!",
		"TÁ TUDO SOB CONTROLE...", "COMO SE NADA TIVESSE ACONTECIDO!",
		"POUSO DE PROFISSIONAL!", "NEM ARRANHOU A PINTURA!",
		"TUDO CALCULADO!", "A SUSPENSÃO AGRADECE!",
		"O CHÃO VEIO MUITO RÁPIDO!", "O SEGURO NÃO COBRE!",
		"O MECÂNICO VAI CHORAR!", "A OFICINA VAI TER TRABALHO!",
	],
	3: [
		"NEWTON NÃO APROVOU!", "A VAN TEM ASAS?!",
		"A FÍSICA PEDIU DEMISSÃO!", "ESQUECERAM DE AVISAR A GRAVIDADE!",
		"ISSO NÃO É UMA PISTA DE POUSO!", "ESSA VAN NÃO CONHECE LIMITES!",
		"ALGUÉM AVISA O CONTROLE AÉREO!", "O CLIENTE VAI RECEBER VIA AÉREA!",
		"DESTINO: ÓRBITA!", "DECOLAGEM NÃO AUTORIZADA!",
		"360° DE PURA COMPETÊNCIA!", "PIRUETA DE DUAS TONELADAS!",
		"ATERRISSAGEM CINEMATOGRÁFICA!", "CADÊ O LADO DE CIMA?!",
	],
}
const LANDING_LABELS: Array[String] = ["POUSO LIMPO", "POUSO BRUTAL", "CAPOTAMENTO"]

@export_range(1.0, 5.0, 0.1) var result_duration: float = 2.5
@export var show_session_total: bool = true
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
	if _panel.visible:
		_place_reward()


func _stop_animation() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_panel.scale = Vector2.ONE
	_panel.modulate.a = 1.0


func _show_flight(distance: float, air_time: float, pitch_rotations: int, roll_rotations: int) -> void:
	var entering_flight: bool = not _panel.visible or _stars.visible
	if entering_flight:
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
		# No voo, distância/tempo vêm antes das linhas menores de giros.
		_distance.get_parent().move_child(_distance, 1)
	var rotation_lines := PackedStringArray()
	if roll_rotations > 0:
		rotation_lines.append("1 giro lateral" if roll_rotations == 1 else "%d giros laterais" % roll_rotations)
	if pitch_rotations > 0:
		rotation_lines.append("1 giro frontal" if pitch_rotations == 1 else "%d giros frontais" % pitch_rotations)
	var rotation_text: String = "\n".join(rotation_lines)
	var refit: bool = entering_flight or _stats.text != rotation_text
	_stats.text = rotation_text
	_stats.visible = not rotation_lines.is_empty()
	_distance.text = ("%.1f m | %.1f s" % [distance, air_time]).replace(".", ",")
	if refit:
		_fit_flight_panel.call_deferred()


func _fit_flight_panel() -> void:
	if not _panel.visible or _stars.visible:
		return
	# Aguarda o layout: encolhe o popup anterior ou acomoda duas linhas de giros.
	_panel.size = Vector2(_panel.size.x, _panel.get_combined_minimum_size().y)
	_place_reward()


func _show_result(result: Dictionary) -> void:
	_stop_animation()
	# Preserva a ordem original dos elementos no popup de resultado.
	_distance.get_parent().move_child(_distance, 3)
	_panel.offset_top = -280.0
	_panel.offset_bottom = -24.0
	_panel.show()
	set_process(true)
	_title.text = _choose_message(result.stars)
	_stats.text = ("%.1f m | %.1f s" % [result.distance, result.air_time]).replace(".", ",")
	if result.rotations > 0:
		_stats.text += " | 1 giro" if result.rotations == 1 else " | %d giros" % result.rotations
	_stats.show()
	_landing.text = LANDING_LABELS[result.landing]
	_landing.show()
	_distance.add_theme_font_size_override("font_size", 38)
	_distance.text = "+%s PTS" % _format_points(result.points)
	_stars.text = "★ ".repeat(result.stars).strip_edges()
	_stars.show()
	_total.text = "SESSÃO: %s PTS · %d ★" % [_format_points(result.session_points), result.session_stars]
	_total.visible = show_session_total
	_panel.scale = Vector2.ONE * 0.85
	_tween = create_tween()
	_tween.tween_property(_panel, "scale", Vector2.ONE * 1.08, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.12)
	_tween.tween_interval(maxf(0.0, result_duration - 0.54))
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(_hide_panel)


func _choose_message(stars: int) -> String:
	var options: Array = MESSAGES[stars]
	var previous: int = _last_messages.get(stars, -1)
	var index: int = _rng.randi_range(0, options.size() - 1)
	if previous >= 0:
		index = (previous + 1 + _rng.randi_range(0, options.size() - 2)) % options.size()
	_last_messages[stars] = index
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
