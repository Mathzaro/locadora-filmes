-- =============================================================
-- Arquivo: 04_views.sql
-- Descrição: views (consultas salvas) para os relatórios do dia a dia
--
-- Uma VIEW é uma consulta com nome. Ela não guarda dados: toda vez
-- que alguém faz SELECT na view, o PostgreSQL roda a consulta por
-- trás dela. Vantagens:
--   * quem usa o relatório não precisa repetir JOINs complicados;
--   * se a regra mudar, alteramos em um lugar só;
--   * dá para liberar acesso só à view, sem expor a tabela inteira.
--
-- CREATE OR REPLACE VIEW permite rodar o script de novo sem erro.
-- =============================================================

-- -------------------------------------------------------------
-- 1) Filmes que têm pelo menos uma cópia disponível agora
--    Pergunta do balcão: "o que eu posso alugar hoje?"
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_filmes_disponiveis AS
SELECT f.id_filme,
       f.titulo,
       f.ano_lancamento,
       f.classificacao,
       f.valor_diaria,
       -- subconsulta para os gêneros: evita que o JOIN com gêneros
       -- multiplique as linhas de cópia e distorça a contagem
       (SELECT STRING_AGG(g.nome, ', ' ORDER BY g.nome)
          FROM filme_genero fg
          JOIN genero g ON g.id_genero = fg.id_genero
         WHERE fg.id_filme = f.id_filme)                  AS generos,
       COUNT(c.id_copia)                                  AS total_copias,
       COUNT(c.id_copia) FILTER (WHERE c.disponivel)      AS copias_disponiveis
FROM filme f
JOIN copia c ON c.id_filme = f.id_filme
GROUP BY f.id_filme
-- HAVING filtra depois do agrupamento (WHERE filtra antes)
HAVING COUNT(c.id_copia) FILTER (WHERE c.disponivel) > 0;

-- -------------------------------------------------------------
-- 2) Todas as locações em aberto (cópia ainda não devolvida)
--    com os dias de atraso calculados em relação a hoje
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_locacoes_em_aberto AS
SELECT l.id_locacao,
       cl.id_cliente,
       cl.nome                                       AS cliente,
       cl.telefone,
       f.titulo,
       c.id_copia,
       c.midia,
       l.data_locacao,
       l.data_prevista,
       -- GREATEST(..., 0): quem ainda está no prazo fica com 0, não negativo
       GREATEST(CURRENT_DATE - l.data_prevista, 0)   AS dias_atraso
FROM locacao l
JOIN cliente cl ON cl.id_cliente = l.id_cliente
JOIN copia c    ON c.id_copia    = l.id_copia
JOIN filme f    ON f.id_filme    = c.id_filme
WHERE l.data_devolucao IS NULL;

-- -------------------------------------------------------------
-- 3) Só as locações atrasadas — uma view construída em cima
--    de outra view. Serve de lista de cobrança (tem o telefone).
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_locacoes_atrasadas AS
SELECT id_locacao,
       cliente,
       telefone,
       titulo,
       midia,
       data_prevista,
       dias_atraso
FROM vw_locacoes_em_aberto
WHERE dias_atraso > 0;

-- -------------------------------------------------------------
-- 4) Resumo financeiro por cliente
--    Cuidado clássico: somar valor_total da locação e valor do
--    pagamento no MESMO JOIN duplica valores (uma locação com 2
--    pagamentos apareceria 2 vezes). Por isso cada soma é feita
--    separadamente em uma subconsulta e só depois juntada.
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_resumo_clientes AS
WITH locacoes AS (
    SELECT id_cliente,
           COUNT(*)                                        AS qtd_locacoes,
           COUNT(*) FILTER (WHERE data_devolucao IS NULL)  AS em_aberto,
           SUM(valor_total)                                AS total_locado
    FROM locacao
    GROUP BY id_cliente
),
pagamentos AS (
    SELECT l.id_cliente,
           SUM(p.valor) AS total_pago
    FROM pagamento p
    JOIN locacao l ON l.id_locacao = p.id_locacao
    GROUP BY l.id_cliente
)
SELECT cl.id_cliente,
       cl.nome,
       COALESCE(lo.qtd_locacoes, 0)                           AS qtd_locacoes,
       COALESCE(lo.em_aberto, 0)                              AS em_aberto,
       COALESCE(lo.total_locado, 0)                           AS total_locado,
       COALESCE(pg.total_pago, 0)                             AS total_pago,
       COALESCE(lo.total_locado, 0) - COALESCE(pg.total_pago, 0) AS saldo_devedor
FROM cliente cl
LEFT JOIN locacoes   lo ON lo.id_cliente = cl.id_cliente
LEFT JOIN pagamentos pg ON pg.id_cliente = cl.id_cliente;

-- -------------------------------------------------------------
-- Exemplos de uso (as views funcionam como tabelas no SELECT)
-- -------------------------------------------------------------
SELECT titulo, generos, copias_disponiveis, valor_diaria
FROM vw_filmes_disponiveis
ORDER BY titulo;

SELECT cliente, titulo, data_prevista, dias_atraso
FROM vw_locacoes_em_aberto
ORDER BY dias_atraso DESC;

SELECT cliente, telefone, titulo, dias_atraso
FROM vw_locacoes_atrasadas
ORDER BY dias_atraso DESC;

SELECT nome, qtd_locacoes, total_locado, total_pago, saldo_devedor
FROM vw_resumo_clientes
WHERE saldo_devedor > 0
ORDER BY saldo_devedor DESC;
