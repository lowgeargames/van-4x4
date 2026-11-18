extends CanvasLayer
## Interface do laboratório de áudio (Oficina Arcade). É só apresentação: lê o
## dicionário que o controlador (engine_audio_demo.gd) entrega a cada quadro e chama
## as funções `action_*` dele. Nenhum estado da demonstração mora aqui, a não ser o
## que é puramente visual (painel técnico aberto, aba escolhida).
## Desenhada para 1920x1080; o projeto usa stretch canvas_items, então 1280x720 só
## reduz a escala. Apenas nós de UI nativos da Godot; botões sem foco de teclado, para
## que Espaço (voo) e as demais teclas nunca "cliquem" um botão por engano.

const Style = preload("res://audio/demo/lab_style.gd")
const Tach = preload("res://audio/demo/lab_tach.gd")
const RoadView = preload("res://audio/demo/lab_road_view.gd")
const StageBar = preload("res://audio/demo/lab_stage_bar.gd")

const TEXT_REFRESH: float = 0.1
const TAB_NAMES: Array[String] = ["DIAGNÓSTICO", "ATALHOS", "EFEITOS"]
const SHORTCUTS: Array = [
	["T", "teste automático liga/desliga"], ["ENTER", "(re)inicia o teste"], ["R", "para e zera a van"],
	["Q · E · F", "teste A · B · C"], ["F3", "painel técnico"], ["P", "acelerador 50%"],
	["7 · 8", "transmissão ligada · desligada"], ["9 · 0", "perfil rápido · calibrado"], ["N", "piso irregular"],
	["1 · 2", "versão A · alternativa B"], ["5 · 6", "referência · efeito curto"], ["M", "lama (segurar)"],
	["W · S", "acelerar · frear/ré"], ["B", "freio suave"], ["ESPAÇO", "voo (segurar)"],
	["3 · 4", "trava · solta a velocidade"], ["V", "vincula/solta o áudio"], ["SHIFT", "turbo (só estado)"],
	["X", "remove/restaura a van"], ["C", "motor liga/desliga"], ["+ · −", "volume"],
]
const CREDITS_LINE: String = (
	"Gravações: Mustang 1985 (lmbubec, CC0) · Ford V8 5.0 (noiseloop, CC BY 3.0) · "
	+ "Mustang 1969 (FlaxGod, CC0) · detalhes e atribuição em game/audio/CREDITS.md"
)

# O controlador não é tipado aqui (evita referência circular entre os scripts).
var _demo = null
var _view: Dictionary = {}
var _text_timer: float = 0.0

var _root: Control = null
var _road: RoadView = null
var _tach: Tach = null
var _stage_bar: StageBar = null
var _drawer: Control = null
var _drawer_open: bool = false
var _tab: int = 0

var _notice_label: Label = null
var _speed_label: Label = null
var _speed_caption: Label = null
var _speed_bar: ProgressBar = null
var _throttle_bar: ProgressBar = null
var _brake_bar: ProgressBar = null
var _v_profile: Label = null
var _v_tx: Label = null
var _v_tx_state: Label = null
var _v_mode: Label = null
var _stage_title: Label = null
var _stage_hint: Label = null
var _test_info: Label = null
var _test_cond: Label = null
var _profile_caption: Label = null
var _tx_caption: Label = null
var _volume_label: Label = null
var _volume: HSlider = null
var _volume_drag: bool = false

var _btn_test: Button = null
var _btn_diag: Button = null
var _btn_profile: Array[Button] = []
var _btn_tx: Array[Button] = []
var _btn_gas: Button = null
var _btn_brake: Button = null
var _btn_auto: Button = null
var _btn_presets: Dictionary = {}
var _btn_modes: Array[Button] = []
var _btn_partial: Button = null
var _btn_rough: Button = null
var _btn_mud: Button = null
var _btn_air: Button = null
var _btn_lock: Button = null
var _btn_engine: Button = null
var _btn_bind: Button = null
var _btn_vehicle: Button = null
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _diag_grid: GridContainer = null
var _diag_values: Array[Label] = []
var _sfx_box: VBoxContainer = null
var _sfx_built: bool = false
var _gfx_box: GridContainer = null
var _sfx_slider: HSlider = null
var _sfx_int_label: Label = null
var _sfx_status: Label = null
var _btn_sfx_repeat: Button = null
var _btn_sfx_mute: Button = null


