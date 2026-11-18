extends Node3D
## Laboratório de áudio do motor V8 (Van 4x4). Este script é o ÚNICO dono do estado da
## demonstração; a interface (lab_ui.gd) é só apresentação e chama as funções
## `action_*` abaixo, exatamente as mesmas que os atalhos de teclado usam.
## O componente VanEngineAudio fica fora do veículo (irmão dele) e o FakeVan só simula
## as entradas que o áudio lê. Nada aqui depende da GameSession.
##
## Mouse: tudo na tela. Teclado (opcional, também listado em F3 > Atalhos):
##   T teste automático liga/desliga · Enter (re)inicia · R para e zera
##   Q teste A · E teste B · F teste C · F3 diagnóstico técnico
##   7/8 transmissão · 9/0 perfil rápido/calibrado · P acelerador parcial
##   1 versão A · 2 alternativa B · 5 referência anterior · 6 efeito curto (Mustang 1969)
##   3/4 trava/solta a velocidade · W/S acelerar/frear · B freio suave · Shift turbo (só estado)
##   Espaço voo · M lama · N piso irregular · V vincula · X remove/restaura a van · C motor
##   +/- volume

const VanEngineAudio = preload("res://audio/van_engine_audio.gd")
const DemoVehicle = preload("res://audio/demo/demo_vehicle_stub.gd")
const LabUI = preload("res://audio/demo/lab_ui.gd")
const Style = preload("res://audio/demo/lab_style.gd")

# ---------------------------------------------------------------- teste automático
const STAGE_COUNT: int = 9
const STAGE_NAMES: Array[String] = [
	"",
	"MARCHA LENTA INICIAL",
	"ARRANCADA PROGRESSIVA",
	"PRIMEIRA TROCA",
	"SEGUNDA TROCA",
	"ACELERAÇÃO ATÉ A VELOCIDADE DO PERFIL",
	"VELOCIDADE CONSTANTE",
	"DESACELERAÇÃO PROGRESSIVA",
	"REDUÇÕES DE MARCHA",
	"PARADA E MARCHA LENTA",
]
const STAGE_HINTS: Array[String] = [
	"",
	"parado, motor em marcha lenta",
	"acelerador pleno a partir da parada",
	"até a troca da 1ª para a 2ª",
	"até a troca da 2ª para a 3ª",
	"acelerando até estabilizar",
	"velocidade travada, sem trocas nem pulsos",
	"solta o acelerador e freia suave",
	"acompanha as reduções até parar",
	"parou; volta à marcha lenta",
]
## Duração típica de cada etapa (s), só para o indicador de progresso.
const STAGE_NOMINAL: Array[float] = [1.0, 3.0, 1.0, 2.5, 3.5, 6.0, 8.0, 5.0, 3.0, 4.0]

const IDLE_MIN_TIME: float = 3.0
const IDLE_MAX_TIME: float = 7.0
const IDLE_SETTLED_RPM: float = 0.05
const IDLE_SETTLED_SURGE: float = 0.10
const LAUNCH_SPEED_FRACTION: float = 0.10
const LAUNCH_MAX_TIME: float = 2.5
const SHIFT_STAGE_MAX_TIME: float = 10.0
const AUTO_ACCEL_MAX_TIME: float = 22.0
const AUTO_REACHED_FRACTION: float = 0.96
const AUTO_REACHED_HOLD: float = 1.5
const AUTO_CRUISE_TIME: float = 8.0
const AUTO_BRAKE_DECEL: float = 3.0
const AUTO_BRAKE_MAX_TIME: float = 16.0
const AUTO_DECEL_END_FRACTION: float = 0.30
const AUTO_IDLE_TIME: float = 4.0
const RUN_MARKS_KMH: Array[float] = [30.0, 60.0, 80.0]

const FLASH_TIME: float = 1.1
const NOTICE_TIME: float = 2.6

## Testes de comparação: combinações de configurações já existentes.
##   A calibrado + transmissão · B calibrado sem transmissão · C rápido + transmissão
const PRESETS: Dictionary = {
	"A": {"profile": 1, "transmission": true},
	"B": {"profile": 1, "transmission": false},
	"C": {"profile": 0, "transmission": true},
}
const PROFILE_INFO: Array[String] = [
	"9 m/s² constantes · 0–80 km/h em ~2,5 s",
	"cai com a velocidade · 0–80 km/h em ~5,6 s",
]

# ------------------------------------------------------------ pré-escuta de efeitos
## Gravações escolhidas na próxima etapa vão em res://audio/sfx/preview/<pasta>/.
const SFX_DIR: String = "res://audio/sfx/preview/"
const SFX_CATEGORIES: Array = [
	["arvore", "Árvore quebrando"],
	["madeira_folhas", "Madeira e folhas"],
	["caixas", "Impacto em caixas"],
	["barris", "Impacto em barris"],
	["aterrissagem", "Aterrissagem"],
	["agua", "Água"],
]
const SFX_EXTENSIONS: Array[String] = ["wav", "ogg", "mp3"]

