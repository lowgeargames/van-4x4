extends Node3D

## Multiplica a emissão, respeitando o limite fixo de 24 partículas por roda.
@export_range(0.0, 2.0) var intensity: float = 1.0
## Velocidade horizontal mínima para emitir, em m/s.
@export_range(0.1, 5.0) var min_speed: float = 1.5
## Quanto a emissão aumenta por m/s acima da velocidade mínima.
@export_range(0.01, 0.1) var speed_multiplier: float = 0.04

@export_category("Lake Spray")
@export_range(0.1, 2.0) var water_emission_speed: float = 0.35
@export_range(0.03, 0.3) var water_emission_rate: float = 0.12
@export_range(1.0, 6.0) var water_jet_speed: float = 3.0

var _surface: int = -1
var _material: ParticleProcessMaterial
var _base_velocity: float = 1.0
var _previous_speed: float = 0.0
var _surface_fade: GradientTexture1D
var _dust_fade: GradientTexture1D
var _dust_growth: CurveTexture
var _original_mesh: Mesh
var _dust_mesh: QuadMesh
var _water_mesh: QuadMesh
var _water_materials: Array[ParticleProcessMaterial] = []
var _lake_water: bool = false
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
	_surface_fade = fade_texture
	var dust_fade := Gradient.new()
	dust_fade.offsets = PackedFloat32Array([0.0, 0.12, 0.45, 1.0])
	dust_fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	_dust_fade = GradientTexture1D.new()
	_dust_fade.gradient = dust_fade
	_dust_fade.width = 64
	var growth := Curve.new()
	growth.max_value = 1.3
	growth.add_point(Vector2(0.0, 0.85))
	growth.add_point(Vector2(0.3, 0.95))
	growth.add_point(Vector2(1.0, 1.15))
	_dust_growth = CurveTexture.new()
	_dust_growth.curve = growth
	_dust_growth.width = 64
	_original_mesh = _emitters[0].draw_pass_1
	_dust_mesh = _original_mesh.duplicate() as QuadMesh
	_dust_mesh.size = Vector2(0.45, 0.45)
	var dust_draw_material := _dust_mesh.material.duplicate() as StandardMaterial3D
	dust_draw_material.billboard_keep_scale = true
	_dust_mesh.material = dust_draw_material
	_water_mesh = _original_mesh.duplicate() as QuadMesh
	_water_mesh.size = Vector2(0.14, 0.55)
	var water_draw_material := _original_mesh.material.duplicate() as StandardMaterial3D
	water_draw_material.billboard_keep_scale = true
	_water_mesh.material = water_draw_material
	for emitter in _emitters:
		emitter.process_material = _material
		_water_materials.append(_material.duplicate() as ParticleProcessMaterial)


