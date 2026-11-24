-- =============================================================
-- Clinica Medica - script inicial (tabelas, regras e dados)
-- SGBD: PostgreSQL 16+
-- Executar no banco clinica_medica:
--   psql -U postgres -d clinica_medica -f database/init.sql
-- =============================================================

DROP TABLE IF EXISTS pagamentos, prontuarios, consultas, medicos, pacientes CASCADE;

-- -------------------------------------------------------------
-- 1. PACIENTES (tabela principal do sistema)
-- -------------------------------------------------------------
CREATE TABLE pacientes (
    id               SERIAL       PRIMARY KEY,
    nome             VARCHAR(120) NOT NULL,
    cpf              CHAR(11)     NOT NULL UNIQUE
                     CHECK (cpf ~ '^[0-9]{11}$'),              -- so 11 digitos
    data_nascimento  DATE         NOT NULL
                     CHECK (data_nascimento > DATE '1900-01-01'),
    telefone         VARCHAR(20)  NOT NULL,
    email            VARCHAR(120) UNIQUE,
    criado_em        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- 2. MEDICOS
-- -------------------------------------------------------------
CREATE TABLE medicos (
    id              SERIAL        PRIMARY KEY,
    nome            VARCHAR(120)  NOT NULL,
    crm             VARCHAR(15)   NOT NULL UNIQUE,             -- ex.: 12345-MA
    especialidade   VARCHAR(60)   NOT NULL,
    valor_consulta  NUMERIC(10,2) NOT NULL
                    CHECK (valor_consulta > 0),                -- REGRA: preco nunca negativo ou zero
    ativo           BOOLEAN       NOT NULL DEFAULT TRUE
);

-- -------------------------------------------------------------
-- 3. CONSULTAS (liga paciente e medico)
-- -------------------------------------------------------------
CREATE TABLE consultas (
    id           SERIAL        PRIMARY KEY,
    paciente_id  INT           NOT NULL REFERENCES pacientes(id),
    medico_id    INT           NOT NULL REFERENCES medicos(id),
    data_hora    TIMESTAMP     NOT NULL
                 CHECK (EXTRACT(MINUTE FROM data_hora) IN (0, 30)
                        AND EXTRACT(SECOND FROM data_hora) = 0), -- agenda em horarios de 30 min
    status       VARCHAR(12)   NOT NULL DEFAULT 'AGENDADA'
                 CHECK (status IN ('AGENDADA', 'REALIZADA', 'CANCELADA')),
    valor        NUMERIC(10,2) NOT NULL CHECK (valor >= 0),
    criado_em    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- REGRA: um medico nao pode ter duas consultas ativas no mesmo horario.
-- Consultas canceladas liberam o horario (indice unico parcial).
CREATE UNIQUE INDEX uq_medico_horario
    ON consultas (medico_id, data_hora)
    WHERE status <> 'CANCELADA';

-- REGRA: o paciente tambem nao pode estar em duas consultas ao mesmo tempo.
CREATE UNIQUE INDEX uq_paciente_horario
    ON consultas (paciente_id, data_hora)
    WHERE status <> 'CANCELADA';

-- -------------------------------------------------------------
-- 4. PRONTUARIOS (registro clinico de uma consulta realizada)
-- -------------------------------------------------------------
CREATE TABLE prontuarios (
    id           SERIAL    PRIMARY KEY,
    consulta_id  INT       NOT NULL UNIQUE REFERENCES consultas(id),  -- 1 prontuario por consulta
    diagnostico  TEXT      NOT NULL CHECK (length(trim(diagnostico)) > 0),
    prescricao   TEXT,
    observacoes  TEXT,
    criado_em    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- 5. PAGAMENTOS
-- -------------------------------------------------------------
CREATE TABLE pagamentos (
    id           SERIAL        PRIMARY KEY,
    consulta_id  INT           NOT NULL UNIQUE REFERENCES consultas(id),  -- 1 pagamento por consulta
    valor        NUMERIC(10,2) NOT NULL CHECK (valor > 0),
    forma        VARCHAR(10)   NOT NULL
                 CHECK (forma IN ('PIX', 'CARTAO', 'DINHEIRO', 'CONVENIO')),
    pago_em      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indices para as consultas mais frequentes (agenda e historico)
CREATE INDEX idx_consultas_medico_data   ON consultas (medico_id, data_hora);
CREATE INDEX idx_consultas_paciente_data ON consultas (paciente_id, data_hora);

-- =============================================================
-- DADOS DE EXEMPLO
-- =============================================================
INSERT INTO pacientes (nome, cpf, data_nascimento, telefone, email) VALUES
    ('Ana Souza',      '12345678901', '1990-04-12', '98999990001', 'ana@email.com'),
    ('Bruno Almeida',  '23456789012', '1985-09-30', '98999990002', 'bruno@email.com'),
    ('Carla Mendes',   '34567890123', '2001-01-05', '98999990003', NULL);

INSERT INTO medicos (nome, crm, especialidade, valor_consulta) VALUES
    ('Dr. Paulo Lima',      '10234-MA', 'Cardiologia', 350.00),
    ('Dra. Fernanda Rocha', '20456-MA', 'Pediatria',   250.00);

-- Agendamento + atendimento + pagamento dentro de uma transacao
BEGIN;
INSERT INTO consultas (paciente_id, medico_id, data_hora, status, valor) VALUES
    (1, 1, '2026-12-01 09:00', 'REALIZADA', 350.00),
    (2, 1, '2026-12-01 09:30', 'AGENDADA',  350.00),
    (3, 2, '2026-12-01 09:00', 'AGENDADA',  250.00),
    (2, 2, '2026-12-02 14:00', 'CANCELADA', 250.00);

INSERT INTO prontuarios (consulta_id, diagnostico, prescricao) VALUES
    (1, 'Hipertensao arterial leve', 'Losartana 50mg 1x ao dia; retorno em 30 dias');

INSERT INTO pagamentos (consulta_id, valor, forma) VALUES
    (1, 350.00, 'PIX');
COMMIT;

-- =============================================================
-- CONSULTAS DE EXEMPLO
-- =============================================================

-- Agenda do dia por medico
SELECT m.nome AS medico, c.data_hora, p.nome AS paciente, c.status
FROM consultas c
JOIN medicos   m ON m.id = c.medico_id
JOIN pacientes p ON p.id = c.paciente_id
WHERE c.data_hora::date = DATE '2026-12-01'
  AND c.status <> 'CANCELADA'
ORDER BY m.nome, c.data_hora;

-- Historico do paciente com prontuario
SELECT p.nome, c.data_hora, m.especialidade, pr.diagnostico, pr.prescricao
FROM consultas c
JOIN pacientes p        ON p.id = c.paciente_id
JOIN medicos   m        ON m.id = c.medico_id
LEFT JOIN prontuarios pr ON pr.consulta_id = c.id
WHERE p.cpf = '12345678901'
ORDER BY c.data_hora DESC;

-- Faturamento por medico (somente consultas pagas)
SELECT m.nome, COUNT(pg.id) AS consultas_pagas, COALESCE(SUM(pg.valor), 0) AS total_recebido
FROM medicos m
LEFT JOIN consultas  c  ON c.medico_id = m.id
LEFT JOIN pagamentos pg ON pg.consulta_id = c.id
GROUP BY m.nome
ORDER BY total_recebido DESC;
