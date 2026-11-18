# Créditos de áudio: motor V8 do Van 4x4

Procedência e licença das gravações usadas nos três WAVs do motor
(`game/audio/sfx/v8_*.wav`). Autor, título, link e licença foram conferidos
diretamente nas páginas do Freesound pelo responsável pelo projeto; este arquivo
os registra e não substitui uma revisão jurídica. Os originais estão preservados,
sem alteração, em `tools/audio/source_recordings/`.

## Resumo

| Gravação | Autor | Licença | Atribuição | Usada em |
|---|---|---|---|---|
| Ford Mustang Engine (1985).wav | lmbubec | CC0 | não exigida | `v8_idle_loop.wav` (marcha lenta aprovada) |
| Acceleration sounds of Ford V8 5 Liter engine | noiseloop | **CC BY 3.0** | **obrigatória** | `v8_accel_loop.wav` (reforço de aceleração) |
| Muscle Car Revving | FlaxGod | CC0 | não exigida | `v8_rev_blip.wav` (efeito curto) |

## Ford V8 5.0 (CC BY 3.0): atribuição obrigatória

Incluir nos créditos do jogo, em qualquer versão distribuída:

> "Acceleration sounds of Ford V8 5 Liter engine" por noiseloop
> (<https://freesound.org/people/noiseloop/sounds/455926/>), licenciado sob
> CC BY 3.0 (<https://creativecommons.org/licenses/by/3.0/>). Modificado para o
> Van 4x4: trecho de ~2 s recortado, altura normalizada, filtrado, equalizado,
> transformado em loop e convertido para mono 16 bits / 44,1 kHz; altura e
> volume também são alterados em tempo real pelo jogo.

English (for store pages and in-game credits):

> "Acceleration sounds of Ford V8 5 Liter engine" by noiseloop
> (<https://freesound.org/people/noiseloop/sounds/455926/>), licensed under
> CC BY 3.0 (<https://creativecommons.org/licenses/by/3.0/>). Modified for
> Van 4x4: a ~2 s excerpt was cut, pitch-normalized, filtered, equalized, looped
> and converted to mono 16-bit / 44.1 kHz; pitch and volume are also changed in
> real time by the game.

**Modificações feitas** (ver `tools/audio/build_engine_samples.py` e o README
de `game/audio/`):

- recorte de 4,55 a 6,60 s da gravação (a segunda subida de rotação);
- normalização de altura por reamostragem com taxa variável (−12% a +18%), para
  o tom ficar fixo em 33 Hz;
- filtro passa-alta de 12 Hz;
- equalização suave (no máximo ±3 dB) de aproximação ao timbre da marcha lenta;
- crossfade de 0,5 s para formar o loop e nivelamento de volume (RMS −14 dBFS,
  pico limitado a −3 dBFS);
- conversão para mono, 16 bits, 44,1 kHz;
- no jogo: pitch e volume controlados em tempo real pelo componente de áudio.

A licença CC BY 3.0 não pede aprovação do autor, mas não permite sugerir que ele
endossa o jogo.

## Ford Mustang 1985 (CC0)

- Título: **Ford Mustang Engine (1985).wav** · Autor: **lmbubec** · Licença: CC0
  (<https://creativecommons.org/publicdomain/zero/1.0/>).
- Original no Freesound: <https://freesound.org/people/lmbubec/sounds/119449/>.
- **Proveniência real do arquivo usado:** MP3 baixado da página do Pixabay
  <https://pixabay.com/sound-effects/technology-ford-mustang-engine-1985-78386/>
  (arquivo local `ford-mustang-engine-1985.mp3`, 24 kHz, estéreo com canais
  idênticos). Essa página identifica lmbubec como autor original e mostra a
  Licença de Conteúdo do Pixabay.
- Como a licença exibida no Freesound (CC0) e a exibida no Pixabay descrevem
  condições diferentes para a mesma gravação, vale registrar as duas. Se o
  projeto quiser usar só a base CC0, o caminho é baixar o WAV original do
  Freesound e regenerar `v8_idle_loop.wav`; não foi feito e nenhum WAV foi
  alterado por causa desta documentação.
- Atribuição não exigida; sugestão de crédito por cortesia: "Ford Mustang Engine
  (1985).wav" por lmbubec (Freesound).
- Modificações em `v8_idle_loop.wav`: trecho de 2,80 a 9,73 s, crossfade de 1,0 s
  para o loop, filtro passa-alta de 12 Hz, nivelamento de volume, mono 16 bits /
  44,1 kHz.

## Muscle Car Revving, Mustang 1969 (CC0)

- Título: **Muscle Car Revving** · Autor: **FlaxGod** · Licença: CC0.
- <https://freesound.org/people/FlaxGod/sounds/653226/>
- Atribuição não exigida; sugestão de crédito por cortesia: "Muscle Car Revving"
  por FlaxGod (Freesound).
- Modificações em `v8_rev_blip.wav`: trecho de 0,00 a 1,90 s, fades, equalização
  de aproximação, filtro passa-alta de 12 Hz, nível normalizado, mono 16 bits /
  44,1 kHz.

## Arquivos de áudio fora do motor

Os arquivos antigos sintetizados (`engine_low_loop.wav`, `engine_high_loop.wav`,
`turbo_whistle_loop.wav`, `turbo_release.wav`) não vêm de gravação de terceiros
e não são usados. O turbo continua sem som.

## Efeitos de gameplay (candidatas: nenhuma incluída no jogo ainda)

Nenhum arquivo de áudio de efeito foi baixado, processado ou incluído. Os dados
abaixo vêm das páginas originais do Freesound, consultadas em 2026-11-09 (título,
autor, licença e duração exibidos na página), **sem ter ouvido as gravações**.
Registro máquina-legível em `tools/audio/sfx_sources.json`. Toda gravação só vira
definitiva depois da aprovação auditiva e deste registro com as modificações feitas.

### Candidatas com licença CC0 (sem atribuição obrigatória)

| Efeito | Título | Autor | URL | Licença | Duração | Arquivo derivado previsto |
|---|---|---|---|---|---|---|
| Árvore | A Tree Falling Down.wav | ecfike | <https://freesound.org/people/ecfike/sounds/139952/> | CC0 | 4,52 s | `sfx/gameplay/arvore/arvore_01.wav` |
| Madeira e folhas | Twigs Breaking | Elements-Library (nome na URL; a página mostra truncado) | <https://freesound.org/people/Elements-Library/sounds/683793/> | CC0 | 1,77 s | `sfx/gameplay/madeira_folhas/madeira_folhas_01.wav` |
| Caixa de madeira | Wood Crate Destory 1 | Bertsz | <https://freesound.org/people/Bertsz/sounds/500902/> | CC0 | 1,61 s | `sfx/gameplay/caixa/caixa_01.wav` |

Modificações previstas (a confirmar): recorte, remoção de silêncio e de componente
contínuo, mixagem para mono, fades curtos e normalização do pico para -3 dBFS.

### Encontradas, mas não usadas

- *heavy_crate_smash.wav*, Srehpog, <https://freesound.org/people/Srehpog/sounds/31625/>,
  **CC BY 3.0**: exigiria atribuição; só entraria com sua aprovação.
- *Big Conifer Tree Creaks And Groans…*, <https://freesound.org/people/Kinoton/sounds/494071/>:
  a página consultada não informa licença nem autor; **não usar** sem conferir.

### Sem candidata verificada

Barril metálico, cone plástico e pouso (suave, firme, brutal): nenhuma gravação
com licença conferida foi encontrada; as categorias seguem vazias. Se você
indicar links, eu verifico autor e licença antes de qualquer uso.

Toda gravação adicionada precisa de entrada aqui antes de ir para o jogo: autor,
título, link, licença, se exige atribuição e as modificações feitas.
