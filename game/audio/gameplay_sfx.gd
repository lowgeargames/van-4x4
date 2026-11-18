class_name GameplaySfx
extends Node3D
## Efeitos sonoros curtos de gameplay (árvore, pouso, caixa, barril, cone), em 3D.
##
## Componente pequeno e independente: nenhum Autoload, nenhuma ligação com a GameSession.
## Basta adicionar como filho de qualquer nó e chamar, por exemplo:
##     sfx.play_tree_break(tree.global_position)
##     sfx.play_landing(van.global_position, GameplaySfx.Landing.STRONG)
##     sfx.play_impact("crate", crate.global_position, 0.6)
##
## As gravações ficam em res://audio/sfx/gameplay/<pasta>/ (ver EVENTS). Uma pasta vazia
## significa "efeito ainda não aprovado": o pedido é ignorado em silêncio (devolve false),
## nunca é substituído por um som falso.
##
## Variação e proteção (tudo em play_event):
##  - escolhe uma gravação alternativa, sem repetir a anterior quando há mais de uma;
##  - pitch com pequena variação aleatória (limitada a MAX_PITCH_VARIATION);
##  - volume com variação moderada em dB, mais a queda pela intensidade (0..1);
##  - tempo mínimo entre disparos do mesmo evento (cooldown);
##  - número máximo de vozes por evento e no conjunto (POOL_SIZE);
##  - quanto mais vozes ativas, mais baixo entra o novo som (CROWD_DB_*), com teto CEILING_DB;
##  - voz já tocando só é substituída se já passou do ataque e o novo som for claramente
##    mais forte; caso contrário o pedido novo é descartado e o som em curso termina inteiro.

enum Landing { LIGHT, MEDIUM, STRONG }

const BASE_DIR: String = "res://audio/sfx/gameplay/"
const EXTENSIONS: Array[String] = ["wav", "ogg", "mp3"]

## Vozes simultâneas do conjunto inteiro (players 3D reaproveitados; nada é criado em jogo).
const POOL_SIZE: int = 8
## Variação máxima de pitch aceita, mesmo que um evento peça mais (±8%).
const MAX_PITCH_VARIATION: float = 0.08
## Nível máximo final de qualquer voz (dB).
const CEILING_DB: float = -1.0
## Queda de volume por voz já ativa e limite dessa queda (dB).
const CROWD_DB_PER_VOICE: float = 2.0
const CROWD_DB_MAX: float = 10.0
## Uma voz só pode ser substituída depois deste tempo (ms) e se o novo som for mais forte
## em pelo menos STEAL_MIN_GAIN_DB.
const STEAL_MIN_AGE_MS: int = 150
const STEAL_MIN_GAIN_DB: float = 1.0

## Ordem de apresentação no laboratório.
const EVENT_ORDER: Array[String] = [
	"tree_break", "wood_leaves", "landing_light", "landing_medium",
	"landing_strong", "crate", "barrel", "cone",
]

## folder: pasta em BASE_DIR · base_db: nível com intensidade máxima · range_db: quanto o
## volume cai com intensidade 0 · pitch: variação aleatória (±fração) · gain: variação
## aleatória de volume (±dB) · voices: vozes simultâneas do evento · cooldown: segundos.
const EVENTS: Dictionary = {
	"tree_break": {"folder": "arvore", "label": "Árvore quebrando", "short": "ÁRVORE",
		"base_db": -2.0, "range_db": 8.0, "pitch": 0.04, "gain": 1.5, "voices": 2, "cooldown": 0.15},
	"wood_leaves": {"folder": "madeira_folhas", "label": "Madeira e folhas", "short": "MADEIRA E FOLHAS",
		"base_db": -4.0, "range_db": 8.0, "pitch": 0.06, "gain": 2.0, "voices": 3, "cooldown": 0.08},
	"landing_light": {"folder": "aterrissagem_suave", "label": "Pouso suave", "short": "POUSO SUAVE",
		"base_db": -8.0, "range_db": 6.0, "pitch": 0.03, "gain": 1.0, "voices": 2, "cooldown": 0.15},
	"landing_medium": {"folder": "aterrissagem_firme", "label": "Pouso firme", "short": "POUSO FIRME",
		"base_db": -5.0, "range_db": 6.0, "pitch": 0.03, "gain": 1.0, "voices": 2, "cooldown": 0.2},
	"landing_strong": {"folder": "aterrissagem_brutal", "label": "Pouso brutal", "short": "POUSO BRUTAL",
		"base_db": -3.0, "range_db": 6.0, "pitch": 0.02, "gain": 1.0, "voices": 2, "cooldown": 0.25},
	"crate": {"folder": "caixa", "label": "Caixa de madeira", "short": "CAIXA",
		"base_db": -4.0, "range_db": 10.0, "pitch": 0.05, "gain": 2.0, "voices": 3, "cooldown": 0.06},
	"barrel": {"folder": "barril", "label": "Barril metálico", "short": "BARRIL",
		"base_db": -4.0, "range_db": 10.0, "pitch": 0.05, "gain": 2.0, "voices": 3, "cooldown": 0.06},
	"cone": {"folder": "cone", "label": "Cone plástico", "short": "CONE",
		"base_db": -7.0, "range_db": 10.0, "pitch": 0.06, "gain": 2.0, "voices": 3, "cooldown": 0.05},
}

