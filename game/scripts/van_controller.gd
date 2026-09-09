extends RigidBody3D


@export_category("Drive")
## Aceleração e frenagem em m/s²; velocidades em m/s.
@export_range(1.0, 20.0) var acceleration: float = 9.0
@export_range(5.0, 40.0) var max_speed: float = 24.0
@export_range(1.0, 15.0) var reverse_speed: float = 8.0
@export_range(1.0, 25.0) var braking: float = 12.0

@export_category("Turbo")
@export_range(1.0, 4.0) var turbo_multiplier: float = 2.0
## Limite em m/s, aplicado somente ao acelerar para frente com Shift.
@export_range(5.0, 60.0) var turbo_max_speed: float = 36.0

@export_category("Handling")
## Velocidade máxima de giro em rad/s, reduzida conforme a velocidade.
@export_range(0.2, 2.0) var steering_strength: float = 1.1
@export_range(1.0, 12.0) var steering_response: float = 6.0
## Rapidez com que a van recupera aderência lateral, em 1/s.
@export_range(0.1, 12.0) var grip: float = 7.0
@export_range(0.1, 5.0) var drift_grip: float = 1.4
@export_range(0.0, 20.0) var stability: float = 6.0
## Assistência plena até metade deste ângulo; desaparece neste limite, em graus.
@export_range(10.0, 60.0) var stability_max_angle: float = 35.0
## Distância virtual abaixo do centro de massa, em metros; maior = mais roll nas curvas.
@export_range(0.0, 3.0, 0.05) var roll_leverage: float = 0.7

@export_category("Manual Roll")
## Aceleração angular em rad/s²; torque calculado a partir da inércia do corpo.
@export_range(0.0, 20.0) var air_roll_strength: float = 8.0
## Limite do giro comandado com A/D, em rad/s, também usado na recuperação.
@export_range(0.5, 8.0) var air_max_angular_speed: float = 4.5
@export_range(0.0, 60.0) var recovery_strength: float = 24.0

@export_category("Suspension")
## Rigidez por unidade de massa apoiada; amortecimento calculado automaticamente.
@export_range(60.0, 200.0) var suspension_strength: float = 120.0

# Geometria compartilhada pelas quatro rodas; não são ajustes de dirigibilidade.
const WHEEL_RADIUS: float = 0.45
const SUSPENSION_LENGTH: float = 0.38
# Apenas estende a consulta acima da roda; não aumenta o curso nem a força da suspensão.
const RAY_ORIGIN_OFFSET: float = 0.6
const MIN_GROUND_DOT: float = 0.35

const WATER_DRAG: float = 0.8
const WATER_ACCELERATION_MULTIPLIER: float = 0.6
const WATER_MAX_SPEED: float = 8.0
const WATER_TURBO_MAX_SPEED: float = 10.0
const WATER_STEERING_MULTIPLIER: float = 0.75

var in_mud: bool = false
var in_water: bool = false
var ground_contacts: int = 0
var _ground_normal: Vector3 = Vector3.UP
var _steering: float = 0.0
var _mud_weight: float = 0.0
var _wheel_spin: float = 0.0
var _reset_requested: bool = false
var _recovering: bool = false
var _spawn_transform: Transform3D
var _wheel_visuals: Array[Node3D] = []

@onready var _rays: Array[RayCast3D] = [
	$WheelFrontLeft, $WheelFrontRight, $WheelRearLeft, $WheelRearRight
]


func _ready() -> void:
	_spawn_transform = global_transform
	# Contatos da carroceria distinguem um salto de uma van tombada no chão.
	max_contacts_reported = 4
	for ray in _rays:
		# Atualizados explicitamente na integração, sem uma segunda consulta automática.
		ray.enabled = false
		ray.target_position = Vector3.DOWN * (SUSPENSION_LENGTH + WHEEL_RADIUS + RAY_ORIGIN_OFFSET)
		ray.add_exception(self)
		_wheel_visuals.append(ray.get_node("WheelVisual"))


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset_vehicle"):
		reset_vehicle()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_requested:
		_apply_reset(state)
		return

	var delta: float = state.step
	_steering = move_toward(
		_steering, Input.get_axis("steer_right", "steer_left"), steering_response * delta
	)
	_mud_weight = move_toward(_mud_weight, 1.0 if in_mud else 0.0, 3.0 * delta)
	_wheel_spin = wrapf(
		_wheel_spin + state.linear_velocity.dot(-state.transform.basis.z)
		* delta / WHEEL_RADIUS, -PI, PI
	)

	if _update_suspension(state):
		_apply_handling(state)
	_apply_manual_roll(state)
	if in_water:
		# Resistência somente horizontal, sem frear a queda ou o salto.
		var horizontal_velocity := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
		state.apply_central_force(
			-horizontal_velocity * mass * (1.0 - exp(-WATER_DRAG * delta)) / delta
		)


