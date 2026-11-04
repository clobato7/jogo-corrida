# Jogo de Corrida

Jogo de corrida 2D com visão de cima, feito em Godot 4.7 para jogar no celular ou no PC. São quatro carros para escolher, uma pista de três voltas e um ranking com os melhores tempos de todo mundo que joga.

Dá pra jogar em https://clobato7.github.io/jogo-corrida/

No celular, o ideal é jogar com a tela deitada. Usando "Adicionar à tela inicial" no navegador, o jogo ganha um ícone e abre em tela cheia.

## Como jogar

O carro acelera sozinho, você só precisa virar.

- No PC: A e D, ou as setas.
- No celular: toque no lado esquerdo da tela pra virar à esquerda e no lado direito pra virar à direita.

Se bater na parede o carro perde velocidade, mas logo recupera.

Antes de cada corrida você escolhe o carro: o hipercarro laranja, o F1 vermelho, o esportivo dourado ou o caminhão azul. Todos andam igual, muda só o visual.

## Ranking

No fim da corrida o tempo vai para um top 10 geral. Na primeira vez o jogo pergunta o seu nome, que fica salvo no aparelho (dá pra trocar depois). Valem só os 3 melhores tempos de cada jogador, pra ninguém ocupar o ranking sozinho.

O ranking também pode ser visto na tela inicial, no botão "VER RANKING".

Os tempos ficam no Supabase, no schema `corrida`. O SQL está em `supabase/ranking.sql` e pode ser rodado de novo sem perder dados. O jogo usa só a chave pública e só consegue chamar as funções `submit_time` (que valida o tempo antes de gravar) e `top_times`.

## Versão

A versão aparece no canto da tela de escolha do carro e embaixo dos botões da tela de vitória (por exemplo, `v0.18`). Quando sai uma versão nova, o jogo mostra um aviso amarelo no topo da tela, e é só tocar nele pra atualizar.

## Organização do projeto

- `main`: cena principal, cuida da largada, das voltas e da vitória.
- `car`: o carro, o som do motor e a câmera. Velocidade, curva, aderência e zoom (PC e celular) dá pra ajustar direto no Inspetor.
- `track`: a pista. O traçado sai dos pontos em `control_points`, e a partir deles são criadas as paredes, as zebras, os checkpoints e as árvores.
- `hud`: tudo que aparece na tela, como escolha de carro, voltas, tempo, contagem regressiva, tela de vitória com confete, ranking e os controles de toque.
- `scripts/car_art.gd`: o desenho dos quatro carros, feito por código.

Cada cena fica em `scenes/` e o script com o mesmo nome em `scripts/`.

Três scripts ficam sempre carregados (autoloads):

- `Sfx`: efeitos sonoros e som ambiente. Os sons ficam em `assets/sfx/` e foram gerados pelo `tools/gen_sfx.py`, mas dá pra trocar qualquer um por outro arquivo com o mesmo nome.
- `Leaderboard`: conversa com o ranking e guarda o nome do jogador.
- `Updater`: verifica se existe versão nova publicada.

## Contagem de voltas

Tem 8 checkpoints invisíveis espalhados pela pista, e o primeiro é a linha de chegada. A volta só conta se o carro passar por todos na ordem, então não tem como cortar caminho.

## Publicação

A cada push na `main`, uma GitHub Action exporta o jogo para a web e publica no GitHub Pages. O número da versão sobe sozinho a cada publicação.
