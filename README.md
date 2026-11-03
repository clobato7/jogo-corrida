# Jogo de Corrida (v1)

Corrida 2D top-down: um carro, uma pista, 3 voltas e tela de vitória.

## Controles
- PC: A/D ou setas esquerda/direita. O clique do mouse também funciona como toque.
- Celular: toque na metade esquerda da tela para virar à esquerda e na metade direita para virar à direita.
- O carro acelera sozinho. Bater na parede faz perder velocidade, que volta aos poucos.

## Estrutura
- `scenes/main.tscn` + `scripts/main.gd`: cena principal. Controla largada, voltas e vitória.
- `scenes/car.tscn` + `scripts/car.gd`: carro (CharacterBody2D) com a câmera. Ajuste velocidade, curva e aderência pelos @export no Inspetor.
- `scenes/track.tscn` + `scripts/track.gd`: pista gerada a partir de `control_points` (linha central). Cria paredes, checkpoints, zebras e árvores.
- `scenes/hud.tscn` + `scripts/hud.gd`: voltas, tempo, contagem 3-2-1, tela de vitória e controles de toque.
- `scripts/touch_hints.gd`: setas que indicam onde tocar.

## Como as voltas são contadas
A pista tem 8 checkpoints invisíveis (Area2D). O checkpoint 0 é a linha de chegada.
O carro precisa passar por todos em ordem; ao cruzar o 0 depois do último, conta uma volta.

## Publicação na web
A cada push na `main`, a GitHub Action `.github/workflows/deploy-web.yml` baixa o Godot 4.7.2,
exporta o preset "Web" (definido em `export_presets.cfg`) e publica no GitHub Pages.
O jogo é exportado como PWA: no celular, abra o link e use "Adicionar à tela inicial".

Para exportar à mão no editor: Projeto > Exportar > Web > Exportar Projeto (saída em `build/web/`, que fica fora do git).
