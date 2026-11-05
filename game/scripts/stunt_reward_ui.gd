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

const RewardArt = preload("res://scripts/stunt_reward_art.gd")
var _tween: Tween
var _spin_tween: Tween
var _generation: int = 0
var _mode: String = "hidden"
var _placed: bool = false
var _last_messages: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _protected_controls: Array[Control] = []
var _star_pool: Array[Control] = []
@onready var _monitor: StuntMonitor = $StuntMonitor
@onready var _panel: PanelContainer = $Reward
@onready var _title: Label = $Reward/Margin/Content/Title
@onready var _distance: Label = $Reward/Margin/Content/Distance
@onready var _stars: HBoxContainer = $Reward/Margin/Content/Stars
@onready var _total: Label = $Reward/Margin/Content/Total
@onready var _stats: Label = $Reward/Margin/Content/Stats
@onready var _landing: Label = $Reward/Margin/Content/Landing
@onready var _burst: Control = $Reward/Burst


func _ready() -> void:
	_rng.randomize()
	for path in [mission_panel_path, objective_marker_path, driving_hud_panel_path, NodePath("../SessionUI/Center/Panel")]:
		var control := get_node_or_null(path) as Control
		if control != null:
			_protected_controls.append(control)
	_monitor.flight_updated.connect(_show_flight)
	_monitor.flight_cancelled.connect(_hide_reward)
	_monitor.stunt_landed.connect(_show_result)
	_panel.resized.connect(_update_pivot)
	get_viewport().size_changed.connect(_viewport_changed)
	set_process(false)


func _blocked(rect: Rect2) -> bool:
	for control in _protected_controls:
		if is_instance_valid(control) and control.is_visible_in_tree() and rect.grow(20.0).intersects(control.get_global_rect()):
			return true
	return false


func _process(_delta: float) -> void:
	if not visible:
		_hide_panel()
		return
	if _placed:
		# Mantém a posição durante a apresentação. Se um marcador móvel a invadir,
		# oculta só este feedback até liberar espaço, sem disputar o marcador.
		_panel.visible = not _blocked(_panel.get_global_rect())


func _viewport_changed() -> void:
	_placed = false
	_layout_presentation.call_deferred(_generation)


func _update_pivot() -> void:
	_panel.pivot_offset = Vector2.ZERO if _mode == "result" else _panel.size * 0.5


func _layout_presentation(generation: int) -> void:
	if generation != _generation or _mode == "hidden":
		return
	_panel.reset_size()
	_update_pivot()
	# Compacta apenas o resultado; o HUD aéreo mantém a proporção aprovada.
	_panel.scale = Vector2.ONE * (0.9 if _mode == "result" else 1.0)
	_distance.pivot_offset = _distance.size * 0.5
	_stats.pivot_offset = _stats.size * 0.5
	for star in _star_pool:
		star.pivot_offset = star.size * 0.5
	_burst.origin = (_stars.get_global_rect().get_center() - _panel.global_position) / _panel.scale
	_burst.pivot_offset = _burst.origin
	if _placed:
		return
	var screen := get_viewport().get_visible_rect().size
	var visual_size: Vector2 = _panel.size * _panel.scale
	var below_mission: float = 24.0
	var mission := get_node_or_null(mission_panel_path) as Control
	if is_instance_valid(mission) and mission.is_visible_in_tree():
		below_mission = mission.get_global_rect().end.y + 32.0
	# Voo e resultado compartilham a coluna esquerda; o mesmo painel é reutilizado.
	# Se houver outro controle nessa faixa, empilha abaixo dele sem ir ao centro.
	var candidate := Vector2(24, below_mission)
	for attempt in _protected_controls.size() + 1:
		for control in _protected_controls:
			if is_instance_valid(control) and control.is_visible_in_tree():
				if Rect2(candidate, visual_size).grow(20.0).intersects(control.get_global_rect()):
					candidate.y = maxf(candidate.y, control.get_global_rect().end.y + 32.0)
		if candidate.y + visual_size.y > screen.y - 24.0:
			break
		if not _blocked(Rect2(candidate, visual_size)):
			_panel.position = candidate
			_placed = true
			_panel.show()
			return
	# Sem espaço na coluna esquerda, preserva a prioridade da missão/contagem.
	_panel.hide()


func _stop_animation() -> void:
	_generation += 1
	for animation in [_tween, _spin_tween]:
		if animation != null and animation.is_valid():
			animation.kill()
	_panel.scale = Vector2.ONE
	_panel.modulate = Color.WHITE
	_distance.scale = Vector2.ONE
	_stats.scale = Vector2.ONE
	_burst.hide()
	_burst.scale = Vector2.ONE
	_burst.modulate = Color.WHITE
	for star in _star_pool:
		star.hide()
		star.scale = Vector2.ONE
		star.rotation = 0.0
		star.modulate = Color.WHITE


func _begin_presentation(mode: String) -> void:
	_stop_animation()
	_mode = mode
	_placed = false
	_panel.show()
	set_process(true)


