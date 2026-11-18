extends Control
## Vista lateral simples da van de teste (apresentação apenas): estrada, colinas e
## postes que rolam com a velocidade, rodas que giram, inclinação ao acelerar,
## trepidação no piso irregular e salto quando o voo está ligado.
## Tudo é desenhado com formas 2D; não usa modelos, shaders nem texturas.

const Style = preload("res://audio/demo/lab_style.gd")

const WHEEL_RADIUS: float = 26.0

var speed: float = 0.0
var max_speed: float = 24.0
var throttle: float = 0.0
var rough: bool = false
var mud: bool = false
var air: bool = false
var has_vehicle: bool = true

var _dist: float = 0.0
var _wheel: float = 0.0
var _time: float = 0.0
var _air_lift: float = 0.0
var _tilt: float = 0.0
var _mud_amount: float = 0.0


func set_values(new_speed: float, new_max: float, new_throttle: float, new_rough: bool,
		new_mud: bool, new_air: bool, new_has_vehicle: bool) -> void:
	speed = new_speed
	max_speed = maxf(new_max, 0.1)
	throttle = new_throttle
	rough = new_rough
	mud = new_mud
	air = new_air
	has_vehicle = new_has_vehicle


## Avança a animação. Chamado pela interface só enquanto a vista está visível.
func step(delta: float) -> void:
	var ppm: float = size.x / 36.0
	var sc: float = _van_scale()
	_dist += speed * delta
	_wheel += speed * ppm / (WHEEL_RADIUS * sc) * delta
	_time += delta
	_air_lift = lerpf(_air_lift, 1.0 if air else 0.0, 1.0 - exp(-8.0 * delta))
	_tilt = lerpf(_tilt, -clampf(throttle, -1.0, 1.0) * 0.03, 1.0 - exp(-6.0 * delta))
	_mud_amount = lerpf(_mud_amount, 1.0 if mud else 0.0, 1.0 - exp(-4.0 * delta))
	queue_redraw()


