extends Node3D
## Áudio do motor V8 de um veículo, feito com gravações reais.
##
## Apenas observa o veículo: lê propriedades por nome e nunca escreve nele nem
## aplica forças. Pode ser filho da van ou ficar em outro ponto da cena; nesse
## caso acompanha a posição do veículo. Todas as propriedades do veículo são
## opcionais e verificadas uma vez, ao vincular:
##   linear_velocity, max_speed, turbo_active, ground_contacts,
##   player_input_enabled, in_mud, in_water, throttle_input.
##
## Camadas (os três players ficam na cena; nenhum nó é criado durante o jogo):
##   EngineIdle  – marcha lenta (Mustang 1985), loop; sempre presente.
##   EngineAccel – aceleração (Ford V8 5.0), loop; reforça a marcha lenta enquanto
##                 a rotação sobe e fica baixa em velocidade constante.
##   RevBlip     – aceleração curta (Mustang 1969), efeito único; alternativa à
##                 camada EngineAccel (veja `accel_mode`).
## O turbo não tem som próprio: só deixa o motor um pouco mais forte.
##
## Transmissão automática virtual (`transmission_enabled`): uma máquina de estados
## pequena, só sonora, calcula marcha, rotação e carga a partir da velocidade e do
## acelerador lidos do veículo. Nada é enviado ao veículo. Com ela desligada o
## componente se comporta exatamente como a versão A anterior.

enum AccelMode {
	## A: marcha lenta como sustentação; a camada de aceleração só reforça enquanto
	## a rotação sobe (e fica baixa em velocidade constante).
	DYNAMIC,
	## B: só a marcha lenta, com pitch e volume pela rotação e pela carga.
	IDLE_ONLY,
	## Referência: o loop de aceleração dominando sempre que há rotação alta ou carga.
	## É a mixagem que produzia a repetição em velocidade constante.
	CONTINUOUS,
	## Marcha lenta + efeito curto (Mustang 1969) ao pisar no acelerador.
	BLIP,
}

## Estado da troca de marcha virtual.
enum ShiftState { NONE, UP, DOWN }
## Estado de condução inferido (informativo; aparece no HUD de depuração).
enum DriveState { STOPPED, ACCELERATING, CRUISING, DECELERATING, REVERSE }

## Emitido a cada troca de marcha virtual: `gear` é a nova marcha (1 = primeira).
signal gear_changed(gear: int, upshift: bool)

const SHIFT_NAMES: Array[String] = ["nenhuma", "SUBINDO", "REDUZINDO"]
const DRIVE_NAMES: Array[String] = ["parado", "acelerando", "estável", "desacelerando", "ré"]
const MOTION_SPEED: float = 0.4
const STOP_HOLD: float = 0.3
const SILENT_DB: float = -80.0
const MIN_PITCH: float = 0.25
const GEAR_HYSTERESIS: float = 0.05
const GROUP_RETRY_INTERVAL: float = 0.5
const OPTIONAL_PROPERTIES: Array[StringName] = [
	&"linear_velocity", &"max_speed", &"turbo_active", &"ground_contacts",
	&"player_input_enabled", &"in_mud", &"in_water", &"throttle_input",
]

@export_category("Vehicle")
## Veículo observado. Pode ser trocado em execução, inclusive por null.
@export var vehicle: Node3D:
	set(value):
		vehicle = value
		if is_node_ready():
			_bind(value)
## Alternativa a `vehicle`: o primeiro nó deste grupo. Vazio desativa a busca.
@export var vehicle_group: StringName = &""
## Referência em m/s quando o veículo não expõe `max_speed`.
@export_range(1.0, 80.0) var fallback_max_speed: float = 24.0
## Ações lidas como acelerador quando o veículo não expõe `throttle_input`.
@export var throttle_action: StringName = &"accelerate"
@export var reverse_action: StringName = &"reverse"
## Desligar silencia o motor com transição suave (pausa, resultados, cutscene).
@export var engine_enabled: bool = true

