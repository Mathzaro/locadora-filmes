-- =============================================================
-- Projeto: Locadora de Filmes
-- Arquivo: 01_schema.sql
-- Descrição: criação das tabelas, chaves e restrições
-- Banco: PostgreSQL 14+
-- =============================================================

-- CASCADE também remove as views que dependem das tabelas (04_views.sql),
-- permitindo rodar o script de novo sem erro.
DROP TABLE IF EXISTS pagamento CASCADE;
DROP TABLE IF EXISTS locacao CASCADE;
DROP TABLE IF EXISTS copia CASCADE;
DROP TABLE IF EXISTS filme_genero CASCADE;
DROP TABLE IF EXISTS filme CASCADE;
DROP TABLE IF EXISTS genero CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;

-- Clientes cadastrados na locadora
CREATE TABLE cliente (
    id_cliente     SERIAL PRIMARY KEY,
    nome           VARCHAR(100) NOT NULL,
    cpf            CHAR(11)     NOT NULL UNIQUE,
    email          VARCHAR(120) UNIQUE,
    telefone       VARCHAR(20),
    data_cadastro  DATE         NOT NULL DEFAULT CURRENT_DATE,
    ativo          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_cliente_cpf CHECK (cpf ~ '^[0-9]{11}$')
);

-- Gêneros de filme (Ação, Comédia, Drama...)
CREATE TABLE genero (
    id_genero  SERIAL PRIMARY KEY,
    nome       VARCHAR(50) NOT NULL UNIQUE
);

-- Catálogo de filmes
CREATE TABLE filme (
    id_filme            SERIAL PRIMARY KEY,
    titulo              VARCHAR(150) NOT NULL,
    ano_lancamento      SMALLINT     NOT NULL,
    duracao_min         SMALLINT     NOT NULL,
    classificacao       VARCHAR(5)   NOT NULL,
    valor_diaria        NUMERIC(6,2) NOT NULL,
    CONSTRAINT ck_filme_ano      CHECK (ano_lancamento BETWEEN 1888 AND 2100),
    CONSTRAINT ck_filme_duracao  CHECK (duracao_min > 0),
    CONSTRAINT ck_filme_classif  CHECK (classificacao IN ('L','10','12','14','16','18')),
    CONSTRAINT ck_filme_valor    CHECK (valor_diaria > 0)
);

-- Um filme pode ter vários gêneros (relação N:N)
CREATE TABLE filme_genero (
    id_filme   INT NOT NULL REFERENCES filme(id_filme)   ON DELETE CASCADE,
    id_genero  INT NOT NULL REFERENCES genero(id_genero) ON DELETE RESTRICT,
    PRIMARY KEY (id_filme, id_genero)
);

-- Cópias físicas de cada filme (DVD / Blu-ray)
CREATE TABLE copia (
    id_copia   SERIAL PRIMARY KEY,
    id_filme   INT         NOT NULL REFERENCES filme(id_filme) ON DELETE RESTRICT,
    midia      VARCHAR(10) NOT NULL,
    disponivel BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_copia_midia CHECK (midia IN ('DVD','BLU-RAY'))
);

-- Cada locação é de uma cópia para um cliente
CREATE TABLE locacao (
    id_locacao        SERIAL PRIMARY KEY,
    id_cliente        INT          NOT NULL REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
    id_copia          INT          NOT NULL REFERENCES copia(id_copia)     ON DELETE RESTRICT,
    data_locacao      DATE         NOT NULL DEFAULT CURRENT_DATE,
    data_prevista     DATE         NOT NULL,
    data_devolucao    DATE,
    valor_total       NUMERIC(8,2) NOT NULL,
    CONSTRAINT ck_locacao_prevista  CHECK (data_prevista  >= data_locacao),
    CONSTRAINT ck_locacao_devolucao CHECK (data_devolucao IS NULL OR data_devolucao >= data_locacao),
    CONSTRAINT ck_locacao_valor     CHECK (valor_total >= 0)
);

-- Pagamentos referentes a uma locação
CREATE TABLE pagamento (
    id_pagamento    SERIAL PRIMARY KEY,
    id_locacao      INT          NOT NULL REFERENCES locacao(id_locacao) ON DELETE CASCADE,
    valor           NUMERIC(8,2) NOT NULL,
    forma           VARCHAR(10)  NOT NULL,
    data_pagamento  DATE         NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT ck_pagamento_valor CHECK (valor > 0),
    CONSTRAINT ck_pagamento_forma CHECK (forma IN ('PIX','DINHEIRO','CREDITO','DEBITO'))
);

-- Índices para as buscas mais comuns
CREATE INDEX idx_filme_titulo     ON filme (titulo);
CREATE INDEX idx_locacao_cliente  ON locacao (id_cliente);
CREATE INDEX idx_locacao_copia    ON locacao (id_copia);
CREATE INDEX idx_copia_filme      ON copia (id_filme);