## Efeitos de gameplay (componente reutilizável). No laboratório os eventos acontecem num
## ponto fixo, onde fica a van, e a câmera de teste faz o papel de ouvinte.
const SfxScript = preload("res://audio/gameplay_sfx.gd")
const SFX_LAB_POINT: Vector3 = Vector3(0.0, 0.5, 0.0)
const SFX_REPEAT_INTERVAL: float = 1.2
const SFX_BURST_COUNT: int = 6
const SFX_BURST_INTERVAL: float = 0.09

@onready var _vehicle: DemoVehicle = $FakeVan as DemoVehicle
@onready var _audio: VanEngineAudio = $VanEngineAudio as VanEngineAudio

## Modos de comparação sonora: [valor do componente, título, subtítulo].
var sound_modes: Array = []

# Estado da demonstração (fonte única; a interface só lê).
var _profile: int = DemoVehicle.PROFILE_GRADUAL
var _partial: bool = false
var _rough: bool = false
var _mud: bool = false
var _air: bool = false
var _ui_gas: bool = false
var _ui_brake: bool = false
var _ui_drive_active: bool = false

var _stage: int = 0
var _stage_time: float = 0.0
var _test_time: float = 0.0
var _test_done: bool = false
var _test_label: String = ""
var _peak_gear: int = 1
var _reached_time: float = 0.0

var _run_active: bool = false
var _run_from_stop: bool = false
var _run_time: float = 0.0
var _run_marks: Array[float] = [-1.0, -1.0, -1.0]

var _gear_seen: int = 0
var _flash_from: int = 0
var _flash_to: int = 0
var _flash_up: bool = true
var _flash_t: float = 0.0

var _notice: String = ""
var _notice_t: float = 0.0

var _ui: LabUI = null
var _vehicle_template: Node = null
var _sfx_player: AudioStreamPlayer = null
var _sfx_files: Dictionary = {}
var _sfx_playing: String = ""

var _gsfx: SfxScript = null
var _sfx_intensity: float = 0.7
var _sfx_event: String = ""
var _sfx_repeat: bool = false
var _sfx_repeat_t: float = 0.0
var _sfx_burst_left: int = 0
var _sfx_burst_t: float = 0.0
var _sfx_engine_muted: bool = false
var _engine_before_mute: bool = true


func _ready() -> void:
	_vehicle_template = _vehicle.duplicate()
	sound_modes = [
		[VanEngineAudio.AccelMode.DYNAMIC, "VERSÃO A", "aprovada"],
		[VanEngineAudio.AccelMode.IDLE_ONLY, "ALTERNATIVA B", "só marcha lenta"],
		[VanEngineAudio.AccelMode.CONTINUOUS, "REFERÊNCIA ANTERIOR", "loop contínuo"],
		[VanEngineAudio.AccelMode.BLIP, "EFEITO CURTO", "Mustang 1969"],
	]
	# O 3D só serve de ouvinte do som: a câmera continua, mas não desenha nada.
	var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		camera.cull_mask = 0
	var old_hud: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
	if old_hud != null:
		old_hud.visible = false
	RenderingServer.set_default_clear_color(Style.BG)

	# Vinculado desde o início; não é preciso apertar V para ouvir o motor.
	_audio.accel_mode = VanEngineAudio.AccelMode.DYNAMIC
	_audio.transmission_enabled = true
	_apply_conditions()
	_audio.set_vehicle(_vehicle)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPreview"
	add_child(_sfx_player)
	_gsfx = SfxScript.new()
	_gsfx.name = "GameplaySfx"
	add_child(_gsfx)
	rescan_sfx()

	_ui = LabUI.new()
	_ui.name = "LabUI"
	add_child(_ui)
	_ui.setup(self)


func _exit_tree() -> void:
	if is_instance_valid(_vehicle_template):
		_vehicle_template.free()


func _notification(what: int) -> void:
	# Perdeu o foco com um botão do mouse segurado: solta tudo para não prender o acelerador.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_ui_gas = false
		_ui_brake = false