## Apelidos aceitos por play_impact.
const IMPACT_MATERIALS: Dictionary = {
	"crate": "crate", "wood": "crate", "box": "crate",
	"barrel": "barrel", "metal": "barrel",
	"cone": "cone", "plastic": "cone",
}

## Volume geral dos efeitos (dB), somado ao nível de cada voz. O laboratório o ajusta.
var master_db: float = 0.0
## Contadores simples, úteis para o painel do laboratório.
var stats: Dictionary = {"played": 0, "cooldown": 0, "empty": 0, "dropped": 0, "stolen": 0}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _streams: Dictionary = {}
var _file_names: Dictionary = {}
var _last_pick: Dictionary = {}
var _last_start_ms: Dictionary = {}
var _players: Array[AudioStreamPlayer3D] = []
var _slot_event: Array[String] = []
var _slot_start_ms: Array[int] = []
var _slot_db: Array[float] = []


func _ready() -> void:
	_rng.randomize()
	for i in POOL_SIZE:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "Voice%d" % i
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 10.0
		player.max_distance = 150.0
		add_child(player)
		_players.append(player)
		_slot_event.append("")
		_slot_start_ms.append(0)
		_slot_db.append(-80.0)
	rescan()


# ------------------------------------------------------------------ API de jogo
func play_tree_break(at: Vector3, intensity: float = 1.0) -> bool:
	return play_event("tree_break", at, intensity)


func play_wood_leaves(at: Vector3, intensity: float = 1.0) -> bool:
	return play_event("wood_leaves", at, intensity)


## `level` é um valor de Landing (leve, médio, forte); `intensity` ajusta dentro do nível.
func play_landing(at: Vector3, level: int = Landing.MEDIUM, intensity: float = 1.0) -> bool:
	var event: String = "landing_medium"
	if level == Landing.LIGHT:
		event = "landing_light"
	elif level == Landing.STRONG:
		event = "landing_strong"
	return play_event(event, at, intensity)


## `material`: "crate", "barrel", "cone" (ou os apelidos de IMPACT_MATERIALS).
func play_impact(material: String, at: Vector3, intensity: float = 1.0) -> bool:
	var event: String = str(IMPACT_MATERIALS.get(material, ""))
	if event == "":
		return false
	return play_event(event, at, intensity)


## Toca `event` na posição global `at`. Devolve true somente se uma voz foi iniciada.
func play_event(event: String, at: Vector3, intensity: float = 1.0) -> bool:
	if not EVENTS.has(event) or _players.is_empty() or not is_inside_tree():
		return false
	var streams: Array = _streams.get(event, [])
	if streams.is_empty():
		stats["empty"] += 1
		return false
	var def: Dictionary = EVENTS[event]
	var now: int = Time.get_ticks_msec()
	var since: int = now - int(_last_start_ms.get(event, -1000000))
	if since < int(float(def["cooldown"]) * 1000.0):
		stats["cooldown"] += 1
		return false

	var level: float = clampf(intensity, 0.0, 1.0)
	var db: float = compute_level_db(def, level, active_voices(), master_db,
			_rng.randf_range(-1.0, 1.0))
	var slot: int = _find_slot(event, int(def["voices"]), db, now)
	if slot < 0:
		stats["dropped"] += 1
		return false

	var pick: int = _pick_index(event, streams.size())
	var player: AudioStreamPlayer3D = _players[slot]
	player.stop()
	player.stream = streams[pick] as AudioStream
	player.global_position = at
	player.volume_db = db
	player.pitch_scale = compute_pitch(def, level, _rng.randf_range(-1.0, 1.0))
	player.play()
	_slot_event[slot] = event
	_slot_start_ms[slot] = now
	_slot_db[slot] = db
	_last_start_ms[event] = now
	stats["played"] += 1
	return true


