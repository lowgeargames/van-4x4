extends RefCounted
## Paleta e tema do laboratório de áudio ("Oficina Arcade": fundo escuro, painéis
## discretos, destaques amarelo/laranja/ciano). Só apresentação: nenhum dado do jogo.
## A fonte é a mesma do HUD do jogo (Barlow Condensed Bold, OFL), só lida.

const BG: Color = Color(0.0510, 0.0588, 0.0667)
const PANEL: Color = Color(0.1020, 0.1137, 0.1255)
const PANEL_SOFT: Color = Color(0.1255, 0.1412, 0.1569)
const HOVER: Color = Color(0.1647, 0.1882, 0.2118)
const BORDER: Color = Color(0.1725, 0.1922, 0.2118)
const TEXT: Color = Color(0.9490, 0.9490, 0.9490)
const CREAM: Color = Color(1.0000, 0.9529, 0.8392)
const MUTED: Color = Color(0.7216, 0.7216, 0.7216)
const DIM: Color = Color(0.4863, 0.5137, 0.5412)
const YELLOW: Color = Color(0.9490, 0.7569, 0.3059)
const AMBER: Color = Color(0.8510, 0.6431, 0.2549)
const ORANGE: Color = Color(1.0000, 0.5412, 0.2392)
const CYAN: Color = Color(0.3098, 0.8196, 0.9098)
const TEAL: Color = Color(0.3961, 0.8392, 0.7451)
const RED: Color = Color(0.9373, 0.3255, 0.3137)
const GREEN: Color = Color(0.4353, 0.8157, 0.5490)
const INK: Color = Color(0.0627, 0.0706, 0.0784)
const UNLIT: Color = Color(0.1373, 0.1569, 0.1765)

const FONT_PATH: String = "res://assets/ui/fonts/BarlowCondensed-Bold.ttf"
const BASE_FONT_SIZE: int = 22

const TYPE_PRIMARY: StringName = &"PrimaryButton"
const TYPE_GHOST: StringName = &"GhostButton"
const TYPE_STOP: StringName = &"StopButton"
const TYPE_TAB: StringName = &"TabButton"
const TYPE_CARD: StringName = &"CardPanel"
const TYPE_THROTTLE_BAR: StringName = &"ThrottleBar"
const TYPE_BRAKE_BAR: StringName = &"BrakeBar"
const TYPE_SPEED_BAR: StringName = &"SpeedBar"


static func load_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		var res: Resource = load(FONT_PATH)
		if res is Font:
			return res as Font
	return null


static func box(fill: Color, border: Color = Color(0.0, 0.0, 0.0, 0.0), radius: int = 8,
		border_width: int = 0, pad_x: int = 14, pad_y: int = 8) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