@export_category("Engine")
@export var accel_mode: AccelMode = AccelMode.DYNAMIC
@export_range(-40.0, 0.0) var engine_volume_db: float = -6.0
## Volume relativo do motor em marcha lenta, sem acelerar.
@export_range(0.0, 1.0) var idle_gain: float = 0.6
## Frequência de explosões (Hz) em marcha lenta e no limite de rotação.
@export_range(20.0, 150.0) var idle_frequency: float = 47.5
@export_range(60.0, 200.0) var max_frequency: float = 70.0
## Curva rotação -> frequência. 1 = linear; acima de 1 sobe mais rápido em baixa
## rotação e achata perto do limite, o que mantém o tom estável em alta velocidade.
@export_range(1.0, 3.0) var frequency_curve: float = 1.5
## Teto do pitch das camadas; evita o som agudo demais.
@export_range(1.0, 3.0) var max_pitch_ratio: float = 1.6
## Frequência de explosões em que cada gravação foi preparada (veja o README).
@export_range(10.0, 400.0) var idle_loop_frequency: float = 47.5
@export_range(10.0, 400.0) var accel_loop_frequency: float = 66.0
@export_range(10.0, 400.0) var rev_blip_frequency: float = 66.7
## Marchas virtuais só sonoras, com queda de rotação discreta. 1 = rotação contínua.
@export_range(1, 6) var gear_count: int = 3
@export_range(0.0, 0.5) var shift_rpm_drop: float = 0.12
## Rotação mínima ao acelerar parado ou em baixa velocidade.
@export_range(0.0, 1.0) var launch_rpm: float = 0.3
@export_range(0.5, 20.0) var rpm_rise_rate: float = 3.0
@export_range(0.5, 20.0) var rpm_fall_rate: float = 2.0
@export_range(0.5, 20.0) var load_rate: float = 3.5
## Velocidade da transição entre as camadas (inclusive ao trocar `accel_mode`).
@export_range(0.5, 20.0) var layer_blend_rate: float = 5.0

@export_category("Transmission")
## Liga a transmissão automática virtual. Desligada = versão A anterior (marchas
## uniformes, mapeamento de frequência achatado).
@export var transmission_enabled: bool = true:
	set(value):
		transmission_enabled = value
		_tx_reset()
## Velocidade, como fração da máxima, em que cada marcha chega à rotação máxima.
## O tamanho do vetor é o número de marchas. A última deixa o motor em ~80% da
## rotação na velocidade máxima, para a marcha final soar relaxada. Com a
## velocidade máxima de 86 km/h da van, as trocas a pleno acelerador ficam perto
## de 30 e 60 km/h; como são frações de `max_speed`, acompanham mudanças nela.
@export var gear_top_fractions: PackedFloat32Array = PackedFloat32Array([0.40, 0.76, 1.25])
## Rotação em que sobe de marcha: perto do primeiro valor com acelerador leve,
## do segundo com acelerador pleno.
@export_range(0.4, 1.0) var upshift_rpm_light: float = 0.66
@export_range(0.5, 1.0) var upshift_rpm_full: float = 0.86
## Rotação abaixo da qual reduz marcha (bem abaixo da de subida: histerese) e a
## versão com acelerador pleno ("kick-down").
@export_range(0.1, 0.5) var downshift_rpm: float = 0.26
@export_range(0.1, 0.6) var kickdown_rpm: float = 0.30
## Tempo mínimo entre duas trocas e tempo que a condição precisa se manter.
@export_range(0.0, 3.0) var min_shift_interval: float = 0.7
@export_range(0.0, 0.5) var shift_hold_time: float = 0.08
## Em frenagem mais forte que isto (m/s²) não reduz marcha: evita a subida de
## rotação no fim de uma freada brusca. Reduções em freada suave continuam.
@export_range(2.0, 30.0) var hard_brake_decel: float = 7.0
## Duração do estado de troca; a carga cai só na subida.
@export_range(0.1, 1.0) var upshift_duration: float = 0.5
@export_range(0.1, 1.0) var downshift_duration: float = 0.35
@export_range(0.0, 1.0) var shift_load_floor: float = 0.2
## Na subida a rotação passa brevemente abaixo da nova marcha (respiro do motor) e o
## volume cai um pouco; os dois voltam em seguida. 0 desliga cada efeito.
@export_range(0.0, 0.3) var shift_rpm_dip: float = 0.10
@export_range(-9.0, 0.0) var shift_dip_db: float = -1.5
## Na subida a carga alivia primeiro e a rotação só começa a cair depois deste atraso (s).
@export_range(0.0, 0.3) var shift_fall_delay: float = 0.08
## Frequência de explosões (Hz) na rotação máxima; mapeamento linear com a marcha lenta.
@export_range(60.0, 200.0) var transmission_max_frequency: float = 74.0
## Taxas (por segundo) da rotação sonora: normal, durante a subida de marcha
## (queda rápida) e durante a redução (subida moderada).
@export_range(0.5, 30.0) var tx_rpm_rise_rate: float = 16.0
@export_range(0.5, 30.0) var tx_rpm_fall_rate: float = 4.0
@export_range(0.5, 30.0) var shift_fall_rate: float = 10.0
@export_range(0.5, 30.0) var downshift_rise_rate: float = 6.0
@export_range(0.5, 30.0) var shift_recover_rate: float = 5.0
## Subida de rotação quando o alvo é só o piso de lançamento ou de patinação (e não
## a velocidade): mais lenta, para o arranque não "gritar", sobretudo na lama.
@export_range(0.5, 30.0) var launch_rise_rate: float = 3.5
## Rotação que as rodas patinando na lama/água puxam com o acelerador pleno.
@export_range(0.0, 1.0) var slip_rpm: float = 0.5
## Em lama/água o intervalo entre trocas é multiplicado por isto.
@export_range(1.0, 4.0) var heavy_interval_scale: float = 2.0
## Intervalo mínimo (s) para uma troca em sentido contrário à anterior (subir depois
## de reduzir, ou o inverso): evita sobe-e-desce em obstáculos e subidas.
@export_range(0.0, 6.0) var opposite_shift_interval: float = 2.0
## Filtro da velocidade usada nas decisões; solavancos mais curtos que isto não trocam marcha.
@export_range(1.0, 30.0) var speed_filter_rate: float = 20.0
## Na queda o filtro é mais lento: quedas curtas (buraco, pancada) pouco mexem na rotação.
@export_range(1.0, 30.0) var speed_fall_rate: float = 5.0
## Tempo sem apoio (s) até contar como voo; durante o voo não há trocas.
@export_range(0.0, 1.0) var airborne_delay: float = 0.25
## Abaixo desta velocidade (m/s) a marcha volta à primeira, sem som de troca.
@export_range(0.0, 5.0) var stop_speed: float = 1.5
## Velocidade de referência (m/s) da rotação em marcha à ré.
@export_range(1.0, 20.0) var reverse_top_speed: float = 8.0

