extends Node3D
## Efeito visual: lê a van e o contorno da WaterZone, sem aplicar forças.

signal splash_triggered(impact_speed: float, strength: float)

@export_range(0.1, 15.0) var minimum_impact_speed: float = 3.5
@export_range(5.0, 40.0) var strong_impact_speed: float = 20.0
@export_range(0.0, 1.0) var horizontal_weight: float = 0.6
@export_range(0.1, 3.0) var impact_cooldown: float = 1.0
@export_range(0.2, 2.0) var reset_grace_time: float = 0.6
@export_range(0.1, 2.0) var rearm_clearance: float = 0.45

var _polygon = PackedVector2Array()
var _body: RigidBody3D
var _collision: CollisionShape3D
var _hull = PackedVector3Array()
var _wheels: Array[Node3D] = []
var _wet: bool = false
var _armed: bool = true
var _clear_time: float = 0.0
var _cooldown: float = 0.0
var _reset_grace: float = 0.0
var _wheel_radius: float = 0.45
@onready var _zone: Area3D = get_parent() as Area3D
@onready var _emitter: GPUParticles3D = $Spray
@onready var _material: ParticleProcessMaterial = $Spray.process_material


func _ready() -> void:
	var volume: CollisionShape3D = _zone.get_node_or_null("WaterVolume") as CollisionShape3D
	if volume == null or not volume.shape is ConvexPolygonShape3D:
		push_error("WaterImpactSplash: WaterVolume deve conter o volume convexo do lago.")
		set_physics_process(false)
		return
	var points: PackedVector3Array = volume.shape.points
	for i in range(0, points.size(), 2):
		var p: Vector3 = volume.global_transform * points[i]
		_polygon.append(Vector2(p.x, p.z))
	_material = _material.duplicate() as ParticleProcessMaterial
	_emitter.process_material = _material
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _on_body_entered(body: Node3D) -> void:
	if not body is RigidBody3D or not body.has_method("enter_water"):
		return
	_body = body as RigidBody3D
	_wheel_radius = float(body.get_script().get_script_constant_map().get("WHEEL_RADIUS", 0.45))
	_collision = body.get_node("BodyCollision") as CollisionShape3D
	_hull = _collision.shape.points
	_wheels.clear()
	for name_text in ["WheelFrontLeft", "WheelFrontRight", "WheelRearLeft", "WheelRearRight"]:
		_wheels.append(body.get_node(name_text + "/WheelVisual") as Node3D)
	_body.set_meta("water_surface_polygon", _polygon)
	_wet = false
	_armed = true
	_clear_time = 0.0
	set_physics_process(true)


func _on_body_exited(body: Node3D) -> void:
	if body != _body:
		return
	if body.has_meta("water_surface_polygon"):
		body.remove_meta("water_surface_polygon")
	_body = null
	_wet = false


func _surface_probe() -> Vector3:
	var lowest = Vector3(0, INF, 0)
	for wheel in _wheels:
		var p = wheel.global_position - Vector3.UP * _wheel_radius
		if p.y < lowest.y and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), _polygon):
			lowest = p
	# O casco também permite detectar o impacto de lado ou de cabeça para baixo.
	var transform_now: Transform3D = _collision.global_transform
	for vertex in _hull:
		var p = transform_now * vertex
		if p.y < lowest.y and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), _polygon):
			lowest = p
	return lowest


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_reset_grace = maxf(0.0, _reset_grace - delta)
	if not is_instance_valid(_body):
		if _cooldown == 0.0 and _reset_grace == 0.0:
			set_physics_process(false)
		return
	if Input.is_action_pressed("reset_vehicle") or _body.freeze:
		_reset_grace = reset_grace_time
		_armed = false
	var probe = _surface_probe()
	var touching: bool = probe.y <= _zone.global_position.y + 0.05
	if touching and not _wet:
		if _armed and _cooldown == 0.0 and _reset_grace == 0.0:
			var offset = probe - (_body.global_transform * _body.center_of_mass)
			var velocity = _body.linear_velocity + _body.angular_velocity.cross(offset)
			var falling = maxf(0.0, -velocity.y)
			var horizontal = Vector2(velocity.x, velocity.z).length() * horizontal_weight
			var impact_speed = sqrt(falling * falling + horizontal * horizontal)
			if impact_speed >= minimum_impact_speed:
				_emit_impact(impact_speed, probe)
		_armed = false
	if probe.y > _zone.global_position.y + rearm_clearance:
		_clear_time += delta
		if _clear_time >= 0.3 and _reset_grace == 0.0:
			_armed = true
	else:
		_clear_time = 0.0
	_wet = touching


func _emit_impact(impact_speed: float, contact_point: Vector3) -> void:
	var strength = clampf(impact_speed / maxf(strong_impact_speed, minimum_impact_speed), 0.0, 1.0)
	_cooldown = impact_cooldown
	_material.initial_velocity_min = lerpf(1.8, 5.0, strength)
	_material.initial_velocity_max = lerpf(6.0, 11.0, strength)
	_material.scale_min = lerpf(0.5, 0.9, strength)
	_material.scale_max = lerpf(0.9, 1.8, strength)
	_emitter.amount_ratio = lerpf(0.35, 1.0, strength)
	var center = _body.global_position
	if not Geometry2D.is_point_in_polygon(Vector2(center.x, center.z), _polygon):
		center = contact_point
	_emitter.global_position = Vector3(center.x, _zone.global_position.y + 0.12, center.z)
	_emitter.emitting = true
	_emitter.restart()
	splash_triggered.emit(impact_speed, strength)
