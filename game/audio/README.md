# Áudio do Van 4x4

Fundação do áudio da van: motor V8 contínuo, feito com **gravações reais**, com
uma **transmissão automática virtual** só sonora. O componente não está integrado
às cenas de gameplay; a demonstração é independente.

> **Licenças e créditos.** As três gravações têm licença verificada nas páginas
> de origem (ver "Procedência e licença" e `CREDITS.md`). O **Ford V8 5.0 é
> CC BY 3.0 e exige atribuição**: o texto pronto está em `CREDITS.md` e precisa
> entrar nos créditos de qualquer versão distribuída do jogo.

## Arquivos

| Caminho | Função |
|---|---|
| `van_engine_audio.gd` | Componente: lê o veículo e controla volume e pitch das camadas. |
| `van_engine_audio.tscn` | Cena reutilizável com três `AudioStreamPlayer3D`. |
| `sfx/v8_idle_loop.wav` | Marcha lenta, loop (derivado do Mustang 1985). |
| `sfx/v8_accel_loop.wav` | Aceleração, loop (derivado do Ford V8 5.0). |
| `sfx/v8_rev_blip.wav` | Aceleração curta, sem loop (derivado do Mustang 1969). |
| `demo/engine_audio_demo.tscn` | Laboratório de áudio isolado (cena a abrir com F6), com veículo falso. |
| `demo/engine_audio_demo.gd` | Controlador único do laboratório: estado, atalhos, teste de 9 etapas, presets A/B/C. |
| `demo/lab_ui.gd` | Interface (só apresentação): painéis, botões, painel técnico (F3). |
| `demo/lab_style.gd`, `lab_tach.gd`, `lab_road_view.gd`, `lab_stage_bar.gd` | Tema escuro "Oficina Arcade", conta-giros com a marcha, vista da estrada e barra das 9 etapas. |
| `demo/demo_vehicle_stub.gd` | Veículo falso: mesmas propriedades que o áudio lê na van real. |
| `gameplay_sfx.gd` | Componente 3D reutilizável dos efeitos de gameplay (árvore, pouso, caixa, barril, cone); ver "Efeitos sonoros de gameplay". |
| `sfx/gameplay/` | Efeitos de gameplay processados (um subdiretório por efeito; vazios até a aprovação das gravações). |
| `sfx/preview/` | Pré-escuta livre de arquivos soltos: só um README por enquanto. |
| `CREDITS.md` | Procedência, licenças e texto de atribuição de cada gravação. |
| `../../tools/audio/build_engine_samples.py` | Gera os três WAVs a partir das gravações. |
| `../../tools/audio/source_recordings/` | Gravações originais, preservadas sem alteração. |

## Procedência e licença

Todo o som vem das gravações abaixo. Não há síntese. Autor, título, link e
licença foram **conferidos diretamente nas páginas do Freesound pelo
responsável pelo projeto** (informados a esta documentação, não verificados de
novo pelo assistente). Texto de atribuição e detalhes: `CREDITS.md`. Isto é
registro de procedência, não parecer jurídico.

| | Gravação | Arquivo local | Autor | Origem | Licença |
|---|---|---|---|---|---|
| A | Ford Mustang Engine (1985).wav | `ford-mustang-engine-1985.mp3` (MP3 baixado do Pixabay) | lmbubec | Original: <https://freesound.org/people/lmbubec/sounds/119449/> · Cópia usada: <https://pixabay.com/sound-effects/technology-ford-mustang-engine-1985-78386/> | **CC0** (Freesound). A página do Pixabay lista lmbubec como autor original e mostra a licença de conteúdo do Pixabay |
| B | Acceleration sounds of Ford V8 5 Liter engine | `ford-v8-accleration.wav` (origem `455926__noiseloop__…`) | noiseloop | <https://freesound.org/people/noiseloop/sounds/455926/> | **CC BY 3.0** (exige atribuição) |
| C | Muscle Car Revving | `mustang-1969-revving.wav` (origem `653226__flaxgod__…`) | FlaxGod | <https://freesound.org/people/FlaxGod/sounds/653226/> | **CC0** |

**Proveniência real do Mustang 1985.** O arquivo que usamos é o MP3 do Pixabay
(24 kHz, estéreo com canais idênticos), cujo nome de origem
(`freesound_community-…-78386`) indica a republicação do Pixabay, e não o WAV
do Freesound. O original do Freesound é CC0; a página do Pixabay mostra a
licença de conteúdo do Pixabay. As duas páginas descrevem condições diferentes
para a mesma gravação. Se o projeto quiser eliminar essa dúvida, a saída é baixar
o WAV original do Freesound e regenerar `v8_idle_loop.wav` a partir dele; isso
é uma decisão futura e **nada foi regenerado nem alterado nesta etapa**.

**Atribuição obrigatória (B, CC BY 3.0).** Autor, título, link, licença e
indicação das modificações. Texto pronto em `CREDITS.md`. A e C são CC0 e não
exigem atribuição; os créditos do jogo podem citá-las por cortesia.