@export_category("Dynamic mix")
## Quanto a camada de aceleração entra (0–1) enquanto a rotação sobe.
@export_range(0.0, 1.0) var surge_max_blend: float = 0.85
## Parcela mantida com carga constante. Baixa de propósito: o loop de aceleração
## repete a cada ~1 s e, sozinho, soa como "nhoum-nhoum" em velocidade constante.
@export_range(0.0, 1.0) var sustain_blend: float = 0.1
## Taxa de subida de rotação (por segundo) que conta como aceleração plena.
@export_range(0.02, 1.0) var surge_rpm_rate: float = 0.12
@export_range(0.5, 20.0) var surge_attack_rate: float = 3.0
## Quão devagar a camada de aceleração se retira quando a rotação se estabiliza.
@export_range(0.2, 10.0) var surge_release_rate: float = 0.8

@export_category("Rev blip")
@export_range(-24.0, 6.0) var blip_volume_db: float = -2.0
## Só dispara se a rotação estiver abaixo disto (acelerador pisado a partir da marcha lenta).
@export_range(0.0, 1.0) var blip_max_rpm: float = 0.45
@export_range(0.0, 5.0) var blip_cooldown: float = 1.5

@export_category("Turbo")
## O turbo apenas reforça o motor: sem assobio, sem alívio.
@export_range(0.0, 6.0) var turbo_boost_db: float = 1.5
@export_range(0.0, 0.3) var turbo_rpm_boost: float = 0.06
@export_range(0.5, 20.0) var turbo_boost_rate: float = 3.0

@export_category("Mix")
## Barramento de saída; recai em Master se não existir.
@export var audio_bus: StringName = &"Master"
## Teto de segurança aplicado a cada camada.
@export_range(-24.0, 6.0) var max_layer_db: float = -3.0

var _vehicle: Node3D = null
var _properties: Dictionary = {}
var _follow_position: bool = false
var _has_throttle_actions: bool = false
var _group_retry: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _has_last_position: bool = false
var _playing: bool = false

var _rpm: float = 0.0
var _rpm_before: float = 0.0
var _surge: float = 0.0
var _gear: int = 0
var _load: float = 0.0
var _presence: float = 0.0
var _blend: float = 0.0
var _boost: float = 0.0
var _turbo_on: bool = false
var _drive: float = 0.0
var _drive_pressed: bool = false
var _grounded: bool = true
var _blip_cooldown: float = 0.0

# Transmissão virtual.
var _tx_gear: int = 0
var _tx_primed: bool = false
var _tx_reverse: bool = false
var _tx_speed: float = 0.0
var _tx_throttle: float = 0.0
var _tx_accel: float = 0.0
var _tx_since_shift: float = 99.0
var _tx_hold_up: float = 0.0
var _tx_hold_down: float = 0.0
var _air_time: float = 0.0
var _tx_stop_time: float = 0.0
var _shift_state: int = ShiftState.NONE
var _shift_time: float = 0.0
var _shift_dip: float = 0.0
var _shift_hold_rpm: float = 0.0
var _tx_last_dir: int = 0
var _drive_state: int = DriveState.STOPPED

@onready var _engine_idle: AudioStreamPlayer3D = get_node_or_null("EngineIdle") as AudioStreamPlayer3D
@onready var _engine_accel: AudioStreamPlayer3D = get_node_or_null("EngineAccel") as AudioStreamPlayer3D
@onready var _rev_blip: AudioStreamPlayer3D = get_node_or_null("RevBlip") as AudioStreamPlayer3D


