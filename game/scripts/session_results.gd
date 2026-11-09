extends CanvasLayer
## Recebe um retrato final da sessão; Tweens alteram somente a apresentação.
signal restart_requested

const IVORY := Color("fff3d6")
const YELLOW := Color("ffc83d")
const MINT := Color("65d6be")
const MUTED := Color("a9b6b7")
const FIXED_PAYMENT: int = 500
const POINTS_PER_CREDIT: float = 20.0

var _results: Dictionary = {}
var _payment: Dictionary = {}
var _entries: Dictionary = {}
var _animation: Tween
var _revealed: bool = false

@onready var _shade: ColorRect = $Screen/Shade
@onready var _sheet: PanelContainer = $Screen/Center/Sheet
@onready var _title: Label = $Screen/Center/Sheet/Margin/Content/Header/Title
@onready var _subtitle: Label = $Screen/Center/Sheet/Margin/Content/Header/Subtitle
@onready var _summary: HBoxContainer = $Screen/Center/Sheet/Margin/Content/Summary
@onready var _feats: VBoxContainer = $Screen/Center/Sheet/Margin/Content/Body/Stats/Feats
@onready var _impacts: VBoxContainer = $Screen/Center/Sheet/Margin/Content/Body/Stats/Impacts
@onready var _scores: VBoxContainer = $Screen/Center/Sheet/Margin/Content/Body/Rewards/Scores
@onready var _pay: VBoxContainer = $Screen/Center/Sheet/Margin/Content/Body/Rewards/Payment
@onready var _skip: Button = $Screen/Center/Sheet/Margin/Content/Buttons/ShowAll
@onready var _restart: Button = $Screen/Center/Sheet/Margin/Content/Buttons/Restart


func _ready() -> void:
	# Os controles são preparados na abertura da cena, não a cada frame/revelação.
	_metric(_summary, "elapsed_time", "TEMPO TOTAL", "s", 0.30, 52)
	_metric(_summary, "distance", "DISTÂNCIA PERCORRIDA", "m", 0.42, 52)
	var records := _row(_feats)
	_metric(records, "jumps", "SALTOS VÁLIDOS", "", 0.62)
	_metric(records, "longest_jump", "MAIOR SALTO", "m", 0.74)
	var spins := _row(_feats)
	_metric(spins, "pitch_rotations", "GIROS FRONTAIS", "", 1.15, 32)
	_metric(spins, "roll_rotations", "GIROS LATERAIS", "", 1.27, 32)
	var landings := _row(_feats)
	_metric(landings, "clean_landings", "POUSOS LIMPOS", "", 1.56, 32)
	_metric(landings, "brutal_landings", "POUSOS BRUTAIS", "", 1.68, 32)
	_metric(landings, "rollovers", "CAPOTAMENTOS NO POUSO", "", 1.80, 32)
	var objects := _row(_impacts)
	_metric(objects, "trees_broken", "ÁRVORES DERRUBADAS", "", 2.02)
	_metric(objects, "crates_hit", "CAIXAS ATINGIDAS", "", 2.14)
	_metric(objects, "barrels_hit", "BARRIS ATINGIDOS", "", 2.26)
	_metric(objects, "cones_hit", "CONES ATINGIDOS", "", 2.38)
	_line(_scores, "points", "Façanhas", "PTS", 2.70)
	_line(_scores, "tree_points", "Árvores", "PTS", 2.88)
	_line(_scores, "prop_points", "Props", "PTS", 3.06)
	_metric(_scores, "total_points", "TOTAL DE PONTOS", "PTS", 3.30, 68, YELLOW)
	_line(_pay, "fixed_payment", "Pagamento fixo", "CR", 4.00)
	_line(_pay, "performance_bonus", "Bônus por desempenho", "CR", 4.25)
	_metric(_pay, "payment_total", "TOTAL RECEBIDO", "CR", 4.55, 76, MINT)
	_skip.pressed.connect(show_all)
	_restart.pressed.connect(_request_restart)
	hide()


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	parent.add_child(row)
	return row


func _label(text: String, font_size: int, color: Color = IVORY) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _metric(parent: Control, key: String, caption: String, unit: String, delay: float, font_size: int = 42, color: Color = IVORY) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = 1.0
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	box.add_child(_label(caption, 20, MUTED))
	var number := _label("0", font_size, color)
	box.add_child(number)
	_entries[key] = {"control": box, "label": number, "unit": unit, "delay": delay, "font_size": font_size}


