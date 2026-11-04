# Van 4x4

Van 4x4 é um jogo 3D de direção off-road com física arcade, desenvolvido pela Low Gear Games para a disciplina de Jogos Digitais da Universidade Federal de Pelotas. O jogador dirige uma van de manutenção por terrenos montanhosos para realizar reparos.

## Tecnologias

- Godot 4.7.2 e GDScript.
- Jolt Physics.
- Renderizador Compatibility (OpenGL).

## Como executar

1. Importe `game/project.godot` na Godot 4.7.2.
2. Abra `game/scenes/mission_level.tscn` e pressione **F6** para jogar a fase com a missão da antena.

Para testar a sessão com contagem regressiva e coleta de estatísticas, abra `game/scenes/session_trial.tscn` e pressione **F6**. O resumo é exibido no Output ao concluir o reparo.

**F5** executa `driving_test.tscn`, o playground original, conforme a configuração atual do projeto.

## Documentação

- [Game Design Document (GDD)](docs/gdd/index.html)
- [Technical Design Document (TDD)](docs/tdd/index.html)

Os documentos são páginas HTML e podem ser abertos no navegador. As seções 11 e 12 do TDD permanecem em elaboração.

## Créditos

Os modelos de natureza são uma seleção do **Stylized Nature MegaKit [Standard]**, de **Quaternius**, sob licença **CC0 1.0**. Consulte a [licença](game/assets/environment/quaternius_nature/License_Standard.txt) e os [recursos utilizados](game/assets/environment/quaternius_nature/README.md).
