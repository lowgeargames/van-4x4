extends Node3D


@export_category("Follow")

@export var follow_speed: float = 6.0
@export var rotation_speed: float = 5.0


@onready var target: Node3D = $"../VanPrototype"


func _ready() -> void:
	global_position = target.global_position
	rotation.y = target.global_rotation.y


func _process(delta: float) -> void:
	follow_target(delta)
	follow_rotation(delta)


func follow_target(delta: float) -> void:
	var weight := 1.0 - exp(-follow_speed * delta)

	global_position = global_position.lerp(
		target.global_position,
		weight
	)


func follow_rotation(delta: float) -> void:
	var weight := 1.0 - exp(-rotation_speed * delta)

	rotation.y = lerp_angle(
		rotation.y,
		target.global_rotation.y,
		weight
	)

	# A câmera não deve inclinar junto quando a van
	# sobe rampas ou capota.
	rotation.x = 0.0
	rotation.z = 0.0