func _ready() -> void:
	var bus: StringName = audio_bus
	if AudioServer.get_bus_index(audio_bus) < 0:
		push_warning("VanEngineAudio: barramento '%s' inexistente; usando Master." % audio_bus)
		bus = &"Master"
	for player in [_engine_idle, _engine_accel, _rev_blip]:
		if player == null:
			push_warning("VanEngineAudio: player ausente; essa camada ficará em silêncio.")
			continue
		player.bus = bus
		player.volume_db = SILENT_DB
		player.autoplay = false
		player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		if player.stream == null:
			push_warning("VanEngineAudio: %s sem stream; essa camada ficará em silêncio." % player.name)
		elif player != _rev_blip:
			_ensure_loop(player)
	_has_throttle_actions = InputMap.has_action(throttle_action) and InputMap.has_action(reverse_action)
	_bind(vehicle)


func _process(delta: float) -> void:
	_blip_cooldown = maxf(0.0, _blip_cooldown - delta)
	var valid: bool = is_instance_valid(_vehicle)
	if not valid:
		_vehicle = null
		_try_group_lookup(delta)
		valid = is_instance_valid(_vehicle)
	var present: bool = valid and engine_enabled
	if present and not _playing:
		_start_loops()
	_presence = _approach(_presence, 1.0 if present else 0.0, 4.0, delta)
	if valid:
		_update_engine_state(delta)
	else:
		_drive = 0.0
		_turbo_on = false
		_tx_reset()
		_rpm = _approach(_rpm, 0.0, rpm_fall_rate, delta)
		_load = _approach(_load, 0.0, load_rate, delta)
		_boost = _approach(_boost, 0.0, turbo_boost_rate, delta)
	_update_surge(delta)
	_update_blip(valid)
	_mix_engine(delta)
	if not present and _presence < 0.002:
		_stop_loops()


## Troca o veículo observado. Equivale a atribuir `vehicle`.
func set_vehicle(new_vehicle: Node3D) -> void:
	vehicle = new_vehicle


## Zera o estado da transmissão e da condução (marcha 1, troca limpa, temporizadores
## e condições de partida) sem mexer em nenhum parâmetro sonoro. A rotação e as
## camadas não saltam: continuam suavizando até a marcha lenta. Usado pelo
## laboratório antes de cada teste, para repeti-lo sempre da mesma condição.
func reset_state() -> void:
	_gear = 0
	_drive = 0.0
	_drive_pressed = false
	_blip_cooldown = 0.0
	_turbo_on = false
	_tx_reset()


## Valores internos para depuração e HUDs de teste; não alteram o estado.
func get_debug_state() -> Dictionary:
	return {
		"has_vehicle": is_instance_valid(_vehicle),
		"rpm": _rpm, "gear": (_tx_gear + 1 if transmission_enabled else _gear + 1), "load": _load, "presence": _presence,
		"frequency": _frequency_for(_rpm), "accel_blend": _blend, "surge": _surge,
		"drive": _drive, "mode": accel_mode,
		"transmission": transmission_enabled,
		"gear_label": _gear_label(),
		"shift_state": SHIFT_NAMES[_shift_state] if transmission_enabled else "—",
		"shift_progress": _shift_progress(),
		"drive_state": DRIVE_NAMES[_drive_state] if transmission_enabled else "—",
		"tx_speed": _tx_speed, "tx_accel": _tx_accel,
		"turbo_on": _turbo_on, "turbo_boost": _boost,
		"idle_db": _engine_idle.volume_db if _engine_idle else SILENT_DB,
		"idle_pitch": _engine_idle.pitch_scale if _engine_idle else 1.0,
		"accel_db": _engine_accel.volume_db if _engine_accel else SILENT_DB,
		"accel_pitch": _engine_accel.pitch_scale if _engine_accel else 1.0,
		"blip_playing": _rev_blip != null and _rev_blip.playing,
	}


func _bind(new_vehicle: Node3D) -> void:
	_vehicle = new_vehicle if is_instance_valid(new_vehicle) else null
	_properties.clear()
	_has_last_position = false
	_gear = 0
	_drive_pressed = false
	_tx_reset()
	if _vehicle == null:
		return
	var available: Dictionary = {}
	for info in _vehicle.get_property_list():
		available[StringName(info.name)] = true
	for property in OPTIONAL_PROPERTIES:
		if available.has(property):
			_properties[property] = true
	# Filho do veículo já se move com ele; fora dele, a posição é copiada.
	_follow_position = not _vehicle.is_ancestor_of(self)
	_start_loops()


func _try_group_lookup(delta: float) -> void:
	if vehicle_group.is_empty() or not is_inside_tree():
		return
	_group_retry -= delta
	if _group_retry > 0.0:
		return
	_group_retry = GROUP_RETRY_INTERVAL
	var found: Node3D = get_tree().get_first_node_in_group(vehicle_group) as Node3D
	if found != null:
		vehicle = found


