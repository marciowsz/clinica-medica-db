-- =============================================================
-- Clinica Medica - criacao do banco de dados
-- SGBD: PostgreSQL 16+
-- Executar conectado ao banco padrao "postgres":
--   psql -U postgres -f database/00_create_database.sql
-- =============================================================

CREATE DATABASE clinica_medica
    WITH ENCODING 'UTF8'
    TEMPLATE template0;
