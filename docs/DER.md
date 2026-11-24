# Diagrama Entidade-Relacionamento (DER)

```mermaid
erDiagram
    PACIENTES ||--o{ CONSULTAS : "agenda"
    MEDICOS   ||--o{ CONSULTAS : "atende"
    CONSULTAS ||--o| PRONTUARIOS : "gera"
    CONSULTAS ||--o| PAGAMENTOS : "e paga por"

    PACIENTES {
        int       id PK
        char11    cpf UK "so 11 digitos"
        varchar   nome
        date      data_nascimento
        varchar   telefone
        varchar   email UK
        timestamp criado_em
    }
    MEDICOS {
        int     id PK
        varchar crm UK
        varchar nome
        varchar especialidade
        numeric valor_consulta "CHECK maior que 0"
        boolean ativo
    }
    CONSULTAS {
        int       id PK
        int       paciente_id FK
        int       medico_id FK
        timestamp data_hora "grade de 30 min"
        varchar   status "AGENDADA, REALIZADA, CANCELADA"
        numeric   valor "CHECK maior ou igual a 0"
        timestamp criado_em
    }
    PRONTUARIOS {
        int       id PK
        int       consulta_id FK,UK
        text      diagnostico
        text      prescricao
        text      observacoes
        timestamp criado_em
    }
    PAGAMENTOS {
        int       id PK
        int       consulta_id FK,UK
        numeric   valor "CHECK maior que 0"
        varchar   forma "PIX, CARTAO, DINHEIRO, CONVENIO"
        timestamp pago_em
    }
```

## Cardinalidades

| Relacionamento | Cardinalidade | Leitura |
|---|---|---|
| Paciente → Consulta | 1 : N | Um paciente pode ter várias consultas; cada consulta é de um único paciente. |
| Médico → Consulta | 1 : N | Um médico atende várias consultas; cada consulta tem um único médico. |
| Consulta → Prontuário | 1 : 0..1 | Só a consulta **realizada** gera prontuário, e no máximo um (`consulta_id UNIQUE`). |
| Consulta → Pagamento | 1 : 0..1 | Uma consulta é paga no máximo uma vez (`consulta_id UNIQUE`). |

**Consultas** é a entidade associativa que resolve o relacionamento N:N entre **Pacientes** e **Médicos**.
