# Quaternius Nature — seleção para Van 4x4

Origem: **Stylized Nature MegaKit [Standard]**, por Quaternius.
Licença: **CC0 1.0**, conforme `License_Standard.txt` copiado do pack.
Os arquivos originais do pack não foram modificados.

## Modelos utilizados

- Árvores: `CommonTree_1`, `CommonTree_3`, `CommonTree_5`.
- Pinheiros: `Pine_1`, `Pine_3`.
- Rochas: `Rock_Medium_1`, `Rock_Medium_2`, `Rock_Medium_3`.
- Arbustos: `Bush_Common`, `Bush_Common_Flowers`.
- Vegetação baixa: `Grass_Common_Short`, `Fern_1`.

Cada modelo mantém seu `.gltf`, `.bin` e as texturas referenciadas pelo glTF.
Somente essa seleção de 12 modelos foi copiada do pack de 68 modelos.

## Recursos usados pelo jogo

`meshes/` contém os meshes nativos comprimidos, derivados dos modelos importados,
para uso em MultiMeshes. `materials/` contém oito materiais compartilhados.
Todos os caminhos dos recursos usam `res://` e permanecem dentro do projeto.
As fontes glTF ficam disponíveis para inspeção e reutilização no editor.

As texturas mantêm os pixels originais. Seus arquivos `.import` limitam a
resolução importada a 512 pixels e ativam mipmaps. Os materiais usam o shader
padrão da Godot, sem animação de vegetação; as folhas conservam o recorte alfa.
Normal maps foram desativados nos materiais derivados. O tronco usa material
opaco. O arbusto `Bush_Common` usa a textura verde já selecionada do pack para
harmonizar sua folhagem originalmente vermelha com o vale.

## Composição estática

`res://scenes/mission_route_nature.tscn` contém 232 instâncias em 60 MultiMeshes,
agrupados por modelo e região: aproximação inicial, instalação na lama, caminho
de ligação, margens da água e instalação da bomba. Escalas e rotações são fixas.
Não existe gerador procedural nem script de ambientação em execução.

Árvores usam alcance visual de 220 m; pedras e arbustos, 150 m; vegetação baixa,
80 m. O limite é aplicado por grupo e pode provocar aparecimento do grupo à
distância. No editor, aproxime a câmera para inspecionar a vegetação.

As estradas são meshes estáticos curvos, com largura central aproximada de 7 m,
bordas irregulares e transição por cores de vértice. As margens da água também
são visuais. Não foram adicionadas colisões à decoração; sair do percurso ainda
pode permitir atravessar elementos decorativos. Chão, lama, água, rampas,
equipamentos e todos os sistemas de gameplay foram preservados.

`ASSET_MANIFEST.md` lista os arquivos dessa seleção e seus recursos derivados.