Arquivos originais (formato): A = MP3 24 kHz, estéreo (os dois canais são
idênticos), 18,7 s · B = WAV 16 bits, 44,1 kHz, estéreo, 11,5 s (gravado com
ZOOM H2, 2017) · C = WAV 24 bits, 48 kHz, estéreo, 2,1 s.

## Amostras derivadas

Todas: mono, 16 bits, 44,1 kHz; filtro passa-alta de 12 Hz; nível normalizado
(RMS de −14 dBFS nos loops, pico limitado a −2 dBFS); nenhuma amostra no limite.
Os loops trazem um chunk `smpl` com o ponto de loop (importação "Detect From WAV").

| Arquivo | Origem | Trecho usado | Construção | Duração | RMS / pico |
|---|---|---|---|---|---|
| `v8_idle_loop.wav` | A | 2,80–9,73 s (evita a partida e o desligamento; o nível é estável por ~17 s) | Início e comprimento escolhidos por correlação para que o fim continue o começo; crossfade de 1,0 s; nivelamento circular de volume. | 5,93 s | −14,0 / −6,5 dBFS |
| `v8_accel_loop.wav` | B | 4,55–6,60 s (segunda subida de rotação; sem as batidas de câmbio em 3,4 s e 6,9 s) | Tom normalizado (ver abaixo); crossfade de 0,5 s; EQ suave (±3 dB) de aproximação à marcha lenta e, só depois, nivelamento circular de volume. | 1,45 s | −14,0 / −3,0 dBFS |
| `v8_rev_blip.wav` | C | 0,00–1,90 s | Fade-in de 5 ms, fade-out de 0,4 s; EQ de aproximação à marcha lenta; sem loop. | 1,90 s | −17,5 / −2,0 dBFS |

**Normalização de tom (B).** A gravação inteira não serve de loop: a rotação
sobe dentro de cada marcha e cai nas trocas. Dentro do trecho escolhido o tom
sobe ~35% em ~2 s (espaçamento das linhas harmônicas de 28,9 a 38,9 Hz). O
tom foi rastreado e o trecho reamostrado com taxa variável (de −12% a +18% de velocidade de leitura)
para ficar fixo em 33 Hz; assim o loop não "respira" em altura. É a única
técnica de processamento além de recorte, filtro, fade e nível.

