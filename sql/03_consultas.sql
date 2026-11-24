-- =============================================================
-- Arquivo: 03_consultas.sql
-- Descrição: consultas que respondem perguntas reais do negócio
-- =============================================================

-- 1) Catálogo: filmes com seus gêneros em uma linha só
SELECT f.titulo,
       f.ano_lancamento,
       STRING_AGG(g.nome, ', ' ORDER BY g.nome) AS generos
FROM filme f
JOIN filme_genero fg ON fg.id_filme  = f.id_filme
JOIN genero g        ON g.id_genero  = fg.id_genero
GROUP BY f.id_filme, f.titulo, f.ano_lancamento
ORDER BY f.titulo;

-- 2) Quantas cópias disponíveis cada filme tem agora
SELECT f.titulo,
       COUNT(c.id_copia)                              AS total_copias,
       COUNT(c.id_copia) FILTER (WHERE c.disponivel)  AS disponiveis
FROM filme f
LEFT JOIN copia c ON c.id_filme = f.id_filme
GROUP BY f.id_filme, f.titulo
ORDER BY disponiveis DESC, f.titulo;

-- 3) Locações em aberto e quantos dias de atraso
--    (troque CURRENT_DATE por uma data fixa para testar, ex.: DATE '2026-11-24')
SELECT cl.nome,
       f.titulo,
       l.data_locacao,
       l.data_prevista,
       GREATEST(CURRENT_DATE - l.data_prevista, 0) AS dias_atraso
FROM locacao l
JOIN cliente cl ON cl.id_cliente = l.id_cliente
JOIN copia c    ON c.id_copia    = l.id_copia
JOIN filme f    ON f.id_filme    = c.id_filme
WHERE l.data_devolucao IS NULL
ORDER BY dias_atraso DESC;

-- 4) Ranking dos filmes mais alugados
SELECT f.titulo,
       COUNT(l.id_locacao) AS vezes_alugado
FROM filme f
LEFT JOIN copia c   ON c.id_filme = f.id_filme
LEFT JOIN locacao l ON l.id_copia = c.id_copia
GROUP BY f.id_filme, f.titulo
ORDER BY vezes_alugado DESC, f.titulo
LIMIT 5;

-- 5) Quanto cada cliente já gastou
SELECT cl.nome,
       COUNT(DISTINCT l.id_locacao)   AS locacoes,
       COALESCE(SUM(p.valor), 0)      AS total_pago
FROM cliente cl
LEFT JOIN locacao l   ON l.id_cliente = cl.id_cliente
LEFT JOIN pagamento p ON p.id_locacao = l.id_locacao
GROUP BY cl.id_cliente, cl.nome
ORDER BY total_pago DESC;

-- 6) Locações sem pagamento registrado (pendências)
SELECT l.id_locacao, cl.nome, l.valor_total
FROM locacao l
JOIN cliente cl ON cl.id_cliente = l.id_cliente
WHERE NOT EXISTS (SELECT 1 FROM pagamento p WHERE p.id_locacao = l.id_locacao);

-- 7) Faturamento por forma de pagamento
SELECT forma,
       COUNT(*)    AS qtd,
       SUM(valor)  AS total
FROM pagamento
GROUP BY forma
ORDER BY total DESC;
