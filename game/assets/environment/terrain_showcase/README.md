# Terreno experimental

Recursos de `terrain_showcase.tscn`, cena de teste de direção com relevo e estrada sinuosa. Abra a cena na Godot 4.7.2 e pressione **F6**. Ela não possui missão ou HUD próprio; `mission_level.tscn` herda essa base e acrescenta os sistemas de gameplay e a extensão com lago.

## Recursos

- `terrain_mesh.res`: solo de 220 × 220 m, grade de 2 m e 24.200 triângulos, com estrada integrada ao relevo.
- `terrain_collision.res`: colisão côncava estática extraída dos triângulos visuais.
- `background_mesh.res`: montanhas decorativas, sem colisão, com 1.728 triângulos.
- `route_curve.tres`: curva de autoria do percurso, de aproximadamente 751 m e largura central de cerca de 8 m. Não conduz a van.
- `ground_surface.tres` e `ground_detail.png`: material do solo e textura de detalhe.

A malha usa cores de vértice e projeção triplanar mundial, sem UVs. O material padrão multiplica a textura neutra pelas cores do terreno e repete o detalhe aproximadamente a cada 4,55 m. A textura foi gerada com imagegen; o PNG fonte foi mantido e a importação utiliza 512 × 512 pixels, mipmaps e filtragem anisotrópica. O material é opaco, sem normal map, parallax ou deslocamento.

A vegetação reutiliza malhas e materiais [Quaternius](../quaternius_nature/README.md) em MultiMeshes. Grama, samambaias e arbustos aparecem em grupos irregulares. As rochas são apoiadas por amostras de suas bases, considerando escala, orientação e relevo, com parte da base enterrada. Essas operações ocorrem na autoria.

## Reconstrução

Os recursos já estão preparados; não é necessário gerar o terreno para jogar. A ferramenta `game/tools/build_terrain_showcase.gd` pode reconstruir a cena e seus recursos. A partir da raiz do repositório, com o executável da Godot disponível como `godot`:

```text
godot --path game --script res://tools/build_terrain_showcase.gd --rendering-method gl_compatibility
```

A ferramenta grava arquivos e exige um renderer ativo para serializar os MultiMeshes; não use `--headless`. Quando encontra os recursos aprovados, verifica a correspondência da geometria, colisão e traçado antes de salvá-los. Não há geração contínua durante o jogo.

## Validação e limites

As notas de validação da cena registram uma travessia automatizada de 54,2 s, com desvio máximo do centro de 1,76 m, usando a câmera original e o Compatibility. A amostragem a cada 2 m no centro e a 3,2 m de cada lado não encontrou lacunas; as inclinações máximas medidas foram 8,87° no sentido longitudinal e 2,33° no transversal. Também foram conferidos o apoio inicial das quatro rodas, o alvo da câmera e a correspondência entre triângulos visuais e físicos.

Esses testes cobrem a faixa principal do showcase, não todas as trajetórias, velocidades ou a fase expandida. As bordas não têm barreiras e a decoração do showcase não possui colisões próprias. Grupos podem aparecer à distância; folhas recortadas, sombras e leituras triplanares têm custo gráfico. A textura perde detalhe com a distância e pode revelar repetição. Não há benchmark registrado em computador modesto.

Consulte a [seção 6 do TDD](../../../../docs/tdd/index.html#terrain) para a integração do terreno e da extensão.
