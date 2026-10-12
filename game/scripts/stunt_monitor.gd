extends Node

## Observador: não aplica forças nem altera a van ou suas consultas de suspensão.
signal flight_updated(distance: float, air_time: float, pitch_rotations: int, roll_rotations: int)
signal flight_cancelled
signal stunt_landed(result: Dictionary)

const VanController = preload("res://scripts/van_controller.gd")
enum Landing { CLEAN, BRUTAL, ROLLOVER }

@export var van_path: NodePath
@export_range(0.1, 2.0, 0.05) var minimum_air_time: float = 0.35
@export_range(1.0, 10.0, 0.5) var minimum_distance: float = 3.0
## Apoio contínuo necessário antes de permitir outro salto, inclusive após quicar.
@export_range(0.1, 1.0, 0.05) var ground_rearm_time: float = 0.25
## Um pulo baixo em alta velocidade pode ter distância, mas pouco voo contínuo.
@export_range(0.35, 1.0, 0.05) var minimum_clear_air_time: float = 0.55
@export_range(0.05, 0.25, 0.01) var contact_confirmation_time: float = 0.12
@export_range(0.005, 0.05, 0.005) var minimum_suspension_compression: float = 0.015
@export var debug_events: bool = false

@export_category("Landing")
@export_range(0.6, 1.0, 0.05) var landing_observation_time: float = 0.8
@export_range(0.8, 2.0, 0.05) var landing_timeout: float = 1.2
@export_range(0.1, 0.5, 0.05) var stable_landing_time: float = 0.2
@export_range(10.0, 40.0) var clean_landing_angle: float = 25.0
@export_range(45.0, 80.0) var rollover_angle: float = 60.0
@export_range(3.0, 15.0) var brutal_impact_speed: float = 7.0
@export_range(0.3, 3.0, 0.1) var stable_angular_speed: float = 1.2
@export_range(0.5, 5.0, 0.1) var stable_normal_speed: float = 2.5

@export_category("Score")
@export_range(0.0, 100.0) var points_per_meter: float = 10.0
@export_range(0.0, 300.0) var points_per_second: float = 50.0
@export_range(0, 2000) var points_per_rotation: int = 400
@export_range(0, 1000) var clean_landing_bonus: int = 150
@export_range(0, 1000) var brutal_landing_bonus: int = 100
@export_range(0, 1000) var rollover_bonus: int = 100
@export_range(1, 5000) var two_star_score: int = 350
@export_range(2, 10000) var three_star_score: int = 900

var total_stars: int = 0
var total_points: int = 0
var last_result: Dictionary = {}
var last_discard_reason: String = ""
var _ground_time: float = 0.0
var _armed: bool = false
var _flying: bool = false
var _air_time: float = 0.0
var _start_position: Vector3
var _previous_position: Vector3
var _previous_rotation: Quaternion
var _pitch: float = 0.0
var _roll: float = 0.0
var _pitch_rotations: int = 0
var _roll_rotations: int = 0
var _has_sample: bool = false
var _surface_normal: Vector3 = Vector3.UP
var _previous_velocity: Vector3 = Vector3.ZERO
var _previous_angular_speed: float = 0.0
var _landing_pending: bool = false
var _landing_elapsed: float = 0.0
var _stable_time: float = 0.0
var _landing_distance: float = 0.0
var _landing_brutal: bool = false
var _landing_interrupted: bool = false
var _landing_alignment: float = 1.0
var _clear_air_time: float = 0.0
var _longest_clear_air: float = 0.0
var _contact_time: float = 0.0
var _contact_gap: float = 0.0
var _contact_position: Vector3
var _contact_alignment: float = 1.0
var _contact_brutal: bool = false
var _brief_contact_seen: bool = false
var _reward_locked: bool = false
var _bounce_window: bool = false
var _bounce_elapsed: float = 0.0
var _last_grounded: bool = false

@onready var _van: VanController = get_node_or_null(van_path) as VanController


func _ready() -> void:
	if _van == null:
		push_error("StuntMonitor: van_path deve apontar para a van existente.")
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _van.freeze or Input.is_action_just_pressed("reset_vehicle"):
		_cancel_flight("reset R" if Input.is_action_just_pressed("reset_vehicle") else "corpo congelado")
		_has_sample = false
		if _landing_pending:
			_observe_interrupted_landing(delta)
		return
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(_van.get_rid())
	if state == null:
		return
	var position_now: Vector3 = _van.global_position
	# Recuperação manual/teleporte não pode completar uma manobra.
	if _has_sample and position_now.distance_to(_previous_position) > maxf(3.0, maxf(_previous_velocity.length(), _van.linear_velocity.length()) * delta * 2.0):
		_cancel_flight("descontinuidade de posição")
		_has_sample = false
	var grounded: bool = _has_ground_support(state)
	var normal: Vector3 = _read_surface_normal(state) if grounded else _surface_normal
	_observe_sample(delta, grounded, position_now, _van.global_basis.get_rotation_quaternion(), normal, _van.linear_velocity, _van.angular_velocity.length())


