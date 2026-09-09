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
## Distância virtual abaixo do centro de massa, em metros; maior = mais roll nas curvas.
@export_range(0.0, 3.0, 0.05) var roll_leverage: float = 1.65

@export_category("Suspension")
## Rigidez por unidade de massa apoiada; amortecimento calculado automaticamente.
@export_range(60.0, 200.0) var suspension_strength: float = 120.0

# Geometria compartilhada pelas quatro rodas; não são ajustes de dirigibilidade.
const WHEEL_RADIUS: float = 0.45
const SUSPENSION_LENGTH: float = 0.38
const MIN_GROUND_DOT: float = 0.35

var in_mud: bool = false
var ground_contacts: int = 0
var _ground_normal: Vector3 = Vector3.UP
var _steering: float = 0.0
var _mud_weight: float = 0.0
var _wheel_spin: float = 0.0
var _reset_requested: bool = false
var _spawn_transform: Transform3D
var _wheel_visuals: Array[Node3D] = []

@onready var _rays: Array[RayCast3D] = [
	$WheelFrontLeft, $WheelFrontRight, $WheelRearLeft, $WheelRearRight
]


func _ready() -> void:
	_spawn_transform = global_transform
	for ray in _rays:
		# Atualizados explicitamente na integração, sem uma segunda consulta automática.
		ray.enabled = false
		ray.target_position = Vector3.DOWN * (SUSPENSION_LENGTH + WHEEL_RADIUS)
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
	# Sem apoio: somente gravidade, colisões e amortecimento angular leve do corpo.


func _update_suspension(state: PhysicsDirectBodyState3D) -> bool:
	ground_contacts = 0
	var normal_sum: Vector3 = Vector3.ZERO
	var left_contact: bool = false
	var right_contact: bool = false
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
					ray.global_position.distance_to(hit) - WHEEL_RADIUS,
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
				left_contact = left_contact or ray.position.x < 0.0
				right_contact = right_contact or ray.position.x > 0.0

		var visual: Node3D = _wheel_visuals[i]
		visual.position = Vector3.DOWN * length
		# O cilindro gira em torno do próprio centro, sem deslocamento excêntrico.
		var steer_angle: float = _steering * 0.38 if i < 2 else 0.0
		visual.basis = Basis(Vector3.UP, steer_angle) * Basis(Vector3.RIGHT, -_wheel_spin)
		visual.basis *= Basis(Vector3.FORWARD, PI / 2.0)

	if ground_contacts < 2 or not left_contact or not right_contact:
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
			next_speed = move_toward(speed, target, drive_acceleration * state.step)
	else:
		next_speed = speed * exp(-drag * state.step)

	# A resistência da superfície atua no plano de apoio, nunca no salto.
	if not handbrake and not is_zero_approx(throttle) and speed * throttle >= -0.15:
		next_speed *= exp(-drag * state.step)
	var lateral_grip: float = drift_grip if handbrake else grip
	lateral_grip *= lerpf(1.0, 0.35 if not handbrake else 0.5, _mud_weight)
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
	var target_yaw: float = _steering * minf(absf(speed) * 0.2, turn_limit) * signf(speed)
	var yaw: float = state.angular_velocity.dot(_ground_normal)
	var yaw_acceleration: float = clampf((target_yaw - yaw) * steering_response, -4.0, 4.0)
	var angular_acceleration: Vector3 = _ground_normal * yaw_acceleration

	# Corrige inclinações pequenas em relação ao terreno; não desvira um capotamento.
	var body_up: Vector3 = state.transform.basis.y
	var assistance: float = smoothstep(0.5, 0.9, body_up.dot(_ground_normal))
	var tilt_velocity: Vector3 = state.angular_velocity.slide(_ground_normal)
	angular_acceleration += (
		body_up.cross(_ground_normal) * stability
		- tilt_velocity * 2.0 * sqrt(stability)
	) * assistance
	state.apply_torque(state.inverse_inertia_tensor.inverse() * angular_acceleration.limit_length(12.0))


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
	state.transform = reset_transform
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	state.sleeping = false
	_steering = 0.0
	_wheel_spin = 0.0
	_ground_normal = Vector3.UP
	ground_contacts = 0
	_reset_requested = false
	reset_physics_interpolation()


func enter_mud() -> void:
	in_mud = true


func exit_mud() -> void:
	in_mud = false
