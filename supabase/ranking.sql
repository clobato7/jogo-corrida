-- =========================================================
-- corrida — Ranking de tempos do Jogo de Corrida
-- =========================================================
-- Criado em: 04/11/2026
-- Baseado no padrão do cs_rank
--
-- Diferente do cs_rank, aqui o frontend (o jogo) também GRAVA dados.
-- Por isso o anon não acessa a tabela: ele só executa as duas funções
-- (submit_time e top_times), que validam tudo antes de gravar.
--
-- Depois de rodar, exponha o schema na API:
-- Project Settings > Data API > Exposed schemas > adicionar "corrida" > Save.

-- 1. Criação do Schema
CREATE SCHEMA IF NOT EXISTS corrida;
SET search_path TO corrida;


-- ─────────────────────────────────────────────
-- 2. Tabela de Tempos (times)
-- ─────────────────────────────────────────────
-- Um registro por corrida terminada. O ranking usa o melhor tempo de cada
-- jogador, mas todas as corridas ficam guardadas para análises futuras.
CREATE TABLE IF NOT EXISTS corrida.times (
    id          BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    player_name VARCHAR(16)  NOT NULL CHECK (CHAR_LENGTH(player_name) >= 1),  -- nome digitado no jogo
    time_ms     INT          NOT NULL CHECK (time_ms BETWEEN 25000 AND 3600000), -- tempo total (25 s a 1 h)
    car         VARCHAR(20)  NOT NULL CHECK (car IN ('hiper_laranja', 'f1_vermelho', 'super_dourado', 'caminhao_azul')),
    track       VARCHAR(32)  NOT NULL DEFAULT 'pista1',                      -- id da pista (muda se o traçado mudar)
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Índices para acelerar consultas
CREATE INDEX IF NOT EXISTS idx_corrida_times_track_time ON corrida.times(track, time_ms);
CREATE INDEX IF NOT EXISTS idx_corrida_times_player     ON corrida.times(player_name);
CREATE INDEX IF NOT EXISTS idx_corrida_times_created    ON corrida.times(created_at);


-- ─────────────────────────────────────────────
-- 3. Função para enviar um tempo (submit_time)
-- ─────────────────────────────────────────────
-- Chamada pelo jogo no fim da corrida.
-- Retorna, por exemplo: {"position": 3, "personal_best": true}
--   position      = posição do jogador no ranking (melhor tempo de cada um)
--   personal_best = se esse foi o melhor tempo do jogador até agora
-- SECURITY DEFINER: roda com a permissão do dono, por isso consegue gravar
-- na tabela mesmo o anon não tendo acesso a ela.
CREATE OR REPLACE FUNCTION corrida.submit_time(
    p_name    TEXT,
    p_time_ms INT,
    p_car     TEXT,
    p_track   TEXT DEFAULT 'pista1'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = corrida
AS $$
DECLARE
    v_name      TEXT := LEFT(TRIM(p_name), 16);
    v_prev_best INT;
    v_position  INT;
BEGIN
    IF v_name IS NULL OR v_name = '' THEN
        RAISE EXCEPTION 'Nome vazio';
    END IF;

    -- Limites contra envio em massa: uma corrida leva mais de 25 s,
    -- então ninguém precisa enviar dois tempos em menos de 20 s.
    IF EXISTS (
        SELECT 1 FROM corrida.times
        WHERE player_name = v_name AND created_at > NOW() - INTERVAL '20 seconds'
    ) THEN
        RAISE EXCEPTION 'Aguarde um pouco antes de enviar outro tempo';
    END IF;

    IF (SELECT COUNT(*) FROM corrida.times WHERE created_at > NOW() - INTERVAL '1 minute') >= 60 THEN
        RAISE EXCEPTION 'Muitos envios agora, tente de novo em instantes';
    END IF;

    SELECT MIN(time_ms) INTO v_prev_best
    FROM corrida.times
    WHERE track = p_track AND player_name = v_name;

    -- As checagens da tabela (tempo, carro, pista) valem aqui também.
    INSERT INTO corrida.times (player_name, time_ms, car, track)
    VALUES (v_name, p_time_ms, p_car, p_track);

    -- Quantos outros jogadores têm um melhor tempo menor que o deste jogador.
    SELECT COUNT(*) + 1 INTO v_position
    FROM (
        SELECT player_name, MIN(time_ms) AS best
        FROM corrida.times
        WHERE track = p_track AND player_name <> v_name
        GROUP BY player_name
    ) others
    WHERE others.best < LEAST(p_time_ms, COALESCE(v_prev_best, p_time_ms));

    RETURN JSONB_BUILD_OBJECT(
        'position', v_position,
        'personal_best', v_prev_best IS NULL OR p_time_ms < v_prev_best
    );
END;
$$;


-- ─────────────────────────────────────────────
-- 4. Função do Top 10 (top_times)
-- ─────────────────────────────────────────────
-- Um lugar por jogador (o melhor tempo de cada um), para ninguém ocupar
-- o ranking todo sozinho. Máximo de 50 linhas por chamada.
CREATE OR REPLACE FUNCTION corrida.top_times(
    p_track TEXT DEFAULT 'pista1',
    p_limit INT  DEFAULT 10
)
RETURNS TABLE (pos BIGINT, player_name VARCHAR, time_ms INT, car VARCHAR, created_at TIMESTAMPTZ)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = corrida
AS $$
    WITH best AS (
        SELECT DISTINCT ON (t.player_name) t.player_name, t.time_ms, t.car, t.created_at
        FROM corrida.times t
        WHERE t.track = p_track
        ORDER BY t.player_name, t.time_ms, t.created_at
    )
    SELECT ROW_NUMBER() OVER (ORDER BY b.time_ms, b.created_at) AS pos,
           b.player_name, b.time_ms, b.car, b.created_at
    FROM best b
    ORDER BY b.time_ms, b.created_at
    LIMIT LEAST(GREATEST(p_limit, 1), 50);
$$;


-- ─────────────────────────────────────────────
-- 5. RLS — Row Level Security
-- ─────────────────────────────────────────────
-- Habilita RLS em todas as tabelas do schema.
-- Sem nenhuma policy de propósito: anon e authenticated não leem nem gravam
-- direto. O acesso do jogo é só pelas funções acima.
DO $$
DECLARE
  t text;
BEGIN
  FOR t IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'corrida'
  LOOP
    EXECUTE format('ALTER TABLE corrida.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END;
$$;


-- ─────────────────────────────────────────────
-- 6. Permissões (Grants)
-- ─────────────────────────────────────────────

-- Revoga tudo e recomeça limpo
REVOKE ALL ON SCHEMA corrida FROM anon, authenticated, service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA corrida FROM anon, authenticated;
-- Funções no Postgres nascem executáveis por todos (PUBLIC); aqui fecha isso.
REVOKE ALL ON ALL ROUTINES IN SCHEMA corrida FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA corrida REVOKE EXECUTE ON ROUTINES FROM PUBLIC;

-- service_role (scripts e manutenção via service role key)
GRANT USAGE ON SCHEMA corrida TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA corrida TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA corrida TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA corrida TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA corrida GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA corrida GRANT ALL ON ROUTINES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA corrida GRANT ALL ON SEQUENCES TO service_role;

-- anon (o jogo no navegador): só as duas funções, nada de tabela
GRANT USAGE ON SCHEMA corrida TO anon, authenticated;
GRANT EXECUTE ON FUNCTION corrida.submit_time(TEXT, INT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION corrida.top_times(TEXT, INT) TO anon, authenticated;


-- ─────────────────────────────────────────────
-- 7. Teste rápido (opcional)
-- ─────────────────────────────────────────────
-- Rode as linhas abaixo separadamente:
-- SELECT corrida.submit_time('Teste', 41230, 'hiper_laranja');
-- SELECT * FROM corrida.top_times();
-- DELETE FROM corrida.times WHERE player_name = 'Teste';


-- ################### 04/11/2026 (2) ###################
-- Ranking passa a mostrar até 3 tempos por jogador (antes era só o melhor).
-- submit_time e top_times também passam a devolver o id da corrida,
-- para o jogo marcar a linha "NOVO!" no top 10.
-- Se você já rodou o script antes, rode só este bloco.

-- top_times muda o formato do retorno, então precisa ser recriada
DROP FUNCTION IF EXISTS corrida.top_times(TEXT, INT);

CREATE OR REPLACE FUNCTION corrida.top_times(
    p_track      TEXT DEFAULT 'pista1',
    p_limit      INT  DEFAULT 10,
    p_per_player INT  DEFAULT 3
)
RETURNS TABLE (pos BIGINT, id BIGINT, player_name VARCHAR, time_ms INT, car VARCHAR, created_at TIMESTAMPTZ)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = corrida
AS $$
    WITH ranked AS (
        SELECT t.id, t.player_name, t.time_ms, t.car, t.created_at,
               ROW_NUMBER() OVER (PARTITION BY t.player_name ORDER BY t.time_ms, t.created_at) AS rn
        FROM corrida.times t
        WHERE t.track = p_track
    )
    SELECT ROW_NUMBER() OVER (ORDER BY r.time_ms, r.created_at) AS pos,
           r.id, r.player_name, r.time_ms, r.car, r.created_at
    FROM ranked r
    WHERE r.rn <= LEAST(GREATEST(p_per_player, 1), 10)
    ORDER BY r.time_ms, r.created_at
    LIMIT LEAST(GREATEST(p_limit, 1), 50);
$$;

-- submit_time: mesma validação; a posição agora considera até 3 tempos por jogador.
-- Retorna, por exemplo: {"id": 12, "position": 4, "personal_best": false, "counted": true}
--   counted = se esse tempo está entre os 3 melhores do jogador (e por isso entra na conta do ranking)
CREATE OR REPLACE FUNCTION corrida.submit_time(
    p_name    TEXT,
    p_time_ms INT,
    p_car     TEXT,
    p_track   TEXT DEFAULT 'pista1'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = corrida
AS $$
DECLARE
    v_name      TEXT := LEFT(TRIM(p_name), 16);
    v_prev_best INT;
    v_id        BIGINT;
    v_rn        INT;
    v_position  INT;
BEGIN
    IF v_name IS NULL OR v_name = '' THEN
        RAISE EXCEPTION 'Nome vazio';
    END IF;

    IF EXISTS (
        SELECT 1 FROM corrida.times
        WHERE player_name = v_name AND created_at > NOW() - INTERVAL '20 seconds'
    ) THEN
        RAISE EXCEPTION 'Aguarde um pouco antes de enviar outro tempo';
    END IF;

    IF (SELECT COUNT(*) FROM corrida.times WHERE created_at > NOW() - INTERVAL '1 minute') >= 60 THEN
        RAISE EXCEPTION 'Muitos envios agora, tente de novo em instantes';
    END IF;

    SELECT MIN(time_ms) INTO v_prev_best
    FROM corrida.times
    WHERE track = p_track AND player_name = v_name;

    INSERT INTO corrida.times (player_name, time_ms, car, track)
    VALUES (v_name, p_time_ms, p_car, p_track)
    RETURNING id INTO v_id;

    -- Posição deste tempo entre os 3 melhores de cada jogador
    WITH ranked AS (
        SELECT t.id, t.time_ms, t.created_at,
               ROW_NUMBER() OVER (PARTITION BY t.player_name ORDER BY t.time_ms, t.created_at) AS rn
        FROM corrida.times t
        WHERE t.track = p_track
    ),
    eligible AS (
        SELECT * FROM ranked WHERE rn <= 3
    )
    SELECT (SELECT rn FROM ranked WHERE ranked.id = v_id),
           (SELECT COUNT(*) + 1 FROM eligible e
             WHERE e.id <> v_id AND (e.time_ms, e.created_at) < (p_time_ms, NOW()))
    INTO v_rn, v_position;

    RETURN JSONB_BUILD_OBJECT(
        'id', v_id,
        'position', v_position,
        'personal_best', v_prev_best IS NULL OR p_time_ms < v_prev_best,
        'counted', v_rn <= 3
    );
END;
$$;

-- Permissões das funções recriadas
REVOKE ALL ON FUNCTION corrida.top_times(TEXT, INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION corrida.submit_time(TEXT, INT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION corrida.top_times(TEXT, INT, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION corrida.submit_time(TEXT, INT, TEXT, TEXT) TO anon, authenticated;
GRANT ALL ON FUNCTION corrida.top_times(TEXT, INT, INT) TO service_role;
-- ################### FIM 04/11/2026 (2) ###################