func _show_flight(distance: float, air_time: float, pitch_rotations: int, roll_rotations: int) -> void:
	var entering: bool = _mode != "flight"
	if entering:
		_begin_presentation("flight")
		_title.text = "SALTO!"
		_stars.hide()
		_total.hide()
		_landing.hide()
		_distance.add_theme_font_size_override("font_size", 60)
		_stats.text = ""
		_stats.set_meta("spins", "")
	var spins := PackedStringArray()
	if roll_rotations > 0:
		spins.append("1 GIRO LATERAL" if roll_rotations == 1 else "%d GIROS LATERAIS" % roll_rotations)
	if pitch_rotations > 0:
		spins.append("1 GIRO FRONTAL" if pitch_rotations == 1 else "%d GIROS FRONTAIS" % pitch_rotations)
	var secondary: String = ("%.1f s" % air_time).replace(".", ",")
	if not spins.is_empty():
		secondary += " · " + " · ".join(spins)
	# Tempo cresce sem disparar o pulso; apenas novos contadores de giro o fazem.
	var changed: bool = not spins.is_empty() and _stats.get_meta("spins", "") != " · ".join(spins)
	_stats.set_meta("spins", " · ".join(spins))
	_stats.text = secondary
	_stats.modulate = Color("65d6be") if not spins.is_empty() else Color("fff3d6")
	_distance.text = ("%.1f m" % distance).replace(".", ",")
	if changed:
		if _spin_tween != null and _spin_tween.is_valid():
			_spin_tween.kill()
		_stats.scale = Vector2.ONE * 1.12
		_spin_tween = create_tween()
		_spin_tween.tween_property(_stats, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if entering or changed:
		_layout_presentation.call_deferred(_generation)


func _set_display_points(value: float) -> void:
	_distance.text = "+%s PTS" % _format_points(roundi(value))


func _show_result(result: Dictionary) -> void:
	_begin_presentation("result")
	_title.text = _choose_message(result.stars)
	_stats.modulate = Color("fff3d6")
	_stats.text = ("%.1f m · %.1f s" % [result.distance, result.air_time]).replace(".", ",")
	if result.rotations > 0:
		_stats.text += " · 1 giro" if result.rotations == 1 else " · %d giros" % result.rotations
	_landing.text = LANDING_LABELS[result.landing]
	_landing.show()
	_distance.add_theme_font_size_override("font_size", 72)
	_set_display_points(0)
	_stars.show()
	while _star_pool.size() < result.stars:
		var star := Control.new()
		star.set_script(RewardArt)
		star.kind = 1
		star.custom_minimum_size = Vector2(64, 62)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stars.add_child(star)
		_star_pool.append(star)
	_total.text = "SESSÃO: %s PTS · %d ★" % [_format_points(result.session_points), result.session_stars]
	_total.visible = show_session_total
	_tween = create_tween().set_parallel(true)
	# Só anima uma cópia visual do valor final recebido; não escreve no resultado.
	_tween.tween_method(_set_display_points, 0.0, float(result.points), 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_distance, "scale", Vector2.ONE * 1.08, 0.08).set_delay(0.4)
	_tween.tween_property(_distance, "scale", Vector2.ONE, 0.14).set_delay(0.48)
	for i in result.stars:
		var star: Control = _star_pool[i]
		# Modulate permite reservar o espaço no HBox antes do carimbo aparecer.
		star.show()
		star.modulate.a = 0.0
		var impact: float = 1.2 + 0.06 * i + (0.18 if result.stars == 3 and i == 2 else 0.0)
		star.scale = Vector2.ONE * impact
		star.rotation = deg_to_rad(-12.0 if i % 2 == 0 else 12.0)
		var delay: float = 0.08 + i * 0.14
		_tween.tween_property(star, "modulate:a", 1.0, 0.07).set_delay(delay)
		_tween.tween_property(star, "scale", Vector2.ONE * 0.92, 0.17).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(star, "scale", Vector2.ONE, 0.13).set_delay(delay + 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(star, "rotation", 0.0, 0.3).set_delay(delay)
	if result.stars == 3:
		_burst.show()
		_burst.modulate.a = 0.0
		_burst.scale = Vector2.ONE * 0.7
		_tween.tween_property(_burst, "modulate:a", 1.0, 0.05).set_delay(0.4)
		_tween.tween_property(_burst, "scale", Vector2.ONE * 1.45, 0.4).set_delay(0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_burst, "modulate:a", 0.0, 0.35).set_delay(0.45)
	var hold: float = maxf(result_duration, 1.2)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.3).set_delay(hold - 0.3)
	_tween.chain().tween_callback(_hide_panel)
	_layout_presentation.call_deferred(_generation)


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
	_stop_animation()
	_mode = "hidden"
	_panel.hide()
	set_process(false)


func _hide_reward() -> void:
	# Um salto inválido não apaga uma recompensa ainda em apresentação.
	if _mode != "result":
		_hide_panel()


func _exit_tree() -> void:
	_stop_animation()
