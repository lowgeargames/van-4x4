# Natureza Quaternius

Seleção de 12 modelos do **Stylized Nature MegaKit [Standard]**, de **Quaternius**, sob licença **CC0 1.0**. A [licença original](License_Standard.txt) acompanha os arquivos. O [manifesto](ASSET_MANIFEST.md) lista as fontes e os recursos derivados.

## Modelos

- Árvores: `CommonTree_1`, `CommonTree_3`, `CommonTree_5`.
- Pinheiros: `Pine_1`, `Pine_3`.
- Rochas: `Rock_Medium_1`, `Rock_Medium_2`, `Rock_Medium_3`.
- Arbustos: `Bush_Common`, `Bush_Common_Flowers`.
- Vegetação baixa: `Grass_Common_Short`, `Fern_1`.

## Recursos

As fontes `.gltf`, `.bin` e PNG do pack foram mantidas sem alterações. `meshes/` contém malhas nativas comprimidas para MultiMeshes; `materials/` contém oito materiais compartilhados.

Os arquivos `.import` limitam as texturas importadas a 512 pixels e ativam mipmaps. Os materiais derivados usam recursos padrão da Godot, com recorte alfa nas folhas e normal maps desativados. O tronco é opaco; `Bush_Common` utiliza uma textura verde do pack.

## Uso nas cenas

O playground usa `mission_route_nature.tscn`. O terreno experimental e a extensão possuem seus próprios grupos de vegetação. Na missão, `mission_nature_interactions.tscn` acrescenta colisões de troncos e rochas, quebra de árvores e cobertura baixa. As transformações são preparadas antes da partida; não há distribuição contínua ou animação de vento.

A organização dos grupos, colisões e limites de visibilidade está descrita nas [seções 6 e 7 do TDD](../../../../docs/tdd/index.html#nature).
