extends Node
## Prepara os emissores reais antes de liberar o gameplay.
signal prepared

const VanController = preload("res://scripts/van_controller.gd")
const FIRST_DRAW_TIMEOUT_MS: int = 12000
const EMITTER_TIMEOUT_MS: int = 6000

@export var van_path: NodePath = NodePath("../VanPrototype")
@export var particle_paths: Array[NodePath] = []
## Caminhos opcionais para compatibilidade com as cenas de missão e ensaio.
@export var repair_path: NodePath = NodePath("../RepairAntenna")
@export var monitor_path: NodePath = NodePath("../StuntRewards/StuntMonitor")
@export var input_owner_path: NodePath = NodePath("../SessionController")

## Sinaliza que o carregamento liberou o gameplay, mesmo em modo headless ou após fallback.
var is_prepared: bool = false
var warmup_succeeded: bool = false

var _started: bool = false
var _van: VanController
var _was_frozen: bool
var _manages_input: bool
var _input_was_enabled: bool
var _dust: Node
var _dust_processing: bool
var _repair: Node
var _repair_active: bool
var _monitor: Node
var _monitor_active: bool
var _overlay: CanvasLayer
var _tree_preview: Node3D
var _deadline_ms: int
var _emitters: Array[GPUParticles3D] = []
var _tree_meshes: Array[Mesh] = []
var _originals: Dictionary = {}
var _pending: Dictionary = {}


func _ready() -> void:
	if _started:
		return
	_started = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_van = get_node_or_null(van_path) as VanController
	if _van != null:
		_was_frozen = _van.freeze
		_van.freeze = true
		_manages_input = get_node_or_null(input_owner_path) == null
		if _manages_input:
			_input_was_enabled = _van.player_input_enabled
			_van.set_player_input_enabled(false)
	_prepare.call_deferred()


func _prepare() -> void:
	if is_prepared or is_processing() or not is_inside_tree():
		return
	if DisplayServer.get_name() == "headless":
		_finish(false)
		return

	_collect_emitters()
	if _emitters.is_empty() and _tree_meshes.is_empty():
		_finish(false)
		return

	# O ensaio já suspende esses nós no _ready. Guarde o estado depois disso.
	_repair = get_node_or_null(repair_path)
	if _repair != null and (not _repair.has_method("set_active") or not "active" in _repair):
		push_warning("VisualWarmup: o nó opcional de reparo não oferece set_active/active.")
		_repair = null
	if _repair != null:
		_repair_active = _repair.active
		_repair.set_active(false)
	_monitor = get_node_or_null(monitor_path)
	if _monitor != null:
		_monitor_active = _monitor.is_physics_processing()
		_monitor.set_physics_process(false)

	_show_overlay()
	_deadline_ms = Time.get_ticks_msec() + FIRST_DRAW_TIMEOUT_MS
	set_process(true)
	# O primeiro quadro também permite que SurfaceParticles configure a poeira.
	RenderingServer.frame_post_draw.connect(_start_emitters, CONNECT_ONE_SHOT)


func _collect_emitters() -> void:
	if not particle_paths.is_empty():
		for path in particle_paths:
			_add_emitter(get_node_or_null(path))
	elif _van != null:
		_add_emitter(_van.get_node_or_null("SurfaceParticles/RearLeft"))
		_add_emitter(_van.get_node_or_null("SurfaceParticles/RearRight"))
	# Descoberta restrita aos componentes que já fornecem árvores destrutíveis.
	for nature in get_parent().find_children("*", "Node3D", true, false):
		if not nature.has_signal("tree_broken"):
			continue
		if particle_paths.is_empty():
			_add_emitter(nature.get_node_or_null("BreakFragments"))
			_add_emitter(nature.get_node_or_null("BreakFragments/Leaves"))
		if "tree_bindings" in nature:
			for binding in nature.tree_bindings:
				var visual := nature.get_node_or_null(binding.path) as MultiMeshInstance3D
				if visual != null and visual.multimesh != null:
					var mesh: Mesh = visual.multimesh.mesh
					if mesh != null and not _tree_meshes.has(mesh):
						_tree_meshes.append(mesh)


func _add_emitter(node: Node) -> void:
	if node is GPUParticles3D and not _emitters.has(node):
		_emitters.append(node)