# --------------------------------------------------------------------- teclado
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F3:
			if _ui != null:
				_ui.toggle_diagnostics()
		KEY_1, KEY_KP_1:
			action_set_sound_mode(VanEngineAudio.AccelMode.DYNAMIC)
		KEY_2, KEY_KP_2:
			action_set_sound_mode(VanEngineAudio.AccelMode.IDLE_ONLY)
		KEY_5, KEY_KP_5:
			action_set_sound_mode(VanEngineAudio.AccelMode.CONTINUOUS)
		KEY_6, KEY_KP_6:
			action_set_sound_mode(VanEngineAudio.AccelMode.BLIP)
		KEY_7, KEY_KP_7:
			action_set_transmission(true)
		KEY_8, KEY_KP_8:
			action_set_transmission(false)
		KEY_9, KEY_KP_9:
			action_set_profile(DemoVehicle.PROFILE_FAST)
		KEY_0, KEY_KP_0:
			action_set_profile(DemoVehicle.PROFILE_GRADUAL)
		KEY_P:
			action_toggle_partial()
		KEY_T:
			action_toggle_test()
		KEY_ENTER, KEY_KP_ENTER:
			action_start_test()
		KEY_R:
			action_stop_test()
		KEY_Q:
			action_preset("A")
		KEY_E:
			action_preset("B")
		KEY_F:
			action_preset("C")
		KEY_3, KEY_KP_3:
			action_lock_speed(true)
		KEY_4, KEY_KP_4:
			action_lock_speed(false)
		KEY_N:
			action_toggle_rough()
		KEY_V:
			action_toggle_bind()
		KEY_X:
			action_toggle_vehicle()
		KEY_C:
			action_toggle_engine()
		KEY_EQUAL, KEY_KP_ADD:
			action_step_volume(2.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			action_step_volume(-2.0)


# ----------------------------------------------------------------------- ações
## Reinicia o teste automático da condição de partida: velocidade zero, motor em marcha
## lenta, marcha virtual reiniciada, temporizadores e estado de troca limpos.
func action_start_test() -> void:
	if not is_instance_valid(_vehicle):
		_say("Sem veículo: restaure com X ou pelo painel de diagnóstico.")
		return
	if _air:
		# Com o voo ligado as rodas não empurram: o teste não sairia do lugar.
		_air = false
		_apply_conditions()
		_say("Voo desligado para rodar o teste.")
	_hard_reset()
	_test_done = false
	_test_time = 0.0
	_peak_gear = 1
	_test_label = _config_label()
	_enter_stage(1)


func action_toggle_test() -> void:
	if _stage > 0:
		action_stop_test()
	else:
		action_start_test()


## Para o teste e deixa tudo em repouso (velocidade zero, marcha 1, sem comandos presos).
func action_stop_test() -> void:
	var was_running: bool = _stage > 0
	_cancel_test(true)
	_say("Teste parado; van em repouso." if was_running else "Van em repouso.")


func action_preset(id: String) -> void:
	if not PRESETS.has(id):
		return
	var preset: Dictionary = PRESETS[id]
	_profile = int(preset["profile"])
	_audio.transmission_enabled = bool(preset["transmission"])
	_apply_conditions()
	action_start_test()
	_say("Teste %s: %s" % [id, _config_label()])


func action_set_profile(profile: int) -> void:
	if profile == _profile:
		return
	_profile = profile
	_apply_conditions()
	_after_config_change()


func action_set_transmission(enabled: bool) -> void:
	if _audio.transmission_enabled == enabled:
		return
	_audio.transmission_enabled = enabled
	_after_config_change()


func action_set_sound_mode(mode: int) -> void:
	# Trocar a versão sonora não reinicia nada: dá para alternar durante o teste.
	_audio.accel_mode = mode as VanEngineAudio.AccelMode


func action_toggle_partial() -> void:
	_partial = not _partial
	if _stage > 0:
		_after_config_change()


func action_toggle_rough() -> void:
	_rough = not _rough


func action_toggle_mud() -> void:
	_mud = not _mud


func action_toggle_air() -> void:
	_air = not _air


func action_lock_speed(locked: bool) -> void:
	_cancel_test(false)
	if not is_instance_valid(_vehicle):
		return
	if locked:
		_vehicle.lock_speed()
	else:
		_vehicle.unlock_speed()


## Segurar o botão "Acelerar" ou "Frear" (o mesmo efeito de W e B).
func action_gas(pressed: bool) -> void:
	_ui_gas = pressed


func action_brake(pressed: bool) -> void:
	_ui_brake = pressed


func action_set_volume_db(db: float) -> void:
	_audio.engine_volume_db = clampf(db, -40.0, 0.0)


func action_step_volume(step_db: float) -> void:
	action_set_volume_db(_audio.engine_volume_db + step_db)


func action_toggle_engine() -> void:
	_sfx_engine_muted = false
	_audio.engine_enabled = not _audio.engine_enabled


func action_toggle_bind() -> void:
	var detached: bool = not is_instance_valid(_audio.vehicle)
	_audio.set_vehicle(_vehicle if detached and is_instance_valid(_vehicle) else null)


## Remove a van para testar a perda do veículo; apertar de novo a restaura em repouso.
func action_toggle_vehicle() -> void:
	if is_instance_valid(_vehicle):
		_cancel_test(false)
		_vehicle.queue_free()
		_say("Van removida (X de novo restaura).")
		return
	if not is_instance_valid(_vehicle_template):
		return
	_vehicle = _vehicle_template.duplicate() as DemoVehicle
	add_child(_vehicle)
	_apply_conditions()
	_audio.set_vehicle(_vehicle)
	_say("Van restaurada em repouso.")


# ---------------------------------------------------------------- pré-escuta SFX
func rescan_sfx() -> void:
	if _gsfx != null:
		_gsfx.rescan()
	_sfx_files.clear()
	for category in SFX_CATEGORIES:
		var folder: String = str(category[0])
		var found: Array[String] = []
		var dir: DirAccess = null
		if DirAccess.dir_exists_absolute(SFX_DIR + folder):
			dir = DirAccess.open(SFX_DIR + folder)
		if dir != null:
			dir.list_dir_begin()
			var entry: String = dir.get_next()
			while entry != "":
				if not dir.current_is_dir():
					var base: String = entry.trim_suffix(".import")
					if SFX_EXTENSIONS.has(base.get_extension().to_lower()) and not found.has(base):
						found.append(base)
				entry = dir.get_next()
			dir.list_dir_end()
		found.sort()
		_sfx_files[folder] = found


func get_sfx_categories() -> Array:
	return SFX_CATEGORIES


func get_sfx_files(folder: String) -> Array:
	return _sfx_files.get(folder, [])


func play_sfx(folder: String, file_name: String) -> void:
	var stream: AudioStream = load(SFX_DIR + folder + "/" + file_name) as AudioStream
	if stream == null:
		_say("Não foi possível carregar %s." % file_name)
		return
	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.volume_db = minf(_audio.engine_volume_db + 6.0, 0.0)
	_sfx_player.play()
	_sfx_playing = file_name


func stop_sfx() -> void:
	_sfx_player.stop()
	_sfx_playing = ""


# ------------------------------------------------- efeitos de gameplay (componente)
## Lista [id, nome, quantidade de gravações] na ordem de apresentação.
func get_gameplay_events() -> Array:
	var result: Array = []
	for event in SfxScript.EVENT_ORDER:
		result.append([event, SfxScript.short_of(event), _gsfx.file_count(event)])
	return result


func get_gameplay_folder(event: String) -> String:
	return SfxScript.folder_of(event)


## Toca o efeito uma vez e o memoriza para REPETIR e RAJADA.
func action_play_gameplay_sfx(event: String) -> void:
	_sfx_event = event
	_sfx_repeat_t = SFX_REPEAT_INTERVAL
	if not _fire_gameplay_sfx(event):
		if _gsfx.file_count(event) == 0:
			_say("Sem gravação para «%s». Pasta: sfx/gameplay/%s/" % [
				SfxScript.label_of(event), SfxScript.folder_of(event)])


func _fire_gameplay_sfx(event: String) -> bool:
	_gsfx.master_db = minf(_audio.engine_volume_db + 6.0, 0.0)
	return _gsfx.play_event(event, SFX_LAB_POINT, _sfx_intensity)


func action_set_sfx_intensity(value: float) -> void:
	_sfx_intensity = clampf(value, 0.0, 1.0)


func action_toggle_sfx_repeat() -> void:
	_sfx_repeat = not _sfx_repeat
	_sfx_repeat_t = 0.0
	if _sfx_repeat and _sfx_event == "":
		_say("Toque um efeito primeiro; a repetição usa o último.")
		_sfx_repeat = false


## Seis disparos seguidos do último efeito, para conferir o limite de vozes e o volume.
func action_sfx_burst() -> void:
	if _sfx_event == "":
		_say("Toque um efeito primeiro; a rajada usa o último.")
		return
	_sfx_burst_left = SFX_BURST_COUNT
	_sfx_burst_t = 0.0


func action_stop_gameplay_sfx() -> void:
	_sfx_repeat = false
	_sfx_burst_left = 0
	_gsfx.stop_all()


## Silencia o motor só durante a pré-escuta; ligar de novo devolve o estado anterior.
func action_toggle_sfx_engine_mute() -> void:
	if _sfx_engine_muted:
		_sfx_engine_muted = false
		_audio.engine_enabled = _engine_before_mute
	else:
		_engine_before_mute = _audio.engine_enabled
		_sfx_engine_muted = true
		_audio.engine_enabled = false


func _tick_gameplay_sfx(delta: float) -> void:
	if _sfx_repeat and _sfx_event != "":
		_sfx_repeat_t -= delta
		if _sfx_repeat_t <= 0.0:
			_sfx_repeat_t = SFX_REPEAT_INTERVAL
			_fire_gameplay_sfx(_sfx_event)
	if _sfx_burst_left > 0:
		_sfx_burst_t -= delta
		if _sfx_burst_t <= 0.0:
			_sfx_burst_t = SFX_BURST_INTERVAL
			_sfx_burst_left -= 1
			_fire_gameplay_sfx(_sfx_event)


func _gameplay_sfx_status() -> String:
	var s: Dictionary = _gsfx.stats
	var last: String = "—" if _sfx_event == "" else SfxScript.label_of(_sfx_event)
	return "último: %s · vozes: %d/%d · tocados %d · descartados %d · trocados %d" % [
		last, _gsfx.active_voices(), SfxScript.POOL_SIZE,
		int(s["played"]), int(s["cooldown"]) + int(s["dropped"]), int(s["stolen"])]


# ------------------------------------------------------------------ simulação
func _physics_process(delta: float) -> void:
	_apply_conditions()
	var state: Dictionary = _audio.get_debug_state()
	_check_takeover()
	_drive_manual()
	_tick_test(delta, state)
	_update_run(delta)


func _process(delta: float) -> void:
	# Rede de segurança: sem botão do mouse pressionado, o acelerador/freio da tela solta.
	if (_ui_gas or _ui_brake) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_ui_gas = false
		_ui_brake = false
	_flash_t = maxf(0.0, _flash_t - delta)
	_notice_t = maxf(0.0, _notice_t - delta)
	if _sfx_playing != "" and not _sfx_player.playing:
		_sfx_playing = ""
	_tick_gameplay_sfx(delta)
	var state: Dictionary = _audio.get_debug_state()
	_track_gear(state)
	if _ui != null:
		_ui.update_view(_build_view(state), delta)


func _apply_conditions() -> void:
	if not is_instance_valid(_vehicle):
		return
	_vehicle.accel_profile = _profile
	_vehicle.partial_throttle = _partial
	_vehicle.rough_road = _rough
	_vehicle.force_mud = _mud
	_vehicle.force_air = _air


func _pedal() -> float:
	return 0.5 if _partial else 1.0


## Assumir o controle: W, S, B ou os botões Acelerar/Frear durante o teste o interrompem.
func _check_takeover() -> void:
	if _stage == 0:
		return
	if _ui_gas or _ui_brake or Input.is_physical_key_pressed(KEY_W) \
			or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_B):
		_cancel_test(false)
		_say("Teste interrompido: controle manual.")


