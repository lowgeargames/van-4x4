extends Control
## Apenas apresentação 2D. Não consulta entradas nem escreve no controlador da van.

const GRAPHITE := Color("182126")
const IVORY := Color("fff3d6")
const YELLOW := Color("ffc83d")
const ORANGE := Color("ff742e")
const MINT := Color("65d6be")
const GRAY := Color("9da9ac")
const CENTER := Vector2(150, 118)
const START: float = 5.0 * PI / 6.0
const SWEEP: float = 4.0 * PI / 3.0
const VISUAL_MAX_SPEED: float = 160.0

var _target_ratio: float = 0.0
var _arc_ratio: float = 0.0
var _energy_ratio: float = 1.0
var _turbo_color: Color = YELLOW
var _active: bool = false
var _blocked: bool = false
var _pulse_time: float = 0.0
var _activation: Tween
var _boost_scale: float = 1.0:
	set(value):
		_boost_scale = value
		$Turbo.scale = Vector2.ONE * value
		queue_redraw()

@onready var _speed: Label = $Speed
@onready var _energy: Label = $Turbo/Energy
@onready var _status: Label = $Turbo/Status


func set_speed(kmh: float) -> void:
	_speed.text = str(roundi(kmh))
	_target_ratio = clampf(kmh / VISUAL_MAX_SPEED, 0.0, 1.0)


func set_turbo(ratio: float, state: String, color: Color, active: bool, blocked: bool, unlimited: bool) -> void:
	var changed: bool = not is_equal_approx(ratio, _energy_ratio) or color != _turbo_color or blocked != _blocked
	_energy_ratio = ratio
	_turbo_color = color
	_blocked = blocked
	_energy.text = "∞" if unlimited else "%d%%" % roundi(ratio * 100.0)
	_status.text = state
	_status.modulate = color
	if active != _active:
		_active = active
		_pulse_time = 0.0
		if _activation != null and _activation.is_valid():
			_activation.kill()
		_activation = create_tween()
		if active:
			_activation.tween_property(self, "_boost_scale", 1.04, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_activation.tween_property(self, "_boost_scale", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		changed = true
	if changed:
		queue_redraw()


func _process(delta: float) -> void:
	if not is_equal_approx(_arc_ratio, _target_ratio):
		_arc_ratio = lerpf(_arc_ratio, _target_ratio, 1.0 - exp(-delta / 0.1))
		if absf(_arc_ratio - _target_ratio) < 0.0001:
			_arc_ratio = _target_ratio
		queue_redraw()
	if _active:
		_pulse_time = fmod(_pulse_time + delta, 0.8)
		queue_redraw()


func _draw() -> void:
	# Uma placa única acompanha o arco e termina na base angular do turbo.
	var plate := PackedVector2Array([Vector2(18, 200)])
	for i in 33:
		plate.append(CENTER + Vector2.from_angle(START + SWEEP * i / 32.0) * 116.0)
	plate.append_array(PackedVector2Array([Vector2(282, 200), Vector2(282, 262), Vector2(266, 278), Vector2(18, 278)]))
	draw_colored_polygon(plate, Color(GRAPHITE, 0.88))
	draw_arc(CENTER, 94, START, START + SWEEP, 65, Color(GRAY, 0.25), 11, true)
	if _arc_ratio > 0.0001:
		draw_arc(CENTER, 94, START, START + SWEEP * _arc_ratio, 65, YELLOW, 11, true)
	for i in 9:
		var direction := Vector2.from_angle(START + SWEEP * i / 8.0)
		draw_line(CENTER + direction * 103.0, CENTER + direction * (113.0 if i % 4 == 0 else 108.0), IVORY if i % 4 == 0 else GRAY, 2.0, true)
	var font: Font = get_theme_font("font")
	for mark in [["0", Vector2(57, 182)], ["80", Vector2(150, 51)], ["160", Vector2(243, 182)]]:
		var label: String = mark[0]
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(font, mark[1] - Vector2(width * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GRAY)

	# Mesmo pivô de Turbo: texto e segmentos expandem juntos sem mover a área reservada.
	var pivot := Vector2(150, 233)
	draw_set_transform(pivot * (1.0 - _boost_scale), 0.0, Vector2.ONE * _boost_scale)
	var fill: Color = Color(GRAY, 0.32) if _blocked else _turbo_color
	if _active:
		fill = fill.lerp(IVORY, (sin(_pulse_time * TAU / 0.8) + 1.0) * 0.07)
	for i in 8:
		var x: float = 32.0 + i * 30.0
		var fraction: float = clampf(_energy_ratio * 8.0 - i, 0.0, 1.0)
		draw_colored_polygon(_segment(x, 1.0), Color(GRAY, 0.16))
		# Evita polígonos degenerados por resíduos de ponto flutuante na recarga.
		if fraction > 0.001:
			draw_colored_polygon(_segment(x, fraction), fill)
		if _blocked:
			draw_line(Vector2(x + 5, 240), Vector2(x + 20, 226), GRAY, 2.0, true)
	draw_set_transform(Vector2.ZERO)


func _segment(x: float, fraction: float) -> PackedVector2Array:
	# Preenchimento parcial acompanha a inclinação, sem arredondar a energia em blocos.
	var width: float = 24.0 * fraction
	return PackedVector2Array([Vector2(x + 6, 223), Vector2(x + 6 + width, 223), Vector2(x + width, 243), Vector2(x, 243)])
