extends Node3D
## Veículo falso da demonstração de áudio. Expõe as mesmas propriedades que o
## áudio lê na van real, com uma aproximação simples da propulsão de
## van_controller.gd. Não usa física nem o Input Map do projeto.
##   W/S acelera e freia/ré · B freio suave · Shift turbo · Espaço simula voo
##   M simula lama (limita a velocidade para testar terreno difícil)
##   N simula piso irregular (quedas curtas de velocidade e perda de contato)
## Dois perfis de aceleração, só neste veículo falso (a van real não muda):
##   RÁPIDO    o comportamento anterior: 9 m/s² constantes, 0–86 km/h em ~2,7 s;
##   CALIBRADO aceleração que cai com a velocidade: 0–30 km/h ~1,9 s, 0–60 ~3,9 s,
##             0–80 ~5,6 s, para avaliar a sensação sonora (sem turbo).
## Com a velocidade fixa (lock_speed), velocidade e acelerador ficam congelados
## para isolar o comportamento do sistema de áudio; o piso irregular continua
## valendo, para testar que solavancos não provocam trocas de marcha.

@export var acceleration: float = 9.0
@export var max_speed: float = 24.0
@export var reverse_speed: float = 8.0
@export var braking: float = 12.0
@export var turbo_multiplier: float = 2.0
@export var turbo_max_speed: float = 36.0
## Acelerador mantido durante a velocidade fixa (cruzeiro), se a van estiver em movimento.
@export_range(0.0, 1.0) var cruise_throttle: float = 0.4
## Perfil CALIBRADO: aceleração inicial (m/s²) e quanto ela cai até a velocidade máxima
## (a = base * (1 - queda * (v / máx)^3)).
@export_range(1.0, 12.0) var gradual_accel: float = 4.5
@export_range(0.0, 0.9) var gradual_falloff: float = 0.5
## Desaceleração (m/s²) da tecla B e do freio suave do teste automático.
@export_range(0.5, 12.0) var gentle_braking: float = 4.0
## Desaceleração (m/s²) ao soltar o acelerador; em lama é 3,5 vezes maior.
@export_range(0.1, 6.0) var coast_decel: float = 1.2
## Velocidade máxima na lama (m/s), só nesta demonstração; 0 = sem limite.
@export_range(0.0, 24.0) var mud_max_speed: float = 7.0

const PROFILE_FAST: int = 0
const PROFILE_GRADUAL: int = 1
const PROFILE_NAMES: Array[String] = [
	"RÁPIDO (atual, 0–80 km/h em ~2,5 s)",
	"CALIBRADO (gradual, 0–80 km/h em ~5,6 s)",
]

var linear_velocity: Vector3 = Vector3.ZERO
var turbo_active: bool = false
var ground_contacts: int = 4
var player_input_enabled: bool = true
var throttle_input: float = 0.0
var in_mud: bool = false
var in_water: bool = false
var speed_locked: bool = false
## Perfil de aceleração ativo (PROFILE_*) e acelerador parcial (50%), ajustados pela demo.
var accel_profile: int = PROFILE_GRADUAL
var partial_throttle: bool = false
## Piso irregular (tecla N): ligado/desligado pela demonstração.
var rough_road: bool = false
## Lama e voo forçados pela interface da demonstração (as teclas M e Espaço continuam valendo).
var force_mud: bool = false
var force_air: bool = false
## Usados pelo teste automático da demonstração no lugar do teclado.
var input_override: bool = false
var override_throttle: float = 0.0
var override_brake: float = 0.0

var _speed: float = 0.0
var _locked_throttle: float = 0.0
var _bump_timer: float = 0.5
var _bump_left: float = 0.0
var _bump_dip: float = 0.0
var _bump_air: bool = false


## Congela a velocidade atual e o acelerador de cruzeiro.
func lock_speed() -> void:
	speed_locked = true
	_locked_throttle = cruise_throttle * signf(_speed) if absf(_speed) > 0.5 else 0.0


func unlock_speed() -> void:
	speed_locked = false


func get_speed() -> float:
	return _speed


## Volta ao repouso: velocidade zero, sem comando, sem solavanco em curso. Não altera
## o perfil, o acelerador parcial nem as condições escolhidas na demonstração.
func reset() -> void:
	_speed = 0.0
	_locked_throttle = 0.0
	speed_locked = false
	input_override = false
	override_throttle = 0.0
	override_brake = 0.0
	throttle_input = 0.0
	turbo_active = false
	in_mud = false
	ground_contacts = 4
	linear_velocity = Vector3.ZERO
	_bump_timer = 0.5
	_bump_left = 0.0
	_bump_dip = 0.0
	_bump_air = false