**EQ de aproximação.** A marcha lenta (A) é muito mais grave que B e C, que
têm mais médios. O EQ aproxima B e C do formato espectral de A em bandas de
1/3 de oitava. No loop de aceleração (B) o EQ é suave, de no máximo ±3 dB, e
vem *antes* do nivelamento de volume; na primeira versão ele era de ±6 dB e
vinha depois, o que quadruplicou a oscilação de volume do loop (ver "Repetição
em velocidade constante"). No efeito curto (C) o EQ continua em ±6 dB, que é o
limite atingido: sobra diferença de timbre, e não se forçou mais.

**Frequências de referência.** Para o pitch, cada amostra tem uma frequência de
explosões nativa (Hz): marcha lenta 47,5 (medida), aceleração 66 e efeito curto
66,7 (estimadas a partir das linhas harmônicas). O componente usa
`idle_loop_frequency`, `accel_loop_frequency` e `rev_blip_frequency`.

Para regenerar (Python 3, numpy e ffmpeg), a partir da raiz do repositório:

```text
python3 tools/audio/build_engine_samples.py
```

O script localiza as gravações por nome (`*mustang*1985*`, `*v8*`,
`*mustang*1969*`, e pelos números de origem), não altera os originais e relê os
arquivos gravados para conferir formato, nível, pico, clipping e emendas.

## Arquitetura

O componente é um `Node3D` com três players filhos criados na cena:
`EngineIdle`, `EngineAccel` e `RevBlip`. Nenhum nó é criado durante o jogo. Todo
o trabalho ocorre em `_process`, com poucas operações por quadro.

- **Rotação:** com `transmission_enabled` (padrão), vem da transmissão virtual
  (próxima seção). Com ela desligada vale a versão A anterior: velocidade
  longitudinal dividida por `max_speed`, com marchas uniformes (`gear_count` = 3,
  queda de rotação `shift_rpm_drop` = 0,12; use 1 para rotação contínua). Nos dois
  casos, no ar a rotação acompanha o acelerador e, na lama ou na água, sobe como
  se as rodas patinassem.
- **Frequência e pitch:** rotação → frequência de explosões. Com a transmissão,
  mapeamento linear de `idle_frequency` (47,5 Hz) a `transmission_max_frequency`
  (74 Hz): a queda de rotação numa troca precisa ser audível. Sem a transmissão
  (versão A), de 47,5 a `max_frequency` (70 Hz) com curva `frequency_curve` (1,5),
  que achata perto do limite e deixa a troca quase inaudível. O pitch de cada
  camada é `frequência / frequência nativa da amostra`, limitado por
  `max_pitch_ratio` (1,6).
- **Modos (`accel_mode`):**
  - `DYNAMIC` (versão A): a marcha lenta é a sustentação. O loop de aceleração
    reforça enquanto a rotação *sobe* ("aceleração em curso", `surge`: entra em
    ~1 s e se retira em ~3 s quando a rotação se estabiliza) e fica em
    `sustain_blend` (0,10, ~−22 dB) com carga constante.
  - `IDLE_ONLY` (versão B): só a marcha lenta, com pitch e volume pela rotação
    e pela carga.
  - `CONTINUOUS` (referência): o loop de aceleração domina sempre que há
    rotação alta ou carga. É a mixagem anterior, mantida para comparação.
  - `BLIP`: marcha lenta + `RevBlip` (Mustang 1969), uma vez ao pisar no
    acelerador a partir da marcha lenta (rotação abaixo de `blip_max_rpm`, no
    chão, intervalo de `blip_cooldown`).
- **Mistura:** crossfade de potência constante entre `EngineIdle` e
  `EngineAccel` (gravações diferentes). A troca de modo em tempo de execução
  acomoda a mistura em ~0,5 s (`layer_blend_rate`), sem corte.
- **Turbo:** sem som próprio. Com `turbo_active`, o motor ganha
  `turbo_boost_db` (1,5 dB) e um pouco de rotação (`turbo_rpm_boost`).
- **Segurança:** transições exponenciais independentes do FPS; volume de cada
  camada com teto `max_layer_db`; barramento inexistente recai em Master; player
  ou stream ausente vira apenas uma camada silenciosa.

## Repetição em velocidade constante

O teste manual reprovou a primeira versão com gravações reais: em velocidade
constante o motor fazia um "nhoum-nhoum" repetitivo. Diagnóstico (medições nos
WAVs e simulação da lógica; sem teste auditivo):

- **Mixagem.** Em velocidade máxima a rotação ficava em 1,0000 e o loop de
  aceleração tocava sozinho, com 100% da mistura, a ~1,44x de pitch: o loop de
  1,45 s repetia a cada ~1 s. RPM, pitch e volume estavam estáveis (não eram a
  causa), mas o conteúdo do loop varia em ciclo.
- **Conteúdo do loop.** O trecho vem de uma subida de rotação. O tom foi
  normalizado, o timbre não: o centróide espectral sobe de ~150 a ~230 Hz
  dentro do trecho. Cada repetição soa como uma nova "acelerada".
- **EQ.** O EQ de ±6 dB aplicado depois do nivelamento de volume elevou a
  modulação de volume do loop no ritmo da repetição de 0,19 dB para 0,83 dB
  (desvio do envelope de 1,2 para 2,2 dB; a marcha lenta aprovada tem ~0,03 dB).
- **Descartados:** a emenda (salto menor que o passo típico do sinal; sem
  diferença no espectrograma), o crossfade (energia harmônica 0,4 dB acima do
  corpo), a variação de tom (0,2%) e as marchas virtuais (em velocidade constante
  não há troca).
- **Gravação B sem trecho estacionário:** o tom sobe dentro de cada marcha e só
  há um platô de ~0,9 s, curto demais. Por isso a sustentação vem da marcha
  lenta (estável por ~17 s na gravação) e o loop de aceleração fica restrito às
  mudanças de carga.

Resultado na simulação (render offline com as amostras reais, W segurado a
86 km/h por 30 s; pico da modulação de volume do envelope): mixagem anterior
com a amostra anterior 0,76 dB a 2,0 Hz; versão A 0,2 dB e versão B 0,17 dB,
no nível da marcha lenta aprovada.

## Transmissão automática virtual

Fica toda em `van_engine_audio.gd` e só **observa** a van (velocidade, acelerador,
contato com o chão, lama/água, turbo); não escreve na van nem aplica forças, e
não depende do veículo falso. `transmission_enabled` (padrão ligado) a liga e
desliga em execução; desligada, o componente segue exatamente o caminho da
versão A anterior (mesmas marchas uniformes, mesma curva de frequência).

**Marchas: 3, calibradas para a van arcade.** `gear_top_fractions` = 0,40 / 0,76 /
1,25: velocidade, como fração de `max_speed`, em que cada marcha chega à
rotação máxima. Com `max_speed` = 24 m/s (86 km/h) e acelerador pleno, isso
dá trocas perto de **30 km/h (1ª→2ª) e 57–60 km/h (2ª→3ª)**; a 3ª vai até a
velocidade máxima com o motor em 80% da rotação (marcha final relaxada). Os
valores seguem a proposta inicial de design (1ª 0–30, 2ª 30–60, 3ª 60–90 km/h) e
a relação entre marchas (1,9 e 1,6) é a do T-5 do Mustang GT 1985 (1,74 e 1,50)
alargada para a queda ficar audível; **não é fidelidade automotiva**. Como são
frações de `max_speed`, as trocas acompanham uma velocidade máxima diferente, e
como dependem da velocidade (não do tempo), acompanham uma aceleração
diferente: aceleração mais lenta = marchas mais longas. O tamanho do vetor
define a quantidade de marchas.

**Decisão.** A "rotação da marcha" é a velocidade filtrada dividida pela
velocidade da marcha; é ela que decide (nunca a rotação sonora, que atrasa). O
filtro sobe rápido (`speed_filter_rate` 20/s) e cai devagar (`speed_fall_rate`
5/s), para quedas curtas de velocidade (buracos) pouco mexerem.

| Regra | Valor |
|---|---|
| Subir | acelerador > 0,15 e rotação da marcha ≥ `upshift_rpm_light` (0,66) com acelerador leve, até `upshift_rpm_full` (0,86) com acelerador pleno (interpolado) |
| Reduzir | rotação da marcha < `downshift_rpm` (0,26); com acelerador > 0,85, < `kickdown_rpm` (0,30) |
| Histerese | subir ≥ 0,66 e reduzir < 0,26; depois de subir, a rotação na nova marcha fica em ≥ 0,35 (acima de 0,30). Nunca reduz para uma marcha que já pediria subida |
| Intervalo mínimo | `min_shift_interval` 0,7 s entre duas trocas; 2 s para uma troca em sentido contrário à anterior (`opposite_shift_interval`); em lama/água os dois dobram (`heavy_interval_scale`) |
| Persistência | a condição precisa durar `shift_hold_time` 0,08 s |
| Voo | sem apoio por mais de `airborne_delay` 0,25 s não há trocas; solavancos e saltos curtos são ignorados |
| Freada forte | desaceleração > `hard_brake_decel` 7 m/s² não reduz (evita o "tranco" no fim de uma freada brusca) |
| Parado | abaixo de `stop_speed` 1,5 m/s por 0,3 s volta à 1ª marcha, sem som de troca |
| Ré | marcha única, rotação baixa (até 0,6), sem trocas |
| Sem tempo aleatório | nenhuma troca depende só do tempo |

Estados internos (em `get_debug_state()`): marcha (`gear_label`: R, N, 1–3),
rotação virtual, carga, estado de troca (`NONE`, `UP`, `DOWN` e progresso),
estado de condução (parado, acelerando, estável, desacelerando, ré). O sinal
`gear_changed(gear, upshift)` avisa cada troca (reservado para ganchos futuros).

**Resposta sonora.**

- *Subida* (5 passos): (1) o motor ganha rotação até ~0,86; (2) a carga alivia
  primeiro (`shift_load_floor` 0,2) e o volume cai `shift_dip_db` (−1,5 dB) além
  do que a carga já tira, com a rotação segurando o pico por `shift_fall_delay`
  (0,08 s); (3) a rotação cai suavemente (`shift_fall_rate`), passando brevemente
  abaixo da nova marcha (`shift_rpm_dip` 0,10, "respiro"); (4) a carga volta a
  `shift_recover_rate` e o motor retoma o ronco na marcha seguinte; (5) segue
  acelerando com a rotação ligada à velocidade. `upshift_duration` = 0,5 s. Nunca
  chega a zero: o motor não é cortado. Na simulação do perfil calibrado: rotação
  sonora 0,86 → 0,47 / 0,50 (pitch −14,8% / −13,6%), nível total −3,8 dB, mínimo
  ~0,35 s depois do início da troca (antes: −11 a −13% e ~−4 dB por 0,4 s).
- *Redução:* sem corte de carga; a rotação sobe moderadamente
  (`downshift_rise_rate` 6, `downshift_duration` 0,35 s): pitch +4% a +5%. A
  "aceleração em curso" da versão A não dispara com rotação que sobe sem
  acelerador, então a camada de aceleração não aparece numa redução.
- *Lançamento e lama:* quando o alvo de rotação é só o piso de arranque (`launch_rpm`)
  ou de patinação (`slip_rpm` 0,5, antes 0,65), a rotação sobe a `launch_rise_rate`
  (3,5/s), não a 16/s. O maior salto de pitch no arranque na lama caiu de 141 para
  27 cents por quadro de 60 Hz na simulação.
- *Velocidade constante:* a marcha não muda; rotação, pitch e carga ficam fixos.
  A sustentação é a da versão A (marcha lenta + camada de aceleração em
  `sustain_blend` 0,10).
- *Desaceleração e parada:* a rotação acompanha a velocidade (`tx_rpm_fall_rate`)
  e pode haver uma ou duas reduções suaves; parado, volta à marcha lenta aprovada.
- A mistura de camadas (versão A), o WAV de marcha lenta e o turbo (sem som, só
  reforço de 1,5 dB e +0,06 de rotação) não mudaram.

**Perfis de aceleração da demo (só no veículo falso).** O componente de áudio só lê
a velocidade; os dois perfis existem em `demo_vehicle_stub.gd` para avaliar a
sensação sonora, e não mudam a van real:

| Perfil | Aceleração | 0–30 | 0–60 | 0–80 | máx. (86) |
|---|---|---|---|---|---|
| RÁPIDO (anterior, tecla 9) | 9 m/s² constante | 0,9 s | 1,9 s | 2,5 s | 2,7 s |
| CALIBRADO (tecla 0) | 4,5·(1 − 0,5·(v/máx)³) m/s² | 1,9 s | 3,9 s | 5,6 s | 6,3 s |

Referência: o Mustang GT 1985 da Car and Driver faz 0–60 mph (97 km/h) em 6,4 s. O
perfil calibrado tem ritmo da mesma ordem (a van para em 86 km/h), sem pretensão de
fidelidade; o perfil rápido é cerca de 2,5 vezes mais rápido.

**Trechos reais de troca de marcha (`ford-v8-accleration.wav`).** Foram
medidos os eventos de ~3,4 s e ~6,9 s (bandas de 20 ms; sem ouvir):

| Evento | Medição | Conclusão |
|---|---|---|
| 3,45 s | pancada de +10 dB em relação ao entorno; banda < 400 Hz = banda total; > 1,5 kHz praticamente inalterada (−52 a −58 dB) | pancada grave de câmbio, sem componente brilhante |
| 6,90 s e 7,30 s | pancadas de +14 dB, também só < 400 Hz | idem; duas pancadas em 0,4 s |
| Tom (rastreado) | 39 → 35 Hz em ~0,7 s ao redor de cada troca, retomando em 41–46 Hz | queda de ~10%, mais curta e mais fraca que a obtida com RPM e carga |

As pancadas estão misturadas ao motor da própria gravação (tom e timbre da
gravação B, e não os da marcha lenta); recortá-las traria junto o outro motor
a outra altura. O resultado seria a "duplicação de motores" e a mudança brusca
de timbre que o pedido manda evitar. **Nenhum trecho real de troca foi usado**
e nenhum WAV foi adicionado; o loop de aceleração continua sem as pancadas
(4,55–6,60 s). O efeito vem só de RPM, pitch e carga. Se na escuta a troca
parecer "mole", o próximo passo possível é uma pancada grave sintetizada ou
outra gravação; fora do escopo deste pedido.

## Como o componente lê a van

Somente leitura, por nome, verificada uma vez ao vincular. Nenhuma propriedade
é obrigatória:

| Propriedade da van | Uso | Sem ela |
|---|---|---|
| `linear_velocity` | velocidade longitudinal | estima pela variação de posição |
| `max_speed` | referência das marchas | `fallback_max_speed` |
| `turbo_active` | reforço do motor | sem reforço |
| `ground_contacts` | detectar voo (< 2; com a transmissão só após 0,25 s) | considera no chão |
| `in_mud`, `in_water` | rotação/carga extra | ignora |
| `player_input_enabled` | zera o acelerador em contagens e menus | lê a entrada |
| `throttle_input` | acelerador (-1 a 1) | lê as ações `accelerate`/`reverse` |

A velocidade é lida com sinal (para frente > 0). Acelerador contra o movimento
(freio) não conta como acelerador do motor: não gera carga nem reforço. Sem
movimento, acelerador negativo é ré.

`van_controller.gd` não expõe o acelerador; por isso o componente lê as mesmas
ações do Input Map e respeita `player_input_enabled`. Se um dia a van expuser
`throttle_input`, ele passa a ter prioridade sem nenhuma mudança no áudio.
`turbo_active` só é verdadeiro com a van apoiada; durante um salto o componente
mantém o reforço até o pouso, para não oscilar a cada salto.

## Laboratório de áudio (demonstração)

Abra `res://audio/demo/engine_audio_demo.tscn` e pressione **F6**. A cena
mostra uma interface escura ("Oficina Arcade") desenhada para 1920×1080; em
1280×720 o `stretch` do projeto (`canvas_items`) só reduz a escala. O veículo
de teste começa vinculado e o motor toca em marcha lenta.

**Organização da tela.**

- *Topo:* título e botão **DIAGNÓSTICO TÉCNICO (F3)**; mensagens curtas ("Teste
  reiniciado…") aparecem no centro.
- *Esquerda, em cima:* vista lateral da van numa estrada (só apresentação; no
  lugar dela aparece o painel técnico quando ele é aberto).
- *Esquerda, instrumentos:* **velocidade** (km/h), **conta-giros** com a
  **marcha** grande no centro (e, a cada troca, a transição "1ª → 2ª" com um
  anel colorido: laranja sobe, ciano reduz), barras de **acelerador** e
  **freio**, e perfil, transmissão, estado e versão sonora ativos.
- *Esquerda, embaixo:* o botão grande **TESTAR ACELERAÇÃO**, a etapa atual, a
  barra de progresso das 9 etapas, as marcas 0–30/60/80 km/h, as condições
  ativas e os botões **COMPARAR TESTES (A, B, C)**.
- *Direita:* controles clicáveis (perfil, transmissão, comportamento,
  comparação sonora, condições, volume).

Os botões não recebem foco de teclado: Espaço (voo) e as demais teclas nunca
"clicam" um botão sem querer. Mouse e teclado chamam as **mesmas** funções
(`action_*`) do controlador `engine_audio_demo.gd`; a interface só lê o estado
e o desenha, a cada quadro, então um atalho de teclado sempre atualiza o botão.

**Controles.**

| Grupo | Controles | Atalho |
|---|---|---|
| Perfil de aceleração | RÁPIDO · CALIBRADO | 9 · 0 |
| Transmissão | LIGADA · DESLIGADA (= versão A anterior) | 7 · 8 |
| Comportamento | ACELERAR e FREAR (segurar o botão do mouse) · TESTE AUTOMÁTICO · PARAR E ZERAR | W · B · T · R |
| Comparação sonora | VERSÃO A (aprovada) · ALTERNATIVA B (só marcha lenta) · REFERÊNCIA ANTERIOR (loop contínuo) · EFEITO CURTO (Mustang 1969) | 1 · 2 · 5 · 6 |
| Condições | ACELERADOR 50% · PISO IRREGULAR · LAMA · VOO · VELOCIDADE FIXA | P · N · M · Espaço · 3/4 |
| Volume geral | controle deslizante, −40 a 0 dB (volume base do motor) | + · − |
| Testes | TESTE A · B · C | Q · E · F |
| Painel técnico | DIAGNÓSTICO TÉCNICO / FECHAR | F3 |

Também: **Enter** (re)inicia o teste, **S** freia/ré, **Shift** mostra o estado
do turbo (sem som), **V** vincula/solta o áudio, **X** remove/restaura a van,
**C** liga/desliga o motor. Estes três últimos também são botões no painel
técnico. Segurar W, S, B ou usar Acelerar/Frear durante um teste automático o
interrompe e devolve o controle (o teste não deixa nada preso).

**Teste automático (TESTAR ACELERAÇÃO).** Roda sempre da mesma condição inicial.
Cada clique reinicia na hora: velocidade zero, marcha 1, transmissão e
temporizadores zerados; o som não salta (a rotação desce até a marcha lenta
sozinha e a etapa 1 espera ela se acalmar).

| # | Etapa | Termina quando |
|---|---|---|
| 1 | Marcha lenta inicial | ≥ 3 s e a rotação se acalmou (máx. 7 s) |
| 2 | Arrancada progressiva | velocidade ≥ 10% da máxima (ou 2,5 s) |
| 3 | Primeira troca | 1ª → 2ª concluída (ou 10 s) |
| 4 | Segunda troca | 2ª → 3ª concluída (ou 10 s) |
| 5 | Aceleração até a velocidade do perfil | 96% da velocidade final por 1,5 s (máx. 22 s) |
| 6 | Velocidade constante | 8 s com a velocidade travada |
| 7 | Desaceleração progressiva | primeira redução ou velocidade ≤ 30% da máxima |
| 8 | Reduções de marcha | van parada |
| 9 | Parada e marcha lenta | 4 s em marcha lenta; "TESTE CONCLUÍDO" |

A velocidade final é a do perfil: acelerador pleno chega a 86 km/h; com 50%,
~60 km/h; na lama, o teto de 25 km/h do veículo falso. Com a transmissão
desligada, as "trocas" das etapas 3, 4 e 7–8 seguem as marchas uniformes da
versão A. O voo é desligado ao iniciar o teste (sem apoio a van não anda).

**Comparação A/B/C.** Só combinam configurações que já existiam:

| Teste | Perfil | Transmissão | Tecla |
|---|---|---|---|
| A | CALIBRADO | ligada | Q |
| B | CALIBRADO | desligada | E |
| C | RÁPIDO | ligada | F |

Cada botão aplica a combinação e roda o teste do início. Para mudar **uma
variável por vez** sem trocar de teste: com um teste rodando, clicar em
Perfil, Transmissão ou Acelerador 50% reinicia o teste com a nova configuração
(A→B muda só a transmissão; A→C muda só o perfil). Trocar a versão sonora (A,
B, referência) **não** reinicia: dá para alternar de ouvido no meio do teste. As
condições (piso, lama, acelerador 50%) ficam como estão e aparecem no painel do
teste, em laranja se não forem as padrão, para a comparação ser justa.

**Painel técnico (F3 ou botão).** Escondido por padrão. Três abas:

- *Diagnóstico:* rotação normalizada, frequência de explosões, carga simulada,
  "aceleração em curso", mistura das camadas, pitch e nível de cada loop, efeito
  curto, estado do turbo (sempre sem som), modo e estado da transmissão, troca em
  curso, condução, velocidade e aceleração filtradas, vinculação do áudio, motor,
  terreno, perfil, tempo desde o início da arrancada, marcas 0–30/60/80, etapa e
  tempo do teste; mais botões de motor, vinculação e van.
- *Atalhos:* todas as teclas.
- *Efeitos:* pré-escuta dos efeitos futuros (ver abaixo).

Todo teste sugerido antes continua valendo (ex.: acelerar até a velocidade
máxima, travar com **3**, alternar **1/2/5**; **N** com a velocidade travada para
conferir que solavancos não trocam de marcha).

**Validação.** A lógica (estados do teste, presets, interrupção e reinício, 99
combinações de interrupção, condições parcial/irregular/lama/voo, assumir o
controle) foi simulada num port em Python do controlador, do veículo falso e do
componente; os scripts passaram por uma checagem estática (indentação,
parênteses, referências entre arquivos e as chaves usadas). **Nada foi executado
na Godot e nada foi ouvido.** O aspecto visual (layout, proporções, fontes) só
será visto no primeiro F6.

## Efeitos sonoros de gameplay (primeiro pacote)

**Estado: infraestrutura pronta, nenhuma gravação incluída ainda.** O ambiente
de trabalho não tem rede e o Freesound exige login para baixar, então os
originais não foram obtidos. Nenhum som foi sintetizado nem inventado. As
pastas ficam vazias até você baixar e aprovar as gravações. Candidatas com
licença conferida: ver `CREDITS.md` e `tools/audio/sfx_sources.json`.

### Pastas

| Caminho | Conteúdo |
|---|---|
| `tools/audio/source_recordings/sfx/<pasta>/` | **Originais** baixados, sem alteração. |
| `game/audio/sfx/gameplay/<pasta>/` | **Versões processadas**, as únicas que o jogo carrega. |
| `tools/audio/sfx_sources.json` | Título, autor, URL, licença, arquivo derivado e parâmetros de cada gravação. |
| `tools/audio/process_sfx.py` | Gera as processadas a partir dos originais (só Python 3 + numpy). |

Pastas de `gameplay/`: `arvore`, `madeira_folhas`, `aterrissagem_suave`,
`aterrissagem_firme`, `aterrissagem_brutal`, `caixa`, `barril`, `cone`
(WAV, OGG ou MP3; mais de um arquivo por pasta vira variação).

### Processamento (`process_sfx.py`)

Recorte manual opcional e recorte automático do silêncio das pontas (folga de
5 ms antes e 40 ms depois do som), remoção do componente contínuo, mixagem para
mono (melhor para posicionamento 3D), fade-in de 2 ms, fade-out de 60 ms e
normalização do pico para **-3 dBFS**. Sem compressão, sem limitador, sem
equalização, sem reamostragem; saída em WAV PCM 16 bits. Sem original, o script só
avisa "original ausente". `--check` confere os WAVs prontos (clipping, fades,
duração). Os parâmetros de cada entrada ficam em `sfx_sources.json` (`process`)
e devem ser ajustados **depois de ouvir** o original.

### Componente `gameplay_sfx.gd` (`class_name GameplaySfx`)

Nó 3D leve, sem Autoload e sem nenhuma ligação com a GameSession. Adicione como
filho de qualquer nó e chame:

```gdscript
sfx.play_tree_break(arvore.global_position)
sfx.play_wood_leaves(pos, 0.8)
sfx.play_landing(van.global_position, GameplaySfx.Landing.STRONG)   # LIGHT / MEDIUM / STRONG
sfx.play_impact("crate", pos, 0.6)      # "crate", "barrel", "cone"
sfx.play_event("cone", pos, 1.0)        # forma geral; devolve true se tocou
```

A intensidade (0 a 1) abaixa o volume (até 6 a 10 dB, conforme o evento) e altera o
pitch em no máximo ±1,5%. Os pousos têm uma pasta por nível, para que
compartilhem a identidade mecânica mas soem diferentes; nível sem gravação não
toca, sem substituto.

### Variação e proteção

- **Alternativas:** com mais de um arquivo na pasta, sorteia sem repetir o anterior.
- **Pitch:** variação aleatória de ±2% a ±6% por evento, com teto fixo de ±8% e
  trava final em 0,9–1,1.
- **Volume:** variação aleatória de ±1 a ±2 dB mais a queda pela intensidade.
- **Vozes:** 8 `AudioStreamPlayer3D` reaproveitados (nada é criado durante o jogo),
  com máximo de 2 a 3 por evento e *cooldown* de 50 a 250 ms por evento.
- **Excesso de volume:** cada voz já ativa abaixa o novo som em 2 dB (até 10 dB) e
  nenhuma voz passa de -1 dB. Não há limitador de barramento: isso exigiria mexer
  no layout de barramentos do projeto, fora do escopo desta tarefa.
- **Sem cortes indevidos:** um som em curso só é substituído se já passou de
  150 ms e o novo for pelo menos 1 dB mais forte; senão o pedido novo é descartado e
  o som atual termina inteiro. Escolhi não usar `AudioStreamRandomizer`:
  o componente já controla pitch, volume e sorteio por chamada, com a intensidade
  entrando na conta, e o Randomizer não faria o limite de vozes nem a intensidade.
- **Custo:** sem `_process`; só trabalha no instante do disparo.

### Como testar no laboratório

Abra a aba **EFEITOS** do painel técnico (F3 e depois a aba). A grade tem um botão
por efeito (árvore, madeira e folhas, pouso suave/firme/brutal, caixa, barril,
cone); botão em tom claro com "aguardando" é pasta sem gravação (clicar mostra
em qual pasta soltar o arquivo). Abaixo:

- **INTENSIDADE:** deslizante de 0 a 100%, vale para todos os efeitos.
- **REPETIR:** repete o último efeito a cada 1,2 s, para avaliar cansaço.
- **RAJADA ×6:** seis disparos seguidos (90 ms), para ouvir o limite de vozes.
- **MOTOR MUDO:** silencia o motor durante a pré-escuta; clicar de novo (ou apertar
  C) devolve o estado anterior. O restante da demonstração do V8 não muda.
- **PARAR:** interrompe efeitos e repetições.
- A linha de estado mostra último efeito, vozes ativas, tocados, descartados e trocados.

Os efeitos tocam num ponto fixo (onde fica a van) e a câmera de teste é o
ouvinte. O volume acompanha o volume geral +6 dB (máx. 0 dB), como a pré-escuta
antiga. A **pré-escuta livre** (`sfx/preview/<pasta>/`, arquivos soltos) continua
disponível no fim da mesma aba.

### Para ativar um efeito

1. Ouça a candidata pela URL em `CREDITS.md`, baixe o WAV (logado) e salve em
   `tools/audio/source_recordings/sfx/<pasta>/`, mantendo o nome que o Freesound dá.
2. Ajuste `process` em `sfx_sources.json` se precisar de recorte manual.
3. `python3 tools/audio/process_sfx.py` e depois `--check`.
4. Reabra o laboratório (ou **REESCANEAR**) e ouça.
5. Só considere definitivo o que você aprovar de ouvido; registre em `CREDITS.md`.

## Integração futura

1. Instancie `van_engine_audio.tscn` como filho da van (acompanha a posição
   sozinho) ou em qualquer ponto da cena de jogo.
2. Defina `vehicle` no inspetor, chame `set_vehicle(van)` ao criar a van, ou
   coloque a van num grupo e preencha `vehicle_group`.
3. Em pausa, resultados ou contagem, use `engine_enabled = false` se quiser
   silenciar o motor; com `player_input_enabled = false` na van, o motor
   continua em marcha lenta.
4. Opcional: crie um barramento `Vehicles` com um limitador e defina
   `audio_bus`. Isso exige alterar o layout de barramentos do projeto.

## Limitações conhecidas

- **Atribuição:** o Ford V8 5.0 (CC BY 3.0) exige crédito no jogo distribuído
  (texto em `CREDITS.md`). A cópia usada do Mustang 1985 vem do Pixabay; veja
  "Proveniência real do Mustang 1985".
- **Laboratório sem teste na engine:** a interface foi escrita e a lógica
  simulada em Python, mas ninguém abriu a cena na Godot. Possíveis ajustes
  visuais (espaçamentos, cortes de texto, tamanho da vista da estrada) só
  aparecem no primeiro F6.
- A qualidade sonora depende de teste auditivo; as amostras e as transições
  foram validadas apenas por medição, análise espectral e simulação.
- Em velocidade constante, as versões A e B ficam quase iguais (a camada de
  aceleração está em ~−22 dB em A); a diferença aparece durante a aceleração.
  Se quiser mais "ronco" sustentado em A, aumente `sustain_blend` aos poucos: a
  modulação no ritmo do loop cresce com ele (0,10 → ~0,1 dB; 0,25 → 0,18 dB).
- A sustentação usa a marcha lenta com pitch até ~1,47x. Fora da faixa em que a
  gravação existe (explosões de 47,5 Hz), o timbre fica mais grave e "lopado"
  do que um V8 em rotação alta de verdade.
- O loop de aceleração mantém a variação de timbre do trecho original; por isso
  só atua durante a subida de rotação. Em aceleração longa pode soar um ciclo de
  ~1,4 s (tem ~3 s para a retirada gradual).
- Sobra diferença de timbre entre a marcha lenta e as outras gravações (o EQ do
  efeito curto atingiu o limite de ±6 dB). Se a mistura parecer "dois veículos",
  o caminho é escolher outro trecho ou outra gravação, não processar mais.
- O importador de WAV da Godot usa compressão QOA por padrão. Se notar
  artefatos, selecione os WAVs, defina "Compress > Mode" como PCM
  (Uncompressed) no painel Import e reimporte.
- Os arquivos antigos sintetizados (`sfx/engine_low_loop.wav`,
  `engine_high_loop.wav`, `turbo_whistle_loop.wav`, `turbo_release.wav` e
  `tools/audio/generate_placeholder_audio.py`) não são mais usados e podem ser
  removidos do projeto.
- Sem som de partida/desligamento, pancada de câmbio, turbo, derrapagem, pouso,
  colisões, lama, água, árvores ou interface.
- **Transmissão:** os parâmetros de tempo e profundidade da troca (queda de
  ~14% no pitch, ~−4 dB por ~0,5 s) vêm de simulação e aritmética, não de escuta.
  O resultado depende de ouvir: se a troca parecer fraca ou demais, os botões são
  `shift_rpm_dip`, `shift_dip_db`, `shift_load_floor`, `shift_fall_delay`,
  `gear_top_fractions` e `transmission_max_frequency`.
- Pelos parâmetros de `van_controller.gd` (`acceleration` 9,0), a van real deve acelerar
  perto do perfil RÁPIDO (ver "Perfis de aceleração"): as duas trocas ficam a ~1,5 s e
  ~2,4 s e cada marcha dura cerca de 1 s. O áudio não altera isso; a calibração
  gradual só existe no veículo falso. Isso não foi medido na van real.
- Rolar para trás com o acelerador à frente conta como freio (o motor não acelera).
- O arranque (e a patinação na lama) agora sobe a rotação devagar (`launch_rise_rate`),
  o que deve evitar o "grito"; se ficar "mole" ao arrancar, aumente esse valor.
- Em oscilações grandes de velocidade na lama (15 a 45 km/h a cada 5 s) ainda há
  uma troca por oscilação, no mínimo 4 s entre elas; é o comportamento esperado
  da histerese, não um sobe-e-desce.
- Os cenários de teste foram simulados num port em Python da lógica (não na
  Godot) e as amostras foram renderizadas offline; ninguém ouviu o resultado.
- O pitch acompanha a rotação estimada a 60 Hz de física com suavização; não
  há modelo de motor real.
