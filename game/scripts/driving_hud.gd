extends CanvasLayer

const VanController = preload("res://scripts/van_controller.gd")

@export var van_path: NodePath = NodePath("../VanPrototype")

var _text_elapsed: float = 0.0
var _last_state: String = ""
var _fill: StyleBoxFlat
@onready var _van: VanController = get_node_or_null(van_path) as VanController
@onready var _speed: Label = $Panel/Margin/Content/Speed
@onready var _energy: Label = $Panel/Margin/Content/TurboLine/Energy
@onready var _bar: ProgressBar = $Panel/Margin/Content/Reserve
@onready var _status: Label = $Panel/Margin/Content/Status


func _ready() -> void:
	if _van == null:
		push_error("DrivingHUD: van_path deve apontar para a van com van_controller.gd.")
		set_process(false)
		return
	_fill = _bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_bar.add_theme_stylebox_override("fill", _fill)
	_update_text()
	_update_reserve()


func _process(delta: float) -> void:
	_update_reserve()
	_text_elapsed += delta
	if _text_elapsed >= 0.05:
		_text_elapsed = fmod(_text_elapsed, 0.05)
		_update_text()


func _update_text() -> void:
	var velocity: Vector3 = _van.linear_velocity
	_speed.text = "%d km/h" % roundi(Vector2(velocity.x, velocity.z).length() * 3.6)
	_energy.text = "%d%%" % roundi(_van.turbo_energy / _van.turbo_energy_max * 100.0) if _van.turbo_energy_enabled else "∞"


func _update_reserve() -> void:
	_bar.max_value = _van.turbo_energy_max
	_bar.value = _van.turbo_energy if _van.turbo_energy_enabled else _van.turbo_energy_max
	var state: String = "PRONTO"
	var color: Color = Color(0.95, 0.73, 0.3)
	if _van.turbo_active:
		state = "ATIVO"
		color = Color(1.0, 0.43, 0.13)
	elif _van.turbo_recharging:
		state = "RECARGA · BLOQUEADO" if _van.turbo_blocked else "RECARREGANDO"
		color = Color(0.35, 0.83, 0.72)
	elif _van.turbo_blocked:
		state = "RESERVA BLOQUEADA"
		color = Color(0.8, 0.43, 0.37)
	if state != _last_state:
		_last_state = state
		_status.text = state
		_status.modulate = color
		_fill.bg_color = color