func _update_suspension(state: PhysicsDirectBodyState3D) -> bool:
	ground_contacts = 0
	var normal_sum: Vector3 = Vector3.ZERO
	var wheel_mass: float = mass / 4.0
	var spring: float = wheel_mass * suspension_strength
	var damper: float = 2.0 * sqrt(spring * wheel_mass) * 0.85
	var max_force: float = wheel_mass * state.total_gravity.length() * 5.0
	var body_up: Vector3 = state.transform.basis.y

	for i in _rays.size():
		var ray: RayCast3D = _rays[i]
		ray.force_raycast_update()
		var length: float = SUSPENSION_LENGTH
		if ray.is_colliding():
			var normal: Vector3 = ray.get_collision_normal()
			# Paredes e teto não viram piso nem recebem assistência de direção.
			if normal.dot(Vector3.UP) > MIN_GROUND_DOT and normal.dot(body_up) > 0.25:
				var hit: Vector3 = ray.get_collision_point()
				length = clampf(
					ray.global_position.distance_to(hit) - WHEEL_RADIUS - RAY_ORIGIN_OFFSET,
					0.0, SUSPENSION_LENGTH
				)
				var offset: Vector3 = hit - state.transform.origin
				var point_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(
					offset - state.center_of_mass
				)
				var force: float = spring * (SUSPENSION_LENGTH - length)
				force -= damper * point_velocity.dot(normal)
				state.apply_force(normal * clampf(force, 0.0, max_force), offset)
				ground_contacts += 1
				normal_sum += normal

		var visual: Node3D = _wheel_visuals[i]
		visual.position = Vector3.DOWN * (length + RAY_ORIGIN_OFFSET)
		# O cilindro gira em torno do próprio centro, sem deslocamento excêntrico.
		var steer_angle: float = _steering * 0.38 if i < 2 else 0.0
		visual.basis = Basis(Vector3.UP, steer_angle) * Basis(Vector3.RIGHT, -_wheel_spin)
		visual.basis *= Basis(Vector3.FORWARD, PI / 2.0)

	# Duas rodas ainda sustentam a direção, mesmo quando são do mesmo lado.
	if ground_contacts < 2:
		return false
	var support_normal: Vector3 = normal_sum.normalized()
	_ground_normal = _ground_normal.lerp(
		support_normal, 1.0 - exp(-12.0 * state.step)
	).normalized()
	return body_up.dot(support_normal) > 0.5


func _apply_handling(state: PhysicsDirectBodyState3D) -> void:
	var forward: Vector3 = (-state.transform.basis.z).slide(_ground_normal).normalized()
	var right: Vector3 = forward.cross(_ground_normal).normalized()
	var speed: float = state.linear_velocity.dot(forward)
	var side_speed: float = state.linear_velocity.dot(right)
	var throttle: float = Input.get_axis("reverse", "accelerate")
	var handbrake: bool = Input.is_action_pressed("handbrake")
	var power: float = lerpf(1.0, 0.78, _mud_weight)
	if in_water:
		power *= WATER_ACCELERATION_MULTIPLIER
	var drag: float = lerpf(0.12, 0.42, _mud_weight)
	var next_speed: float = speed

	if handbrake:
		next_speed = move_toward(speed, 0.0, braking * 0.3 * state.step)
	elif not is_zero_approx(throttle):
		if speed * throttle < -0.15:
			# W/S primeiro param o movimento contrário, sem ultrapassar o zero.
			next_speed = move_toward(speed, 0.0, braking * state.step)
		else:
			var target: float = max_speed if throttle > 0.0 else -reverse_speed
			var drive_acceleration: float = acceleration * power
			if throttle > 0.0 and Input.is_action_pressed("turbo"):
				drive_acceleration *= turbo_multiplier
				target = maxf(max_speed, turbo_max_speed)
			if throttle < 0.0:
				drive_acceleration *= 0.7
			if in_water:
				var water_limit: float = WATER_TURBO_MAX_SPEED if Input.is_action_pressed("turbo") else WATER_MAX_SPEED
				target = clampf(target, -reverse_speed * 0.5, water_limit)
			next_speed = move_toward(speed, target, drive_acceleration * state.step)
	else:
		next_speed = speed * exp(-drag * state.step)

	# A resistência da superfície atua no plano de apoio, nunca no salto.
	if not handbrake and not is_zero_approx(throttle) and speed * throttle >= -0.15:
		next_speed *= exp(-drag * state.step)
	var lateral_grip: float = drift_grip if handbrake else grip
	lateral_grip *= lerpf(1.0, 0.35 if not handbrake else 0.5, _mud_weight)
	if in_water:
		lateral_grip = maxf(lateral_grip, grip)
	var side_acceleration: float = -side_speed * (1.0 - exp(-lateral_grip * state.step)) / state.step
	var drive_force: Vector3 = forward * ((next_speed - speed) / state.step)
	state.apply_central_force(drive_force * mass)
	# A mesma aderência lateral agora inclina a carroceria; aceleração e turbo ficam centrais.
	state.apply_force(
		right * side_acceleration * mass,
		state.center_of_mass - _ground_normal * roll_leverage
	)

	var turn_limit: float = steering_strength / (1.0 + absf(speed) * 0.035)
	if handbrake:
		turn_limit *= lerpf(1.25, 1.55, _mud_weight)
	if in_water:
		turn_limit *= WATER_STEERING_MULTIPLIER
	var target_yaw: float = _steering * minf(absf(speed) * 0.2, turn_limit) * signf(speed)
	var yaw: float = state.angular_velocity.dot(_ground_normal)
	var yaw_acceleration: float = clampf((target_yaw - yaw) * steering_response, -4.0, 4.0)
	var angular_acceleration: Vector3 = _ground_normal * yaw_acceleration

	# A assistência diminui pelo ângulo, sem cortes ao alternar entre duas e quatro rodas.
	var body_up: Vector3 = state.transform.basis.y
	var max_tilt: float = deg_to_rad(stability_max_angle)
	var assistance: float = smoothstep(cos(max_tilt), cos(max_tilt * 0.5), body_up.dot(_ground_normal))
	var tilt_velocity: Vector3 = state.angular_velocity.slide(_ground_normal)
	angular_acceleration += (
		body_up.cross(_ground_normal) * stability
		- tilt_velocity * 2.0 * sqrt(stability)
	) * assistance
	state.apply_torque(state.inverse_inertia_tensor.inverse() * angular_acceleration.limit_length(12.0))


