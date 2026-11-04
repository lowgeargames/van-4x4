extends Node
## Primeira utilização gráfica dos emissores reais, antes dos comandos do jogador.
signal prepared
var is_prepared: bool = false


func _ready() -> void:
	_prepare.call_deferred()
	# No ensaio, o controlador de sessão já é o dono do bloqueio de entradas.
	if not get_parent().has_node("SessionController"):
		get_node("../VanPrototype").set_player_input_enabled(false)


func _prepare() -> void:
	var level: Node = get_parent()
	if DisplayServer.get_name() == "headless":
		# Sem renderer não há preparação gráfica possível.
		is_prepared = true
		if not level.has_node("SessionController"):
			level.get_node("VanPrototype").set_player_input_enabled(true)
		prepared.emit()
		return
	var van = level.get_node("VanPrototype")
	var antenna = level.get_node("RepairAntenna")
	var monitor = level.get_node("StuntRewards/StuntMonitor")
	var repair_active: bool = antenna.active
	var monitor_active: bool = monitor.is_physics_processing()
	antenna.set_active(false)
	monitor.set_physics_process(false)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	var background := ColorRect.new()
	background.color = Color(0.04, 0.055, 0.065, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	var label := Label.new()
	label.text = "PREPARANDO TERRENO..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(label)
	# Inclui o primeiro desenho do cenário e a configuração inicial da poeira.
	await RenderingServer.frame_post_draw
	var dust = van.get_node("SurfaceParticles")
	var dust_processing: bool = dust.is_processing()
	dust.set_process(false)
	var emitters: Array[GPUParticles3D] = [dust.get_node("RearLeft"), dust.get_node("RearRight")]
	for nature in level.find_children("*", "Node3D", true, false):
		if nature.has_signal("tree_broken"):
			emitters.append(nature.get_node("BreakFragments"))
			emitters.append(nature.get_node("BreakFragments/Leaves"))
	var camera: Camera3D = get_viewport().get_camera_3d()
	var originals: Array[Dictionary] = []
	var pending: Array[GPUParticles3D] = []
	for i in emitters.size():
		var emitter: GPUParticles3D = emitters[i]
		originals.append({"transform": emitter.global_transform, "ratio": emitter.amount_ratio, "one_shot": emitter.one_shot})
		pending.append(emitter)
		emitter.finished.connect(func(): pending.erase(emitter), CONNECT_ONE_SHOT)
		# Dentro do frustum, com os materiais, meshes e simulação originais.
		emitter.global_position = camera.global_position - camera.global_basis.z * 6.0 + camera.global_basis.x * (i * 0.3)
		emitter.amount_ratio = 1.0
		# Um ciclo real permite aguardar finished, inclusive na poeira contínua.
		emitter.one_shot = true
		emitter.emitting = true
		emitter.restart()
	# Espera as partículas realmente terminarem, sem sobras visíveis no gameplay.
	while not pending.is_empty():
		await RenderingServer.frame_post_draw
	for i in emitters.size():
		emitters[i].emitting = false
		emitters[i].global_transform = originals[i].transform
		emitters[i].amount_ratio = originals[i].ratio
		emitters[i].one_shot = originals[i].one_shot
	dust.set_process(dust_processing)
	antenna.set_active(repair_active)
	monitor.set_physics_process(monitor_active)
	overlay.free()
	is_prepared = true
	if not level.has_node("SessionController"):
		van.set_player_input_enabled(true)
	prepared.emit()
