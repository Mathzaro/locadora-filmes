# 📚 Diário de estudo — Locadora de Filmes

Registro do que foi feito em cada etapa, por que foi feito e o que estudar para explicar o projeto em uma entrevista.

---

## 24/11/2026 — Views para relatórios + testes automatizados

### O que mudou
- Novo arquivo `sql/04_views.sql` com 4 views:
  - `vw_filmes_disponiveis` — filmes com pelo menos uma cópia livre;
  - `vw_locacoes_em_aberto` — locações não devolvidas com `dias_atraso`;
  - `vw_locacoes_atrasadas` — filtra a view anterior (lista de cobrança);
  - `vw_resumo_clientes` — total locado, total pago e saldo devedor por cliente.
- Novo arquivo `testes/teste_04_views.sql`: insere dados de teste, confere os resultados das views com `ASSERT` e desfaz tudo com `ROLLBACK`.
- `sql/01_schema.sql`: os `DROP TABLE` agora usam `CASCADE`, porque o PostgreSQL não deixa apagar uma tabela que tem view dependendo dela.

### Por que
As consultas de relatório (o que está disponível, quem está atrasado, quem deve) eram repetidas com vários `JOIN`s. Com views, quem usa o banco escreve só `SELECT * FROM vw_locacoes_atrasadas`, e se a regra mudar, muda em um lugar só. Os testes garantem que as views continuam certas quando o projeto evoluir.

### Conceitos envolvidos
- **VIEW:** consulta salva com nome. Não guarda dados; roda a consulta toda vez. (Diferente de `MATERIALIZED VIEW`, que guarda o resultado e precisa de `REFRESH`.)
- **View sobre view:** `vw_locacoes_atrasadas` reaproveita `vw_locacoes_em_aberto`.
- **`HAVING` x `WHERE`:** `WHERE` filtra linhas antes do `GROUP BY`; `HAVING` filtra grupos depois.
- **`COUNT(...) FILTER (WHERE ...)`:** conta só as linhas que atendem a uma condição.
- **Armadilha do JOIN duplicado (fan-out):** juntar locação com pagamento e somar `valor_total` conta a mesma locação várias vezes se ela tiver 2 pagamentos. Solução usada: somar cada tabela separadamente em uma CTE (`WITH`) e só depois juntar.
- **CTE (`WITH`):** dá nome a uma subconsulta para deixar o SQL mais legível.
- **Testes em SQL:** `BEGIN ... ROLLBACK` deixa o banco como estava; datas relativas (`CURRENT_DATE - 3`) fazem o teste passar em qualquer dia; `ASSERT` interrompe com mensagem clara quando algo está errado. Conferi que o teste realmente falha se a view for escrita com o JOIN ingênuo.

### Para rodar hoje
```bash
psql -d locadora -f sql/01_schema.sql
psql -d locadora -f sql/02_dados.sql
psql -d locadora -f sql/04_views.sql
psql -d locadora -v ON_ERROR_STOP=1 -f testes/teste_04_views.sql
```
Exercício: troque a `vw_resumo_clientes` por uma versão com um JOIN só entre `cliente`, `locacao` e `pagamento` e rode o teste de novo para ver ele falhar.

### Perguntas de entrevista
1. **Uma view deixa a consulta mais rápida?**
   Não por si só: a view comum só guarda o texto da consulta, e o PostgreSQL executa a consulta original toda vez. O ganho é de organização, reuso e segurança (dar acesso só à view). Para desempenho, usaria índices ou uma `MATERIALIZED VIEW`, sabendo que ela precisa ser atualizada com `REFRESH MATERIALIZED VIEW`.

2. **Por que você não fez um JOIN só entre cliente, locação e pagamento no resumo financeiro?**
   Porque uma locação com dois pagamentos apareceria duas vezes no resultado e o `SUM(valor_total)` ficaria em dobro. Por isso somei locações e pagamentos separadamente (em CTEs agrupadas por cliente) e só depois juntei — e escrevi um teste com dois pagamentos na mesma locação para provar que o valor está certo.