## Botões Acelerar/Frear do mouse usam o mesmo caminho do teste (override do FakeVan);
## sem eles, o FakeVan volta a ler W/S/B diretamente.
func _drive_manual() -> void:
	if _stage > 0 or not is_instance_valid(_vehicle):
		return
	if _ui_gas or _ui_brake:
		_ui_drive_active = true
		_vehicle.input_override = true
		_vehicle.override_throttle = _pedal() if _ui_gas and not _ui_brake else 0.0
		_vehicle.override_brake = _vehicle.gentle_braking if _ui_brake else 0.0
	elif _ui_drive_active:
		_ui_drive_active = false
		_vehicle.input_override = false
		_vehicle.override_throttle = 0.0
		_vehicle.override_brake = 0.0


func _after_config_change() -> void:
	if _stage > 0:
		action_start_test()
		_say("Configuração alterada; teste reiniciado: %s" % _config_label())


func _config_label() -> String:
	return "%s · transmissão %s%s" % [
		"RÁPIDO" if _profile == DemoVehicle.PROFILE_FAST else "CALIBRADO",
		"ligada" if _audio.transmission_enabled else "desligada",
		" · acelerador 50%" if _partial else "",
	]


func _say(text: String) -> void:
	_notice = text
	_notice_t = NOTICE_TIME


