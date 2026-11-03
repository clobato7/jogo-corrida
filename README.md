# Jogo de Corrida

Jogo de corrida 2D com visão de cima, feito em Godot 4.7. Por enquanto é a primeira versão: um carro, uma pista e três voltas até a tela de vitória.

Dá pra jogar em https://clobato7.github.io/jogo-corrida/

## Como jogar

O carro acelera sozinho, você só precisa virar.

- No PC: A e D, ou as setas.
- No celular: toque no lado esquerdo da tela pra virar à esquerda e no lado direito pra virar à direita.

Se bater na parede o carro perde velocidade, mas logo recupera.

## Organização do projeto

- `main`: cena principal, cuida da largada, das voltas e da vitória.
- `car`: o carro e a câmera. Velocidade, curva e aderência dá pra ajustar direto no Inspetor.
- `track`: a pista. O traçado sai dos pontos em `control_points`, e a partir deles são criadas as paredes, as zebras, os checkpoints e as árvores.
- `hud`: tudo que aparece na tela, como voltas, tempo, contagem regressiva, tela de vitória e os controles de toque.

Cada cena fica em `scenes/` e o script com o mesmo nome em `scripts/`.

## Contagem de voltas

Tem 8 checkpoints invisíveis espalhados pela pista, e o primeiro é a linha de chegada. A volta só conta se o carro passar por todos na ordem, então não tem como cortar caminho.