func _apply_manual_roll(state: PhysicsDirectBodyState3D) -> void:
	if ground_contacts >= 3:
		_recovering = false
	var roll_input: float = Input.get_axis("steer_right", "steer_left")
	if is_zero_approx(roll_input):
		return
	var body_contact: bool = state.get_contact_count() > 0
	if (
		ground_contacts < 3 and body_contact and state.transform.basis.y.dot(Vector3.UP) < 0.5
		and state.linear_velocity.length() < 2.0
	):
		_recovering = true
	# Permite pausar e retomar a tentativa; sem A/D nunca aplica torque de recuperação.
	var recovering: bool = (
		_recovering and (body_contact or ground_contacts > 0)
		and state.linear_velocity.length() < 2.0
	)
	# Curva sobre duas rodas não é voo: não mistura roll aéreo com a força lateral.
	var airborne: bool = ground_contacts < 2 and not body_contact
	if not recovering and not airborne:
		return
	var axis: Vector3 = state.transform.basis.z
	var strength: float = recovery_strength if recovering else air_roll_strength
	var roll_speed: float = state.angular_velocity.dot(axis)
	var roll_acceleration: float = clampf(
		(roll_input * air_max_angular_speed - roll_speed) / state.step, -strength, strength
	)
	state.apply_torque(state.inverse_inertia_tensor.inverse() * axis * roll_acceleration)


func reset_vehicle() -> void:
	# A alteração do estado físico acontece somente na próxima integração.
	_reset_requested = true


func _apply_reset(state: PhysicsDirectBodyState3D) -> void:
	var position_now: Vector3 = state.transform.origin
	var query := PhysicsRayQueryParameters3D.create(
		position_now + Vector3.UP * 3.0, position_now + Vector3.DOWN * 10.0,
		collision_mask, [get_rid()]
	)
	query.collide_with_areas = false
	var hit: Dictionary = state.get_space_state().intersect_ray(query)
	var reset_transform: Transform3D = _spawn_transform
	if not hit.is_empty() and hit.normal.dot(Vector3.UP) > MIN_GROUND_DOT:
		var forward: Vector3 = (-state.transform.basis.z).slide(Vector3.UP)
		var heading: float = _spawn_transform.basis.get_euler().y
		if forward.length_squared() > 0.01:
			heading = atan2(-forward.x, -forward.z)
		reset_transform = Transform3D(Basis(Vector3.UP, heading), hit.position + Vector3.UP * 1.25)
	else:
		in_mud = false
		in_water = false
	state.transform = reset_transform
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	state.sleeping = false
	_steering = 0.0
	_wheel_spin = 0.0
	_ground_normal = Vector3.UP
	ground_contacts = 0
	_reset_requested = false
	_recovering = false
	reset_physics_interpolation()


func enter_mud() -> void:
	in_mud = true


func exit_mud() -> void:
	in_mud = false


func enter_water() -> void:
	in_water = true


func exit_water() -> void:
	in_water = false
