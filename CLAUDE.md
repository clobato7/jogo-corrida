# Jogo de Corrida: notas para o Claude

Jogo de corrida 2D com visão de cima, feito pelo Caio para o filho pequeno dele (quase 5 anos), que joga principalmente no celular (iPhone, Safari). Inspiração: Rock n' Roll Racing (SNES). O Caio é desenvolvedor de dados (SQL, Python) e está aprendendo Godot com este projeto, então explique o "porquê" das mudanças de forma curta.

- Jogo publicado: https://clobato7.github.io/jogo-corrida/
- Repo público: `clobato7/jogo-corrida` (branch `main`)
- Pasta no PC do Caio (Windows): `C:\Portables\Godot\Projects\jogo-corrida`
- Godot do Caio: 4.7.2 (portátil em `C:\Portables\Godot`)

## Regras de trabalho com o Caio

- **Commit e push só quando o Caio pedir.** Por padrão, as alterações vão para a pasta do projeto no PC dele (`C:\Portables\Godot\Projects\jogo-corrida`, pelo app desktop) para ele testar no editor do Godot. Só faça commit/push direto no GitHub quando ele pedir explicitamente (por exemplo, quando ele estiver só com o celular, sem o Godot do PC).
  - A pasta `.github` não pode ser gravada pelas ferramentas de arquivo do PC. Se uma mudança precisar mexer no workflow, avise e peça autorização para fazer por push.
  - Se o PC não estiver acessível, prepare as mudanças e avise; não publique por conta própria.
- **Sempre que publicar (push na main), informe a versão nova (`v0.N`)** para ele conferir no celular. Pegue o número com `gh run list -R clobato7/jogo-corrida -L 1` depois que a Action terminar.
- Teste antes de publicar (ver "Como testar"). Mostre screenshots quando a mudança for visual.
- O Caio também edita pelo editor do Godot. Antes de mexer, faça `git fetch`/`git pull`. Se o Godot estiver com um arquivo aberto, ele pode sobrescrever uma alteração externa ao salvar (já aconteceu com o README).
- Commits em nome de "Caio Lobato". Mensagens em português.
- Textos do jogo e do repo em português, tom simples, sem cara de "texto de IA" (evitar travessão).
- Nada de logos ou nomes de marcas reais no jogo (os carros são "inspirados").
- A pasta `.github` não pode ser gravada pelas ferramentas de arquivo do PC; mudanças em workflow vão por push.

## Decisões de jogabilidade (já combinadas)

- Aceleração automática. O jogador só vira (esquerda/direita). Acelerador/freio ficou **em stand by** (2 comandos a mais complicam no celular).
- Toque: metade esquerda da tela vira à esquerda, metade direita vira à direita. Setas grandes e altas (210x285, centro a 340 px da base) a pedido do filho.
- Bater na parede reduz a velocidade, que volta aos poucos; o carro "desliza" junto à parede para a criança não ficar presa.
- Câmera: zoom 0.85 no PC e 1.25 no celular (`desktop_zoom`/`mobile_zoom` no carro).
- 3 voltas, contagem 3-2-1-VAI, confete e fogos na vitória.
- 4 carros, todos com o mesmo desempenho (só muda visual e tamanho da colisão):
  - `hiper_laranja`: hipercarro laranja com cabine/teto pretos, entradas de ar laterais e asa preta (baseado numa foto que o filho escolheu). **É o favorito dele**, primeiro da lista.
  - `f1_vermelho`: monoposto de F1 vermelho.
  - `super_dourado`: superesportivo dourado em cunha.
  - `caminhao_azul`: caminhão azul escuro.
- Tela inicial: escolha de carro (o toque também libera o som no navegador) e botão "VER RANKING".

## Estrutura

- `scenes/main.tscn` + `scripts/main.gd`: corrida (largada, voltas por checkpoints em ordem, vitória). `static var selected_car` mantém o carro ao recarregar a cena.
- `scenes/car.tscn` + `scripts/car.gd`: carro (CharacterBody2D, motion_mode floating), som do motor, câmera.
- `scripts/car_art.gd` (`class_name CarArt`): desenho dos 4 carros por código (`ORDER`, `NAMES`, `SIZES`). Usado na pista, nos cards e nas miniaturas do ranking.
- `scenes/track.tscn` + `scripts/track.gd`: pista gerada a partir de `control_points` (Catmull-Rom), paredes, zebras, 8 checkpoints, árvores. Se mudar o traçado, troque `TRACK_ID` no `leaderboard.gd` para começar um ranking novo.
- `scenes/hud.tscn` + `scripts/hud.gd`: HUD, escolha de carro, contagem, vitória com confete, ranking (tela de vitória e tela inicial), pedido de nome, controles de toque.
- `scripts/car_card.gd`, `scripts/car_icon.gd`, `scripts/touch_hints.gd`: UI auxiliar.
- Autoloads (`project.godot`):
  - `Sfx` (`scripts/sfx.gd`): efeitos e som ambiente. Sons em `assets/sfx/*.wav`, gerados por `tools/gen_sfx.py` (numpy/scipy). Loops ligados no `.wav.import` (`edit/loop_mode=2`).
  - `Leaderboard` (`scripts/leaderboard.gd`): API do ranking e nome do jogador salvo em `user://jogador.cfg`.
  - `Updater` (`scripts/updater.gd`): aviso "Nova versão disponível" (ver Publicação).