## Círculo liso para o botão do controle deslizante (o tema precisa de uma textura).
static func dot_texture(diameter: int, color: Color) -> ImageTexture:
	var image: Image = Image.create_empty(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center: float = (diameter - 1) * 0.5
	var radius: float = diameter * 0.5
	for y in diameter:
		for x in diameter:
			var d: float = Vector2(x - center, y - center).length()
			var a: float = clampf(radius - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(image)


static func _button_states(t: Theme, type_name: StringName, normal: StyleBox, hover: StyleBox,
		pressed: StyleBox, hover_pressed: StyleBox, disabled: StyleBox) -> void:
	t.set_stylebox("normal", type_name, normal)
	t.set_stylebox("hover", type_name, hover)
	t.set_stylebox("pressed", type_name, pressed)
	t.set_stylebox("hover_pressed", type_name, hover_pressed)
	t.set_stylebox("disabled", type_name, disabled)
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())


static func _button_colors(t: Theme, type_name: StringName, normal: Color, pressed: Color, disabled: Color) -> void:
	t.set_color("font_color", type_name, normal)
	t.set_color("font_hover_color", type_name, normal)
	t.set_color("font_focus_color", type_name, normal)
	t.set_color("font_pressed_color", type_name, pressed)
	t.set_color("font_hover_pressed_color", type_name, pressed)
	t.set_color("font_disabled_color", type_name, disabled)


static func make_theme() -> Theme:
	var t: Theme = Theme.new()
	var font: Font = load_font()
	if font != null:
		t.default_font = font
	t.default_font_size = BASE_FONT_SIZE

	t.set_color("font_color", "Label", CREAM)

	# Botão padrão: cinza discreto; ligado = amarelo com texto escuro.
	_button_states(t, "Button",
		box(PANEL_SOFT, BORDER, 8, 2), box(HOVER, AMBER, 8, 2),
		box(YELLOW, YELLOW, 8, 2), box(Color(1.0, 0.82, 0.38), YELLOW, 8, 2),
		box(PANEL, BORDER, 8, 2))
	_button_colors(t, "Button", CREAM, INK, DIM)
	t.set_font_size("font_size", "Button", 23)

	# Botão principal (TESTAR ACELERAÇÃO): laranja forte.
	t.set_type_variation(TYPE_PRIMARY, "Button")
	_button_states(t, TYPE_PRIMARY,
		box(ORANGE, YELLOW, 14, 3, 20, 10), box(Color(1.0, 0.64, 0.33), YELLOW, 14, 3, 20, 10),
		box(Color(0.86, 0.42, 0.16), YELLOW, 14, 3, 20, 10), box(Color(1.0, 0.64, 0.33), YELLOW, 14, 3, 20, 10),
		box(PANEL, BORDER, 14, 3, 20, 10))
	_button_colors(t, TYPE_PRIMARY, INK, INK, DIM)
	t.set_font_size("font_size", TYPE_PRIMARY, 46)

	# Parar: contorno vermelho.
	t.set_type_variation(TYPE_STOP, "Button")
	_button_states(t, TYPE_STOP,
		box(PANEL_SOFT, RED, 8, 2), box(Color(0.25, 0.14, 0.14), RED, 8, 2),
		box(RED, RED, 8, 2), box(RED, RED, 8, 2), box(PANEL, BORDER, 8, 2))
	_button_colors(t, TYPE_STOP, Color(1.0, 0.82, 0.80), INK, DIM)

	# Botão fantasma (barra superior).
	t.set_type_variation(TYPE_GHOST, "Button")
	_button_states(t, TYPE_GHOST,
		box(Color(0.0, 0.0, 0.0, 0.0), BORDER, 8, 2), box(HOVER, CYAN, 8, 2),
		box(Color(0.12, 0.30, 0.34), CYAN, 8, 2), box(Color(0.16, 0.38, 0.42), CYAN, 8, 2),
		box(PANEL, BORDER, 8, 2))
	_button_colors(t, TYPE_GHOST, MUTED, CYAN, DIM)

	# Abas do painel técnico: texto com sublinhado amarelo quando ativa.
	t.set_type_variation(TYPE_TAB, "Button")
	var tab_normal: StyleBoxFlat = box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 4, 0, 16, 6)
	var tab_active: StyleBoxFlat = box(Color(0.0, 0.0, 0.0, 0.0), YELLOW, 4, 0, 16, 6)
	tab_active.border_width_bottom = 4
	_button_states(t, TYPE_TAB, tab_normal, box(HOVER, Color(0.0, 0.0, 0.0, 0.0), 4, 0, 16, 6),
		tab_active, tab_active, tab_normal)
	_button_colors(t, TYPE_TAB, MUTED, YELLOW, DIM)

	# Painéis.
	t.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 12, 2, 16, 12))
	t.set_type_variation(TYPE_CARD, "PanelContainer")
	t.set_stylebox("panel", TYPE_CARD, box(PANEL, BORDER, 12, 2, 16, 12))

	# Barras.
	_bar(t, "ProgressBar", YELLOW)
	_bar(t, TYPE_THROTTLE_BAR, ORANGE)
	_bar(t, TYPE_BRAKE_BAR, CYAN)
	_bar(t, TYPE_SPEED_BAR, YELLOW)

	# Controle deslizante.
	var track: StyleBoxFlat = box(UNLIT, BORDER, 6, 1, 0, 4)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(AMBER, AMBER, 6, 0, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(YELLOW, YELLOW, 6, 0, 0, 4))
	t.set_icon("grabber", "HSlider", dot_texture(30, YELLOW))
	t.set_icon("grabber_highlight", "HSlider", dot_texture(30, Color(1.0, 0.85, 0.45)))
	t.set_icon("grabber_disabled", "HSlider", dot_texture(30, DIM))
	t.set_constant("center_grabber", "HSlider", 1)

	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)
	return t


static func _bar(t: Theme, type_name: StringName, fill: Color) -> void:
	if type_name != &"ProgressBar":
		t.set_type_variation(type_name, "ProgressBar")
	t.set_stylebox("background", type_name, box(UNLIT, BORDER, 6, 1, 0, 0))
	t.set_stylebox("fill", type_name, box(fill, fill, 6, 0, 0, 0))
	t.set_color("font_color", type_name, CREAM)
