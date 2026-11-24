-- =============================================================
-- Arquivo: 02_dados.sql
-- Descrição: dados de exemplo para testar o banco
-- (nomes e CPFs são fictícios)
-- =============================================================

INSERT INTO genero (nome) VALUES
('Ação'), ('Comédia'), ('Drama'), ('Ficção Científica'),
('Animação'), ('Terror'), ('Romance'), ('Suspense');

INSERT INTO filme (titulo, ano_lancamento, duracao_min, classificacao, valor_diaria) VALUES
('Cidade de Deus',          2002, 130, '16', 6.50),
('Central do Brasil',       1998, 113, '12', 5.00),
('O Auto da Compadecida',   2000, 104, '12', 5.00),
('Matrix',                  1999, 136, '14', 6.00),
('Interestelar',            2014, 169, '10', 7.50),
('Toy Story',               1995,  81, 'L',  4.50),
('O Iluminado',             1980, 146, '16', 5.50),
('Tropa de Elite',          2007, 115, '16', 6.50),
('Divertida Mente',         2015,  95, 'L',  5.50),
('Titanic',                 1997, 195, '12', 6.00);

INSERT INTO filme_genero (id_filme, id_genero) VALUES
(1,3),(1,1),
(2,3),
(3,2),
(4,4),(4,1),
(5,4),(5,3),
(6,5),(6,2),
(7,6),(7,8),
(8,1),(8,3),
(9,5),(9,2),
(10,7),(10,3);

INSERT INTO copia (id_filme, midia) VALUES
(1,'DVD'),(1,'BLU-RAY'),
(2,'DVD'),
(3,'DVD'),(3,'DVD'),
(4,'BLU-RAY'),(4,'DVD'),
(5,'BLU-RAY'),
(6,'DVD'),(6,'DVD'),
(7,'DVD'),
(8,'DVD'),(8,'BLU-RAY'),
(9,'BLU-RAY'),
(10,'DVD');

INSERT INTO cliente (nome, cpf, email, telefone, data_cadastro) VALUES
('Ana Souza',        '11111111111', 'ana.souza@email.com',     '(44) 99999-0001', '2026-01-10'),
('Bruno Lima',       '22222222222', 'bruno.lima@email.com',    '(44) 99999-0002', '2026-02-05'),
('Carla Mendes',     '33333333333', 'carla.mendes@email.com',  '(44) 99999-0003', '2026-03-12'),
('Diego Ferreira',   '44444444444', 'diego.f@email.com',       '(44) 99999-0004', '2026-04-20'),
('Eduarda Rocha',    '55555555555', 'eduarda.rocha@email.com', '(44) 99999-0005', '2026-06-01'),
('Felipe Alves',     '66666666666', NULL,                      '(44) 99999-0006', '2026-08-15');

-- Locações: algumas já devolvidas, outras em aberto e uma atrasada
INSERT INTO locacao (id_cliente, id_copia, data_locacao, data_prevista, data_devolucao, valor_total) VALUES
(1,  1, '2026-11-01', '2026-11-03', '2026-11-03', 13.00),
(2,  6, '2026-11-02', '2026-11-04', '2026-11-05', 12.00),
(3,  8, '2026-11-05', '2026-11-07', '2026-11-07', 15.00),
(1,  9, '2026-11-10', '2026-11-11', '2026-11-11',  4.50),
(4, 12, '2026-11-12', '2026-11-14', '2026-11-14', 13.00),
(5, 14, '2026-11-15', '2026-11-17', '2026-11-16', 11.00),
(2,  4, '2026-11-18', '2026-11-20', NULL,          10.00),
(6, 11, '2026-11-20', '2026-11-22', NULL,         11.00),
(3, 15, '2026-11-22', '2026-11-25', NULL,         18.00);

-- Marca como indisponíveis as cópias que ainda não voltaram
UPDATE copia SET disponivel = FALSE
WHERE id_copia IN (SELECT id_copia FROM locacao WHERE data_devolucao IS NULL);

INSERT INTO pagamento (id_locacao, valor, forma, data_pagamento) VALUES
(1, 13.00, 'PIX',      '2026-11-01'),
(2, 12.00, 'DEBITO',   '2026-11-02'),
(3, 15.00, 'CREDITO',  '2026-11-05'),
(4,  4.50, 'DINHEIRO', '2026-11-10'),
(5, 13.00, 'PIX',      '2026-11-12'),
(6, 11.00, 'PIX',      '2026-11-15'),
(7, 10.00, 'DEBITO',   '2026-11-18'),
(9, 18.00, 'PIX',      '2026-11-22');