func _has_ground_support(state: PhysicsDirectBodyState3D) -> bool:
	# ground_contacts inclui raios no limite do curso, mesmo sem força de apoio.
	# Lê o resultado existente e verifica compressão/carga, sem atualizar raycasts.
	for ray in _van._rays:
		if not ray.is_colliding():
			continue
		var normal: Vector3 = ray.get_collision_normal()
		if normal.dot(Vector3.UP) <= _van.MIN_GROUND_DOT or normal.dot(_van.global_basis.y) <= 0.25:
			continue
		var length: float = ray.global_position.distance_to(ray.get_collision_point()) - _van.WHEEL_RADIUS - _van.RAY_ORIGIN_OFFSET
		var compression: float = _van.SUSPENSION_LENGTH - clampf(length, 0.0, _van.SUSPENSION_LENGTH)
		var offset: Vector3 = ray.get_collision_point() - state.transform.origin - state.center_of_mass
		var point_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(offset)
		var support: float = _van.suspension_strength * compression - 2.0 * sqrt(_van.suspension_strength) * 0.85 * point_velocity.dot(normal)
		if compression >= minimum_suspension_compression and support > 0.0:
			return true
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).dot(Vector3.UP) > _van.MIN_GROUND_DOT:
			return true
	return false


func _read_surface_normal(state: PhysicsDirectBodyState3D) -> Vector3:
	var normal_sum: Vector3 = Vector3.ZERO
	# Apenas lê os raycasts que a suspensão já atualizou; nenhuma nova consulta.
	for ray in _van._rays:
		if ray.is_colliding():
			var normal: Vector3 = ray.get_collision_normal()
			if normal.dot(Vector3.UP) > _van.MIN_GROUND_DOT and normal.dot(_van.global_basis.y) > 0.25:
				normal_sum += normal
	if normal_sum.is_zero_approx():
		# Jolt entrega a normal do contato da carroceria em coordenadas globais.
		for i in state.get_contact_count():
			var normal: Vector3 = state.get_contact_local_normal(i)
			if normal.dot(Vector3.UP) > _van.MIN_GROUND_DOT:
				normal_sum += normal
	return normal_sum.normalized() if not normal_sum.is_zero_approx() else _surface_normal


func _observe_sample(delta: float, grounded: bool, position_now: Vector3, rotation_now: Quaternion, surface_normal: Vector3 = Vector3.UP, velocity: Vector3 = Vector3.ZERO, angular_speed: float = 0.0) -> void:
	if not _has_sample:
		_previous_position = position_now
		_previous_rotation = rotation_now
		_has_sample = true
	var alignment: float = Basis(rotation_now).y.dot(surface_normal)
	_last_grounded = grounded
	if _bounce_window:
		_bounce_elapsed += delta
	if not _landing_interrupted:
		_surface_normal = surface_normal
	if _landing_pending:
		if _landing_interrupted:
			_observe_interrupted_landing(delta)
		elif not grounded and _ground_time >= ground_rearm_time and _stable_time >= stable_landing_time:
			# Apoio sustentado seguido de nova decolagem: são eventos independentes.
			# A classificação anterior não deve usar a orientação do próximo voo.
			_award_result(_classify_landing())
			_reward_locked = false
			_begin_flight(position_now, rotation_now)
			_sample_air(delta, position_now, rotation_now)
		elif not grounded and _bounce_elapsed < landing_timeout:
			# Quique após contato confirmado: continua a mesma medição, com janela finita.
			_landing_pending = false
			_flying = true
			_brief_contact_seen = true
			_contact_time = 0.0
			_contact_gap = 0.0
			_clear_air_time = 0.0
			_previous_rotation = rotation_now
			_debug_event("voo retomado após quique")
			_sample_air(delta, position_now, rotation_now)
		else:
			_ground_time = _ground_time + delta if grounded and alignment >= cos(deg_to_rad(rollover_angle)) else 0.0
			_observe_landing(delta, grounded, alignment, velocity.dot(surface_normal), angular_speed)
	elif grounded:
		if _flying:
			if _contact_time == 0.0:
				_contact_position = position_now
				_contact_alignment = alignment
				_contact_brutal = alignment < cos(deg_to_rad(clean_landing_angle)) or -_previous_velocity.dot(surface_normal) > brutal_impact_speed or _previous_angular_speed > stable_angular_speed
				_debug_event("contato em confirmação")
			_contact_gap = 0.0
			_contact_time += delta
			_clear_air_time = 0.0
			if _contact_time >= contact_confirmation_time:
				_finish_flight(_contact_position, _contact_alignment)
		elif alignment >= cos(deg_to_rad(rollover_angle)):
			_ground_time += delta
			if _ground_time >= ground_rearm_time:
				_armed = true
				_reward_locked = false
		else:
			_ground_time = 0.0
			_armed = false
	else:
		_ground_time = 0.0
		if (_armed or not _reward_locked) and not _flying:
			_begin_flight(position_now, rotation_now)
		if _flying:
			_sample_air(delta, position_now, rotation_now)
	_previous_position = position_now
	_previous_rotation = rotation_now
	_previous_velocity = velocity
	_previous_angular_speed = angular_speed