## Volta ao ponto de partida do teste: velocidade zero, marcha 1, sem troca em curso.
## A rotação do som não salta: continua suavizando até a marcha lenta.
func _hard_reset() -> void:
	if is_instance_valid(_vehicle):
		_vehicle.reset()
	_audio.reset_state()
	_gear_seen = 0
	_flash_t = 0.0
	_run_active = false
	_run_from_stop = false
	_run_time = 0.0
	_run_marks = [-1.0, -1.0, -1.0]
	_reached_time = 0.0
	_ui_drive_active = false


func _cancel_test(hard: bool) -> void:
	_stage = 0
	_stage_time = 0.0
	_test_done = false
	if is_instance_valid(_vehicle):
		_vehicle.input_override = false
		_vehicle.override_throttle = 0.0
		_vehicle.override_brake = 0.0
		_vehicle.unlock_speed()
	if hard:
		_hard_reset()
	_ui_drive_active = false


func _enter_stage(stage: int) -> void:
	_stage = stage
	_stage_time = 0.0
	_reached_time = 0.0
	if not is_instance_valid(_vehicle):
		return
	match stage:
		1:
			_vehicle.unlock_speed()
			_vehicle.input_override = true
			_vehicle.override_throttle = 0.0
			_vehicle.override_brake = 0.0
		2:
			_vehicle.override_throttle = _pedal()
			_vehicle.override_brake = 0.0
		6:
			_vehicle.lock_speed()
		7:
			_vehicle.unlock_speed()
			_vehicle.override_throttle = 0.0
			_vehicle.override_brake = AUTO_BRAKE_DECEL
		9:
			_vehicle.override_brake = 0.0