func _van_scale() -> float:
	return clampf(size.y / 330.0, 0.55, 1.5)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 40.0 or h < 40.0:
		return
	var ppm: float = w / 36.0
	var horizon: float = h * 0.56
	var road_top: float = h * 0.68
	var ground_y: float = road_top + (h - road_top) * 0.60

	# Céu: faixas do azul-noturno ao laranja do horizonte.
	var strips: int = 12
	for i in strips:
		var t: float = float(i) / float(strips - 1)
		var color: Color = Color(0.045, 0.060, 0.085).lerp(Color(0.30, 0.16, 0.08), t * t * t)
		draw_rect(Rect2(0.0, horizon * float(i) / float(strips), w, horizon / float(strips) + 1.0), color)

	# Colinas em duas camadas, com paralaxe.
	_draw_hills(horizon, 0.05 * ppm, 34.0, 150.0, Color(0.075, 0.085, 0.10), 0.0)
	_draw_hills(horizon + 6.0, 0.18 * ppm, 22.0, 90.0, Color(0.060, 0.068, 0.080), 40.0)

	# Chão e estrada.
	draw_rect(Rect2(0.0, horizon + 6.0, w, road_top - horizon), Color(0.055, 0.062, 0.070))
	var road_color: Color = Color(0.125, 0.133, 0.145).lerp(Color(0.20, 0.14, 0.09), _mud_amount)
	draw_rect(Rect2(0.0, road_top, w, h - road_top), road_color)
	draw_rect(Rect2(0.0, road_top, w, 4.0), Style.AMBER)

	# Postes à beira da estrada (rolam um pouco mais devagar que a pista).
	var pole_period: float = 14.0 * ppm * 0.8
	var pole_offset: float = fposmod(_dist * ppm * 0.8, pole_period)
	var px: float = -pole_offset
	while px < w + pole_period:
		draw_rect(Rect2(px, road_top - 54.0, 5.0, 54.0), Color(0.20, 0.22, 0.25))
		draw_rect(Rect2(px - 6.0, road_top - 58.0, 17.0, 6.0), Style.YELLOW)
		px += pole_period

	# Tracejado central.
	var dash_period: float = 6.0 * ppm
	var dash_offset: float = fposmod(_dist * ppm, dash_period)
	var dx: float = -dash_offset
	var dash_y: float = road_top + (h - road_top) * 0.82
	while dx < w:
		draw_rect(Rect2(dx, dash_y, 3.0 * ppm, 5.0), Color(0.80, 0.80, 0.75, 0.65))
		dx += dash_period

	# Linhas de velocidade.
	var fast: float = clampf((speed / max_speed - 0.35) / 0.65, 0.0, 1.0)
	if fast > 0.02:
		for i in 9:
			var ly: float = h * (0.12 + 0.07 * float((i * 5) % 9)) + float(i % 3) * 5.0
			var span: float = w + 260.0
			var lx: float = fposmod(float(i) * 197.0 - _dist * ppm * 1.7, span) - 130.0
			var line_len: float = 60.0 + 120.0 * fast
			draw_line(Vector2(lx, ly), Vector2(lx + line_len, ly), Color(1.0, 0.95, 0.85, 0.10 + 0.22 * fast), 2.0)

	if not has_vehicle:
		var font: Font = get_theme_default_font()
		if font != null:
			var text: String = "SEM VEÍCULO"
			var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
			draw_string(font, Vector2((w - tw) * 0.5, h * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Style.ORANGE)
		return
	_draw_van(Vector2(w * 0.34, ground_y))


func _draw_hills(base_y: float, scroll: float, amplitude: float, wavelength: float, color: Color, phase: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var step_px: float = 24.0
	var x: float = 0.0
	var offset: float = _dist * scroll + phase
	while x <= size.x + step_px:
		var y: float = base_y - amplitude * (0.55 + 0.30 * sin((x + offset) / wavelength) + 0.15 * sin((x + offset) / (wavelength * 0.37)))
		points.append(Vector2(x, y))
		x += step_px
	points.append(Vector2(size.x + step_px, base_y + 8.0))
	points.append(Vector2(0.0, base_y + 8.0))
	draw_colored_polygon(points, color)


func _draw_van(ground: Vector2) -> void:
	var sc: float = _van_scale()
	var jolt: float = 0.0
	if rough:
		jolt = sin(_time * 38.0) * 2.6 + sin(_time * 23.0) * 1.6
	var lift: float = _air_lift * 46.0 * (0.8 + 0.2 * sin(_time * 5.0))
	var origin: Vector2 = Vector2(ground.x, ground.y - lift + jolt * sc)

	# Sombra no chão (some quando a van está no ar).
	draw_set_transform(Vector2(ground.x, ground.y + 2.0), 0.0, Vector2(sc, sc))
	draw_rect(Rect2(-130.0, -3.0, 262.0, 7.0), Color(0.0, 0.0, 0.0, 0.40 * (1.0 - _air_lift * 0.7)))

	draw_set_transform(origin, _tilt, Vector2(sc, sc))
	# Fumaça do escapamento ao acelerar.
	if throttle > 0.1:
		for k in 3:
			var life: float = fposmod(_time * 1.6 + float(k) / 3.0, 1.0)
			draw_circle(Vector2(-130.0 - life * 46.0, -30.0 - life * 8.0), 4.0 + life * 7.0,
				Color(0.75, 0.75, 0.78, 0.30 * (1.0 - life)))
	# Lama nas rodas traseiras.
	if _mud_amount > 0.2 and speed > 1.0:
		for k in 5:
			var life: float = fposmod(_time * 3.1 + float(k) * 0.21, 1.0)
			draw_circle(Vector2(-84.0 - life * 34.0, -20.0 - sin(life * PI) * 30.0), 3.0,
				Color(0.34, 0.22, 0.12, 0.8 * (1.0 - life)))

	# Carroceria: caixa traseira alta, cabine e capô inclinado.
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(-120.0, -26.0), Vector2(-120.0, -110.0), Vector2(22.0, -110.0), Vector2(30.0, -96.0),
		Vector2(66.0, -96.0), Vector2(98.0, -62.0), Vector2(122.0, -58.0), Vector2(124.0, -26.0),
	])
	draw_colored_polygon(body, Style.AMBER)
	draw_rect(Rect2(-120.0, -64.0, 244.0, 7.0), Color(0.10, 0.11, 0.12, 0.85))
	var window: PackedVector2Array = PackedVector2Array([
		Vector2(36.0, -91.0), Vector2(64.0, -91.0), Vector2(90.0, -64.0), Vector2(36.0, -64.0),
	])
	draw_colored_polygon(window, Color(0.18, 0.34, 0.42))
	draw_rect(Rect2(-128.0, -34.0, 258.0, 8.0), Color(0.10, 0.11, 0.12))
	draw_rect(Rect2(114.0, -52.0, 10.0, 8.0), Style.YELLOW)
	draw_rect(Rect2(-122.0, -50.0, 6.0, 10.0), Style.RED)
	# Baú de bagagem no teto (identidade "4x4").
	draw_rect(Rect2(-96.0, -118.0, 96.0, 8.0), Color(0.16, 0.17, 0.19))

	# Rodas (giram com a velocidade).
	for cx in [-72.0, 78.0]:
		var c: Vector2 = Vector2(cx, -WHEEL_RADIUS + 1.0)
		draw_circle(c, WHEEL_RADIUS, Color(0.04, 0.045, 0.05))
		draw_circle(c, WHEEL_RADIUS * 0.58, Color(0.55, 0.56, 0.58))
		for k in 5:
			var a: float = _wheel + float(k) * TAU / 5.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * WHEEL_RADIUS * 0.55, Color(0.22, 0.23, 0.25), 3.0)
		draw_circle(c, 4.0, Color(0.22, 0.23, 0.25))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
