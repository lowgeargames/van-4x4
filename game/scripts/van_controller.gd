extends VehicleBody3D


@export_category("Engine")

@export var engine_power: float = 4000.0
@export var reverse_power: float = 3000.0
@export var brake_force: float = 100.0


@export_category("Steering")

@export var max_steer_angle: float = 0.5
@export var steering_speed: float = 2.5


func _physics_process(delta: float) -> void:
	handle_engine()
	handle_steering(delta)
	handle_reset()


func handle_engine() -> void:
	# Freio de mão
	if Input.is_action_pressed("handbrake"):
		engine_force = 0.0
		brake = brake_force
		return

	brake = 0.0

	# W - direção que estamos considerando como "frente"
	if Input.is_action_pressed("accelerate"):
		engine_force = -engine_power

	# S - ré
	elif Input.is_action_pressed("reverse"):
		engine_force = reverse_power

	# Nenhuma tecla
	else:
		engine_force = 0.0


func handle_steering(delta: float) -> void:
	var steering_input := Input.get_axis(
		"steer_right",
        "steer_left"
	)

	var target_steering := steering_input * max_steer_angle

	steering = move_toward(
		steering,
		target_steering,
		steering_speed * delta
	)


func handle_reset() -> void:
	if Input.is_action_just_pressed("reset_vehicle"):
		reset_vehicle()


func reset_vehicle() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	global_position += Vector3.UP * 1.5

	global_rotation = Vector3(
		0.0,
		global_rotation.y,
		0.0
	)