func _finish_test() -> void:
	_stage = 0
	_stage_time = 0.0
	_test_done = true
	if is_instance_valid(_vehicle):
		_vehicle.input_override = false
		_vehicle.override_throttle = 0.0
		_vehicle.override_brake = 0.0
		_vehicle.unlock_speed()
	_say("Teste concluído.")


func _is_shifting(state: Dictionary) -> bool:
	var shift_name: String = str(state.shift_state)
	return shift_name != VanEngineAudio.SHIFT_NAMES[0] and shift_name != "—"


func _tick_test(delta: float, state: Dictionary) -> void:
	if _stage == 0:
		return
	if not is_instance_valid(_vehicle):
		_cancel_test(false)
		return
	_test_time += delta
	_stage_time += delta
	var speed: float = absf(_vehicle.get_speed())
	var top: float = _vehicle.max_speed
	var target: float = _vehicle.get_cruise_target(_pedal())
	var gear: int = int(state.gear)
	var shifting: bool = _is_shifting(state)
	_peak_gear = maxi(_peak_gear, gear)
	var reached: bool = speed >= AUTO_REACHED_FRACTION * target
	match _stage:
		1:
			var settled: bool = float(state.rpm) < IDLE_SETTLED_RPM and float(state.surge) < IDLE_SETTLED_SURGE
			if (_stage_time >= IDLE_MIN_TIME and settled) or _stage_time >= IDLE_MAX_TIME:
				_enter_stage(2)
		2:
			if speed >= LAUNCH_SPEED_FRACTION * top or _stage_time >= LAUNCH_MAX_TIME:
				_enter_stage(3)
		3:
			if reached:
				_enter_stage(5)
			elif (gear >= 2 and not shifting) or _stage_time >= SHIFT_STAGE_MAX_TIME:
				_enter_stage(4)
		4:
			if reached or (gear >= 3 and not shifting) or _stage_time >= SHIFT_STAGE_MAX_TIME:
				_enter_stage(5)
		5:
			_reached_time = _reached_time + delta if reached else 0.0
			if _reached_time >= AUTO_REACHED_HOLD or _stage_time >= AUTO_ACCEL_MAX_TIME:
				_enter_stage(6)
		6:
			if _stage_time >= AUTO_CRUISE_TIME:
				_enter_stage(7)
		7:
			if gear < _peak_gear or speed <= AUTO_DECEL_END_FRACTION * top or _stage_time >= AUTO_BRAKE_MAX_TIME:
				_enter_stage(8)
		8:
			if speed < 0.05 or _stage_time >= AUTO_BRAKE_MAX_TIME:
				_enter_stage(9)
		9:
			if _stage_time >= AUTO_IDLE_TIME:
				_finish_test()


## 0..1 dentro da etapa atual, só para o indicador (nunca chega a 1 antes da etapa terminar).
func _stage_fraction() -> float:
	if _stage == 0:
		return 1.0 if _test_done else 0.0
	var fraction: float = _stage_time / STAGE_NOMINAL[_stage]
	if is_instance_valid(_vehicle):
		var top: float = _vehicle.max_speed
		var speed: float = absf(_vehicle.get_speed())
		if _stage == 2:
			fraction = speed / (LAUNCH_SPEED_FRACTION * top)
		elif _stage == 5:
			fraction = speed / (AUTO_REACHED_FRACTION * _vehicle.get_cruise_target(_pedal()))
	return clampf(fraction, 0.0, 0.97)


