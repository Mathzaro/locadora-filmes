-- =============================================================
-- Arquivo: testes/teste_04_views.sql
-- Descrição: testes automatizados das views de 04_views.sql
--
-- Como funciona:
--   * tudo roda dentro de uma transação (BEGIN ... ROLLBACK),
--     então os dados de teste são apagados no final e o banco
--     volta exatamente como estava;
--   * os dados de teste usam datas relativas a CURRENT_DATE,
--     assim o teste continua passando em qualquer dia;
--   * ASSERT para o script com erro se a condição for falsa.
--
-- Rodar (depois de 01, 02 e 04):
--   psql -d locadora -v ON_ERROR_STOP=1 -f testes/teste_04_views.sql
-- =============================================================

\set QUIET on
BEGIN;

-- ---------- Dados de teste (fictícios) ----------
INSERT INTO cliente (id_cliente, nome, cpf) VALUES
(9001, 'Teste Atrasado', '90000000001'),
(9002, 'Teste Sem Locacao', '90000000002');

INSERT INTO filme (id_filme, titulo, ano_lancamento, duracao_min, classificacao, valor_diaria) VALUES
(9001, 'Filme Teste Esgotado',   2020, 90, 'L', 5.00),
(9002, 'Filme Teste Disponivel', 2021, 95, 'L', 4.00);

INSERT INTO filme_genero (id_filme, id_genero) VALUES (9002, 1), (9002, 2);

-- Filme 9001: a única cópia está alugada. Filme 9002: 1 de 2 livre.
INSERT INTO copia (id_copia, id_filme, midia, disponivel) VALUES
(9001, 9001, 'DVD',     FALSE),
(9002, 9002, 'DVD',     FALSE),
(9003, 9002, 'BLU-RAY', TRUE);

INSERT INTO locacao (id_locacao, id_cliente, id_copia, data_locacao, data_prevista, data_devolucao, valor_total) VALUES
-- atrasada há 3 dias
(9001, 9001, 9001, CURRENT_DATE - 5, CURRENT_DATE - 3, NULL, 20.00),
-- em aberto, mas ainda dentro do prazo
(9002, 9001, 9002, CURRENT_DATE - 1, CURRENT_DATE + 2, NULL,  8.00),
-- já devolvida: não pode aparecer como em aberto
(9003, 9001, 9003, CURRENT_DATE - 9, CURRENT_DATE - 8, CURRENT_DATE - 8, 4.00);

-- Dois pagamentos para a mesma locação (testa a duplicação em JOIN)
INSERT INTO pagamento (id_locacao, valor, forma) VALUES
(9001, 5.00, 'PIX'),
(9001, 5.00, 'DINHEIRO'),
(9003, 4.00, 'PIX');

-- ---------- vw_filmes_disponiveis ----------
DO $$
BEGIN
    ASSERT NOT EXISTS (SELECT 1 FROM vw_filmes_disponiveis WHERE id_filme = 9001),
        'Filme sem cópia livre não deveria aparecer como disponível';

    ASSERT (SELECT copias_disponiveis FROM vw_filmes_disponiveis WHERE id_filme = 9002) = 1,
        'Filme 9002 deveria ter 1 cópia disponível';

    ASSERT (SELECT total_copias FROM vw_filmes_disponiveis WHERE id_filme = 9002) = 2,
        'Filme 9002 deveria ter 2 cópias no total (gêneros não podem duplicar a contagem)';

    ASSERT (SELECT generos FROM vw_filmes_disponiveis WHERE id_filme = 9002) = 'Ação, Comédia',
        'Gêneros do filme 9002 deveriam ser "Ação, Comédia"';
END $$;

-- ---------- vw_locacoes_em_aberto ----------
DO $$
BEGIN
    ASSERT (SELECT dias_atraso FROM vw_locacoes_em_aberto WHERE id_locacao = 9001) = 3,
        'Locação 9001 deveria ter 3 dias de atraso';

    ASSERT (SELECT dias_atraso FROM vw_locacoes_em_aberto WHERE id_locacao = 9002) = 0,
        'Locação dentro do prazo deveria ter 0 dias de atraso (e não negativo)';

    ASSERT NOT EXISTS (SELECT 1 FROM vw_locacoes_em_aberto WHERE id_locacao = 9003),
        'Locação devolvida não deveria estar em aberto';
END $$;

-- ---------- vw_locacoes_atrasadas ----------
DO $$
BEGIN
    ASSERT EXISTS (SELECT 1 FROM vw_locacoes_atrasadas WHERE id_locacao = 9001),
        'Locação 9001 deveria estar na lista de atrasadas';

    ASSERT NOT EXISTS (SELECT 1 FROM vw_locacoes_atrasadas WHERE id_locacao = 9002),
        'Locação no prazo não deveria estar na lista de atrasadas';

    ASSERT NOT EXISTS (SELECT 1 FROM vw_locacoes_atrasadas WHERE dias_atraso <= 0),
        'Nenhuma linha de atrasadas pode ter atraso zero ou negativo';
END $$;

-- ---------- vw_resumo_clientes ----------
DO $$
DECLARE
    r RECORD;
BEGIN
    SELECT * INTO r FROM vw_resumo_clientes WHERE id_cliente = 9001;
    ASSERT r.qtd_locacoes = 3,    'Cliente 9001 deveria ter 3 locações';
    ASSERT r.em_aberto    = 2,    'Cliente 9001 deveria ter 2 locações em aberto';
    ASSERT r.total_locado = 32.00, 'Total locado deveria ser 20 + 8 + 4 = 32 (sem duplicar)';
    ASSERT r.total_pago   = 14.00, 'Total pago deveria ser 5 + 5 + 4 = 14';
    ASSERT r.saldo_devedor = 18.00, 'Saldo devedor deveria ser 32 - 14 = 18';

    SELECT * INTO r FROM vw_resumo_clientes WHERE id_cliente = 9002;
    ASSERT r.qtd_locacoes = 0 AND r.total_pago = 0 AND r.saldo_devedor = 0,
        'Cliente sem locação deveria aparecer com tudo zerado';

    -- Conferência geral: a soma da view bate com as tabelas originais
    ASSERT (SELECT SUM(total_locado) FROM vw_resumo_clientes) = (SELECT SUM(valor_total) FROM locacao),
        'Soma de total_locado da view diferente da tabela locacao';
    ASSERT (SELECT SUM(total_pago) FROM vw_resumo_clientes) = (SELECT SUM(valor) FROM pagamento),
        'Soma de total_pago da view diferente da tabela pagamento';
END $$;

ROLLBACK;

\echo 'OK: todos os testes das views passaram.'
