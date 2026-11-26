-- =============================================================
-- Arquivo: testes/teste_05_funcoes.sql
-- Descrição: testes automatizados das funções de 05_funcoes.sql
--
-- Mesmo padrão dos testes das views: BEGIN ... ROLLBACK (não
-- deixa sujeira), datas relativas a CURRENT_DATE e ASSERT.
--
-- Rodar (depois de 01, 02, 04 e 05):
--   psql -d locadora -v ON_ERROR_STOP=1 -f testes/teste_05_funcoes.sql
-- =============================================================

\set QUIET on
BEGIN;

-- ---------- Dados de teste (fictícios) ----------
INSERT INTO cliente (id_cliente, nome, cpf) VALUES
(9101, 'Teste Multa', '91000000001');

INSERT INTO filme (id_filme, titulo, ano_lancamento, duracao_min, classificacao, valor_diaria) VALUES
(9101, 'Filme Teste Diaria 5', 2020, 90, 'L', 5.00),
(9102, 'Filme Teste Diaria 4', 2021, 95, 'L', 4.00);

INSERT INTO copia (id_copia, id_filme, midia, disponivel) VALUES
(9101, 9101, 'DVD',     FALSE),
(9102, 9102, 'DVD',     FALSE),
(9103, 9102, 'BLU-RAY', TRUE),
(9104, 9101, 'BLU-RAY', TRUE);

INSERT INTO locacao (id_locacao, id_cliente, id_copia, data_locacao, data_prevista, data_devolucao, valor_total) VALUES
-- em aberto e atrasada há 3 dias (diária 5)
(9101, 9101, 9101, CURRENT_DATE - 5,  CURRENT_DATE - 3,  NULL,              10.00),
-- em aberto, ainda no prazo (diária 4)
(9102, 9101, 9102, CURRENT_DATE - 1,  CURRENT_DATE + 2,  NULL,              12.00),
-- devolvida com 2 dias de atraso (diária 4)
(9103, 9101, 9103, CURRENT_DATE - 12, CURRENT_DATE - 10, CURRENT_DATE - 8,   8.00),
-- devolvida ANTES do prazo (diária 5)
(9104, 9101, 9104, CURRENT_DATE - 6,  CURRENT_DATE - 2,  CURRENT_DATE - 4,  20.00);

-- ---------- fn_dias_atraso (função pura) ----------
DO $$
BEGIN
    ASSERT fn_dias_atraso(DATE '2026-11-10', NULL, DATE '2026-11-13') = 3,
        'Não devolvida: deveria contar 3 dias até a data de referência';

    ASSERT fn_dias_atraso(DATE '2026-11-10', DATE '2026-11-12', DATE '2026-11-30') = 2,
        'Devolvida: deveria contar até a devolução, ignorando a data de referência';

    ASSERT fn_dias_atraso(DATE '2026-11-10', DATE '2026-11-08') = 0,
        'Devolução antes do prazo deveria dar 0 (e não negativo)';

    ASSERT fn_dias_atraso(DATE '2026-11-10', DATE '2026-11-10') = 0,
        'Devolução no dia previsto não é atraso';

    ASSERT fn_dias_atraso(CURRENT_DATE - 4, NULL) = 4,
        'Sem data de referência deveria usar CURRENT_DATE';
END $$;

-- ---------- fn_calcular_multa ----------
DO $$
BEGIN
    ASSERT fn_calcular_multa(9101) = 22.50,
        'Locação 9101: 3 dias x R$ 5,00 x 1,5 deveria dar R$ 22,50';

    ASSERT fn_calcular_multa(9102) = 0,
        'Locação no prazo não deveria ter multa';

    ASSERT fn_calcular_multa(9102, CURRENT_DATE + 5) = 18.00,
        'Simulação: se 9102 voltar 3 dias depois do prazo, multa = 3 x 4 x 1,5 = 18';

    ASSERT fn_calcular_multa(9103) = 12.00,
        'Locação 9103: devolvida com 2 dias de atraso, multa = 2 x 4 x 1,5 = 12';

    ASSERT fn_calcular_multa(9103, CURRENT_DATE + 30) = 12.00,
        'Locação já devolvida: a multa não pode crescer com a data de referência';

    ASSERT fn_calcular_multa(9104) = 0,
        'Devolução antes do prazo não deveria ter multa';
END $$;

-- ---------- Locação inexistente deve dar erro claro ----------
DO $$
BEGIN
    PERFORM fn_calcular_multa(-1);
    RAISE EXCEPTION 'Deveria ter dado erro para locação inexistente';
EXCEPTION
    -- RAISE EXCEPTION sem código usa o SQLSTATE P0001 (raise_exception)
    WHEN raise_exception THEN
        ASSERT SQLERRM = 'Locação -1 não encontrada',
            'Mensagem de erro inesperada: ' || SQLERRM;
END $$;

-- ---------- Consistência com a view de 04_views.sql ----------
DO $$
BEGIN
    -- a função e a view precisam concordar sobre os dias de atraso
    ASSERT NOT EXISTS (
        SELECT 1
        FROM vw_locacoes_em_aberto v
        JOIN locacao l ON l.id_locacao = v.id_locacao
        WHERE fn_dias_atraso(l.data_prevista, l.data_devolucao) <> v.dias_atraso
    ), 'fn_dias_atraso diverge de vw_locacoes_em_aberto.dias_atraso';

    -- toda locação atrasada tem multa positiva
    ASSERT NOT EXISTS (
        SELECT 1 FROM vw_locacoes_atrasadas WHERE fn_calcular_multa(id_locacao) <= 0
    ), 'Toda locação atrasada deveria ter multa maior que zero';
END $$;

ROLLBACK;

\echo 'OK: todos os testes das funções passaram.'