func _begin_flight(position_now: Vector3, rotation_now: Quaternion) -> void:
	_flying = true
	_armed = false
	_start_position = _previous_position
	_previous_rotation = rotation_now
	_air_time = 0.0
	_clear_air_time = 0.0
	_longest_clear_air = 0.0
	_contact_time = 0.0
	_contact_gap = 0.0
	_brief_contact_seen = false
	_bounce_window = false
	_bounce_elapsed = 0.0
	_pitch = 0.0
	_roll = 0.0
	_pitch_rotations = 0
	_roll_rotations = 0
	last_discard_reason = ""
	_debug_event("início de voo", "medição; recompensa ainda não validada", _horizontal_distance(position_now))


func _sample_air(delta: float, position_now: Vector3, rotation_now: Quaternion) -> void:
	if _contact_time > 0.0:
		if _contact_gap == 0.0:
			_debug_event("contato breve ignorado", "%.3f s" % _contact_time)
			_brief_contact_seen = true
			_previous_rotation = rotation_now
		_contact_gap += delta
		# Apoios repetidos entre gaps curtíssimos confirmam pouso, não um voo infinito.
		# Um afastamento real limpa esse histórico e preserva o salto em andamento.
		if _contact_gap >= contact_confirmation_time:
			_contact_time = 0.0
			_contact_gap = 0.0
	_air_time += delta
	_clear_air_time += delta
	_longest_clear_air = maxf(_longest_clear_air, _clear_air_time)
	_measure_rotation(rotation_now)
	var distance: float = _horizontal_distance(position_now)
	if not _validation_reason(distance).is_empty():
		flight_updated.emit(distance, _air_time, _pitch_rotations, _roll_rotations)


func _validation_reason(distance: float) -> String:
	if _air_time < minimum_air_time:
		return ""
	if _pitch_rotations + _roll_rotations > 0 and _longest_clear_air >= minimum_air_time:
		return "giro completo em voo"
	if distance >= minimum_distance and _longest_clear_air >= minimum_clear_air_time:
		return "voo contínuo e deslocamento suficientes"
	return ""


func _measure_rotation(rotation_now: Quaternion) -> void:
	# Delta no espaço global, no hemisfério curto; não usa Euler normalizado.
	var change: Quaternion = (rotation_now * _previous_rotation.inverse()).normalized()
	if change.w < 0.0:
		change = Quaternion(-change.x, -change.y, -change.z, -change.w)
	var axis_vector: Vector3 = Vector3(change.x, change.y, change.z)
	var axis_length: float = axis_vector.length()
	var angle: float = 2.0 * atan2(axis_length, change.w)
	if angle < 0.00001:
		return
	# Descarta descontinuidades, conservadoramente, em vez de premiar um reset.
	if angle > PI * 0.5:
		_debug_event("amostra de rotação ignorada", "delta angular descontínuo; voo preservado")
		return
	var rotation_vector: Vector3 = axis_vector / axis_length * angle
	# Rejeita yaw global, sem encurtar um roll cujo eixo está inclinado na encosta.
	if absf((axis_vector / axis_length).dot(Vector3.UP)) > 0.995:
		return
	var previous_basis: Basis = Basis(_previous_rotation)
	_pitch += rotation_vector.dot(previous_basis.x)
	_roll += rotation_vector.dot(previous_basis.z)
	# Soma assinada: inclinar e voltar não equivale a uma volta completa.
	while absf(_pitch) >= TAU - 0.0001:
		_pitch -= signf(_pitch) * TAU
		_pitch_rotations += 1
	while absf(_roll) >= TAU - 0.0001:
		_roll -= signf(_roll) * TAU
		_roll_rotations += 1


func _horizontal_distance(position_now: Vector3) -> float:
	var offset: Vector3 = position_now - _start_position
	return Vector2(offset.x, offset.z).length()


