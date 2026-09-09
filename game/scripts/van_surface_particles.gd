extends Node3D

## Multiplica a emissão, respeitando o limite fixo de 24 partículas por roda.
@export_range(0.0, 2.0) var intensity: float = 1.0
## Velocidade horizontal mínima para emitir, em m/s.
@export_range(0.1, 5.0) var min_speed: float = 1.5
## Quanto a emissão aumenta por m/s acima da velocidade mínima.
@export_range(0.01, 0.1) var speed_multiplier: float = 0.04

var _surface: int = -1
var _material: ParticleProcessMaterial
var _base_velocity: float = 1.0
@onready var _van = get_parent()
@onready var _rays: Array[RayCast3D] = [
	get_parent().get_node("WheelRearLeft"), get_parent().get_node("WheelRearRight")
]
@onready var _emitters: Array[GPUParticles3D] = [$RearLeft, $RearRight]


func _ready() -> void:
	# Compartilhado apenas pelos dois emissores desta van, sem modificar o recurso da cena.
	_material = ParticleProcessMaterial.new()
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_material.emission_sphere_radius = 0.12
	_material.initial_velocity_min = 0.7
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.1, 0.55, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	fade_texture.width = 64
	_material.color_ramp = fade_texture
	for emitter in _emitters:
		emitter.process_material = _material


func _process(_delta: float) -> void:
	var surface: int = 2 if _van.in_water else (1 if _van.in_mud else 0)
	if surface != _surface:
		_set_surface(surface)
	var velocity: Vector3 = _van.linear_velocity
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var side_speed: float = velocity.dot(_van.global_basis.x)
	var slip: float = clampf(absf(side_speed) / 8.0, 0.0, 1.0)
	var rate: float = 0.12 + maxf(speed - min_speed, 0.0) * speed_multiplier
	if surface == 1:
		rate *= 1.0 + 0.35 * absf(Input.get_axis("reverse", "accelerate")) + 0.65 * slip
	elif surface == 2:
		rate *= 1.6
	_material.spread = lerpf(30.0, 70.0, slip) if surface == 1 else 35.0
	var backwards: float = 1.0 if velocity.dot(-_van.global_basis.z) >= 0.0 else -1.0
	_material.direction = Vector3(clampf(-side_speed * 0.15, -1.2, 1.2), 0.7, backwards).normalized()
	_material.initial_velocity_max = _base_velocity + minf(speed * 0.08, 2.0)
	for i in _emitters.size():
		var ray: RayCast3D = _rays[i]
		var contact: bool = (
			_van.ground_contacts > 0 and ray.is_colliding()
			and ray.get_collision_normal().dot(Vector3.UP) > 0.35
			and ray.get_collision_normal().dot(_van.global_basis.y) > 0.5
		)
		if contact:
			_emitters[i].global_position = ray.get_collision_point() + ray.get_collision_normal() * 0.12
		_emitters[i].amount_ratio = clampf(rate * intensity, 0.0, 1.0)
		_emitters[i].emitting = contact and speed > min_speed and intensity > 0.0


func _set_surface(surface: int) -> void:
	_surface = surface
	match surface:
		0: # Poeira pequena e discreta.
			_material.color = Color(0.64, 0.60, 0.51, 0.45)
			_material.gravity = Vector3(0, 0.3, 0)
			_material.scale_min = 1.0
			_material.scale_max = 2.0
			_base_velocity = 1.0
		1: # Grumos mais compactos, com dispersão adicional no drift.
			_material.color = Color(0.32, 0.16, 0.065, 0.95)
			_material.gravity = Vector3(0, -4.0, 0)
			_material.scale_min = 0.5
			_material.scale_max = 1.0
			_base_velocity = 2.0
		2: # Gotas claras, curtas e sem colisão.
			_material.color = Color(0.65, 0.86, 1.0, 0.9)
			_material.gravity = Vector3(0, -4.0, 0)
			_material.scale_min = 0.6
			_material.scale_max = 1.3
			_base_velocity = 2.6