func _update_engine_state(delta: float) -> void:
	if _follow_position:
		global_position = _vehicle.global_position
	var velocity: Vector3 = _read_velocity(delta)
	var signed_speed: float = velocity.dot(-_vehicle.global_basis.z)
	var speed: float = absf(signed_speed)
	var top_speed: float = maxf(_read_float(&"max_speed", fallback_max_speed), 0.1)
	var ratio: float = speed / top_speed
	var throttle: float = _read_throttle()
	_drive = absf(throttle)
	var touching: bool = _read_int(&"ground_contacts", 4) >= 2
	var heavy: bool = _read_bool(&"in_mud") or _read_bool(&"in_water")
	if transmission_enabled:
		# Com a transmissão o voo só conta depois de `airborne_delay`.
		_air_time = 0.0 if touching else _air_time + delta
		_grounded = _air_time <= airborne_delay
	else:
		_grounded = touching
	# Sem apoio a van zera turbo_active; mantém o turbo durante o voo para o
	# reforço não oscilar a cada salto.
	_turbo_on = (_read_bool(&"turbo_active") or (_turbo_on and not _grounded)) and engine_enabled
	_boost = _approach(_boost, 1.0 if _turbo_on else 0.0, turbo_boost_rate, delta)

	if transmission_enabled:
		_update_transmission(delta, signed_speed, top_speed, throttle, heavy)
		return

	_update_gear(ratio)
	var target_rpm: float = _gear_rpm(ratio)
	if not _grounded:
		# Rodas livres no ar: a rotação acompanha o acelerador, não a velocidade.
		target_rpm = maxf(target_rpm * 0.85, _drive * 0.9)
	else:
		target_rpm = maxf(target_rpm, _drive * launch_rpm)
		if heavy and _drive > 0.0:
			# Patinação na lama/água sobe a rotação sem aumentar a velocidade.
			target_rpm = maxf(target_rpm, _drive * 0.65)
	target_rpm = clampf(target_rpm + _boost * turbo_rpm_boost, 0.0, 1.1)
	_rpm = _approach(_rpm, target_rpm, rpm_rise_rate if target_rpm > _rpm else rpm_fall_rate, delta)

	var target_load: float = maxf(_drive, _boost)
	if heavy and _drive > 0.0:
		target_load = minf(1.0, target_load + 0.25)
	_load = _approach(_load, target_load, load_rate, delta)


func _update_gear(ratio: float) -> void:
	if gear_count <= 1:
		_gear = 0
		return
	var width: float = 1.0 / gear_count
	if _gear < gear_count - 1 and ratio > (_gear + 1) * width:
		_gear += 1
	elif _gear > 0 and ratio < _gear * width - GEAR_HYSTERESIS:
		_gear -= 1


func _gear_rpm(ratio: float) -> float:
	if gear_count <= 1:
		return ratio
	var width: float = 1.0 / gear_count
	var progress: float = clampf((ratio - _gear * width) / width, 0.0, 1.2)
	return lerpf(0.0 if _gear == 0 else shift_rpm_drop, 1.0, progress)