func _line(parent: Control, key: String, caption: String, unit: String, delay: float) -> void:
	var row := _row(parent)
	var title := _label(caption, 22, MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var number := _label("0", 26)
	row.add_child(number)
	_entries[key] = {"control": row, "label": number, "unit": unit, "delay": delay, "font_size": 26}


static func calculate_payment(total_points: int) -> Dictionary:
	# Demonstração local: não cria saldo, salvamento ou uma segunda pontuação.
	var bonus: int = floori(float(total_points) / POINTS_PER_CREDIT)
	return {"fixed_payment": FIXED_PAYMENT, "performance_bonus": bonus, "payment_total": FIXED_PAYMENT + bonus}


func present(final_results: Dictionary) -> void:
	_cancel_animation()
	_results = final_results.duplicate(true)
	_results.make_read_only()
	if _results.has("services_total"):
		_title.text = "SESSÃO CONCLUÍDA!"
		_subtitle.text = "SERVIÇOS CONCLUÍDOS · %d/%d" % [_results.services_completed, _results.services_total]
	else:
		_title.text = "SERVIÇO CONCLUÍDO!"
		_subtitle.text = "ANTENA REPARADA"
	_payment = calculate_payment(int(_results.get("total_points", 0)))
	_payment.make_read_only()
	_revealed = false
	_restart.disabled = false
	_skip.show()
	show()
	_shade.modulate.a = 0.0
	_sheet.modulate.a = 0.0
	_sheet.pivot_offset = _sheet.size * 0.5
	_sheet.scale = Vector2.ONE * 0.97
	_pay.modulate.a = 0.0
	_plan_presentation()
	for key in _entries:
		var entry: Dictionary = _entries[key]
		entry.control.modulate.a = 0.0
		entry.label.scale = Vector2.ONE
		# Reserva a largura final antes de animar; evita deslocar colunas/botões.
		entry.label.custom_minimum_size.x = 0.0
		_set_number(_final_value(key), key)
		var text: String = entry.label.text
		var font_size: int = entry.font_size
		if text.length() > 10:
			font_size = maxi(22, roundi(font_size * 10.0 / text.length()))
		entry.label.add_theme_font_size_override("font_size", font_size)
		entry.label.custom_minimum_size.x = entry.label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_set_number(0.0, key)
	_animation = create_tween().set_parallel(true)
	_animation.tween_property(_shade, "modulate:a", 1.0, 0.22)
	_animation.tween_property(_sheet, "modulate:a", 1.0, 0.24)
	_animation.tween_property(_sheet, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for key in _entries:
		var entry: Dictionary = _entries[key]
		if not entry.control.visible:
			continue
		var duration: float = 0.50 if key == "payment_total" else 0.32
		_animation.tween_property(entry.control, "modulate:a", 1.0, 0.16).set_delay(entry.delay)
		_animation.tween_method(_set_number.bind(key), 0.0, _final_value(key), duration).set_delay(entry.delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		if key in ["total_points", "payment_total"]:
			_animation.tween_property(entry.label, "scale", Vector2.ONE * 1.04, 0.08).set_delay(entry.delay + duration)
			_animation.tween_property(entry.label, "scale", Vector2.ONE, 0.16).set_delay(entry.delay + duration + 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_pay, "modulate:a", 1.0, 0.16).set_delay(_entries.fixed_payment.delay - 0.05)
	_animation.tween_callback(_complete_presentation).set_delay(_entries.payment_total.delay + 0.80)
	_skip.grab_focus()


func _plan_presentation() -> void:
	# Decide com dados finais; o zero inicial do Tween nunca controla visibilidade.
	var always: Array[String] = ["elapsed_time", "distance", "total_points", "fixed_payment", "payment_total"]
	var order: Array[String] = []
	for key in _entries:
		var applicable: bool = key in always or _final_value(key) > 0.0
		if key in ["jumps", "longest_jump"]:
			applicable = int(_results.get("jumps", 0)) > 0
		_entries[key].control.visible = applicable
		if applicable and not _payment.has(key):
			order.append(key)
	# Remove também as fileiras e títulos vazios, sem reservar buracos.
	for group in [_feats, _impacts]:
		var populated: bool = false
		for row in group.get_children():
			var used: bool = false
			for key in _entries:
				var control: Control = _entries[key].control
				if control == row or control.get_parent() == row:
					used = used or control.visible
			row.visible = used
			populated = populated or used
		group.visible = populated
	var stats: Control = _feats.get_parent()
	stats.get_node("FeatsTitle").visible = _feats.visible
	stats.get_node("ImpactsTitle").visible = _impacts.visible
	stats.visible = _feats.visible or _impacts.visible
	_sheet.custom_minimum_size.x = 1320.0 if stats.visible else 900.0
	var step: float = minf(0.22, 2.5 / maxf(1.0, order.size() - 1.0))
	for i in order.size():
		_entries[order[i]].delay = 0.30 + i * step
	var payment_start: float = maxf(2.60, _entries.total_points.delay + 0.60)
	var offset: float = 0.0
	for key in ["fixed_payment", "performance_bonus", "payment_total"]:
		_entries[key].delay = payment_start + offset
		if _entries[key].control.visible:
			offset += 0.22


func _final_value(key: String) -> float:
	return float(_payment.get(key, 0)) if _payment.has(key) else float(_results.get(key, 0))


func _set_number(value: float, key: String) -> void:
	var entry: Dictionary = _entries[key]
	var text: String
	if entry.unit in ["s", "m"]:
		text = ("%.1f" % value).replace(".", ",")
	else:
		text = str(roundi(value))
		var index: int = text.length() - 3
		while index > 0:
			text = text.insert(index, ".")
			index -= 3
	entry.label.text = text + (" " + entry.unit if not entry.unit.is_empty() else "")


func _complete_presentation() -> void:
	_revealed = true
	_skip.hide()
	_restart.grab_focus()


func show_all() -> void:
	_cancel_animation()
	_shade.modulate.a = 1.0
	_sheet.modulate.a = 1.0
	_sheet.scale = Vector2.ONE
	_pay.modulate.a = 1.0
	for key in _entries:
		_entries[key].control.modulate.a = 1.0
		_entries[key].label.scale = Vector2.ONE
		_set_number(_final_value(key), key)
	_complete_presentation()


func dismiss() -> void:
	_cancel_animation()
	hide()


func _cancel_animation() -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	_animation = null


func _request_restart() -> void:
	_restart.disabled = true
	dismiss()
	restart_requested.emit()


func _exit_tree() -> void:
	_cancel_animation()
