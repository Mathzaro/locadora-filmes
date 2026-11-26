-- =============================================================
-- Arquivo: 05_funcoes.sql
-- Descrição: funções para calcular dias de atraso e multa
--
-- Regra de negócio (fictícia) da locadora:
--   * cada dia de atraso custa a diária do filme + 50%
--     (multa por dia = valor_diaria x 1,5);
--   * se a cópia já foi devolvida, o atraso é contado até a
--     data de devolução; se ainda não voltou, até a data de
--     referência (por padrão, hoje);
--   * quem devolve no prazo (ou antes) não paga multa.
--
-- Por que funções? A regra fica em UM lugar só. Relatórios,
-- procedures e uma futura aplicação chamam a mesma função, e se
-- a taxa mudar, alteramos só aqui.
--
-- CREATE OR REPLACE FUNCTION permite rodar o script de novo.
-- =============================================================

-- Taxa da multa guardada em uma função "constante": assim o
-- número 1.5 não fica espalhado pelo código.
CREATE OR REPLACE FUNCTION fn_taxa_multa()
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT 1.5::NUMERIC;
$$;

-- -------------------------------------------------------------
-- 1) Dias de atraso
--    Função "pura": só depende dos parâmetros, sem ler tabelas.
--    Por isso pode ser IMMUTABLE (o PostgreSQL pode otimizar).
--    O valor padrão CURRENT_DATE é calculado na hora da chamada,
--    então não atrapalha o IMMUTABLE.
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_dias_atraso(
    p_data_prevista   DATE,
    p_data_devolucao  DATE,
    p_data_referencia DATE DEFAULT CURRENT_DATE
)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
    -- COALESCE: se ainda não devolveu (NULL), usa a data de referência
    -- GREATEST(..., 0): devolução no prazo vira 0, nunca negativo
    SELECT GREATEST(COALESCE(p_data_devolucao, p_data_referencia) - p_data_prevista, 0);
$$;

-- -------------------------------------------------------------
-- 2) Multa de uma locação
--    Lê a locação e o filme, por isso é STABLE (não altera nada,
--    mas o resultado depende do que está nas tabelas).
--    Escrita em PL/pgSQL para poder validar a entrada e dar um
--    erro claro quando a locação não existe.
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_multa(
    p_id_locacao      INT,
    p_data_referencia DATE DEFAULT CURRENT_DATE
)
RETURNS NUMERIC(8,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_data_prevista  DATE;
    v_data_devolucao DATE;
    v_valor_diaria   NUMERIC(6,2);
    v_dias           INT;
BEGIN
    SELECT l.data_prevista, l.data_devolucao, f.valor_diaria
      INTO v_data_prevista, v_data_devolucao, v_valor_diaria
      FROM locacao l
      JOIN copia c ON c.id_copia = l.id_copia
      JOIN filme f ON f.id_filme = c.id_filme
     WHERE l.id_locacao = p_id_locacao;

    -- FOUND é preenchido pelo PL/pgSQL depois do SELECT INTO
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Locação % não encontrada', p_id_locacao;
    END IF;

    v_dias := fn_dias_atraso(v_data_prevista, v_data_devolucao, p_data_referencia);

    -- ROUND(..., 2): valor em reais com 2 casas decimais
    RETURN ROUND(v_dias * v_valor_diaria * fn_taxa_multa(), 2);
END;
$$;

-- -------------------------------------------------------------
-- Exemplos de uso
-- -------------------------------------------------------------

-- Multa de uma locação específica (até hoje)
SELECT fn_calcular_multa(7) AS multa_locacao_7;

-- "Quanto essa locação vai dever se voltar só no dia 30/11?"
SELECT fn_calcular_multa(7, DATE '2026-11-30') AS multa_se_voltar_dia_30;

-- Lista de cobrança com a multa calculada (usa a view de 04_views.sql)
SELECT cliente, telefone, titulo, dias_atraso,
       fn_calcular_multa(id_locacao) AS multa
FROM vw_locacoes_atrasadas
ORDER BY multa DESC;

-- Locações já devolvidas com atraso e a multa que gerou
SELECT l.id_locacao, cl.nome, l.data_prevista, l.data_devolucao,
       fn_dias_atraso(l.data_prevista, l.data_devolucao) AS dias_atraso,
       fn_calcular_multa(l.id_locacao)                   AS multa
FROM locacao l
JOIN cliente cl ON cl.id_cliente = l.id_cliente
WHERE l.data_devolucao > l.data_prevista;