func profile_name() -> String:
	return PROFILE_NAMES[clampi(accel_profile, 0, PROFILE_NAMES.size() - 1)]


## Velocidade (m/s) em que o veículo se estabiliza com o acelerador dado
## (limitada pela lama, quando ela está ligada).
func get_cruise_target(throttle: float = 1.0) -> float:
	var target: float = max_speed * _power_scale(throttle)
	if in_mud and mud_max_speed > 0.0:
		target = minf(target, mud_max_speed)
	return target


func _physics_process(delta: float) -> void:
	var dip: float = _roughness(delta)
	if speed_locked:
		throttle_input = _locked_throttle
		ground_contacts = 0 if _bump_air else 4
		in_mud = false
		turbo_active = false
		linear_velocity = -global_basis.z * (_speed - dip * signf(_speed))
		return
	var throttle: float = 0.0
	var brake: float = 0.0
	if input_override:
		throttle = override_throttle
		brake = override_brake
	elif player_input_enabled:
		var pedal: float = 0.5 if partial_throttle else 1.0
		throttle = pedal * float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
		if Input.is_physical_key_pressed(KEY_B):
			brake = gentle_braking
	var grounded: bool = not (force_air or Input.is_physical_key_pressed(KEY_SPACE))
	if brake > 0.0:
		# Freio suave: pedal de freio (acelerador negativo) enquanto a van anda.
		throttle = -0.4 if _speed > 0.05 else 0.0
	throttle_input = throttle
	ground_contacts = 4 if grounded and not _bump_air else 0
	in_mud = force_mud or Input.is_physical_key_pressed(KEY_M)
	turbo_active = (
		grounded and throttle > 0.0 and _speed >= -0.15
		and player_input_enabled and Input.is_physical_key_pressed(KEY_SHIFT)
	)
	if grounded:
		if brake > 0.0 and _speed > 0.05:
			_speed = move_toward(_speed, 0.0, brake * delta)
		elif throttle * _speed < -0.15:
			_speed = move_toward(_speed, 0.0, braking * delta)
		elif not is_zero_approx(throttle):
			var target: float = max_speed if throttle > 0.0 else -reverse_speed
			var rate: float = _drive_rate() * (0.7 if throttle < 0.0 else 1.0)
			if absf(throttle) < 1.0:
				# Acelerador parcial: menos força e velocidade final menor.
				rate *= _power_scale(throttle)
				if throttle > 0.0:
					target *= _power_scale(throttle)
			if turbo_active:
				target = turbo_max_speed
				rate *= turbo_multiplier
			if in_mud:
				rate *= 0.78
				if mud_max_speed > 0.0:
					target = clampf(target, -mud_max_speed, mud_max_speed)
			_speed = move_toward(_speed, target, rate * delta)
		else:
			_speed = move_toward(_speed, 0.0, coast_decel * (3.5 if in_mud else 1.0) * delta)
	linear_velocity = -global_basis.z * (_speed - dip * signf(_speed))


func _drive_rate() -> float:
	if accel_profile == PROFILE_GRADUAL:
		var ratio: float = clampf(absf(_speed) / max_speed, 0.0, 1.0)
		return gradual_accel * (1.0 - gradual_falloff * ratio * ratio * ratio)
	return acceleration


func _power_scale(throttle: float) -> float:
	return 0.4 + 0.6 * clampf(absf(throttle), 0.0, 1.0)


## Solavancos do piso irregular: queda curta na velocidade lida e perda de contato.
## Devolve a queda (m/s) deste quadro; a velocidade real do veículo não muda.
func _roughness(delta: float) -> float:
	if not rough_road:
		_bump_left = 0.0
		_bump_air = false
		return 0.0
	_bump_timer -= delta
	if _bump_timer <= 0.0:
		_bump_timer = randf_range(0.4, 1.0)
		_bump_left = randf_range(0.05, 0.12)
		_bump_dip = randf_range(1.5, 3.5)
	if _bump_left > 0.0:
		_bump_left -= delta
		_bump_air = true
		return minf(_bump_dip, absf(_speed) * 0.5)
	_bump_air = false
	return 0.0
