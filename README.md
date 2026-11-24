# 🎬 Locadora de Filmes — Banco de Dados

Modelagem e implementação de um banco de dados relacional para uma locadora de filmes, com cadastro de clientes, catálogo, controle de cópias físicas, locações e pagamentos.

Projeto de estudo desenvolvido para praticar **modelagem relacional e SQL** (PostgreSQL).

## 📌 O que o banco resolve

- Saber quais filmes estão disponíveis para locação agora
- Controlar locações em aberto e calcular dias de atraso
- Descobrir os filmes mais alugados
- Ver quanto cada cliente já gastou e quais locações ainda não foram pagas
- Acompanhar o faturamento por forma de pagamento

## 🗂️ Modelo de dados

```mermaid
erDiagram
    CLIENTE ||--o{ LOCACAO : faz
    COPIA   ||--o{ LOCACAO : "é alugada em"
    FILME   ||--|{ COPIA   : possui
    FILME   ||--o{ FILME_GENERO : classificado
    GENERO  ||--o{ FILME_GENERO : agrupa
    LOCACAO ||--o{ PAGAMENTO : recebe

    CLIENTE { int id_cliente PK
              varchar nome
              char cpf UK
              varchar email UK }
    FILME   { int id_filme PK
              varchar titulo
              smallint ano_lancamento
              numeric valor_diaria }
    GENERO  { int id_genero PK
              varchar nome UK }
    COPIA   { int id_copia PK
              int id_filme FK
              varchar midia
              boolean disponivel }
    LOCACAO { int id_locacao PK
              int id_cliente FK
              int id_copia FK
              date data_prevista
              date data_devolucao }
    PAGAMENTO { int id_pagamento PK
                int id_locacao FK
                numeric valor
                varchar forma }
```

**Decisões de modelagem**

- **Filme × Cópia:** o filme é o título do catálogo; a cópia é o DVD/Blu-ray físico. Assim uma locadora pode ter várias cópias do mesmo filme.
- **Filme × Gênero (N:N):** um filme pode ter mais de um gênero, por isso a tabela `filme_genero`.
- **Restrições (`CHECK`)** garantem dados válidos: CPF com 11 dígitos, classificação indicativa válida, datas coerentes e valores positivos.
- **Índices** nas colunas mais usadas em buscas e `JOIN`s.

## 🚀 Como executar

Pré-requisito: [PostgreSQL](https://www.postgresql.org/download/) instalado.

```bash
createdb locadora
psql -d locadora -f sql/01_schema.sql
psql -d locadora -f sql/02_dados.sql
psql -d locadora -f sql/03_consultas.sql
```

## 📁 Estrutura

```
locadora-filmes/
├── README.md
└── sql/
    ├── 01_schema.sql      # tabelas, chaves e restrições
    ├── 02_dados.sql       # dados de exemplo (fictícios)
    └── 03_consultas.sql   # consultas de negócio
```

## 🔍 Exemplo de consulta

Locações em aberto com dias de atraso:

```sql
SELECT cl.nome, f.titulo, l.data_prevista,
       GREATEST(CURRENT_DATE - l.data_prevista, 0) AS dias_atraso
FROM locacao l
JOIN cliente cl ON cl.id_cliente = l.id_cliente
JOIN copia c    ON c.id_copia    = l.id_copia
JOIN filme f    ON f.id_filme    = c.id_filme
WHERE l.data_devolucao IS NULL
ORDER BY dias_atraso DESC;
```

## 🛣️ Próximos passos

- [ ] Views para relatórios (`vw_filmes_disponiveis`, `vw_locacoes_atrasadas`)
- [ ] Função para calcular multa por atraso
- [ ] Trigger que atualiza a disponibilidade da cópia automaticamente
- [ ] Procedure para registrar locação e devolução
- [ ] Interface em Python para consultar o banco

## 🛠️ Tecnologias

PostgreSQL · SQL

---
Feito por **Matheus de Freitas Cunha**
