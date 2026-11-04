-- Ranking do Jogo de Corrida (schema "corrida")
-- Rode tudo de uma vez no SQL Editor do Supabase. Pode rodar de novo sem problema.
--
-- O jogo nunca acessa a tabela direto: ele só chama as duas funções abaixo,
-- que validam o que chega. A tabela fica fechada para a chave pública (anon).
--
-- Depois de rodar, exponha o schema na API:
-- Project Settings > Data API > Exposed schemas > adicionar "corrida" > Save.

create schema if not exists corrida;
grant usage on schema corrida to anon, authenticated;

-- 1. Tabela com todos os tempos -------------------------------------------------

create table if not exists corrida.times (
  id          bigint generated always as identity primary key,
  player_name text        not null check (char_length(player_name) between 1 and 16),
  time_ms     integer     not null check (time_ms between 25000 and 3600000), -- 25 s a 1 h
  car         text        not null check (car in ('hiper_laranja', 'f1_vermelho', 'super_dourado', 'caminhao_azul')),
  track       text        not null default 'pista1' check (char_length(track) between 1 and 32),
  created_at  timestamptz not null default now()
);

create index if not exists times_track_time_idx on corrida.times (track, time_ms);
create index if not exists times_created_idx on corrida.times (created_at);

alter table corrida.times enable row level security;
-- Sem nenhuma policy: anon e authenticated não leem nem gravam direto na tabela.
revoke all on all tables in schema corrida from anon, authenticated;


-- 2. Enviar um tempo ------------------------------------------------------------
-- Retorna, por exemplo: {"position": 3, "personal_best": true}
-- position = posição do jogador no ranking (considerando o melhor tempo de cada um)

create or replace function corrida.submit_time(
  p_name    text,
  p_time_ms integer,
  p_car     text,
  p_track   text default 'pista1'
)
returns jsonb
language plpgsql
security definer
set search_path = corrida
as $$
declare
  v_name      text := left(trim(p_name), 16);
  v_prev_best integer;
  v_position  integer;
begin
  if v_name is null or v_name = '' then
    raise exception 'Nome vazio';
  end if;

  -- Limites contra envio em massa: uma corrida leva mais de 25 s,
  -- então ninguém precisa enviar dois tempos em menos de 20 s.
  if exists (
    select 1 from corrida.times
    where player_name = v_name and created_at > now() - interval '20 seconds'
  ) then
    raise exception 'Aguarde um pouco antes de enviar outro tempo';
  end if;

  if (select count(*) from corrida.times where created_at > now() - interval '1 minute') >= 60 then
    raise exception 'Muitos envios agora, tente de novo em instantes';
  end if;

  select min(time_ms) into v_prev_best
  from corrida.times
  where track = p_track and player_name = v_name;

  -- As checagens da tabela (tempo, carro, pista) valem aqui também.
  insert into corrida.times (player_name, time_ms, car, track)
  values (v_name, p_time_ms, p_car, p_track);

  -- Quantos outros jogadores têm um melhor tempo menor que o deste jogador.
  select count(*) + 1 into v_position
  from (
    select player_name, min(time_ms) as best
    from corrida.times
    where track = p_track and player_name <> v_name
    group by player_name
  ) others
  where others.best < least(p_time_ms, coalesce(v_prev_best, p_time_ms));

  return jsonb_build_object(
    'position', v_position,
    'personal_best', v_prev_best is null or p_time_ms < v_prev_best
  );
end;
$$;


-- 3. Top 10 ---------------------------------------------------------------------
-- Um lugar por jogador (o melhor tempo de cada um), para ninguém ocupar o ranking todo.

create or replace function corrida.top_times(
  p_track text    default 'pista1',
  p_limit integer default 10
)
returns table (pos bigint, player_name text, time_ms integer, car text, created_at timestamptz)
language sql
stable
security definer
set search_path = corrida
as $$
  with best as (
    select distinct on (t.player_name) t.player_name, t.time_ms, t.car, t.created_at
    from corrida.times t
    where t.track = p_track
    order by t.player_name, t.time_ms, t.created_at
  )
  select row_number() over (order by b.time_ms, b.created_at) as pos,
         b.player_name, b.time_ms, b.car, b.created_at
  from best b
  order by b.time_ms, b.created_at
  limit least(greatest(p_limit, 1), 50);
$$;


-- 4. Permissões: a chave pública só pode chamar as duas funções -----------------

revoke all on function corrida.submit_time(text, integer, text, text) from public;
revoke all on function corrida.top_times(text, integer) from public;
grant execute on function corrida.submit_time(text, integer, text, text) to anon, authenticated;
grant execute on function corrida.top_times(text, integer) to anon, authenticated;


-- 5. Teste rápido (opcional): rode as linhas abaixo separadamente -------------
-- select corrida.submit_time('Teste', 41230, 'hiper_laranja');
-- select * from corrida.top_times();
-- delete from corrida.times where player_name = 'Teste';
