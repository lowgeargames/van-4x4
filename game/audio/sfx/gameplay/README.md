# Efeitos de gameplay processados

Só entram aqui as versões **processadas** e **aprovadas de ouvido**; os originais
ficam em `tools/audio/source_recordings/sfx/`. Hoje todas as pastas estão vazias:
nenhuma gravação foi baixada e nada foi sintetizado.

Pastas lidas por `game/audio/gameplay_sfx.gd`:

| Pasta | Evento |
|---|---|
| `arvore/` | `tree_break` |
| `madeira_folhas/` | `wood_leaves` |
| `aterrissagem_suave/` | `landing_light` |
| `aterrissagem_firme/` | `landing_medium` |
| `aterrissagem_brutal/` | `landing_strong` |
| `caixa/` | `crate` |
| `barril/` | `barrel` |
| `cone/` | `cone` |

Mais de um arquivo por pasta = variações sorteadas. Gere os arquivos com
`python3 tools/audio/process_sfx.py` (ver `game/audio/README.md`). Origem, autor,
licença e modificações de cada um: `game/audio/CREDITS.md` e
`tools/audio/sfx_sources.json`.