## Transmissão virtual. Entradas: velocidade com sinal (m/s, + à frente), velocidade
## máxima, acelerador (-1..1) e terreno pesado. Saídas: marcha, rotação, carga e
## estados de troca/condução. A decisão usa a velocidade filtrada e a rotação "da
## marcha" (velocidade / velocidade da marcha), nunca a rotação sonora atrasada.
func _update_transmission(delta: float, signed_speed: float, top_speed: float, throttle: float, heavy: bool) -> void:
	var speed: float = absf(signed_speed)
	var forward: bool = signed_speed > MOTION_SPEED
	var backward: bool = signed_speed < -MOTION_SPEED
	# Acelerador à frente ou, sem avanço, à ré. Freio (sentido contrário ao
	# movimento) não aciona o motor: não gera carga nem reforço.
	var engine_drive: float = 0.0
	if throttle > 0.0 and not backward:
		engine_drive = throttle
	elif throttle < 0.0 and not forward:
		engine_drive = -throttle
	_drive = engine_drive
	_tx_reverse = backward or (throttle < 0.0 and engine_drive > 0.0)

	var previous_speed: float = _tx_speed
	if not _tx_primed:
		_tx_speed = speed
		_tx_throttle = engine_drive
		_tx_accel = 0.0
		previous_speed = speed
		_tx_gear = _tx_sync_gear(speed, top_speed)
		_tx_primed = true
	else:
		_tx_speed = _approach(_tx_speed, speed, speed_filter_rate if speed > _tx_speed else speed_fall_rate, delta)
		_tx_throttle = _approach(_tx_throttle, engine_drive, 8.0 if engine_drive > _tx_throttle else 1.5, delta)
	if delta > 0.0:
		_tx_accel = _approach(_tx_accel, (_tx_speed - previous_speed) / delta, 4.0, delta)

	_tx_since_shift += delta
	if _shift_state != ShiftState.NONE:
		_shift_time += delta
		var duration: float = upshift_duration if _shift_state == ShiftState.UP else downshift_duration
		if _shift_time >= duration:
			_shift_state = ShiftState.NONE
	if _tx_reverse:
		_tx_gear = 0
		_tx_last_dir = 0
		_shift_state = ShiftState.NONE
		_tx_hold_up = 0.0
		_tx_hold_down = 0.0
	elif _grounded:
		_tx_decide(delta, top_speed, heavy)
	else:
		_tx_hold_up = 0.0
		_tx_hold_down = 0.0

	# Rotação alvo: da marcha, com piso de "lançamento" e patinação na lama.
	var target_rpm: float = _tx_gear_rpm(_tx_speed, top_speed)
	if _tx_reverse:
		target_rpm = _tx_speed / reverse_top_speed * 0.6
	var gear_rpm: float = target_rpm
	if not _grounded:
		target_rpm = maxf(target_rpm * 0.85, engine_drive * 0.9)
	else:
		target_rpm = maxf(target_rpm, engine_drive * launch_rpm)
		if heavy and engine_drive > 0.0:
			target_rpm = maxf(target_rpm, engine_drive * slip_rpm)
	# Alvo puxado só pelo piso (arranque, patinação, rodas no ar): sobe devagar.
	var floor_driven: bool = target_rpm > gear_rpm + 0.02
	target_rpm = clampf(target_rpm + _boost * turbo_rpm_boost, 0.0, 1.1)
	if _shift_state == ShiftState.UP:
		target_rpm = maxf(0.0, target_rpm - shift_rpm_dip * sin(PI * _shift_progress()))
		if _shift_time < shift_fall_delay:
			# A carga alivia primeiro; a rotação segura o pico por um instante.
			target_rpm = maxf(target_rpm, _shift_hold_rpm)
	var rate: float = tx_rpm_rise_rate if target_rpm > _rpm else tx_rpm_fall_rate
	if floor_driven and target_rpm > _rpm:
		rate = launch_rise_rate
	if _shift_state == ShiftState.UP and target_rpm < _rpm:
		rate = shift_fall_rate
	elif _shift_state == ShiftState.DOWN and target_rpm > _rpm:
		rate = downshift_rise_rate
	_rpm = _approach(_rpm, target_rpm, rate, delta)

	var target_load: float = maxf(engine_drive, _boost)
	if heavy and engine_drive > 0.0:
		target_load = minf(1.0, target_load + 0.25)
	var load_speed: float = shift_recover_rate if target_load > _load else load_rate
	if _shift_state == ShiftState.UP:
		# Corte de carga na troca: o motor "respira" e volta a empurrar na marcha seguinte.
		target_load = minf(target_load, shift_load_floor)
		load_speed = maxf(load_rate, 14.0)
	_load = _approach(_load, target_load, load_speed, delta)
	var dip_target: float = 1.0 if _shift_state == ShiftState.UP else 0.0
	_shift_dip = _approach(_shift_dip, dip_target, 16.0 if dip_target > _shift_dip else 5.0, delta)
	_drive_state = _infer_drive_state(engine_drive)


func _tx_decide(delta: float, top_speed: float, heavy: bool) -> void:
	var last: int = _tx_gear_count() - 1
	if _tx_speed < stop_speed:
		# Parado (por um instante): primeira marcha, sem som de troca. A espera evita
		# que uma queda breve de velocidade zere a marcha e provoque nova subida.
		_tx_hold_up = 0.0
		_tx_hold_down = 0.0
		_tx_stop_time += delta
		if _tx_stop_time >= STOP_HOLD:
			_tx_gear = 0
			_tx_last_dir = 0
			_shift_state = ShiftState.NONE
		return
	_tx_stop_time = 0.0
	var rpm_in_gear: float = _tx_gear_rpm(_tx_speed, top_speed)
	var throttle: float = clampf(_tx_throttle, 0.0, 1.0)
	var want_up: bool = (
		_tx_gear < last and throttle > 0.15
		and rpm_in_gear >= lerpf(upshift_rpm_light, upshift_rpm_full, throttle)
	)
	var down_limit: float = kickdown_rpm if throttle > 0.85 else downshift_rpm
	var want_down: bool = _tx_gear > 0 and not want_up and rpm_in_gear < down_limit
	if want_down:
		# Nunca reduzir para uma marcha que já pediria subida (evita oscilar).
		var rpm_lower: float = _tx_speed / _tx_gear_speed(_tx_gear - 1, top_speed)
		want_down = rpm_lower <= upshift_rpm_light - 0.08 and _tx_accel > -hard_brake_decel
	_tx_hold_up = _tx_hold_up + delta if want_up else 0.0
	_tx_hold_down = _tx_hold_down + delta if want_down else 0.0
	var scale: float = heavy_interval_scale if heavy else 1.0
	if _shift_state != ShiftState.NONE or _tx_since_shift < min_shift_interval * scale:
		return
	var may_reverse: bool = _tx_since_shift >= opposite_shift_interval * scale
	if want_up and _tx_hold_up >= shift_hold_time and (_tx_last_dir != -1 or may_reverse):
		_tx_shift(_tx_gear + 1, true)
	elif want_down and _tx_hold_down >= shift_hold_time and (_tx_last_dir != 1 or may_reverse):
		_tx_shift(_tx_gear - 1, false)