func setup(demo) -> void:
	_demo = demo
	layer = 5
	_build()


func toggle_diagnostics() -> void:
	set_diagnostics(not _drawer_open)


func set_diagnostics(open: bool) -> void:
	_drawer_open = open
	if _drawer != null:
		_drawer.visible = open
	if _road != null:
		_road.visible = not open
	if open:
		_text_timer = 0.0
		if _tab == 2 and not _sfx_built:
			_rebuild_sfx()


# ------------------------------------------------------------------ construção
func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = Style.make_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg: ColorRect = ColorRect.new()
	bg.color = Style.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_root.add_child(margin)

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	margin.add_child(main)
	main.add_child(_build_topbar())

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	main.add_child(body)
	body.add_child(_build_left())
	body.add_child(_build_right())


func _label(text: String, size: int = 22, color: Color = Style.CREAM,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Rótulo que nunca alarga o layout: texto longo é cortado em vez de empurrar os vizinhos.
func _clipped(text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = _label(text, size, color, align)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(text: String, tip: String = "", toggle: bool = true, variation: StringName = &"", height: int = 52) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = toggle
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = tip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = true
	if variation != &"":
		button.theme_type_variation = variation
	return button


## Botão que chama `method` do controlador ao ser clicado.
func _action_button(text: String, method: StringName, args: Array = [], tip: String = "",
		toggle: bool = true, variation: StringName = &"", height: int = 52) -> Button:
	var button: Button = _button(text, tip, toggle, variation, height)
	var callback: Callable = Callable(_demo, method)
	if args.size() > 0:
		callback = callback.bindv(args)
	button.pressed.connect(callback)
	return button


func _hbox(parent: Control, separation: int = 10) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box


func _section(parent: Control, title: String) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label(title, 21, Style.AMBER))
	parent.add_child(box)
	return box


func _card(padding_x: int = 16, padding_y: int = 12) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.BORDER, 12, 2, padding_x, padding_y))
	return card


func _bar(variation: StringName, height: int = 16) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.theme_type_variation = variation
	return bar


func _build_topbar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 60)
	bar.add_theme_constant_override("separation", 14)

	var stripe: ColorRect = ColorRect.new()
	stripe.color = Style.ORANGE
	stripe.custom_minimum_size = Vector2(10, 0)
	bar.add_child(stripe)

	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(_label("LABORATÓRIO DE ÁUDIO", 36, Style.CREAM))
	titles.add_child(_label("VAN 4X4 · MOTOR V8 · TRANSMISSÃO VIRTUAL", 18, Style.MUTED))
	bar.add_child(titles)

	_notice_label = _clipped("", 22, Style.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_notice_label)

	_btn_diag = _button("DIAGNÓSTICO TÉCNICO · F3", "Mostra ou esconde os dados técnicos", true, Style.TYPE_GHOST, 48)
	_btn_diag.size_flags_horizontal = Control.SIZE_SHRINK_END
	_btn_diag.custom_minimum_size = Vector2(300, 48)
	_btn_diag.pressed.connect(toggle_diagnostics)
	bar.add_child(_btn_diag)
	return bar


# --------------------------------------------------------------- coluna esquerda
func _build_left() -> Control:
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	left.add_child(_build_slot())
	left.add_child(_build_instruments())
	left.add_child(_build_test_panel())
	return left


## Quadro superior: a vista da estrada; com o painel técnico aberto, ele ocupa o lugar dela.
func _build_slot() -> Control:
	var slot: PanelContainer = PanelContainer.new()
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size = Vector2(0, 240)
	slot.clip_contents = true
	slot.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.BORDER, 12, 2, 2, 2))
	_road = RoadView.new()
	_road.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_road.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_road)
	_drawer = _build_drawer()
	_drawer.visible = false
	slot.add_child(_drawer)
	return slot


