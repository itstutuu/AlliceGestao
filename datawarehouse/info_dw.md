# ALLICE GESTÃO - DATA WAREHOUSE 📆 (raw -> staging -> dw)
- PostgreSQL

---

## Estrutura

### ⭐ **Star Schema**: (constelação de fatos, dimensões compartilhadas):

| Fato | Grão |
|--- | --- |
| fact_vendas | 1 item de venda |
| fact_consignacao | 1 item de consignação |
| fact_estoque_mov | 1 movimentação de estoque |

### Dimensões

- dim_data
- dim_estudio 
- dim_produto (produto + cor)
- dim_tamanho
- dim_status_repasse
- dim_status_consignacao
- dim_tipo_movimentacao

### Dados

Origem (OLTP): tabelas do schema public.

Destino (DW):  schemas raw, staging e dw no mesmo banco.

### Camadas:

  raw     : cópia fiel da origem, TODAS as colunas em TEXT (+ dt_carga). Sem tratamento nenhum.

  staging : dados tipados e tratados (TRIM, caixa, dígitos, nulos, padronização), já "achatados" (join).

  dw      : modelo estrela (dimensões + fatos) com chaves substitutas (_sk) e chaves naturais (_nk).

### Segurança: a tabela usuario (senha) NÃO é copiada para o DW.

---

## Etapas 

### `datawarehouse_allice.sql` - Pré-requisito: banco AlliceGestaoDB já criado com:

→ 01_schema_recomendado_app.sql (estrutura)

→ 02_postgresql_seed_novo.sql (dados)

→ 03_carregar_csv.sql (histórico sintético, opcional)

### Execução

Parte A: cria schemas, tabelas e funções de apoio. Roda uma vez

Parte B: é o ETL completo, com TRUNCATE e carga. Pode rodar de novo sempre que quiser atualizar o DW.

Parte C: conferências da carga.

Parte D: consultas analíticas com ROLLUP e CUBE.

============================================================================================