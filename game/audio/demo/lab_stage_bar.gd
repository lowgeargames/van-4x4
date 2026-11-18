extends Control
## Progresso do teste automático em nove segmentos, um por etapa: etapas concluídas
## cheias, a atual preenchida conforme o andamento, as demais vazias.

const Style = preload("res://audio/demo/lab_style.gd")

const GAP: float = 6.0

var stage_count: int = 9
## Etapa atual de 1 a stage_count (0 = nenhum teste em andamento).
var stage: int = 0
var fraction: float = 0.0
var finished: bool = false


func set_progress(new_stage: int, new_fraction: float, new_finished: bool) -> void:
	if new_stage == stage and is_equal_approx(new_fraction, fraction) and new_finished == finished:
		return
	stage = new_stage
	fraction = new_fraction
	finished = new_finished
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var seg_w: float = (size.x - GAP * float(stage_count - 1)) / float(stage_count)
	if seg_w < 4.0:
		return
	for i in stage_count:
		var rect: Rect2 = Rect2(float(i) * (seg_w + GAP), 0.0, seg_w, size.y)
		draw_rect(rect, Style.UNLIT)
		var fill: float = 0.0
		var color: Color = Style.YELLOW
		if finished or i + 1 < stage:
			fill = 1.0
		elif i + 1 == stage:
			fill = clampf(fraction, 0.0, 1.0)
			color = Style.ORANGE
		if fill > 0.0:
			draw_rect(Rect2(rect.position, Vector2(seg_w * fill, size.y)), color)
		draw_rect(rect, Style.BORDER, false, 1.0)
		if font != null:
			var text: String = str(i + 1)
			var fs: int = maxi(int(size.y * 0.62), 12)
			var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var text_color: Color = Style.INK if fill > 0.55 else Style.MUTED
			draw_string(font, Vector2(rect.position.x + (seg_w - tw) * 0.5, size.y * 0.5 + fs * 0.35), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