func _build_instruments() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 300)
	row.add_theme_constant_override("separation", 14)

	# Velocidade.
	var speed_card: PanelContainer = _card()
	speed_card.custom_minimum_size = Vector2(330, 0)
	var speed_col: VBoxContainer = VBoxContainer.new()
	speed_col.add_theme_constant_override("separation", 2)
	speed_card.add_child(speed_col)
	speed_col.add_child(_label("VELOCIDADE", 20, Style.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_speed_label = _label("0", 128, Style.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	speed_col.add_child(_speed_label)
	speed_col.add_child(_label("km/h", 28, Style.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_speed_bar = _bar(Style.TYPE_SPEED_BAR, 14)
	speed_col.add_child(_speed_bar)
	_speed_caption = _clipped("", 20, Style.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	speed_col.add_child(_speed_caption)
	row.add_child(speed_card)

	# Conta-giros com a marcha.
	var tach_card: PanelContainer = _card(6, 6)
	tach_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tach = Tach.new()
	_tach.custom_minimum_size = Vector2(300, 0)
	_tach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tach.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tach_card.add_child(_tach)
	row.add_child(tach_card)

	# Acelerador, freio e estados.
	var status_card: PanelContainer = _card()
	status_card.custom_minimum_size = Vector2(380, 0)
	var status_col: VBoxContainer = VBoxContainer.new()
	status_col.add_theme_constant_override("separation", 6)
	status_card.add_child(status_col)
	status_col.add_child(_label("ACELERADOR", 20, Style.DIM))
	_throttle_bar = _bar(Style.TYPE_THROTTLE_BAR, 20)
	status_col.add_child(_throttle_bar)
	status_col.add_child(_label("FREIO", 20, Style.DIM))
	_brake_bar = _bar(Style.TYPE_BRAKE_BAR, 20)
	status_col.add_child(_brake_bar)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	status_col.add_child(spacer)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_col.add_child(grid)
	grid.add_child(_label("PERFIL", 20, Style.DIM))
	_v_profile = _clipped("", 24, Style.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	grid.add_child(_v_profile)
	grid.add_child(_label("TRANSMISSÃO", 20, Style.DIM))
	_v_tx = _clipped("", 24, Style.TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	grid.add_child(_v_tx)
	grid.add_child(_label("ESTADO", 20, Style.DIM))
	_v_tx_state = _clipped("", 24, Style.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	grid.add_child(_v_tx_state)
	grid.add_child(_label("SOM", 20, Style.DIM))
	_v_mode = _clipped("", 24, Style.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	grid.add_child(_v_mode)
	row.add_child(status_card)
	return row


func _build_test_panel() -> Control:
	var card: PanelContainer = _card()
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	var top: HBoxContainer = _hbox(col, 18)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(460, 0)
	left.add_theme_constant_override("separation", 8)
	top.add_child(left)
	_btn_test = _action_button("TESTAR ACELERAÇÃO", &"action_start_test", [],
		"Roda a sequência de 9 etapas (Enter). Clique de novo para reiniciar na hora.", false, Style.TYPE_PRIMARY, 92)
	left.add_child(_btn_test)
	left.add_child(_action_button("PARAR E ZERAR  ·  R", &"action_stop_test", [],
		"Interrompe o teste e deixa a van parada em marcha lenta", false, Style.TYPE_STOP, 40))

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	top.add_child(info)
	_stage_title = _clipped("PRONTO PARA TESTAR", 34, Style.YELLOW)
	info.add_child(_stage_title)
	_stage_hint = _clipped("", 22, Style.MUTED)
	info.add_child(_stage_hint)
	_stage_bar = StageBar.new()
	_stage_bar.custom_minimum_size = Vector2(0, 34)
	_stage_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_stage_bar)
	_test_info = _clipped("", 21, Style.CREAM)
	info.add_child(_test_info)
	_test_cond = _clipped("", 20, Style.MUTED)
	info.add_child(_test_cond)

	var presets: HBoxContainer = _hbox(col, 10)
	var presets_label: Label = _label("COMPARAR TESTES", 20, Style.AMBER)
	presets_label.custom_minimum_size = Vector2(150, 0)
	presets_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	presets.add_child(presets_label)
	var preset_texts: Dictionary = {
		"A": "A · CALIBRADO + TRANSMISSÃO",
		"B": "B · CALIBRADO SEM TRANSMISSÃO",
		"C": "C · RÁPIDO + TRANSMISSÃO",
	}
	var preset_keys: Dictionary = {"A": "Q", "B": "E", "C": "F"}
	for id in ["A", "B", "C"]:
		var button: Button = _action_button(str(preset_texts[id]), &"action_preset", [id],
			"Aplica a configuração e roda o teste do início (tecla %s). Muda só uma variável por vez." % preset_keys[id],
			true, &"", 50)
		presets.add_child(button)
		_btn_presets[id] = button
	return card


# ---------------------------------------------------------------- coluna direita
func _build_right() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card: PanelContainer = _card(18, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(card)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)

	# Perfil.
	var profile_box: VBoxContainer = _section(col, "PERFIL DE ACELERAÇÃO")
	var profile_row: HBoxContainer = _hbox(profile_box)
	var fast: Button = _action_button("RÁPIDO", &"action_set_profile", [0], "Tecla 9")
	var calibrated: Button = _action_button("CALIBRADO", &"action_set_profile", [1], "Tecla 0")
	profile_row.add_child(fast)
	profile_row.add_child(calibrated)
	_btn_profile = [fast, calibrated]
	_profile_caption = _clipped("", 19, Style.MUTED)
	profile_box.add_child(_profile_caption)

	# Transmissão.
	var tx_box: VBoxContainer = _section(col, "TRANSMISSÃO")
	var tx_row: HBoxContainer = _hbox(tx_box)
	var tx_on: Button = _action_button("LIGADA", &"action_set_transmission", [true], "Tecla 7")
	var tx_off: Button = _action_button("DESLIGADA", &"action_set_transmission", [false], "Tecla 8")
	tx_row.add_child(tx_on)
	tx_row.add_child(tx_off)
	_btn_tx = [tx_on, tx_off]
	_tx_caption = _clipped("", 19, Style.MUTED)
	tx_box.add_child(_tx_caption)

	# Comportamento.
	var drive_box: VBoxContainer = _section(col, "COMPORTAMENTO")
	var drive_row: HBoxContainer = _hbox(drive_box)
	_btn_gas = _button("ACELERAR  ·  W", "Segure o botão do mouse para acelerar")
	_btn_gas.button_down.connect(Callable(_demo, "action_gas").bind(true))
	_btn_gas.button_up.connect(Callable(_demo, "action_gas").bind(false))
	_btn_gas.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_btn_brake = _button("FREAR  ·  B", "Segure o botão do mouse para frear")
	_btn_brake.button_down.connect(Callable(_demo, "action_brake").bind(true))
	_btn_brake.button_up.connect(Callable(_demo, "action_brake").bind(false))
	_btn_brake.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	drive_row.add_child(_btn_gas)
	drive_row.add_child(_btn_brake)
	var test_row: HBoxContainer = _hbox(drive_box)
	_btn_auto = _action_button("TESTE AUTOMÁTICO  ·  T", &"action_toggle_test", [], "Liga ou desliga o teste automático")
	test_row.add_child(_btn_auto)
	test_row.add_child(_action_button("PARAR E ZERAR  ·  R", &"action_stop_test", [],
		"Interrompe o teste e deixa a van parada em marcha lenta", false, &"", 52))

	# Comparação sonora.
	var sound_box: VBoxContainer = _section(col, "COMPARAÇÃO SONORA")
	var sound_grid: GridContainer = GridContainer.new()
	sound_grid.columns = 2
	sound_grid.add_theme_constant_override("h_separation", 10)
	sound_grid.add_theme_constant_override("v_separation", 10)
	sound_box.add_child(sound_grid)
	var keys: Array[String] = ["1", "2", "5", "6"]
	var index: int = 0
	for entry in _demo.sound_modes:
		var button: Button = _action_button("%s\n%s" % [entry[1], entry[2]], &"action_set_sound_mode", [int(entry[0])],
			"Tecla %s" % keys[index], true, &"", 66)
		sound_grid.add_child(button)
		_btn_modes.append(button)
		index += 1

	# Condições.
	var cond_box: VBoxContainer = _section(col, "CONDIÇÕES")
	var cond_row1: HBoxContainer = _hbox(cond_box)
	_btn_partial = _action_button("ACELERADOR 50%", &"action_toggle_partial", [], "Tecla P")
	_btn_rough = _action_button("PISO IRREGULAR", &"action_toggle_rough", [], "Tecla N")
	_btn_mud = _action_button("LAMA", &"action_toggle_mud", [], "Tecla M (segurar)")
	cond_row1.add_child(_btn_partial)
	cond_row1.add_child(_btn_rough)
	cond_row1.add_child(_btn_mud)
	var cond_row2: HBoxContainer = _hbox(cond_box)
	_btn_air = _action_button("VOO", &"action_toggle_air", [], "Espaço (segurar)")
	_btn_lock = _button("VELOCIDADE FIXA", "Teclas 3 e 4")
	_btn_lock.pressed.connect(_on_lock_pressed)
	cond_row2.add_child(_btn_air)
	cond_row2.add_child(_btn_lock)

	# Volume.
	var volume_box: VBoxContainer = _section(col, "VOLUME GERAL")
	var volume_row: HBoxContainer = _hbox(volume_box, 14)
	_volume = HSlider.new()
	_volume.min_value = -40.0
	_volume.max_value = 0.0
	_volume.step = 1.0
	_volume.value = -6.0
	_volume.focus_mode = Control.FOCUS_NONE
	_volume.custom_minimum_size = Vector2(0, 36)
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume.value_changed.connect(Callable(_demo, "action_set_volume_db"))
	_volume.drag_started.connect(_on_volume_drag_started)
	_volume.drag_ended.connect(_on_volume_drag_ended)
	volume_row.add_child(_volume)
	_volume_label = _label("-6 dB", 24, Style.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	_volume_label.custom_minimum_size = Vector2(90, 0)
	volume_row.add_child(_volume_label)
	return scroll


func _on_lock_pressed() -> void:
	_demo.action_lock_speed(not bool(_view.get("locked", false)))


func _on_volume_drag_started() -> void:
	_volume_drag = true


func _on_volume_drag_ended(_changed: bool) -> void:
	_volume_drag = false


# ----------------------------------------------------------------- painel técnico
func _build_drawer() -> Control:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)

	# Rolável por segurança: se o conteúdo passar da altura do quadro, rola em vez de
	# empurrar os painéis de baixo para fora da tela.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	var tabs: HBoxContainer = _hbox(col, 6)
	for i in TAB_NAMES.size():
		var button: Button = _button(TAB_NAMES[i], "", true, Style.TYPE_TAB, 42)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.pressed.connect(_on_tab_pressed.bind(i))
		tabs.add_child(button)
		_tab_buttons.append(button)
	var tab_spacer: Control = Control.new()
	tab_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(tab_spacer)
	var close: Button = _button("FECHAR  ·  F3", "", false, Style.TYPE_GHOST, 42)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(set_diagnostics.bind(false))
	tabs.add_child(close)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(stack)
	var diag_page: VBoxContainer = _build_diag_page()
	var keys_page: Control = _build_keys_page()
	var sfx_page: VBoxContainer = _build_sfx_page()
	_pages = [diag_page, keys_page, sfx_page]
	for page in _pages:
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.add_child(page)

	col.add_child(_clipped(CREDITS_LINE, 17, Style.DIM))
	_show_tab(0)
	return margin


func _on_tab_pressed(index: int) -> void:
	_show_tab(index)


func _show_tab(index: int) -> void:
	_tab = index
	for i in _pages.size():
		_pages[i].visible = i == index
	if index == 2 and _drawer_open and not _sfx_built:
		_rebuild_sfx()
	_text_timer = 0.0


func _build_diag_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	_diag_grid = GridContainer.new()
	_diag_grid.columns = 5
	_diag_grid.add_theme_constant_override("h_separation", 22)
	_diag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_diag_grid)
	for section in _demo.get_diag_sections():
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		box.add_child(_clipped(str(section["title"]), 19, Style.YELLOW))
		for row in section["rows"]:
			var line: HBoxContainer = HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			line.add_child(_clipped(str(row[0]), 17, Style.MUTED))
			var value: Label = _clipped("", 19, Style.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
			value.size_flags_horizontal = Control.SIZE_SHRINK_END
			value.custom_minimum_size = Vector2(88, 0)
			line.add_child(value)
			_diag_values.append(value)
			box.add_child(line)
		_diag_grid.add_child(box)

	var tools: HBoxContainer = _hbox(page, 10)
	_btn_engine = _action_button("MOTOR  ·  C", &"action_toggle_engine", [], "Liga ou desliga o som do motor", true, &"", 42)
	_btn_bind = _action_button("ÁUDIO VINCULADO  ·  V", &"action_toggle_bind", [], "Vincula ou solta o componente de áudio da van", true, &"", 42)
	_btn_vehicle = _action_button("VAN PRESENTE  ·  X", &"action_toggle_vehicle", [], "Remove ou restaura a van (testa a perda do veículo)", true, &"", 42)
	tools.add_child(_btn_engine)
	tools.add_child(_btn_bind)
	tools.add_child(_btn_vehicle)
	return page


func _build_keys_page() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in SHORTCUTS:
		var chip: Label = _label(str(entry[0]), 19, Style.INK, HORIZONTAL_ALIGNMENT_CENTER)
		chip.custom_minimum_size = Vector2(96, 28)
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_stylebox_override("normal", Style.box(Style.YELLOW, Style.YELLOW, 6, 0, 6, 1))
		grid.add_child(chip)
		var description: Label = _clipped(str(entry[1]), 19, Style.CREAM)
		grid.add_child(description)
	return grid


func _build_sfx_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	var head: HBoxContainer = _hbox(page, 12)
	head.add_child(_clipped(
		"Efeitos de gameplay: gravações em game/audio/sfx/gameplay/<pasta>/. Botão claro = ainda aguardando gravação aprovada.",
		19, Style.MUTED))
	var rescan: Button = _button("REESCANEAR", "", false, Style.TYPE_GHOST, 38)
	rescan.size_flags_horizontal = Control.SIZE_SHRINK_END
	rescan.pressed.connect(_rebuild_sfx)
	head.add_child(rescan)

	_gfx_box = GridContainer.new()
	_gfx_box.columns = 4
	_gfx_box.add_theme_constant_override("h_separation", 10)
	_gfx_box.add_theme_constant_override("v_separation", 8)
	_gfx_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_gfx_box)

	var controls: HBoxContainer = _hbox(page, 12)
	var int_title: Label = _label("INTENSIDADE", 19, Style.MUTED)
	int_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(int_title)
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.05
	_sfx_slider.value = 0.7
	_sfx_slider.focus_mode = Control.FOCUS_NONE
	_sfx_slider.custom_minimum_size = Vector2(220, 36)
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sfx_slider.value_changed.connect(Callable(_demo, "action_set_sfx_intensity"))
	controls.add_child(_sfx_slider)
	_sfx_int_label = _label("70%", 21, Style.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	_sfx_int_label.custom_minimum_size = Vector2(64, 0)
	_sfx_int_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(_sfx_int_label)
	_btn_sfx_repeat = _action_button("REPETIR", &"action_toggle_sfx_repeat", [],
		"Repete o último efeito a cada ~1,2 s, para avaliar cansaço", true, &"", 38)
	controls.add_child(_btn_sfx_repeat)
	controls.add_child(_action_button("RAJADA ×6", &"action_sfx_burst", [],
		"Seis disparos seguidos do último efeito (testa limite de vozes)", false, &"", 38))
	_btn_sfx_mute = _action_button("MOTOR MUDO", &"action_toggle_sfx_engine_mute", [],
		"Silencia o motor durante a pré-escuta; clique de novo para voltar", true, &"", 38)
	controls.add_child(_btn_sfx_mute)
	controls.add_child(_action_button("PARAR", &"action_stop_gameplay_sfx", [], "",
		false, Style.TYPE_STOP, 38))
	_sfx_status = _clipped("", 18, Style.DIM)
	page.add_child(_sfx_status)

	page.add_child(_clipped("PRÉ-ESCUTA LIVRE  (arquivos soltos em sfx/preview/<pasta>/)", 18, Style.AMBER))
	_sfx_box = VBoxContainer.new()
	_sfx_box.add_theme_constant_override("separation", 6)
	page.add_child(_sfx_box)
	return page


func _rebuild_sfx() -> void:
	_sfx_built = true
	_demo.rescan_sfx()
	for child in _gfx_box.get_children():
		_gfx_box.remove_child(child)
		child.queue_free()
	for entry in _demo.get_gameplay_events():
		var count: int = int(entry[2])
		var text: String = str(entry[1]) if count > 0 else "%s · aguardando" % str(entry[1])
		var tip: String = "Sem gravação aprovada ainda. Pasta: sfx/gameplay/%s/" % _demo.get_gameplay_folder(str(entry[0]))
		if count > 0:
			tip = "%d gravação(ões) · sfx/gameplay/%s/" % [count, _demo.get_gameplay_folder(str(entry[0]))]
		var variation: StringName = &"" if count > 0 else Style.TYPE_GHOST
		_gfx_box.add_child(_action_button(text, &"action_play_gameplay_sfx", [str(entry[0])],
			tip, false, variation, 44))
	for child in _sfx_box.get_children():
		_sfx_box.remove_child(child)
		child.queue_free()
	for category in _demo.get_sfx_categories():
		var folder: String = str(category[0])
		var row: HBoxContainer = _hbox(_sfx_box, 10)
		var name_label: Label = _label(str(category[1]), 21, Style.CREAM)
		name_label.custom_minimum_size = Vector2(240, 0)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		var files: Array = _demo.get_sfx_files(folder)
		if files.is_empty():
			row.add_child(_clipped("sem gravações · aguardando seleção  (%s)" % folder, 19, Style.DIM))
			continue
		var shown: int = 0
		for file_name in files:
			if shown >= 5:
				break
			var button: Button = _button(str(file_name), "Toca a gravação", false, &"", 38)
			button.pressed.connect(Callable(_demo, "play_sfx").bind(folder, str(file_name)))
			row.add_child(button)
			shown += 1
		var stop: Button = _button("PARAR", "", false, Style.TYPE_STOP, 38)
		stop.size_flags_horizontal = Control.SIZE_SHRINK_END
		stop.pressed.connect(Callable(_demo, "stop_sfx"))
		row.add_child(stop)


# ------------------------------------------------------------------- atualização
func _sync_toggle(button: Button, on: bool) -> void:
	if button != null and button.button_pressed != on:
		button.set_pressed_no_signal(on)


func _tint(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)


func update_view(view: Dictionary, delta: float) -> void:
	if _root == null:
		return
	_view = view
	var state: Dictionary = view["state"]

	# Elementos desenhados: a cada quadro.
	_tach.set_values(float(state["rpm"]), str(state["gear_label"]), bool(view["shifting"]))
	_tach.set_flash(int(view["flash_from"]), int(view["flash_to"]), float(view["flash_amount"]), bool(view["flash_up"]))
	if _road.visible:
		_road.set_values(float(view["speed_ms"]), float(view["top_ms"]), float(view["throttle"]),
			bool(view["rough"]), bool(view["mud"]), bool(view["air"]), bool(view["has_vehicle"]))
		_road.step(delta)
	var running: bool = bool(view["test_running"])
	_stage_bar.set_progress(int(view["stage"]), float(view["stage_fraction"]), bool(view["test_done"]))
	_speed_bar.value = clampf(float(view["speed_ms"]) / maxf(float(view["top_ms"]), 0.1), 0.0, 1.0)
	_throttle_bar.value = clampf(float(view["throttle"]), 0.0, 1.0)
	_brake_bar.value = clampf(-float(view["throttle"]), 0.0, 1.0)

	# Estado dos botões: a cada quadro, para mouse e teclado nunca divergirem.
	_sync_toggle(_btn_diag, _drawer_open)
	_sync_toggle(_btn_profile[0], int(view["profile"]) == 0)
	_sync_toggle(_btn_profile[1], int(view["profile"]) == 1)
	_sync_toggle(_btn_tx[0], bool(view["tx_on"]))
	_sync_toggle(_btn_tx[1], not bool(view["tx_on"]))
	_sync_toggle(_btn_gas, bool(view["gas_active"]))
	_sync_toggle(_btn_brake, bool(view["brake_active"]))
	_sync_toggle(_btn_auto, running)
	for id in _btn_presets:
		_sync_toggle(_btn_presets[id], str(view["preset"]) == str(id))
	for i in _btn_modes.size():
		_sync_toggle(_btn_modes[i], int(_demo.sound_modes[i][0]) == int(view["mode"]))
	_sync_toggle(_btn_partial, bool(view["partial"]))
	_sync_toggle(_btn_rough, bool(view["rough"]))
	_sync_toggle(_btn_mud, bool(view["mud"]))
	_sync_toggle(_btn_air, bool(view["air"]))
	_sync_toggle(_btn_lock, bool(view["locked"]))
	for i in _tab_buttons.size():
		_sync_toggle(_tab_buttons[i], i == _tab)
	_sync_toggle(_btn_engine, bool(view["engine_on"]))
	_sync_toggle(_btn_bind, bool(view["bound"]))
	_sync_toggle(_btn_vehicle, bool(view["has_vehicle"]))
	_sync_toggle(_btn_sfx_repeat, bool(view["sfx_repeat"]))
	_sync_toggle(_btn_sfx_mute, bool(view["sfx_muted"]))
	if _sfx_slider != null and not is_equal_approx(_sfx_slider.value, float(view["sfx_intensity"])):
		_sfx_slider.set_value_no_signal(float(view["sfx_intensity"]))
	if not _volume_drag and not is_equal_approx(_volume.value, float(view["volume_db"])):
		_volume.set_value_no_signal(float(view["volume_db"]))
	_notice_label.modulate.a = float(view["notice_alpha"])

	# Textos: 10 vezes por segundo bastam.
	_text_timer -= delta
	if _text_timer > 0.0:
		return
	_text_timer = TEXT_REFRESH
	_refresh_texts(view, state, running)


func _refresh_texts(view: Dictionary, state: Dictionary, running: bool) -> void:
	if _sfx_status != null:
		_sfx_status.text = str(view["sfx_status"])
		_sfx_int_label.text = "%d%%" % int(round(float(view["sfx_intensity"]) * 100.0))
	_speed_label.text = str(int(round(float(view["speed_kmh"]))))
	var caption: String = "alvo do perfil: %d km/h" % int(round(float(view["target_kmh"])))
	if bool(view["locked"]):
		caption = "velocidade TRAVADA"
	_speed_caption.text = caption

	_v_profile.text = str(view["profile_name"])
	var tx_on: bool = bool(view["tx_on"])
	_v_tx.text = "LIGADA" if tx_on else "DESLIGADA"
	_tint(_v_tx, Style.TEAL if tx_on else Style.ORANGE)
	_v_tx_state.text = str(view["tx_state"])
	_tint(_v_tx_state, Style.YELLOW if bool(view["shifting"]) else Style.CREAM)
	var mode_text: String = "—"
	for entry in _demo.sound_modes:
		if int(entry[0]) == int(view["mode"]):
			mode_text = str(entry[1])
	_v_mode.text = mode_text

	if running:
		_btn_test.text = "REINICIAR TESTE"
	elif bool(view["test_done"]):
		_btn_test.text = "TESTAR DE NOVO"
	else:
		_btn_test.text = "TESTAR ACELERAÇÃO"
	_stage_title.text = str(view["stage_name"])
	_stage_hint.text = str(view["stage_hint"])
	var info: String = ""
	if running or bool(view["test_done"]):
		info = "%s · %.1f s" % [view["test_label"], float(view["test_time"])]
	var marks: String = str(view["run_marks"])
	if marks != "":
		info = (info + "   |   " if info != "" else "") + marks
	_test_info.text = info
	_test_cond.text = "condições: " + str(view["conditions"])
	_tint(_test_cond, Style.ORANGE if bool(view["conditions_changed"]) else Style.MUTED)

	_profile_caption.text = str(view["profile_info"])
	_tx_caption.text = "3 marchas automáticas (subida e redução com histerese)" if tx_on else "desligada: comportamento da versão A anterior"
	_volume_label.text = "%d dB" % int(round(float(view["volume_db"])))
	_notice_label.text = str(view["notice"])

	if _drawer_open and _tab == 0:
		_refresh_diag()


func _refresh_diag() -> void:
	var sections: Array = _demo.get_diag_sections()
	var index: int = 0
	for section in sections:
		for row in section["rows"]:
			if index < _diag_values.size():
				_diag_values[index].text = str(row[1])
			index += 1