## Cronômetro da aceleração: começa quando o acelerador é pisado e para quando é solto
## ou a velocidade é travada. Os tempos 0–30/60/80 km/h só valem partindo da parada.
func _update_run(delta: float) -> void:
	if not is_instance_valid(_vehicle):
		return
	var kmh: float = _vehicle.linear_velocity.length() * 3.6
	var pressed: bool = _vehicle.throttle_input > 0.0 and not _vehicle.speed_locked
	if _vehicle.input_override and _vehicle.override_throttle <= 0.0:
		# Comando de freio/solto: o throttle_input de um quadro atrás não conta como arrancada.
		pressed = false
	if not pressed:
		_run_active = false
		return
	if not _run_active:
		_run_active = true
		_run_time = 0.0
		_run_from_stop = kmh < 1.5
		_run_marks = [-1.0, -1.0, -1.0]
		return
	_run_time += delta
	if _run_from_stop:
		for i in RUN_MARKS_KMH.size():
			if _run_marks[i] < 0.0 and kmh >= RUN_MARKS_KMH[i]:
				_run_marks[i] = _run_time


## Transição "1ª → 2ª": detectada pela mudança da marcha mostrada (vale também com a
## transmissão desligada). N/R e reinícios não geram transição.
func _track_gear(state: Dictionary) -> void:
	var label: String = str(state.gear_label)
	if not label.is_valid_int() or not bool(state.has_vehicle):
		_gear_seen = 0
		return
	var current: int = int(state.gear)
	if _gear_seen > 0 and current != _gear_seen:
		_flash_from = _gear_seen
		_flash_to = current
		_flash_up = current > _gear_seen
		_flash_t = FLASH_TIME
	_gear_seen = current


func _current_preset() -> String:
	var tx: bool = _audio.transmission_enabled
	if _profile == DemoVehicle.PROFILE_GRADUAL:
		return "A" if tx else "B"
	return "C" if tx else ""


func _run_marks_text() -> String:
	if not _run_from_stop:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for i in RUN_MARKS_KMH.size():
		parts.append("0–%d km/h: %s" % [int(RUN_MARKS_KMH[i]), _run_mark_text(i)])
	return " · ".join(parts)


# ------------------------------------------------------------ dados da interface
func _build_view(state: Dictionary) -> Dictionary:
	var has_vehicle: bool = is_instance_valid(_vehicle)
	var speed: float = 0.0
	var throttle: float = 0.0
	var top: float = 24.0
	var target: float = 24.0
	var locked: bool = false
	if has_vehicle:
		speed = _vehicle.linear_velocity.length()
		throttle = _vehicle.throttle_input
		top = _vehicle.max_speed
		target = _vehicle.get_cruise_target(_pedal())
		locked = _vehicle.speed_locked
	var tx_on: bool = _audio.transmission_enabled
	var tx_state: String = "—"
	if tx_on:
		tx_state = str(state.drive_state).to_upper()
		if _is_shifting(state):
			tx_state = str(state.shift_state)
	var stage_name: String = "PRONTO PARA TESTAR"
	var stage_hint: String = "aperte o botão para ouvir a sequência completa"
	if _stage > 0:
		stage_name = "ETAPA %d/%d · %s" % [_stage, STAGE_COUNT, STAGE_NAMES[_stage]]
		stage_hint = STAGE_HINTS[_stage]
	elif _test_done:
		stage_name = "TESTE CONCLUÍDO"
		stage_hint = "van parada em marcha lenta · repita ou troque uma variável"
	var launch_time: float = _run_time
	var mode_title: String = "—"
	for entry in sound_modes:
		if int(entry[0]) == int(_audio.accel_mode):
			mode_title = "%s · %s" % [entry[1], entry[2]]
	return {
		"state": state,
		"has_vehicle": has_vehicle,
		"bound": bool(state.has_vehicle),
		"engine_on": _audio.engine_enabled,
		"speed_ms": speed,
		"speed_kmh": speed * 3.6,
		"top_ms": top,
		"top_kmh": top * 3.6,
		"target_kmh": target * 3.6,
		"throttle": throttle,
		"locked": locked,
		"profile": _profile,
		"profile_name": "RÁPIDO" if _profile == DemoVehicle.PROFILE_FAST else "CALIBRADO",
		"profile_info": PROFILE_INFO[clampi(_profile, 0, PROFILE_INFO.size() - 1)],
		"tx_on": tx_on,
		"tx_state": tx_state,
		"shifting": _is_shifting(state),
		"mode": int(_audio.accel_mode),
		"mode_title": mode_title,
		"partial": _partial,
		"rough": _rough,
		"mud": _mud,
		"air": _air,
		"gas_active": _ui_gas or (_stage == 0 and Input.is_physical_key_pressed(KEY_W)),
		"brake_active": _ui_brake or (_stage == 0 and Input.is_physical_key_pressed(KEY_B)),
		"volume_db": _audio.engine_volume_db,
		"preset": _current_preset(),
		"test_running": _stage > 0,
		"test_done": _test_done,
		"stage": _stage,
		"stage_name": stage_name,
		"stage_hint": stage_hint,
		"stage_fraction": _stage_fraction(),
		"test_time": _test_time,
		"stage_time": _stage_time,
		"test_label": _test_label,
		"launch_time": launch_time,
		"run_active": _run_active,
		"run_marks": _run_marks_text(),
		"flash_from": _flash_from,
		"flash_to": _flash_to,
		"flash_up": _flash_up,
		"flash_amount": clampf(_flash_t / FLASH_TIME, 0.0, 1.0),
		"notice": _notice,
		"notice_alpha": clampf(_notice_t / 0.6, 0.0, 1.0),
		"conditions": _conditions_text(),
		"conditions_changed": _partial or _rough or _mud or _air,
		"sfx_playing": _sfx_playing,
		"sfx_intensity": _sfx_intensity,
		"sfx_repeat": _sfx_repeat,
		"sfx_muted": _sfx_engine_muted,
		"sfx_status": _gameplay_sfx_status(),
	}


