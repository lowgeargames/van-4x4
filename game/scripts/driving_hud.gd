extends CanvasLayer

const VanController = preload("res://scripts/van_controller.gd")
const ArcadeSpeedometer = preload("res://scripts/arcade_speedometer.gd")

@export var van_path: NodePath = NodePath("../VanPrototype")

var _text_elapsed: float = 0.0
@onready var _van: VanController = get_node_or_null(van_path) as VanController
@onready var _instrument: ArcadeSpeedometer = $Panel


func _ready() -> void:
	if _van == null:
		push_error("DrivingHUD: van_path deve apontar para a van com van_controller.gd.")
		set_process(false)
		return
	_update_text()
	_update_reserve()


func _process(delta: float) -> void:
	_update_reserve()
	_text_elapsed += delta
	if _text_elapsed >= 0.05:
		_text_elapsed = fmod(_text_elapsed, 0.05)
		_update_text()


func _update_text() -> void:
	# Mesma medição horizontal do HUD original, independente da escala do arco.
	var velocity: Vector3 = _van.linear_velocity
	_instrument.set_speed(Vector2(velocity.x, velocity.z).length() * 3.6)


func _update_reserve() -> void:
	var unlimited: bool = not _van.turbo_energy_enabled
	var ratio: float = 1.0 if unlimited else clampf(_van.turbo_energy / _van.turbo_energy_max, 0.0, 1.0)
	var state: String = "PRONTO"
	var color: Color = ArcadeSpeedometer.YELLOW
	if _van.turbo_active:
		state = "ATIVO"
		color = ArcadeSpeedometer.ORANGE
	elif _van.turbo_recharging:
		state = "RECARGA · BLOQUEADO" if _van.turbo_blocked else "RECARGA"
		color = ArcadeSpeedometer.MINT
	elif _van.turbo_blocked:
		# O bloqueio também pode aguardar a soltura de Shift após recuperar energia.
		state = "BLOQUEADO"
		color = ArcadeSpeedometer.GRAY
	_instrument.set_turbo(ratio, state, color, _van.turbo_active, _van.turbo_blocked, unlimited)
