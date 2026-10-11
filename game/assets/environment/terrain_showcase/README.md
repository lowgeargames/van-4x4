# Terrain Showcase — prova de conceito isolada

Abra `res://scenes/terrain_showcase.tscn` e pressione **F6**. A cena principal
continua sendo `driving_test.tscn`. Use os mesmos controles da van; R conserva
o reposicionamento original. Não há missões nem interface nesta experiência.

## Construção

- Área física de 220 × 220 m, com grade de 2 m e 24.200 triângulos.
- Um MeshInstance3D e um StaticBody3D com uma forma côncava estática.
- A colisão é extraída dos mesmos triângulos do mesh visual.
- A estrada faz parte do terreno: altura e cor são calculadas juntas, sem
  mesh sobreposto, material transparente, degrau ou colisão independente.
- Percurso sinuoso de aproximadamente 751 m, largura central de cerca de 8 m,
  bordas irregulares, clareira inicial e mirante a 24 m de altura.
- Colinas são modeladas por funções suaves e influência contínua do percurso.
  Os perfis da estrada são graduados para a van existente; seus parâmetros
  físicos não são ajustados.
- O anel montanhoso ao fundo tem 1.728 triângulos e não possui colisão. Sua
  junção se estende discretamente sob a borda do terreno para evitar frestas.
- 230 instâncias de natureza em grupos de MultiMesh, reaproveitando os meshes
  e materiais já disponíveis do Quaternius. A altura de cada elemento é
  interpolada a partir dos triângulos reais do terreno. A vegetação permanece
  vertical, sem física individual, fora da faixa principal de circulação.
- Uma luz direcional, sombras até 85 m, céu nativo e névoa convencional leve.
  Não são usados efeitos volumétricos, shaders personalizados ou streaming.

## Recursos

- `terrain_mesh.res`: superfície física/visual, cores de vértice e normais.
- `terrain_collision.res`: colisão triangular estática correspondente.
- `background_mesh.res`: montanhas decorativas irregulares.
- `route_curve.tres`: guia de autoria, visível como gizmo ao selecionar
  `RouteGuide` no editor; não controla a van durante o jogo.

Os recursos já estão preparados. Nenhuma geometria é gerada durante o gameplay.
`res://tools/build_terrain_showcase.gd` é uma ferramenta de autoria determinística,
não anexada à cena. Para reconstruir somente a experiência, execute manualmente:

```text
godot --path game --script res://tools/build_terrain_showcase.gd --rendering-method gl_compatibility
```

A geração usa um renderer ativo para serializar corretamente os MultiMeshes;
não execute esse comando com `--headless`. Ele escreve somente a cena e os
recursos desta experiência. A van e o script da câmera são referenciados dos
arquivos existentes. Nenhum script de missões, lama ou água é usado aqui.

## Validação realizada

No Godot 4.7.2, o teste de direção usando apenas as ações de input existentes
completou o percurso em 54,2 segundos de simulação, sem reposicionar a van.
O desvio máximo do centro foi de 1,76 m. O teste utiliza comandos analógicos
automáticos para guiar o veículo e não substitui a avaliação manual com teclado.

Raycasts a cada 2 m no centro e a 3,2 m de cada lado não encontraram lacunas.
A inclinação longitudinal máxima medida foi de 8,87°; a transversal, de 2,33°.
O teste verificou quatro rodas apoiadas no spawn, o alvo da câmera, a igualdade
dos triângulos físicos/visuais e a existência de uma única colisão estática.
Também foi executada a travessia com o renderer Compatibility e produzidas
capturas pela câmera original em execução.

## Limitações

A validação cobre a faixa principal do percurso, não todas as combinações de
velocidade, turbo, drift ou trajetórias fora da estrada. As bordas do terreno
não têm barreiras e a decoração não tem colisão. Os grupos de vegetação têm
alcance visual limitado e podem aparecer à distância. Folhas recortadas e
sombras têm custo gráfico; não foi feito benchmark em computador modesto.

Os arquivos do mapa principal e as mudanças locais anteriores foram preservados.
Esta experiência não foi integrada ao mapa principal.