# ------------------------------------------------------------------ cálculo (puro)
## Nível final em dB. `noise` é um número em [-1, 1] (aleatório em jogo, fixo em testes).
static func compute_level_db(def: Dictionary, level: float, voices_active: int,
		master: float, noise: float) -> float:
	var db: float = float(def["base_db"]) - (1.0 - level) * float(def["range_db"])
	db += noise * float(def["gain"])
	db -= minf(CROWD_DB_PER_VOICE * float(voices_active), CROWD_DB_MAX)
	db += master
	return minf(db, CEILING_DB)


## Pitch final: variação aleatória limitada, com leve queda quando o impacto é forte.
static func compute_pitch(def: Dictionary, level: float, noise: float) -> float:
	var variation: float = minf(float(def["pitch"]), MAX_PITCH_VARIATION)
	var pitch: float = 1.0 + noise * variation
	pitch *= 1.0 + 0.03 * (0.5 - level)
	return clampf(pitch, 0.9, 1.1)


# ------------------------------------------------------------------ consultas e controle
func active_voices() -> int:
	var count: int = 0
	for player in _players:
		if player.playing:
			count += 1
	return count


func has_event(event: String) -> bool:
	return file_count(event) > 0


func file_count(event: String) -> int:
	return (_file_names.get(event, []) as Array).size()


func get_files(event: String) -> Array:
	return _file_names.get(event, [])


static func label_of(event: String) -> String:
	if not EVENTS.has(event):
		return event
	return str(EVENTS[event]["label"])


static func short_of(event: String) -> String:
	if not EVENTS.has(event):
		return event
	return str(EVENTS[event]["short"])


static func folder_of(event: String) -> String:
	if not EVENTS.has(event):
		return ""
	return str(EVENTS[event]["folder"])


func seed_rng(seed_value: int) -> void:
	_rng.seed = seed_value


func stop_all() -> void:
	for player in _players:
		player.stop()


## Relê as pastas de BASE_DIR e carrega as gravações (também chamado em _ready).
func rescan() -> void:
	_streams.clear()
	_file_names.clear()
	_last_pick.clear()
	for event in EVENTS:
		var event_id: String = str(event)
		var folder_path: String = BASE_DIR + str(EVENTS[event_id]["folder"])
		var names: Array[String] = []
		if DirAccess.dir_exists_absolute(folder_path):
			var dir: DirAccess = DirAccess.open(folder_path)
			if dir != null:
				dir.list_dir_begin()
				var entry: String = dir.get_next()
				while entry != "":
					if not dir.current_is_dir():
						var base: String = entry.trim_suffix(".import")
						if EXTENSIONS.has(base.get_extension().to_lower()) and not names.has(base):
							names.append(base)
					entry = dir.get_next()
				dir.list_dir_end()
		names.sort()
		var loaded_names: Array[String] = []
		var loaded: Array = []
		for file_name in names:
			var stream: AudioStream = load(folder_path + "/" + file_name) as AudioStream
			if stream != null:
				loaded.append(stream)
				loaded_names.append(file_name)
		_streams[event_id] = loaded
		_file_names[event_id] = loaded_names


# ------------------------------------------------------------------ internos
func _pick_index(event: String, count: int) -> int:
	if count <= 1:
		return 0
	var index: int = _rng.randi_range(0, count - 1)
	var last: int = int(_last_pick.get(event, -1))
	if index == last:
		index = (index + 1 + _rng.randi_range(0, count - 2)) % count
	_last_pick[event] = index
	return index


## Escolhe a voz a usar, ou -1 se o pedido deve ser descartado.
func _find_slot(event: String, cap: int, db: float, now: int) -> int:
	var free: int = -1
	var same_count: int = 0
	var weakest_same: int = -1
	var weakest_any: int = -1
	for i in _players.size():
		if not _players[i].playing:
			if free < 0:
				free = i
			continue
		if _slot_event[i] == event:
			same_count += 1
			if weakest_same < 0 or _slot_db[i] < _slot_db[weakest_same]:
				weakest_same = i
		if weakest_any < 0 or _slot_db[i] < _slot_db[weakest_any]:
			weakest_any = i
	if same_count >= cap:
		return _try_steal(weakest_same, db, now)
	if free >= 0:
		return free
	return _try_steal(weakest_any, db, now)


func _try_steal(slot: int, db: float, now: int) -> int:
	if slot < 0:
		return -1
	if now - _slot_start_ms[slot] < STEAL_MIN_AGE_MS:
		return -1
	if db < _slot_db[slot] + STEAL_MIN_GAIN_DB:
		return -1
	stats["stolen"] += 1
	return slot
