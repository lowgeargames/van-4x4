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
- 325 instâncias de natureza em grupos de MultiMesh, reaproveitando os meshes
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

## Polimento visual do solo e das rochas

A superfície original possui uma única superfície, cores de vértice e nenhum
UV. O polimento mantém essas características e o material padrão: duas escalas
de ruído determinístico são avaliadas apenas na ferramenta de autoria para
preparar as cores. Elas introduzem variações suaves de verde, tons mais secos
nas encostas e pequenos trechos de terra exposta. O peso da cor da estrada e
suas bordas continua usando exatamente o traçado anterior.

Foram adicionadas 63 instâncias de grama/samambaia em pequenos agrupamentos
assimétricos, aproveitando os MultiMeshes já existentes. Naquela etapa não foram criadas texturas,
materiais, nós de plantas ou sombras de vegetação rasteira.

As 29 rochas usam amostras dos vértices da faixa inferior de cada modelo para
assentar suas bases. A ferramenta considera escala, rotação, altura e normal
da superfície; limita a inclinação visual a 20° e busca apoio próximo nas
encostas mais fortes. Quatorze rochas foram reposicionadas. A busca preserva
distância da estrada, clareiras e troncos. Uma pequena porção da base fica
enterrada, e uma verificação limita o enterramento excessivo.

O teste no Compatibility verificou todas as bases, mantendo pelo menos 59%
dos vértices de cada rocha acima do terreno. Também comparou exatamente os
vértices, índices e normais do terreno com a versão aprovada. A travessia
automatizada repetiu 54,2 segundos e 1,76 m de desvio máximo. Os arquivos de
colisão, curva e montanhas permaneceram sem alterações.

Ao reconstruir, a ferramenta reutiliza os recursos físicos aprovados e impede
que o polimento substitua uma geometria ou um traçado divergente. A quantidade
de triângulos, superfícies e colisões do terreno não mudou. O custo adicional
durante o jogo está nas 63 plantas; as buscas de apoio e o ruído não executam
durante o gameplay. Não foi realizado benchmark em computador modesto.

## Detalhe repetível de superfície

`ground_detail.png` é uma textura neutra estilizada, criada com a ferramenta
built-in imagegen. `ground_surface.tres` usa StandardMaterial3D para multiplicar
essa textura pelas cores de vértice existentes. Não foi necessário shader
personalizado. As cores de vértice, posições, índices e normais foram preservados.

A projeção triplanar em coordenadas mundiais repete o detalhe a cada 4,55 m
aproximadamente e evita o esticamento típico de uma projeção plana nas encostas.
O recurso importado tem 512 × 512 pixels, mipmaps e filtragem anisotrópica. O PNG
fonte permanece na resolução retornada pelo gerador de imagem. O material é
opaco, com rugosidade máxima, sem normal map, parallax ou deslocamento.

Foram adicionadas 32 instâncias de vegetação rasteira, incluindo cinco pequenos
arbustos floridos. A quantidade de nós e MultiMeshes permaneceu igual: as
instâncias reutilizam os grupos e materiais do Quaternius. Árvores e rochas
mantêm os posicionamentos da etapa anterior.

A comparação antes/depois foi capturada durante uma travessia com a câmera
original. A textura é visível perto da van e nas encostas, sem exigir câmera
aproximada. A travessia repetiu os mesmos 54,2 segundos. Textura triplanar,
repetição e resolução importada foram verificadas no Compatibility.

O custo adicional é uma textura e suas leituras triplanares por pixel, além das
32 plantas. Não foram adicionados materiais por pedaço de terreno, colisões ou
processamento de superfície em runtime. O padrão perde detalhes à distância
por causa dos mipmaps e pode revelar repetição ao observar uma área extensa.
Não foi realizado benchmark em computador modesto.

### Prompt da textura (built-in imagegen)

```text
Use case: stylized-concept. Asset type: seamless square tileable grayscale albedo detail texture for a low-poly off-road game terrain, 1024x1024. Primary request: an evenly distributed, non-photorealistic hand-painted ground microtexture: short tiny irregular brush strokes suggesting clipped grass, interspersed with tiny rounded grit flecks and fine earthy grains. This neutral texture will multiply existing green grass and brown road vertex colors, so use ONLY neutral grayscale values predominantly light gray 75-95%, with moderate small darker flecks 50-65%; no black, no bright white. Flat orthographic top-down texture only, filling the entire square. No objects, horizons, text, logos, perspective, lighting gradients, cast shadows, large rocks, tall grass clumps, repetitive stripes, grid, or visible borders. Small clustered marks with irregular empty gaps; consistent density across the image. Stylized painterly grain visible when tiled across a 4-5 meter terrain patch during third-person driving, never photorealistic. Seamlessly matching left/right and top/bottom edges. No transparency.
```
