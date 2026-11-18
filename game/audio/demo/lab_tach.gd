extends Control
## Conta-giros do laboratório: arco segmentado com a rotação virtual, marcha atual
## em destaque no centro e a transição "1ª → 2ª" por um instante a cada troca.
## Só desenha valores recebidos; não lê o áudio nem o veículo.

const Style = preload("res://audio/demo/lab_style.gd")

const ARC_START: float = 2.35619449
const ARC_SWEEP: float = 4.71238898
const SEGMENTS: int = 44
const RPM_FULL_SCALE: float = 1.1

var rpm: float = 0.0
var gear_text: String = "N"
var shifting: bool = false
## Transição mostrada na troca (marchas de origem e destino; 0 = nada).
var flash_from: int = 0
var flash_to: int = 0
## 1 logo após a troca, caindo a 0.
var flash_amount: float = 0.0
var flash_up: bool = true


func set_values(new_rpm: float, new_gear_text: String, new_shifting: bool) -> void:
	rpm = new_rpm
	gear_text = new_gear_text
	shifting = new_shifting
	queue_redraw()


func set_flash(from_gear: int, to_gear: int, amount: float, upshift: bool) -> void:
	flash_from = from_gear
	flash_to = to_gear
	flash_amount = amount
	flash_up = upshift
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.47)
	var radius: float = minf(size.x * 0.5, size.y * 0.46) - 12.0
	if radius < 20.0:
		return
	var thick: float = maxf(radius * 0.14, 8.0)
	var level: float = clampf(rpm / RPM_FULL_SCALE, 0.0, 1.0)
	for i in SEGMENTS:
		var frac: float = (float(i) + 0.5) / float(SEGMENTS)
		var angle: float = ARC_START + ARC_SWEEP * frac
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var color: Color = Style.UNLIT
		if frac <= level:
			if frac < 0.55:
				color = Style.YELLOW
			elif frac < 0.78:
				color = Style.ORANGE
			else:
				color = Style.RED
		draw_line(center + dir * (radius - thick), center + dir * radius, color, 5.0, true)

	# Anel que pulsa a cada troca, na cor do sentido (laranja sobe, ciano reduz).
	var accent: Color = Style.ORANGE if flash_up else Style.CYAN
	if flash_amount > 0.01:
		var ring: Color = Color(accent.r, accent.g, accent.b, flash_amount * 0.8)
		draw_arc(center, radius * 0.66 + (1.0 - flash_amount) * radius * 0.12, 0.0, TAU, 64, ring, 4.0, true)
	elif shifting:
		draw_arc(center, radius * 0.66, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.35), 3.0, true)

	# Rótulo e marcha.
	var label_size: int = maxi(int(radius * 0.17), 14)
	var label_text: String = "MARCHA"
	var label_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
	draw_string(font, Vector2(center.x - label_width * 0.5, center.y - radius * 0.62), label_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Style.DIM)

	var gear_size: int = int(radius * (1.05 + 0.22 * flash_amount))
	var gear_color: Color = Style.CREAM.lerp(accent, clampf(flash_amount, 0.0, 1.0) * 0.85)
	var gear_width: float = font.get_string_size(gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1, gear_size).x
	draw_string(font, Vector2(center.x - gear_width * 0.5, center.y + gear_size * 0.30), gear_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, gear_size, gear_color)

	# Transição "1ª → 2ª": a seta é desenhada (a fonte do jogo não tem setas).
	if flash_amount > 0.02 and flash_from > 0 and flash_to > 0:
		var tsize: int = maxi(int(radius * 0.24), 16)
		var left: String = "%dª" % flash_from
		var right: String = "%dª" % flash_to
		var lw: float = font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x
		var rw: float = font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x
		var arrow: float = tsize * 0.9
		var gap: float = tsize * 0.25
		var total: float = lw + gap + arrow + gap + rw
		var x: float = center.x - total * 0.5
		var base_y: float = center.y + radius * 0.70
		var col: Color = Color(accent.r, accent.g, accent.b, clampf(flash_amount * 1.6, 0.0, 1.0))
		draw_string(font, Vector2(x, base_y), left, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize, col)
		var ax: float = x + lw + gap
		var ay: float = base_y - tsize * 0.30
		draw_line(Vector2(ax, ay), Vector2(ax + arrow, ay), col, 3.0, true)
		draw_line(Vector2(ax + arrow, ay), Vector2(ax + arrow - tsize * 0.28, ay - tsize * 0.22), col, 3.0, true)
		draw_line(Vector2(ax + arrow, ay), Vector2(ax + arrow - tsize * 0.28, ay + tsize * 0.22), col, 3.0, true)
		draw_string(font, Vector2(ax + arrow + gap, base_y), right, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize, col)

	# Percentual de rotação no vão inferior do arco.
	var pct_size: int = maxi(int(radius * 0.17), 14)
	var pct_text: String = "ROTAÇÃO %d%%" % int(round(clampf(rpm, 0.0, RPM_FULL_SCALE) * 100.0))
	var pct_width: float = font.get_string_size(pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pct_size).x
	draw_string(font, Vector2(center.x - pct_width * 0.5, center.y + radius * 0.98), pct_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pct_size, Style.MUTED)