- `scripts/build_info.gd` (`BuildInfo.VERSION`): "dev" localmente; a Action troca por `v0.N`.

## Publicação (web)

- Push na `main` dispara `.github/workflows/deploy-web.yml`: baixa Godot 4.7.2 + template web (com cache), grava a versão `v0.<run_number>` em `build_info.gd`, exporta o preset "Web" e publica no GitHub Pages. Também grava `version.txt` no site e roda `tools/version_pack.py`, que renomeia o pacote para `index-v0.N.pck` (o `index.wasm` mantém o nome).
- Export Web **sem threads** (não precisa de headers COOP/COEP) e como **PWA**.
- Cache: o navegador (service worker + cache do Pages, `max-age=600`) pode mostrar versão antiga. O `Updater` consulta `version.txt` sem cache ao abrir; se for diferente de `BuildInfo.VERSION`, mostra o aviso amarelo, e o toque remove o service worker/caches e recarrega com `?v=`. Isso só funciona porque o pacote tem nome por versão: com o nome fixo `index.pck`, o navegador reaproveitava o pacote antigo e o aviso voltava em loop.
- Por que não Cloudflare Pages: o `index.wasm` do Godot tem ~39,5 MB e o limite por arquivo lá é 25 MiB.
- Domínio próprio (`corrida.gondata.com.br` via CNAME na Cloudflare) ainda **não foi configurado**.

## Ranking (Supabase)

- Projeto: `https://ghshlpnxrcwwpujyypmd.supabase.co`, schema **`corrida`** (o Caio separa projetos por schema no mesmo banco; outros: `cs_rank`, `dota_rank`).
- O schema precisa estar em Data API > Exposed schemas (já está).
- SQL em `supabase/ranking.sql`: **idempotente**, pode rodar inteiro de novo sem perder dados. Segue o estilo dos outros schemas do Caio (cabeçalho, seções numeradas, `REVOKE ALL` + grants explícitos, `service_role` com acesso total). Ao mudar, mantenha idempotente, teste num Postgres local e peça para o Caio rodar no SQL Editor (não temos acesso direto ao banco).
- Tabela `corrida.times` fechada para `anon` (RLS ligado, sem policies). O jogo só chama:
  - `corrida.submit_time(p_name, p_time_ms, p_car, p_track)`: valida (25 s a 1 h, carro válido, nome 1 a 16, 20 s entre envios do mesmo nome, 60 envios/min no total) e devolve `{id, position, personal_best, counted}`.
  - `corrida.top_times(p_track, p_limit, p_per_player)`: top 10 com **até 3 tempos por jogador**.
- O aviso do Table Editor "no RLS policies exist so no data will be returned" é esperado. O aviso de RLS ao rodar o script no SQL Editor é falso alarme (o RLS é ligado por um loop `DO $$`).
- Chave usada no jogo: **publishable key** (`sb_publishable_...`, em `leaderboard.gd`), pública por natureza. **Nunca** usar nem pedir a secret key no jogo/repo. As chamadas usam os headers `apikey`, `Content-Profile: corrida` e `Accept-Profile: corrida`.
- **Lição:** no navegador o `HTTPRequest` precisa de `accept_gzip = false`, senão a resposta falha (o navegador já descompacta).

## Como testar (no ambiente do Claude)

1. Baixe o Godot 4.7.2 para Linux e o template web:
   - `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
   - `.../Godot_v4.7.2-stable_export_templates.tpz` (1,3 GB; só precisa de `templates/web_nothreads_release.zip` e `templates/version.txt` em `~/.local/share/godot/export_templates/4.7.2.stable/`)
2. `godot --headless --import` (o primeiro import pode reclamar dos `preload` de `.wav`; é normal).
3. Corrida completa: `godot --headless --path . -s tools/test/autopilot.gd` → deve imprimir `FINISHED laps=3` (variável `CAR` escolhe o carro).
4. Screenshots: `xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --resolution 1280x720 --path . -s <script>` salvando `root.get_texture().get_image()`.
5. Ranking sem tocar no banco real: `python3 tools/test/mock_ranking.py` e rode o jogo com `RANKING_URL=http://127.0.0.1:8799/rest/v1/rpc/` (só em build de debug). **Nunca enviar tempos de teste para o Supabase real.** Leituras (`top_times`) e envios inválidos (que são rejeitados) são seguros.
6. Web: exporte com `--export-release "Web" build/web/index.html`, sirva com `python3 -m http.server` e abra no Playwright/Chromium (`--use-angle=swiftshader`). Celular: `devices['Pixel 7 landscape']`.

## Ideias e próximos passos (ainda não feitos)

- Oponentes controlados pelo computador e posição na corrida.
- Tiro e itens na pista (estilo Rock n' Roll Racing).
- Músicas (o Caio vai fazer com IA).
- Personalidade para cada carro (ex.: caminhão mais lento mas sem perder velocidade ao bater).
- Acelerador/freio (em stand by).
- APK Android (por enquanto o PWA resolve).
- Domínio `corrida.gondata.com.br`.

## Detalhes que já deram problema

- A fonte padrão do Godot não tem símbolos como "▶" (aparecem como quadradinho no iPhone). Use só texto ou desenhe o ícone.
- No celular, o navegador só libera áudio depois de um toque; por isso a escolha de carro vem antes da contagem.
- O Godot 4.7 regrava `.tscn` com `unique_id` e `uid`; ao editar cenas à mão, partir sempre da versão atual do repo.