func _process(delta: float) -> void:
	var surface: int = 2 if _van.in_water else (1 if _van.in_mud else 0)
	var lake_water: bool = surface == 2 and _van.has_meta("water_surface_height")
	if surface != _surface or lake_water != _lake_water:
		_lake_water = lake_water
		_set_surface(surface)
	var velocity: Vector3 = _van.linear_velocity
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var side_speed: float = velocity.dot(_van.global_basis.x)
	var slip: float = clampf(absf(side_speed) / 8.0, 0.0, 1.0)
	var accelerating: float = clampf((speed - _previous_speed) / maxf(delta, 0.001) / 9.0, 0.0, 1.0)
	_previous_speed = speed
	var rate: float = 0.12 + maxf(speed - min_speed, 0.0) * speed_multiplier
	if surface == 0:
		# Cruzeiro discreto; aceleração e escorregamento têm mais personalidade.
		rate = 0.08 + maxf(speed - min_speed, 0.0) * speed_multiplier * 0.5
		rate += accelerating * 0.18 + slip * 0.45
		if _van.turbo_active:
			rate += 0.08
	elif surface == 1:
		rate *= 1.0 + 0.35 * absf(Input.get_axis("reverse", "accelerate")) + 0.65 * slip
	elif surface == 2:
		rate *= 1.6
		if _lake_water:
			rate = maxf(0.0, speed - water_emission_speed) * water_emission_rate
			rate += accelerating * 0.25 + slip * 0.25
	_material.spread = lerpf(35.0, 65.0, slip) if surface == 0 else (lerpf(30.0, 70.0, slip) if surface == 1 else 35.0)
	var backwards: float = 1.0 if velocity.dot(-_van.global_basis.z) >= 0.0 else -1.0
	_material.direction = Vector3(clampf(-side_speed * 0.15, -1.2, 1.2), 0.28 if surface == 0 else 0.7, backwards).normalized()
	_material.initial_velocity_max = _base_velocity + minf(speed * (0.05 if surface == 0 else 0.08), 1.3 if surface == 0 else 2.0)
	for i in _emitters.size():
		var ray: RayCast3D = _rays[i]
		var contact: bool = (
			_van.ground_contacts > 0 and ray.is_colliding()
			and ray.get_collision_normal().dot(Vector3.UP) > 0.35
			and ray.get_collision_normal().dot(_van.global_basis.y) > 0.5
		)
		if contact:
			# Proximidade no limite do raio não é apoio. Apenas lê os resultados existentes.
			var reach: float = _van.SUSPENSION_LENGTH + _van.WHEEL_RADIUS + _van.RAY_ORIGIN_OFFSET
			var offset: Vector3 = ray.get_collision_point() - _van.global_position - _van.global_basis * _van.center_of_mass
			var point_velocity: Vector3 = velocity + _van.angular_velocity.cross(offset)
			contact = ray.global_position.distance_to(ray.get_collision_point()) < reach - 0.015 and point_velocity.dot(ray.get_collision_normal()) < 1.0
		if _lake_water:
			var wheel: Vector3 = ray.get_node("WheelVisual").global_position
			var surface_y: float = float(_van.get_meta("water_surface_height"))
			contact = contact and wheel.y - _van.WHEEL_RADIUS <= surface_y + 0.05
			if _van.has_meta("water_surface_polygon"):
				contact = contact and Geometry2D.is_point_in_polygon(Vector2(wheel.x, wheel.z), _van.get_meta("water_surface_polygon"))
			var sideways: Vector3 = _van.global_basis.x.slide(Vector3.UP).normalized() * (-1.0 if i == 0 else 1.0)
			var trailing: Vector3 = -Vector3(velocity.x, 0, velocity.z).normalized()
			_water_materials[i].direction = _emitters[i].global_basis.inverse() * (Vector3.UP * 1.4 + sideways * 0.85 + trailing * 0.45).normalized()
			_water_materials[i].initial_velocity_min = water_jet_speed * 0.6
			_water_materials[i].initial_velocity_max = water_jet_speed + minf(speed * 0.35 + accelerating * 1.0, 3.5)
		if contact:
			_emitters[i].global_position = ray.get_collision_point() + ray.get_collision_normal() * (0.18 if surface == 0 else 0.12)
			if surface == 2 and _van.has_meta("water_surface_height"):
				_emitters[i].global_position.y = maxf(_emitters[i].global_position.y, float(_van.get_meta("water_surface_height")) + 0.12)
		_emitters[i].amount_ratio = clampf(rate * intensity, 0.0, 1.0)
		_emitters[i].emitting = contact and speed > (water_emission_speed if _lake_water else min_speed) and intensity > 0.0


func _set_surface(surface: int) -> void:
	_surface = surface
	_material.color_ramp = _dust_fade if surface == 0 else _surface_fade
	_material.scale_curve = _dust_growth if surface == 0 else null
	_material.initial_velocity_min = 0.45 if surface == 0 else 0.7
	for emitter in _emitters:
		emitter.lifetime = 0.75 if surface == 0 else 0.65
		emitter.draw_pass_1 = _dust_mesh if surface == 0 else _original_mesh
	match surface:
		0: # Poeira pequena e discreta.
			_material.color = Color(0.67, 0.52, 0.34, 0.65)
			_material.gravity = Vector3(0, 0.65, 0)
			_material.scale_min = 1.2
			_material.scale_max = 2.1
			_base_velocity = 0.85
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
	# Só o lago opta pelos novos jatos. Poeira, lama e água antiga ficam intactas.
	for i in _emitters.size():
		if surface == 2 and _lake_water:
			var water_material: ParticleProcessMaterial = _water_materials[i]
			water_material.color = Color(0.5, 0.78, 0.7, 0.85)
			water_material.color_ramp = _surface_fade
			water_material.gravity = Vector3(0, -7.0, 0)
			water_material.scale_min = 0.8
			water_material.scale_max = 1.5
			water_material.spread = 22.0
			water_material.particle_flag_align_y = true
			_emitters[i].process_material = water_material
			_emitters[i].draw_pass_1 = _water_mesh
			_emitters[i].lifetime = 0.8
		else:
			_emitters[i].process_material = _material