func _show_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	add_child(_overlay)
	var background := ColorRect.new()
	background.color = Color(0.04, 0.055, 0.065, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(background)
	var label := Label.new()
	label.text = "PREPARANDO TERRENO..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(label)


func _start_emitters() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		push_warning("VisualWarmup: nenhuma câmera ativa para preparar os emissores.")
		_finish(false)
		return
	_dust = _van.get_node_or_null("SurfaceParticles") if is_instance_valid(_van) else null
	if _dust != null:
		_dust_processing = _dust.is_processing()
		_dust.set_process(false)
	# Guarde todas as transformações locais antes de mover o emissor pai das folhas.
	for emitter in _emitters:
		if not is_instance_valid(emitter):
			continue
		var callback := _on_emitter_finished.bind(emitter)
		_originals[emitter] = {
			"transform": emitter.transform, "ratio": emitter.amount_ratio,
			"one_shot": emitter.one_shot, "emitting": emitter.emitting,
			"callback": callback,
		}
		_pending[emitter] = str(emitter.get_path())
		emitter.finished.connect(callback, CONNECT_ONE_SHOT)
	if _pending.is_empty() and _tree_meshes.is_empty():
		_finish(false)
		return
	# Use relógio monotônico: o delta do primeiro desenho pode vir acumulado.
	_deadline_ms = Time.get_ticks_msec() + EMITTER_TIMEOUT_MS
	var origin := camera.global_position - camera.global_basis.z * 6.0
	for i in _emitters.size():
		var emitter := _emitters[i]
		if not is_instance_valid(emitter):
			continue
		# Dentro do frustum, atrás do painel opaco, com o material original.
		emitter.global_position = origin + camera.global_basis.x * (i * 0.3)
		emitter.amount_ratio = 1.0
		emitter.one_shot = true
		emitter.emitting = true
		emitter.restart(true)
	_draw_tree_meshes(camera)


func _draw_tree_meshes(camera: Camera3D) -> void:
	if _tree_meshes.is_empty():
		return
	# A queda usa MeshInstance3D, que tem uma variante gráfica diferente do MultiMesh.
	_tree_preview = Node3D.new()
	add_child(_tree_preview)
	var origin := camera.global_position - camera.global_basis.z * 10.0
	for i in _tree_meshes.size():
		var preview := MeshInstance3D.new()
		preview.mesh = _tree_meshes[i]
		_tree_preview.add_child(preview)
		var offset: float = (i - (_tree_meshes.size() - 1) * 0.5) * 1.5
		preview.global_position = origin + camera.global_basis.x * offset - preview.mesh.get_aabb().get_center()
	RenderingServer.frame_post_draw.connect(_on_tree_meshes_drawn, CONNECT_ONE_SHOT)


func _on_tree_meshes_drawn() -> void:
	_remove_tree_preview()
	if _pending.is_empty():
		_finish(true)


func _remove_tree_preview() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_tree_meshes_drawn):
		RenderingServer.frame_post_draw.disconnect(_on_tree_meshes_drawn)
	if is_instance_valid(_tree_preview):
		_tree_preview.hide()
		_tree_preview.queue_free()
		_tree_preview = null


func _on_emitter_finished(emitter: GPUParticles3D) -> void:
	_pending.erase(emitter)
	if _pending.is_empty() and _tree_preview == null:
		_finish(true)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() < _deadline_ms:
		return
	if _tree_preview != null and _pending.is_empty():
		push_warning("VisualWarmup: tempo limite ao aguardar o desenho das malhas de queda.")
	elif _pending.is_empty():
		push_warning("VisualWarmup: tempo limite ao aguardar o primeiro quadro.")
	else:
		push_warning("VisualWarmup: emissores não concluídos no tempo limite: " + ", ".join(_pending.values()))
	_finish(false)


func _finish(succeeded: bool) -> void:
	if is_prepared:
		return
	is_prepared = true
	warmup_succeeded = succeeded
	_restore()
	prepared.emit()


func _restore() -> void:
	set_process(false)
	if RenderingServer.frame_post_draw.is_connected(_start_emitters):
		RenderingServer.frame_post_draw.disconnect(_start_emitters)
	_remove_tree_preview()
	_tree_meshes.clear()
	for emitter in _originals:
		if not is_instance_valid(emitter):
			continue
		var state: Dictionary = _originals[emitter]
		if emitter.finished.is_connected(state.callback):
			emitter.finished.disconnect(state.callback)
		# No fallback, descarta a emissão ainda ativa antes de liberar a tela.
		if _pending.has(emitter):
			emitter.restart(true)
		emitter.transform = state.transform
		emitter.amount_ratio = state.ratio
		emitter.one_shot = state.one_shot
		emitter.emitting = state.emitting
	_originals.clear()
	_pending.clear()
	_emitters.clear()
	if is_instance_valid(_dust):
		_dust.set_process(_dust_processing)
	if is_instance_valid(_repair):
		_repair.set_active(_repair_active)
	if is_instance_valid(_monitor):
		_monitor.set_physics_process(_monitor_active)
	if is_instance_valid(_overlay):
		_overlay.hide()
		_overlay.queue_free()
		_overlay = null
	if is_instance_valid(_van):
		_van.freeze = _was_frozen
		if _manages_input:
			_van.set_player_input_enabled(_input_was_enabled)


func _exit_tree() -> void:
	if not is_prepared:
		_restore()
