extends Node3D
## Controles exclusivos da filmagem; não utiliza nem modifica o Input Map.

@export_range(5.0, 7.0, 0.1) var take_a_duration: float = 6.0
@export_range(6.0, 8.0, 0.1) var take_b_duration: float = 7.0

var _last_take: int = 1
var _tween: Tween
@onready var _van: Node3D = $VanPrototype
@onready var _camera: Camera3D = $CameraRig/FollowCamera


func _ready() -> void:
	_camera.current = true
	_sample_take(0.0, 1)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_1:
			play_take(1)
		KEY_2:
			play_take(2)
		KEY_R:
			play_take(_last_take)
		_:
			return
	get_viewport().set_input_as_handled()


func play_take(take: int) -> void:
	if take != 1 and take != 2:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_last_take = take
	_sample_take(0.0, take)
	_tween = create_tween()
	_tween.tween_method(_sample_take.bind(take), 0.0, 1.0,
		take_a_duration if take == 1 else take_b_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _sample_take(progress: float, take: int) -> void:
	var position_local: Vector3
	var target_local: Vector3
	if take == 1:
		# Revelação frontal: linha reta no centro da van, sem deslocamento lateral.
		position_local = Vector3(0, 1.18, -3.1).lerp(Vector3(0, 3.0, -6.3), progress)
		target_local = Vector3(0, 0.7, -2.0).lerp(Vector3(0, 0.9, 0), progress)
	else:
		var side_end: float = 0.58
		if progress <= side_end:
			# Primeiro desliza em linha reta, paralela à carroceria e sem subir.
			position_local = Vector3(-3.6, 1.5, lerpf(-1.15, 2.6, progress / side_end))
			var rear_focus: float = smoothstep(0.75, 2.6, position_local.z)
			target_local = Vector3(0, 1.05, lerpf(position_local.z, 1.05, rear_focus))
		else:
			# A curva só começa depois da traseira. A primeira tangente mantém
			# direção e velocidade do trecho reto, evitando um tranco na junção.
			var curve_progress: float = (progress - side_end) / (1.0 - side_end)
			var remaining: float = 1.0 - curve_progress
			var tangent_length: float = 3.75 * (1.0 - side_end) / (3.0 * side_end)
			position_local = (
				Vector3(-3.6, 1.5, 2.6) * remaining * remaining * remaining
				+ Vector3(-3.6, 1.5, 2.6 + tangent_length) * 3.0 * remaining * remaining * curve_progress
				+ Vector3(-2.4, 3.6, 7.5) * 3.0 * remaining * curve_progress * curve_progress
				+ Vector3(0, 4, 8) * curve_progress * curve_progress * curve_progress
			)
			# Mantém o final com o offset e a inclinação da câmera de gameplay.
			target_local = Vector3(0, 1.05, 1.05).lerp(
				Vector3(0, 1.8564065, 0), smoothstep(0.0, 1.0, curve_progress)
			)
	var heading: Basis = Basis(Vector3.UP, _van.global_rotation.y)
	_camera.global_position = _van.global_position + heading * position_local
	_camera.look_at(_van.global_position + heading * target_local, Vector3.UP)