func _finish_flight(position_now: Vector3, alignment: float) -> void:
	_flying = false
	_armed = false
	_ground_time = _contact_time
	var distance: float = _horizontal_distance(position_now)
	var reason: String = _validation_reason(distance)
	if reason.is_empty():
		last_discard_reason = "tempo no ar insuficiente" if _air_time < minimum_air_time else ("voo contínuo curto; oscilação/pulo baixo" if _longest_clear_air < minimum_clear_air_time else "deslocamento insuficiente e sem giro completo")
		_debug_event("voo descartado", last_discard_reason, distance)
		# Uma tentativa pequena não bloqueia a próxima decolagem real.
		_reward_locked = false
		flight_cancelled.emit()
		return
	_debug_event("fim de voo confirmado", reason, distance)
	_landing_distance = distance
	_landing_pending = true
	_landing_elapsed = _contact_time
	_stable_time = 0.0
	_landing_alignment = alignment
	_landing_interrupted = false
	_landing_brutal = _contact_brutal or _brief_contact_seen
	if not _bounce_window:
		_bounce_window = true
		_bounce_elapsed = _contact_time


func _observe_landing(delta: float, grounded: bool, alignment: float, normal_speed: float, angular_speed: float) -> void:
	_landing_elapsed += delta
	_landing_alignment = alignment
	var controlled: bool = grounded and alignment >= cos(deg_to_rad(clean_landing_angle)) and absf(normal_speed) <= stable_normal_speed and angular_speed <= stable_angular_speed
	_stable_time = _stable_time + delta if controlled else 0.0
	if not grounded or alignment < cos(deg_to_rad(clean_landing_angle)) or absf(normal_speed) > brutal_impact_speed or angular_speed > stable_angular_speed:
		_landing_brutal = true
	if _landing_elapsed < landing_observation_time:
		return
	if _stable_time >= stable_landing_time or _landing_elapsed >= maxf(landing_timeout, landing_observation_time):
		_award_result(_classify_landing())


func _classify_landing() -> Landing:
	if _landing_alignment < cos(deg_to_rad(rollover_angle)):
		return Landing.ROLLOVER
	if _landing_brutal or _stable_time < stable_landing_time:
		return Landing.BRUTAL
	return Landing.CLEAN


func _observe_interrupted_landing(delta: float) -> void:
	# R após o impacto não cria outro pouso nem apaga uma façanha já realizada.
	# Mantém orientação anterior ao reset e conclui na janela original.
	_landing_elapsed += delta
	if _landing_elapsed >= landing_observation_time:
		_award_result(_classify_landing())


func _calculate_reward(landing: Landing) -> Dictionary:
	var rotations: int = _pitch_rotations + _roll_rotations
	var bonus: int = clean_landing_bonus
	if landing == Landing.BRUTAL:
		bonus = brutal_landing_bonus
	elif landing == Landing.ROLLOVER:
		bonus = rollover_bonus
	var points: int = roundi(_landing_distance * points_per_meter + _air_time * points_per_second) + rotations * points_per_rotation + bonus
	var stars: int = 1
	if points >= two_star_score:
		stars = 2
	if points >= maxi(three_star_score, two_star_score + 1):
		stars = 3
	return {"distance": _landing_distance, "air_time": _air_time, "pitch_rotations": _pitch_rotations, "roll_rotations": _roll_rotations, "rotations": rotations, "landing": landing, "points": points, "stars": stars}


func _award_result(landing: Landing) -> void:
	_landing_pending = false
	_landing_interrupted = false
	_armed = _last_grounded and _ground_time >= ground_rearm_time and _landing_alignment >= cos(deg_to_rad(rollover_angle))
	_reward_locked = not _armed
	_bounce_window = false
	last_result = _calculate_reward(landing)
	total_points += last_result.points
	total_stars += last_result.stars
	last_result["session_points"] = total_points
	last_result["session_stars"] = total_stars
	_debug_event("manobra concluída", "pouso=%d; pontos=%d" % [landing, last_result.points], _landing_distance)
	stunt_landed.emit(last_result)


func _cancel_flight(reason: String = "cancelamento explícito") -> void:
	if _has_sample or reason == "reset R":
		_debug_event("reinício da medição", reason)
	last_discard_reason = reason
	if _landing_pending:
		_landing_interrupted = true
		_landing_brutal = true
	if _flying:
		flight_cancelled.emit()
	_flying = false
	_armed = false
	_ground_time = 0.0
	_contact_time = 0.0
	_contact_gap = 0.0
	_reward_locked = true


func _debug_event(event: String, reason: String = "", distance: float = -1.0) -> void:
	if not debug_events:
		return
	if distance < 0.0:
		distance = _horizontal_distance(_previous_position)
	print("[Façanhas] %s | %.2f s | %.1f m | giros=%d/%d | %s" % [event, _air_time, distance, _pitch_rotations, _roll_rotations, reason])