func _tx_shift(to_gear: int, upshift: bool) -> void:
	_tx_gear = to_gear
	_tx_since_shift = 0.0
	_shift_time = 0.0
	_shift_state = ShiftState.UP if upshift else ShiftState.DOWN
	_shift_hold_rpm = _rpm
	_tx_last_dir = 1 if upshift else -1
	_tx_hold_up = 0.0
	_tx_hold_down = 0.0
	gear_changed.emit(to_gear + 1, upshift)


func _tx_gear_count() -> int:
	return maxi(gear_top_fractions.size(), 1)


## Velocidade (m/s) em que a marcha chega à rotação 1.
func _tx_gear_speed(gear: int, top_speed: float) -> float:
	var fraction: float = 1.0
	if gear_top_fractions.size() > 0:
		fraction = gear_top_fractions[clampi(gear, 0, gear_top_fractions.size() - 1)]
	return maxf(fraction, 0.05) * top_speed


func _tx_gear_rpm(speed: float, top_speed: float) -> float:
	return speed / _tx_gear_speed(_tx_gear, top_speed)


## Marcha inicial ao vincular com o veículo já em movimento: sem cascata de trocas.
func _tx_sync_gear(speed: float, top_speed: float) -> int:
	var gear: int = 0
	while gear < _tx_gear_count() - 1 and speed / _tx_gear_speed(gear, top_speed) > 0.8:
		gear += 1
	return gear


func _tx_reset() -> void:
	_tx_primed = false
	_tx_gear = 0
	_tx_reverse = false
	_tx_since_shift = 99.0
	_tx_hold_up = 0.0
	_tx_hold_down = 0.0
	_air_time = 0.0
	_tx_stop_time = 0.0
	_shift_state = ShiftState.NONE
	_shift_time = 0.0
	_shift_dip = 0.0
	_shift_hold_rpm = 0.0
	_tx_last_dir = 0
	_drive_state = DriveState.STOPPED


func _infer_drive_state(engine_drive: float) -> int:
	if _tx_reverse:
		return DriveState.REVERSE
	if _tx_speed < MOTION_SPEED and engine_drive < 0.05:
		return DriveState.STOPPED
	if engine_drive > 0.1 and _tx_accel > 0.35:
		return DriveState.ACCELERATING
	if _tx_accel < -0.5 or (engine_drive < 0.05 and _tx_accel < -0.2):
		return DriveState.DECELERATING
	return DriveState.CRUISING


func _gear_label() -> String:
	if not transmission_enabled:
		return str(_gear + 1)
	if _tx_reverse:
		return "R"
	if _drive_state == DriveState.STOPPED:
		return "N"
	return str(_tx_gear + 1)


func _shift_progress() -> float:
	if not transmission_enabled or _shift_state == ShiftState.NONE:
		return 0.0
	var duration: float = upshift_duration if _shift_state == ShiftState.UP else downshift_duration
	return clampf(_shift_time / maxf(duration, 0.001), 0.0, 1.0)


func _frequency_for(rpm: float) -> float:
	if transmission_enabled:
		# Mapeamento linear: a queda de rotação numa troca precisa ser audível.
		return lerpf(idle_frequency, transmission_max_frequency, clampf(rpm, 0.0, 1.1))
	var progress: float = 1.0 - pow(1.0 - clampf(rpm, 0.0, 1.0), frequency_curve)
	return lerpf(idle_frequency, max_frequency, progress)


## "Aceleração em curso": a rotação está subindo. Rotação estável, em qualquer
## nível, a leva a zero, e a camada de aceleração se retira devagar.
func _update_surge(delta: float) -> void:
	var rising: float = 0.0
	if delta > 0.0:
		rising = clampf((_rpm - _rpm_before) / delta / surge_rpm_rate, 0.0, 1.0)
		if transmission_enabled:
			# Rotação que sobe sem acelerador (redução de marcha) não é "aceleração".
			rising *= clampf(_drive * 5.0, 0.0, 1.0)
	_rpm_before = _rpm
	var rate: float = surge_attack_rate if rising > _surge else surge_release_rate
	_surge = _approach(_surge, rising, rate, delta)


func _target_blend() -> float:
	match accel_mode:
		AccelMode.DYNAMIC:
			return clampf(maxf(sustain_blend * _load, surge_max_blend * _surge), 0.0, 1.0)
		AccelMode.CONTINUOUS:
			return clampf(smoothstep(0.05, 0.6, _rpm) * 0.6 + _load * 0.4, 0.0, 1.0)
	return 0.0