---

## 26/11/2026 — Funções de dias de atraso e multa

### O que mudou
- Novo arquivo `sql/05_funcoes.sql` com 3 funções:
  - `fn_taxa_multa()` — devolve a taxa 1,5 (diária + 50%), guardada em um lugar só;
  - `fn_dias_atraso(prevista, devolucao, referencia)` — dias de atraso, nunca negativo;
  - `fn_calcular_multa(id_locacao, referencia)` — busca a locação e a diária do filme e devolve a multa em reais.
- Novo arquivo `testes/teste_05_funcoes.sql`: testa atraso, devolução no prazo e antes do prazo, locação já devolvida (a multa não cresce com o tempo), simulação com data futura, erro para locação inexistente e se a função concorda com a `vw_locacoes_em_aberto`.
- README com a seção "Multa por atraso" e o item marcado em "Próximos passos".

### Por que
O cálculo de atraso já existia dentro da view, mas a multa ia precisar ser repetida em relatórios, na futura procedure de devolução e em qualquer aplicação que use o banco. Com a regra em uma função, todos chamam o mesmo código e, se a taxa mudar, muda em um lugar só. O parâmetro `p_data_referencia` permite simular ("quanto vai dar se devolver dia 30?") e deixa a função fácil de testar.

### Conceitos envolvidos
- **`CREATE FUNCTION` em `LANGUAGE sql` x `plpgsql`:** SQL puro para cálculos simples; PL/pgSQL quando preciso de variáveis, `IF` e `RAISE`.
- **Volatilidade:** `IMMUTABLE` (só depende dos parâmetros, ex.: `fn_dias_atraso`), `STABLE` (lê tabelas, mas não altera nada, ex.: `fn_calcular_multa`) e `VOLATILE` (padrão; pode mudar dados ou dar resultados diferentes a cada chamada). Declarar certo ajuda o PostgreSQL a otimizar.
- **Parâmetro com `DEFAULT`:** `p_data_referencia DATE DEFAULT CURRENT_DATE` — o padrão é calculado na chamada.
- **`SELECT ... INTO` + `FOUND`:** carrega valores em variáveis e diz se achou alguma linha.
- **`RAISE EXCEPTION`:** erro com mensagem clara em vez de devolver `NULL` silenciosamente.
- **`COALESCE`, `GREATEST`, `ROUND`:** trata devolução nula, evita atraso negativo e arredonda para centavos.
- **Testando erros:** bloco `DO` com `EXCEPTION WHEN raise_exception` para confirmar que o erro acontece. Conferi que o teste falha se a função deixar o atraso ficar negativo.

### Para rodar hoje
```bash
psql -d locadora -f sql/05_funcoes.sql
psql -d locadora -v ON_ERROR_STOP=1 -f testes/teste_05_funcoes.sql
```
Exercício: mude `fn_taxa_multa()` para devolver `2.0` e rode o teste. Quais asserts quebram? Por que os de "sem multa" continuam passando?

### Perguntas de entrevista
1. **Qual a diferença entre `IMMUTABLE`, `STABLE` e `VOLATILE`?**
   `IMMUTABLE` sempre dá o mesmo resultado para os mesmos parâmetros e não lê tabelas; `STABLE` não altera dados e dá o mesmo resultado dentro de uma consulta, mas pode ler tabelas; `VOLATILE` pode mudar a cada chamada ou alterar dados. Por isso `fn_dias_atraso` é `IMMUTABLE` e `fn_calcular_multa`, que lê `locacao` e `filme`, é `STABLE`.

2. **Por que colocar a regra da multa no banco e não na aplicação?**
   Assim todo sistema que usa o banco (relatório, procedure, app) calcula igual, e a regra muda em um lugar só. A desvantagem é que lógica no banco é mais difícil de versionar e testar se não houver disciplina — por isso o script está no Git e tem testes automatizados. Em muitos times a regra fica na aplicação; o importante é não duplicar.
