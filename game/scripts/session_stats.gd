extends RefCounted
## Coletor de uma sessão; não detecta manobras nem aplica forças.
const StuntMonitor = preload("res://scripts/stunt_monitor.gd")
const TREE_POINTS: int = 100
const PROP_POINTS: int = 25
var _active: bool = false
var _data: Dictionary = {
	"elapsed_time": 0.0, "distance": 0.0, "jumps": 0,
	"longest_jump": 0.0, "longest_air_time": 0.0, "total_air_time": 0.0,
	"pitch_rotations": 0, "roll_rotations": 0, "rotations": 0,
	"clean_landings": 0, "brutal_landings": 0, "rollovers": 0,
	"trees_broken": 0, "points": 0, "stars": 0,
	"crates_hit": 0, "barrels_hit": 0, "cones_hit": 0, "props_hit": 0,
	"tree_points": 0, "prop_points": 0, "total_points": 0,
}
var _result: Dictionary = {}
var _trees: Dictionary = {}
var _props: Dictionary = {}
var _baseline_points: int = 0
var _baseline_stars: int = 0
var _last_stars: int = 0
var _previous_position: Vector3
var _previous_speed: float = 0.0
var _skip_next_sample: bool = false


func start(van: RigidBody3D, points: int, stars: int) -> void:
	_baseline_points = points
	_baseline_stars = stars
	_last_stars = stars
	_previous_position = van.global_position
	_previous_speed = van.linear_velocity.length()
	_active = true


func sample_motion(van: RigidBody3D, delta: float, reset_requested: bool) -> void:
	if not _active:
		return
	var position_now: Vector3 = van.global_position
	var speed: float = van.linear_velocity.length()
	var displacement: float = position_now.distance_to(_previous_position)
	# Margem ligada ao raio da roda, não à velocidade máxima de direção.
	# O envelope acompanha velocidades reais, inclusive em saltos/turbo rápidos.
	var motion_budget: float = maxf(speed, _previous_speed) * delta * 2.0 + van.WHEEL_RADIUS
	if not reset_requested and not _skip_next_sample and displacement <= motion_budget:
		_data.distance += displacement
	# R pode ser aplicado na integração seguinte: descarta também essa amostra.
	_skip_next_sample = reset_requested
	_previous_position = position_now
	_previous_speed = speed


func record_stunt(result: Dictionary) -> void:
	if not _active or int(result.session_stars) <= _last_stars:
		return
	# session_stars cresce em toda façanha válida (ao menos uma estrela).
	# Serve como sequência do monitor único, sem criar outro contador nele.
	_last_stars = int(result.session_stars)
	_data.jumps += 1
	_data.longest_jump = maxf(_data.longest_jump, result.distance)
	_data.longest_air_time = maxf(_data.longest_air_time, result.air_time)
	_data.total_air_time += result.air_time
	_data.pitch_rotations += result.pitch_rotations
	_data.roll_rotations += result.roll_rotations
	_data.rotations += result.rotations
	match result.landing:
		StuntMonitor.Landing.CLEAN: _data.clean_landings += 1
		StuntMonitor.Landing.BRUTAL: _data.brutal_landings += 1
		StuntMonitor.Landing.ROLLOVER: _data.rollovers += 1
	# Usa o acumulado real, sem somar novamente os pontos individuais.
	_data.points = int(result.session_points) - _baseline_points
	_data.stars = int(result.session_stars) - _baseline_stars
	_update_total()


func record_tree(source_id: int, index: int) -> void:
	if not _active:
		return
	var key: String = "%d:%d" % [source_id, index]
	if not _trees.has(key):
		_trees[key] = true
		_data.trees_broken += 1
		_data.tree_points += TREE_POINTS
		_update_total()


func record_prop(instance_id: int, category: String) -> void:
	if not _active or _props.has(instance_id):
		return
	var field: String = {"crate": "crates_hit", "barrel": "barrels_hit", "cone": "cones_hit"}.get(category, "")
	if field.is_empty():
		return
	_props[instance_id] = true
	_data[field] += 1
	_data.props_hit += 1
	_data.prop_points += PROP_POINTS
	_update_total()


func _update_total() -> void:
	# points mantém o significado anterior: somente façanhas do monitor.
	_data.total_points = _data.points + _data.tree_points + _data.prop_points


func finish(elapsed_time: float) -> void:
	if not _active:
		return
	_active = false
	_data.elapsed_time = elapsed_time
	_result = _data.duplicate(true)
	_result.make_read_only()


func get_snapshot() -> Dictionary:
	if not _active and not _result.is_empty():
		return _result
	var snapshot: Dictionary = _data.duplicate(true)
	snapshot.make_read_only()
	return snapshot