func _mix_engine(delta: float) -> void:
	if not _playing:
		return
	_blend = _approach(_blend, _target_blend(), layer_blend_rate, delta)
	var loudness: float = lerpf(idle_gain, 1.0, clampf(_rpm * 0.55 + _load * 0.45, 0.0, 1.0)) * _presence
	loudness *= db_to_linear(turbo_boost_db * _boost + shift_dip_db * _shift_dip)
	var frequency: float = _frequency_for(_rpm)
	# Crossfade de potência constante: as duas camadas são gravações diferentes.
	_apply_layer(_engine_idle, loudness * cos(_blend * PI * 0.5), frequency / idle_loop_frequency)
	_apply_layer(_engine_accel, loudness * sin(_blend * PI * 0.5), frequency / accel_loop_frequency)


func _apply_layer(player: AudioStreamPlayer3D, gain: float, pitch: float) -> void:
	if player == null:
		return
	player.volume_db = SILENT_DB if gain <= 0.0001 else minf(engine_volume_db + linear_to_db(gain), max_layer_db)
	player.pitch_scale = clampf(pitch, MIN_PITCH, max_pitch_ratio)


func _update_blip(vehicle_valid: bool) -> void:
	if _rev_blip == null or _rev_blip.stream == null:
		return
	var pressed: bool = _drive > 0.5
	var trigger: bool = (
		pressed and not _drive_pressed and vehicle_valid and engine_enabled
		and accel_mode == AccelMode.BLIP and _grounded
		and _blip_cooldown <= 0.0 and _rpm < blip_max_rpm
	)
	_drive_pressed = pressed
	if trigger:
		_blip_cooldown = blip_cooldown
	if trigger or _rev_blip.playing:
		# O pitch acompanha a rotação para o efeito continuar o mesmo motor.
		var frequency: float = _frequency_for(maxf(_rpm, _drive * launch_rpm))
		_rev_blip.pitch_scale = clampf(frequency / rev_blip_frequency, MIN_PITCH, max_pitch_ratio)
		_rev_blip.volume_db = minf(
			engine_volume_db + blip_volume_db + linear_to_db(maxf(_presence, 0.0001)), max_layer_db)
	if trigger:
		_rev_blip.play()


func _start_loops() -> void:
	_playing = true
	for player in [_engine_idle, _engine_accel]:
		if player != null and player.stream != null and not player.playing:
			player.play()


func _stop_loops() -> void:
	if not _playing:
		return
	_playing = false
	for player in [_engine_idle, _engine_accel, _rev_blip]:
		if player != null:
			player.stop()
			player.volume_db = SILENT_DB


func _ensure_loop(player: AudioStreamPlayer3D) -> void:
	# Proteção caso a importação não detecte o loop gravado no WAV.
	var wav: AudioStreamWAV = player.stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var looped: AudioStreamWAV = wav.duplicate() as AudioStreamWAV
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = 0
		looped.loop_end = int(looped.get_length() * looped.mix_rate)
		player.stream = looped
		return
	var ogg: AudioStreamOggVorbis = player.stream as AudioStreamOggVorbis
	if ogg != null and not ogg.loop:
		var looped_ogg: AudioStreamOggVorbis = ogg.duplicate() as AudioStreamOggVorbis
		looped_ogg.loop = true
		player.stream = looped_ogg


func _read_velocity(delta: float) -> Vector3:
	if _properties.has(&"linear_velocity"):
		var value: Variant = _vehicle.get(&"linear_velocity")
		if value is Vector3:
			return value
	# Sem linear_velocity: estima pela variação da posição.
	var position_now: Vector3 = _vehicle.global_position
	var velocity: Vector3 = Vector3.ZERO
	if _has_last_position and delta > 0.0:
		velocity = (position_now - _last_position) / delta
	_last_position = position_now
	_has_last_position = true
	return velocity


func _read_throttle() -> float:
	if _properties.has(&"throttle_input"):
		return clampf(float(_vehicle.get(&"throttle_input")), -1.0, 1.0)
	if _properties.has(&"player_input_enabled") and not bool(_vehicle.get(&"player_input_enabled")):
		return 0.0
	if _has_throttle_actions:
		return Input.get_axis(reverse_action, throttle_action)
	return 0.0


func _read_float(property: StringName, fallback: float) -> float:
	return float(_vehicle.get(property)) if _properties.has(property) else fallback


func _read_int(property: StringName, fallback: int) -> int:
	return int(_vehicle.get(property)) if _properties.has(property) else fallback


func _read_bool(property: StringName, fallback: bool = false) -> bool:
	return bool(_vehicle.get(property)) if _properties.has(property) else fallback


static func _approach(current: float, target: float, rate: float, delta: float) -> float:
	# Suavização exponencial independente da taxa de quadros.
	return lerpf(current, target, 1.0 - exp(-rate * delta))