func _conditions_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("acelerador 50%" if _partial else "acelerador pleno")
	parts.append("piso irregular" if _rough else "piso liso")
	if _mud:
		parts.append("lama")
	if _air:
		parts.append("voo")
	return " · ".join(parts)


## Linhas do painel técnico (F3): lista de seções {title, rows: [[rótulo, valor], ...]}.
## Rótulos e valores curtos, para caberem em cinco colunas sem quebrar o layout.
func get_diag_sections() -> Array:
	var s: Dictionary = _audio.get_debug_state()
	var has_vehicle: bool = is_instance_valid(_vehicle)
	var kmh: float = _vehicle.linear_velocity.length() * 3.6 if has_vehicle else 0.0
	var bind_text: String = "vinculado"
	if not has_vehicle:
		bind_text = "sem van"
	elif not bool(s.has_vehicle):
		bind_text = "solto (V)"
	var ground: PackedStringArray = PackedStringArray()
	if _rough:
		ground.append("irreg.")
	if _mud:
		ground.append("lama")
	if _air:
		ground.append("voo")
	var stage_text: String = "—"
	if _stage > 0:
		stage_text = "%d/%d" % [_stage, STAGE_COUNT]
	elif _test_done:
		stage_text = "concluído"
	return [
		{"title": "ROTAÇÃO E CARGA", "rows": [
			["rotação norm.", "%.3f" % float(s.rpm)],
			["frequência", "%.1f Hz" % float(s.frequency)],
			["carga simulada", "%.2f" % float(s.load)],
			["acel. em curso", "%.2f" % float(s.surge)],
			["mix aceleração", "%.2f" % float(s.accel_blend)],
			["presença", "%.2f" % float(s.presence)],
		]},
		{"title": "CAMADAS DE ÁUDIO", "rows": [
			["lenta · pitch", "%.3f" % float(s.idle_pitch)],
			["lenta · nível", "%.1f dB" % float(s.idle_db)],
			["acel. · pitch", "%.3f" % float(s.accel_pitch)],
			["acel. · nível", "%.1f dB" % float(s.accel_db)],
			["efeito curto", "tocando" if bool(s.blip_playing) else "parado"],
			["turbo sintético", "ATIVO" if bool(s.turbo_on) else "desligado"],
		]},
		{"title": "TRANSMISSÃO", "rows": [
			["modo", "3 marchas" if bool(s.transmission) else "legado"],
			["marcha", str(s.gear_label)],
			["troca", str(s.shift_state)],
			["condução", str(s.drive_state)],
			["veloc. filtrada", "%.2f m/s" % float(s.tx_speed)],
			["acel. filtrada", "%.2f m/s²" % float(s.tx_accel)],
		]},
		{"title": "VEÍCULO E VINCULAÇÃO", "rows": [
			["vinculação", bind_text],
			["motor (C)", "ligado" if _audio.engine_enabled else "desligado"],
			["velocidade", "%.1f km/h" % kmh],
			["acelerador lido", "%.2f" % float(s.drive)],
			["vel. travada", "sim" if has_vehicle and _vehicle.speed_locked else "não"],
			["terreno", "+".join(ground) if ground.size() > 0 else "liso"],
		]},
		{"title": "ACELERAÇÃO E TESTE", "rows": [
			["perfil", ("RÁPIDO" if _profile == DemoVehicle.PROFILE_FAST else "CALIBRADO")],
			["desde a arrancada", "%.1f s%s" % [_run_time, "" if _run_active else " ·"]],
			["0–30 km/h", _run_mark_text(0)],
			["0–60 km/h", _run_mark_text(1)],
			["0–80 km/h", _run_mark_text(2)],
			["etapa do teste", stage_text],
			["tempo do teste", "%.1f s" % _test_time],
		]},
	]


func _run_mark_text(index: int) -> String:
	if not _run_from_stop or _run_marks[index] < 0.0:
		return "—"
	return "%.1f s" % _run_marks[index]
