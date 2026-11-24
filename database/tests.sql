-- =============================================================
-- Testes das regras de negocio (rodar DEPOIS do init.sql)
--   psql -U postgres -d clinica_medica -v ON_ERROR_STOP=1 -f database/tests.sql
-- Cada bloco tenta gravar um dado INVALIDO. Se o banco aceitar,
-- o teste falha com RAISE EXCEPTION. Se o banco recusar, passa.
-- =============================================================

-- 1. Preco da consulta nao pode ser negativo (CHECK)
DO $$
BEGIN
    INSERT INTO medicos (nome, crm, especialidade, valor_consulta)
    VALUES ('Dr. Teste', '99999-MA', 'Clinica Geral', -100.00);
    RAISE EXCEPTION 'FALHOU: aceitou valor_consulta negativo';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK 1: valor_consulta negativo recusado';
END $$;

-- 2. Medico nao pode ter duas consultas no mesmo horario (indice unico)
DO $$
BEGIN
    INSERT INTO consultas (paciente_id, medico_id, data_hora, valor)
    VALUES (3, 1, '2026-12-01 09:30', 350.00);   -- 09:30 do Dr. Paulo ja esta ocupado
    RAISE EXCEPTION 'FALHOU: aceitou dois pacientes no mesmo horario';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK 2: horario duplicado do medico recusado';
END $$;

-- 3. Horario de consulta cancelada pode ser reaproveitado
DO $$
BEGIN
    INSERT INTO consultas (paciente_id, medico_id, data_hora, valor)
    VALUES (1, 2, '2026-12-02 14:00', 250.00);   -- era a consulta cancelada
    RAISE NOTICE 'OK 3: horario cancelado foi reaproveitado';
END $$;

-- 4. Agenda so aceita horarios cheios ou meia hora
DO $$
BEGIN
    INSERT INTO consultas (paciente_id, medico_id, data_hora, valor)
    VALUES (1, 1, '2026-12-03 10:17', 350.00);
    RAISE EXCEPTION 'FALHOU: aceitou horario 10:17';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK 4: horario fora da grade recusado';
END $$;

-- 5. CPF precisa ter 11 digitos numericos
DO $$
BEGIN
    INSERT INTO pacientes (nome, cpf, data_nascimento, telefone)
    VALUES ('Teste', '123.456.789', '2000-01-01', '98999990000');
    RAISE EXCEPTION 'FALHOU: aceitou CPF invalido';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK 5: CPF invalido recusado';
END $$;

-- 6. CPF nao pode se repetir
DO $$
BEGIN
    INSERT INTO pacientes (nome, cpf, data_nascimento, telefone)
    VALUES ('Outra Ana', '12345678901', '1999-01-01', '98999990000');
    RAISE EXCEPTION 'FALHOU: aceitou CPF duplicado';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK 6: CPF duplicado recusado';
END $$;

-- 7. Consulta precisa de paciente existente (chave estrangeira)
DO $$
BEGIN
    INSERT INTO consultas (paciente_id, medico_id, data_hora, valor)
    VALUES (999, 1, '2026-12-04 08:00', 350.00);
    RAISE EXCEPTION 'FALHOU: aceitou paciente inexistente';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'OK 7: paciente inexistente recusado';
END $$;

-- 8. Uma consulta so pode ser paga uma vez
DO $$
BEGIN
    INSERT INTO pagamentos (consulta_id, valor, forma) VALUES (1, 350.00, 'CARTAO');
    RAISE EXCEPTION 'FALHOU: aceitou pagamento duplicado';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK 8: pagamento duplicado recusado';
END $$;

-- 9. Status invalido e recusado
DO $$
BEGIN
    UPDATE consultas SET status = 'ATRASADA' WHERE id = 2;
    RAISE EXCEPTION 'FALHOU: aceitou status invalido';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK 9: status invalido recusado';
END $$;

-- 10. Dados de exemplo foram carregados
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM pacientes) <> 3
       OR (SELECT COUNT(*) FROM medicos) <> 2
       OR (SELECT SUM(valor) FROM pagamentos) <> 350.00 THEN
        RAISE EXCEPTION 'FALHOU: dados de exemplo incorretos';
    END IF;
    RAISE NOTICE 'OK 10: dados de exemplo conferem';
END $$;
