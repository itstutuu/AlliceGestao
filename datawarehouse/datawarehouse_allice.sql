-- ============================================================
-- PARTE A - ESTRUTURA
-- ============================================================
BEGIN;

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS dw;

-- ------------------------------------------------------------
-- A.1  Funções auxiliares de tratamento (usadas no staging)
-- ------------------------------------------------------------

-- Nome próprio: INITCAP + preposições em minúsculo
-- ('ferraz DE vasconcelos' -> 'Ferraz de Vasconcelos').
CREATE OR REPLACE FUNCTION staging.fn_nome_proprio(p_texto TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        replace(replace(replace(replace(replace(replace(
            INITCAP(regexp_replace(TRIM(p_texto), '\s+', ' ', 'g')),
            ' De ',  ' de '),
            ' Da ',  ' da '),
            ' Do ',  ' do '),
            ' Das ', ' das '),
            ' Dos ', ' dos '),
            ' E ',   ' e '),
        '');
$$;

-- Tamanho: maiúsculo e sinônimos de "único" padronizados.
CREATE OR REPLACE FUNCTION staging.fn_tamanho(p_texto TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN UPPER(TRIM(p_texto)) IN ('UNICO', 'ÚNICO', 'U', 'UN', 'UNICA', 'ÚNICA')
            THEN 'Único'
        ELSE UPPER(TRIM(p_texto))
    END;
$$;

-- ------------------------------------------------------------
-- A.2  RAW  (tudo TEXT, espelho da origem)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS raw.estudio CASCADE;
CREATE TABLE raw.estudio (
    id_estudio    TEXT,
    id_usuario    TEXT,
    nome_fantasia TEXT,
    telefone      TEXT,
    responsavel   TEXT,
    status        TEXT,
    cnpj          TEXT,
    instagram     TEXT,
    dt_carga      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS raw.estudio_endereco CASCADE;
CREATE TABLE raw.estudio_endereco (
    id_endereco TEXT,
    id_estudio  TEXT,
    logradouro  TEXT,
    numero      TEXT,
    complemento TEXT,
    bairro      TEXT,
    cidade      TEXT,
    estado      TEXT,
    cep         TEXT,
    dt_carga    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS raw.produto CASCADE;
CREATE TABLE raw.produto (
    id_produto  TEXT,
    nome        TEXT,
    categoria   TEXT,
    status      TEXT,
    preco_venda TEXT,
    preco_custo TEXT,
    dt_carga    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS raw.produto_cores CASCADE;
CREATE TABLE raw.produto_cores (
    id_produto_cor TEXT,
    id_produto     TEXT,
    nome_cor       TEXT,
    dt_carga       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS raw.produto_variacao CASCADE;
CREATE TABLE raw.produto_variacao (
    id_variacao    TEXT,
    id_produto     TEXT,
    id_produto_cor TEXT,
    dt_carga       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS raw.estoque CASCADE;
CREATE TABLE raw.estoque (
    id_estoque        TEXT,
    id_variacao       TEXT,
    tamanho           TEXT,
    quantidade        TEXT,
    tipo_movimentacao TEXT,
    data_movimentacao TEXT,
    dt_carga          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS raw.consignacao CASCADE;
CREATE TABLE raw.consignacao (
    id_consignacao TEXT,
    id_estudio     TEXT,
    data_envio     TEXT,
    data_retorno   TEXT,
    status         TEXT,
    tipo_entrega   TEXT,
    criado_em      TEXT,
    dt_carga       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS raw.consignacao_item CASCADE;
CREATE TABLE raw.consignacao_item (
    id_item_consignado   TEXT,
    id_consignacao       TEXT,
    id_variacao          TEXT,
    tamanho              TEXT,
    quantidade_enviada   TEXT,
    quantidade_vendida   TEXT,
    quantidade_devolvida TEXT,
    preco_unitario       TEXT,
    dt_carga             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS raw.venda CASCADE;
CREATE TABLE raw.venda (
    id_venda          TEXT,
    id_estudio        TEXT,
    id_consignacao    TEXT,
    data_venda        TEXT,
    valor_total_bruto TEXT,
    desconto          TEXT,
    comissao          TEXT,
    valor_liquido     TEXT,
    status_repasse    TEXT,
    data_baixa        TEXT,
    dt_carga          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS raw.venda_item CASCADE;
CREATE TABLE raw.venda_item (
    id_venda_item  TEXT,
    id_venda       TEXT,
    id_variacao    TEXT,
    tamanho        TEXT,
    quantidade     TEXT,
    preco_unitario TEXT,
    dt_carga       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- A.3  STAGING  (tipado e tratado)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS staging.estudio CASCADE;
CREATE TABLE staging.estudio (
    id_estudio    INTEGER PRIMARY KEY,
    nome_fantasia VARCHAR(160) NOT NULL,
    cnpj          VARCHAR(14),
    responsavel   VARCHAR(160),
    instagram     VARCHAR(120),
    telefone      VARCHAR(20),
    status        VARCHAR(20)  NOT NULL,
    bairro        VARCHAR(120) NOT NULL,
    cidade        VARCHAR(120) NOT NULL,
    estado        CHAR(2)      NOT NULL,
    cep           CHAR(8)
);

-- Uma linha por VARIAÇÃO (produto + cor).
DROP TABLE IF EXISTS staging.produto CASCADE;
CREATE TABLE staging.produto (
    id_variacao    INTEGER PRIMARY KEY,
    id_produto     INTEGER       NOT NULL,
    id_produto_cor INTEGER,
    nome_produto   VARCHAR(180)  NOT NULL,
    categoria      VARCHAR(80)   NOT NULL,
    cor            VARCHAR(80)   NOT NULL,
    status         VARCHAR(20)   NOT NULL,
    preco_venda    NUMERIC(12,2) NOT NULL,
    preco_custo    NUMERIC(12,2) NOT NULL
);

DROP TABLE IF EXISTS staging.estoque_mov CASCADE;
CREATE TABLE staging.estoque_mov (
    id_estoque        BIGINT PRIMARY KEY,
    id_variacao       INTEGER     NOT NULL,
    tamanho           VARCHAR(20) NOT NULL,
    quantidade        INTEGER     NOT NULL,
    tipo_movimentacao VARCHAR(40) NOT NULL,
    data_movimentacao TIMESTAMP   NOT NULL
);

-- Cabeçalho da consignação + item.
DROP TABLE IF EXISTS staging.consignacao_item CASCADE;
CREATE TABLE staging.consignacao_item (
    id_item_consignado   INTEGER PRIMARY KEY,
    id_consignacao       INTEGER       NOT NULL,
    id_estudio           INTEGER       NOT NULL,
    id_variacao          INTEGER       NOT NULL,
    tamanho              VARCHAR(20)   NOT NULL,
    quantidade_enviada   INTEGER       NOT NULL,
    quantidade_vendida   INTEGER       NOT NULL,
    quantidade_devolvida INTEGER       NOT NULL,
    preco_unitario       NUMERIC(12,2) NOT NULL,
    status               VARCHAR(30)   NOT NULL,
    tipo_entrega         VARCHAR(30)   NOT NULL,
    criado_em            TIMESTAMP     NOT NULL,
    data_envio           TIMESTAMP,
    data_retorno         TIMESTAMP
);

-- Cabeçalho da venda + item.
DROP TABLE IF EXISTS staging.venda_item CASCADE;
CREATE TABLE staging.venda_item (
    id_venda_item     INTEGER PRIMARY KEY,
    id_venda          INTEGER       NOT NULL,
    id_estudio        INTEGER       NOT NULL,
    id_consignacao    INTEGER,
    id_variacao       INTEGER       NOT NULL,
    tamanho           VARCHAR(20)   NOT NULL,
    quantidade        INTEGER       NOT NULL,
    preco_unitario    NUMERIC(12,2) NOT NULL,
    data_venda        TIMESTAMP     NOT NULL,
    valor_total_bruto NUMERIC(12,2) NOT NULL,
    desconto          NUMERIC(12,2) NOT NULL,
    comissao          NUMERIC(12,2) NOT NULL,
    valor_liquido     NUMERIC(12,2) NOT NULL,
    status_repasse    VARCHAR(20)   NOT NULL,
    data_baixa        TIMESTAMP
);

-- ------------------------------------------------------------
-- A.4  DW - dimensões
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dw.fact_vendas       CASCADE;
DROP TABLE IF EXISTS dw.fact_consignacao  CASCADE;
DROP TABLE IF EXISTS dw.fact_estoque_mov  CASCADE;
DROP TABLE IF EXISTS dw.dim_data               CASCADE;
DROP TABLE IF EXISTS dw.dim_estudio            CASCADE;
DROP TABLE IF EXISTS dw.dim_produto            CASCADE;
DROP TABLE IF EXISTS dw.dim_tamanho            CASCADE;
DROP TABLE IF EXISTS dw.dim_status_repasse     CASCADE;
DROP TABLE IF EXISTS dw.dim_status_consignacao CASCADE;
DROP TABLE IF EXISTS dw.dim_tipo_movimentacao  CASCADE;

-- data_sk no formato YYYYMMDD (ex.: 20261116).
CREATE TABLE dw.dim_data (
    data_sk        INTEGER PRIMARY KEY,
    data_completa  DATE        NOT NULL UNIQUE,
    dia            SMALLINT    NOT NULL,
    mes            SMALLINT    NOT NULL,
    nome_mes       VARCHAR(15) NOT NULL,
    ano_mes        CHAR(7)     NOT NULL,
    trimestre      SMALLINT    NOT NULL,
    semestre       SMALLINT    NOT NULL,
    ano            SMALLINT    NOT NULL,
    dia_semana_num SMALLINT    NOT NULL,   -- 1 = segunda ... 7 = domingo (ISO)
    dia_semana     VARCHAR(15) NOT NULL,
    fim_de_semana  BOOLEAN     NOT NULL
);

CREATE TABLE dw.dim_estudio (
    estudio_sk    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    estudio_nk    INTEGER      NOT NULL UNIQUE,   -- estudio.id_estudio
    nome_fantasia VARCHAR(160) NOT NULL,
    cnpj          VARCHAR(14),
    instagram     VARCHAR(120),
    status        VARCHAR(20)  NOT NULL,
    bairro        VARCHAR(120) NOT NULL,
    cidade        VARCHAR(120) NOT NULL,
    estado        CHAR(2)      NOT NULL,
    cep           CHAR(8)
);

-- Grão: variação (produto + cor). O tamanho fica em dim_tamanho.
CREATE TABLE dw.dim_produto (
    produto_sk          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    variacao_nk         INTEGER       NOT NULL UNIQUE,   -- produto_variacao.id_variacao
    produto_nk          INTEGER       NOT NULL,          -- produto.id_produto
    nome_produto        VARCHAR(180)  NOT NULL,
    categoria           VARCHAR(80)   NOT NULL,
    cor                 VARCHAR(80)   NOT NULL,
    status              VARCHAR(20)   NOT NULL,
    preco_venda_atual   NUMERIC(12,2) NOT NULL,
    preco_custo_atual   NUMERIC(12,2) NOT NULL
);

CREATE TABLE dw.dim_tamanho (
    tamanho_sk INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tamanho    VARCHAR(20) NOT NULL UNIQUE,
    ordem      SMALLINT    NOT NULL
);

CREATE TABLE dw.dim_status_repasse (
    status_repasse_sk INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_repasse    VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE dw.dim_status_consignacao (
    status_consignacao_sk INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status                VARCHAR(30) NOT NULL,
    tipo_entrega          VARCHAR(30) NOT NULL,
    UNIQUE (status, tipo_entrega)
);

CREATE TABLE dw.dim_tipo_movimentacao (
    tipo_movimentacao_sk INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_movimentacao    VARCHAR(40) NOT NULL,
    sentido              VARCHAR(10) NOT NULL,   -- ENTRADA | SAIDA
    UNIQUE (tipo_movimentacao, sentido)
);

-- ------------------------------------------------------------
-- A.5  DW - fatos
-- ------------------------------------------------------------

-- Grão: 1 linha por item de venda.
-- desconto/comissão/valor líquido vêm do cabeçalho da venda e são
-- rateados entre os itens proporcionalmente ao valor bruto de cada item.
-- lucro_bruto = valor_liquido (parte da proprietária) - custo_total.
-- O custo usa o preco_custo ATUAL do produto (a origem não guarda histórico).
-- data_baixa_sk é NULL enquanto o repasse estiver PENDENTE.
CREATE TABLE dw.fact_vendas (
    venda_item_nk     INTEGER PRIMARY KEY,                      -- venda_item.id_venda_item
    venda_nk          INTEGER NOT NULL,                         -- dimensão degenerada
    consignacao_nk    INTEGER,                                  -- dimensão degenerada
    data_sk           INTEGER NOT NULL REFERENCES dw.dim_data(data_sk),
    data_baixa_sk     INTEGER REFERENCES dw.dim_data(data_sk),
    estudio_sk        INTEGER NOT NULL REFERENCES dw.dim_estudio(estudio_sk),
    produto_sk        INTEGER NOT NULL REFERENCES dw.dim_produto(produto_sk),
    tamanho_sk        INTEGER NOT NULL REFERENCES dw.dim_tamanho(tamanho_sk),
    status_repasse_sk INTEGER NOT NULL REFERENCES dw.dim_status_repasse(status_repasse_sk),
    quantidade        INTEGER       NOT NULL,
    preco_unitario    NUMERIC(12,2) NOT NULL,
    valor_bruto       NUMERIC(12,2) NOT NULL,
    desconto          NUMERIC(12,2) NOT NULL,
    comissao          NUMERIC(12,2) NOT NULL,
    valor_liquido     NUMERIC(12,2) NOT NULL,
    custo_total       NUMERIC(12,2) NOT NULL,
    lucro_bruto       NUMERIC(12,2) NOT NULL
);

-- Grão: 1 linha por item de consignação.
-- quantidade_em_posse só conta consignações ENVIADO/ENTREGUE/EM_CONSIGNACAO
-- (mesma regra da view vw_saldo_consignado_estudio); nas demais fica 0.
-- data_envio_sk / data_retorno_sk são NULL enquanto o evento não ocorreu.
CREATE TABLE dw.fact_consignacao (
    item_consignado_nk    INTEGER PRIMARY KEY,                  -- consignacao_item.id_item_consignado
    consignacao_nk        INTEGER NOT NULL,                     -- dimensão degenerada
    data_criacao_sk       INTEGER NOT NULL REFERENCES dw.dim_data(data_sk),
    data_envio_sk         INTEGER REFERENCES dw.dim_data(data_sk),
    data_retorno_sk       INTEGER REFERENCES dw.dim_data(data_sk),
    estudio_sk            INTEGER NOT NULL REFERENCES dw.dim_estudio(estudio_sk),
    produto_sk            INTEGER NOT NULL REFERENCES dw.dim_produto(produto_sk),
    tamanho_sk            INTEGER NOT NULL REFERENCES dw.dim_tamanho(tamanho_sk),
    status_consignacao_sk INTEGER NOT NULL REFERENCES dw.dim_status_consignacao(status_consignacao_sk),
    quantidade_enviada    INTEGER       NOT NULL,
    quantidade_vendida    INTEGER       NOT NULL,
    quantidade_devolvida  INTEGER       NOT NULL,
    quantidade_em_posse   INTEGER       NOT NULL,
    preco_unitario        NUMERIC(12,2) NOT NULL,
    valor_enviado         NUMERIC(12,2) NOT NULL,
    valor_vendido         NUMERIC(12,2) NOT NULL,
    valor_em_posse        NUMERIC(12,2) NOT NULL
);

-- Grão: 1 linha por movimentação de estoque.
-- quantidade é COM SINAL (entrada > 0, saída < 0): SUM() = saldo.
CREATE TABLE dw.fact_estoque_mov (
    estoque_nk           BIGINT PRIMARY KEY,                    -- estoque.id_estoque
    data_sk              INTEGER NOT NULL REFERENCES dw.dim_data(data_sk),
    produto_sk           INTEGER NOT NULL REFERENCES dw.dim_produto(produto_sk),
    tamanho_sk           INTEGER NOT NULL REFERENCES dw.dim_tamanho(tamanho_sk),
    tipo_movimentacao_sk INTEGER NOT NULL REFERENCES dw.dim_tipo_movimentacao(tipo_movimentacao_sk),
    data_movimentacao    TIMESTAMP NOT NULL,
    quantidade           INTEGER   NOT NULL
);

CREATE INDEX idx_fv_data     ON dw.fact_vendas(data_sk);
CREATE INDEX idx_fv_estudio  ON dw.fact_vendas(estudio_sk);
CREATE INDEX idx_fv_produto  ON dw.fact_vendas(produto_sk);
CREATE INDEX idx_fc_data     ON dw.fact_consignacao(data_criacao_sk);
CREATE INDEX idx_fc_estudio  ON dw.fact_consignacao(estudio_sk);
CREATE INDEX idx_fc_produto  ON dw.fact_consignacao(produto_sk);
CREATE INDEX idx_fe_data     ON dw.fact_estoque_mov(data_sk);
CREATE INDEX idx_fe_produto  ON dw.fact_estoque_mov(produto_sk);

COMMIT;


-- ============================================================
-- PARTE B - ETL (reexecutável)
-- ============================================================
BEGIN;

TRUNCATE TABLE
    dw.fact_vendas, dw.fact_consignacao, dw.fact_estoque_mov,
    dw.dim_data, dw.dim_estudio, dw.dim_produto, dw.dim_tamanho,
    dw.dim_status_repasse, dw.dim_status_consignacao, dw.dim_tipo_movimentacao
RESTART IDENTITY;

TRUNCATE TABLE
    staging.estudio, staging.produto, staging.estoque_mov,
    staging.consignacao_item, staging.venda_item;

TRUNCATE TABLE
    raw.estudio, raw.estudio_endereco, raw.produto, raw.produto_cores,
    raw.produto_variacao, raw.estoque, raw.consignacao,
    raw.consignacao_item, raw.venda, raw.venda_item;

-- ------------------------------------------------------------
-- B.1  EXTRAÇÃO: origem (public) -> raw   (tudo vira TEXT)
-- ------------------------------------------------------------
INSERT INTO raw.estudio (id_estudio, id_usuario, nome_fantasia, telefone, responsavel, status, cnpj, instagram)
SELECT id_estudio::TEXT, id_usuario::TEXT, nome_fantasia, telefone, responsavel, status, cnpj, instagram
FROM public.estudio;

INSERT INTO raw.estudio_endereco (id_endereco, id_estudio, logradouro, numero, complemento, bairro, cidade, estado, cep)
SELECT id_endereco::TEXT, id_estudio::TEXT, logradouro, numero, complemento, bairro, cidade, estado, cep
FROM public.estudio_endereco;

INSERT INTO raw.produto (id_produto, nome, categoria, status, preco_venda, preco_custo)
SELECT id_produto::TEXT, nome, categoria, status, preco_venda::TEXT, preco_custo::TEXT
FROM public.produto;

INSERT INTO raw.produto_cores (id_produto_cor, id_produto, nome_cor)
SELECT id_produto_cor::TEXT, id_produto::TEXT, nome_cor
FROM public.produto_cores;

INSERT INTO raw.produto_variacao (id_variacao, id_produto, id_produto_cor)
SELECT id_variacao::TEXT, id_produto::TEXT, id_produto_cor::TEXT
FROM public.produto_variacao;

INSERT INTO raw.estoque (id_estoque, id_variacao, tamanho, quantidade, tipo_movimentacao, data_movimentacao)
SELECT id_estoque::TEXT, id_variacao::TEXT, tamanho, quantidade::TEXT, tipo_movimentacao, data_movimentacao::TEXT
FROM public.estoque;

INSERT INTO raw.consignacao (id_consignacao, id_estudio, data_envio, data_retorno, status, tipo_entrega, criado_em)
SELECT id_consignacao::TEXT, id_estudio::TEXT, data_envio::TEXT, data_retorno::TEXT, status, tipo_entrega, criado_em::TEXT
FROM public.consignacao;

INSERT INTO raw.consignacao_item (id_item_consignado, id_consignacao, id_variacao, tamanho,
                                  quantidade_enviada, quantidade_vendida, quantidade_devolvida, preco_unitario)
SELECT id_item_consignado::TEXT, id_consignacao::TEXT, id_variacao::TEXT, tamanho,
       quantidade_enviada::TEXT, quantidade_vendida::TEXT, quantidade_devolvida::TEXT, preco_unitario::TEXT
FROM public.consignacao_item;

INSERT INTO raw.venda (id_venda, id_estudio, id_consignacao, data_venda, valor_total_bruto,
                       desconto, comissao, valor_liquido, status_repasse, data_baixa)
SELECT id_venda::TEXT, id_estudio::TEXT, id_consignacao::TEXT, data_venda::TEXT, valor_total_bruto::TEXT,
       desconto::TEXT, comissao::TEXT, valor_liquido::TEXT, status_repasse, data_baixa::TEXT
FROM public.venda;

INSERT INTO raw.venda_item (id_venda_item, id_venda, id_variacao, tamanho, quantidade, preco_unitario)
SELECT id_venda_item::TEXT, id_venda::TEXT, id_variacao::TEXT, tamanho, quantidade::TEXT, preco_unitario::TEXT
FROM public.venda_item;

-- ------------------------------------------------------------
-- B.2  TRATAMENTO: raw -> staging  (tipagem, limpeza, join)
-- ------------------------------------------------------------

-- Estúdio + endereço
INSERT INTO staging.estudio (id_estudio, nome_fantasia, cnpj, responsavel, instagram, telefone,
                             status, bairro, cidade, estado, cep)
SELECT
    e.id_estudio::INTEGER,
    regexp_replace(TRIM(e.nome_fantasia), '\s+', ' ', 'g'),
    NULLIF(regexp_replace(COALESCE(e.cnpj, ''), '\D', '', 'g'), ''),
    NULLIF(TRIM(e.responsavel), ''),
    CASE WHEN NULLIF(TRIM(e.instagram), '') IS NULL THEN NULL
         ELSE '@' || LOWER(LTRIM(TRIM(e.instagram), '@')) END,
    NULLIF(regexp_replace(COALESCE(e.telefone, ''), '\D', '', 'g'), ''),
    UPPER(TRIM(e.status)),
    COALESCE(staging.fn_nome_proprio(en.bairro), 'Não Informado'),
    COALESCE(staging.fn_nome_proprio(en.cidade), 'Não Informada'),
    COALESCE(NULLIF(UPPER(TRIM(en.estado)), ''), 'NI'),
    LEFT(NULLIF(regexp_replace(COALESCE(en.cep, ''), '\D', '', 'g'), ''), 8)
FROM raw.estudio e
LEFT JOIN raw.estudio_endereco en
       ON en.id_estudio::INTEGER = e.id_estudio::INTEGER
WHERE NULLIF(TRIM(e.id_estudio), '') IS NOT NULL;

-- Produto + cor + variação
INSERT INTO staging.produto (id_variacao, id_produto, id_produto_cor, nome_produto, categoria,
                             cor, status, preco_venda, preco_custo)
SELECT
    v.id_variacao::INTEGER,
    v.id_produto::INTEGER,
    NULLIF(TRIM(v.id_produto_cor), '')::INTEGER,
    regexp_replace(TRIM(p.nome), '\s+', ' ', 'g'),
    CASE WHEN UPPER(TRIM(p.categoria)) = 'MOLETON' THEN 'Moletom'   -- correção de grafia
         ELSE staging.fn_nome_proprio(p.categoria) END,
    COALESCE(staging.fn_nome_proprio(c.nome_cor), 'Sem Cor'),
    UPPER(TRIM(p.status)),
    CAST(TRIM(p.preco_venda) AS NUMERIC(12,2)),
    CAST(TRIM(p.preco_custo) AS NUMERIC(12,2))
FROM raw.produto_variacao v
JOIN raw.produto p
  ON p.id_produto::INTEGER = v.id_produto::INTEGER
LEFT JOIN raw.produto_cores c
  ON c.id_produto_cor::INTEGER = NULLIF(TRIM(v.id_produto_cor), '')::INTEGER
WHERE NULLIF(TRIM(v.id_variacao), '') IS NOT NULL;

-- Movimentações de estoque
INSERT INTO staging.estoque_mov (id_estoque, id_variacao, tamanho, quantidade,
                                 tipo_movimentacao, data_movimentacao)
SELECT
    TRIM(id_estoque)::BIGINT,
    TRIM(id_variacao)::INTEGER,
    staging.fn_tamanho(tamanho),
    TRIM(quantidade)::INTEGER,
    UPPER(TRIM(tipo_movimentacao)),
    TRIM(data_movimentacao)::TIMESTAMP
FROM raw.estoque
WHERE NULLIF(TRIM(id_estoque), '') IS NOT NULL;

-- Consignação + itens
INSERT INTO staging.consignacao_item (id_item_consignado, id_consignacao, id_estudio, id_variacao,
                                      tamanho, quantidade_enviada, quantidade_vendida,
                                      quantidade_devolvida, preco_unitario, status, tipo_entrega,
                                      criado_em, data_envio, data_retorno)
SELECT
    ci.id_item_consignado::INTEGER,
    ci.id_consignacao::INTEGER,
    c.id_estudio::INTEGER,
    ci.id_variacao::INTEGER,
    staging.fn_tamanho(ci.tamanho),
    ci.quantidade_enviada::INTEGER,
    ci.quantidade_vendida::INTEGER,
    ci.quantidade_devolvida::INTEGER,
    CAST(TRIM(ci.preco_unitario) AS NUMERIC(12,2)),
    UPPER(TRIM(c.status)),
    UPPER(TRIM(c.tipo_entrega)),
    TRIM(c.criado_em)::TIMESTAMP,
    NULLIF(TRIM(c.data_envio), '')::TIMESTAMP,
    NULLIF(TRIM(c.data_retorno), '')::TIMESTAMP
FROM raw.consignacao_item ci
JOIN raw.consignacao c
  ON c.id_consignacao::INTEGER = ci.id_consignacao::INTEGER
WHERE NULLIF(TRIM(ci.id_item_consignado), '') IS NOT NULL;

-- Venda + itens
INSERT INTO staging.venda_item (id_venda_item, id_venda, id_estudio, id_consignacao, id_variacao,
                                tamanho, quantidade, preco_unitario, data_venda, valor_total_bruto,
                                desconto, comissao, valor_liquido, status_repasse, data_baixa)
SELECT
    vi.id_venda_item::INTEGER,
    vi.id_venda::INTEGER,
    v.id_estudio::INTEGER,
    NULLIF(TRIM(v.id_consignacao), '')::INTEGER,
    vi.id_variacao::INTEGER,
    staging.fn_tamanho(vi.tamanho),
    vi.quantidade::INTEGER,
    CAST(TRIM(vi.preco_unitario) AS NUMERIC(12,2)),
    TRIM(v.data_venda)::TIMESTAMP,
    CAST(TRIM(v.valor_total_bruto) AS NUMERIC(12,2)),
    CAST(TRIM(v.desconto) AS NUMERIC(12,2)),
    CAST(TRIM(v.comissao) AS NUMERIC(12,2)),
    CAST(TRIM(v.valor_liquido) AS NUMERIC(12,2)),
    UPPER(TRIM(v.status_repasse)),
    NULLIF(TRIM(v.data_baixa), '')::TIMESTAMP
FROM raw.venda_item vi
JOIN raw.venda v
  ON v.id_venda::INTEGER = vi.id_venda::INTEGER
WHERE NULLIF(TRIM(vi.id_venda_item), '') IS NOT NULL;

-- ------------------------------------------------------------
-- B.3  CARGA DAS DIMENSÕES: staging -> dw
-- ------------------------------------------------------------

-- dim_data: calendário completo dos anos cobertos pelos dados
-- (do 1º de janeiro do menor ano ao 31 de dezembro do maior ano).
INSERT INTO dw.dim_data (data_sk, data_completa, dia, mes, nome_mes, ano_mes, trimestre,
                         semestre, ano, dia_semana_num, dia_semana, fim_de_semana)
WITH datas AS (
    SELECT data_venda::DATE AS d FROM staging.venda_item
    UNION ALL SELECT data_baixa::DATE        FROM staging.venda_item
    UNION ALL SELECT criado_em::DATE         FROM staging.consignacao_item
    UNION ALL SELECT data_envio::DATE        FROM staging.consignacao_item
    UNION ALL SELECT data_retorno::DATE      FROM staging.consignacao_item
    UNION ALL SELECT data_movimentacao::DATE FROM staging.estoque_mov
),
limites AS (
    SELECT
        MAKE_DATE(EXTRACT(YEAR FROM COALESCE(MIN(d), CURRENT_DATE))::INT, 1, 1)   AS inicio,
        MAKE_DATE(EXTRACT(YEAR FROM COALESCE(MAX(d), CURRENT_DATE))::INT, 12, 31) AS fim
    FROM datas
),
calendario AS (
    SELECT (l.inicio + g.n) AS d
    FROM limites l
    CROSS JOIN LATERAL generate_series(0, l.fim - l.inicio) AS g(n)
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d,
    EXTRACT(DAY FROM d)::SMALLINT,
    EXTRACT(MONTH FROM d)::SMALLINT,
    (ARRAY['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho',
           'Agosto','Setembro','Outubro','Novembro','Dezembro'])[EXTRACT(MONTH FROM d)::INT],
    TO_CHAR(d, 'YYYY-MM'),
    EXTRACT(QUARTER FROM d)::SMALLINT,
    CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END::SMALLINT,
    EXTRACT(YEAR FROM d)::SMALLINT,
    EXTRACT(ISODOW FROM d)::SMALLINT,
    (ARRAY['Segunda-feira','Terça-feira','Quarta-feira','Quinta-feira',
           'Sexta-feira','Sábado','Domingo'])[EXTRACT(ISODOW FROM d)::INT],
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM calendario
ORDER BY d;

INSERT INTO dw.dim_estudio (estudio_nk, nome_fantasia, cnpj, instagram, status, bairro, cidade, estado, cep)
SELECT id_estudio, nome_fantasia, cnpj, instagram, status, bairro, cidade, estado, cep
FROM staging.estudio
ORDER BY id_estudio;

INSERT INTO dw.dim_produto (variacao_nk, produto_nk, nome_produto, categoria, cor, status,
                            preco_venda_atual, preco_custo_atual)
SELECT id_variacao, id_produto, nome_produto, categoria, cor, status, preco_venda, preco_custo
FROM staging.produto
ORDER BY id_variacao;

INSERT INTO dw.dim_tamanho (tamanho, ordem)
SELECT t.tamanho,
       CASE t.tamanho
            WHEN 'PP' THEN 1 WHEN 'P' THEN 2 WHEN 'M' THEN 3
            WHEN 'G'  THEN 4 WHEN 'GG' THEN 5 WHEN 'XG' THEN 6
            WHEN 'Único' THEN 9
            ELSE 8
       END
FROM (
    SELECT tamanho FROM staging.estoque_mov
    UNION
    SELECT tamanho FROM staging.consignacao_item
    UNION
    SELECT tamanho FROM staging.venda_item
) t
ORDER BY 2, 1;

INSERT INTO dw.dim_status_repasse (status_repasse)
SELECT DISTINCT status_repasse FROM staging.venda_item ORDER BY 1;

INSERT INTO dw.dim_status_consignacao (status, tipo_entrega)
SELECT DISTINCT status, tipo_entrega FROM staging.consignacao_item ORDER BY 1, 2;

INSERT INTO dw.dim_tipo_movimentacao (tipo_movimentacao, sentido)
SELECT DISTINCT tipo_movimentacao,
       CASE WHEN quantidade > 0 THEN 'ENTRADA' ELSE 'SAIDA' END
FROM staging.estoque_mov
ORDER BY 1, 2;

-- ------------------------------------------------------------
-- B.4  CARGA DOS FATOS: staging -> dw  (lookup das chaves _sk)
-- ------------------------------------------------------------

-- fact_vendas
INSERT INTO dw.fact_vendas (venda_item_nk, venda_nk, consignacao_nk, data_sk, data_baixa_sk,
                            estudio_sk, produto_sk, tamanho_sk, status_repasse_sk,
                            quantidade, preco_unitario, valor_bruto, desconto, comissao,
                            valor_liquido, custo_total, lucro_bruto)
WITH base AS (
    SELECT vi.*,
           vi.quantidade * vi.preco_unitario AS bruto_item,
           SUM(vi.quantidade * vi.preco_unitario) OVER (PARTITION BY vi.id_venda) AS bruto_venda,
           COUNT(*) OVER (PARTITION BY vi.id_venda) AS qtd_itens
    FROM staging.venda_item vi
),
rateio AS (
    SELECT b.*,
           CASE WHEN b.bruto_venda > 0 THEN b.bruto_item / b.bruto_venda
                ELSE 1.0 / b.qtd_itens END AS participacao
    FROM base b
)
SELECT
    r.id_venda_item,
    r.id_venda,
    r.id_consignacao,
    TO_CHAR(r.data_venda, 'YYYYMMDD')::INTEGER,
    TO_CHAR(r.data_baixa, 'YYYYMMDD')::INTEGER,            -- NULL se ainda não houve baixa
    de.estudio_sk,
    dp.produto_sk,
    dt.tamanho_sk,
    ds.status_repasse_sk,
    r.quantidade,
    r.preco_unitario,
    ROUND(r.bruto_item, 2),
    ROUND(r.desconto      * r.participacao, 2),
    ROUND(r.comissao      * r.participacao, 2),
    ROUND(r.valor_liquido * r.participacao, 2),
    ROUND(r.quantidade * dp.preco_custo_atual, 2),
    ROUND(r.valor_liquido * r.participacao, 2) - ROUND(r.quantidade * dp.preco_custo_atual, 2)
FROM rateio r
JOIN dw.dim_estudio         de ON de.estudio_nk     = r.id_estudio
JOIN dw.dim_produto         dp ON dp.variacao_nk    = r.id_variacao
JOIN dw.dim_tamanho         dt ON dt.tamanho        = r.tamanho
JOIN dw.dim_status_repasse  ds ON ds.status_repasse = r.status_repasse;

-- fact_consignacao
INSERT INTO dw.fact_consignacao (item_consignado_nk, consignacao_nk, data_criacao_sk, data_envio_sk,
                                 data_retorno_sk, estudio_sk, produto_sk, tamanho_sk,
                                 status_consignacao_sk, quantidade_enviada, quantidade_vendida,
                                 quantidade_devolvida, quantidade_em_posse, preco_unitario,
                                 valor_enviado, valor_vendido, valor_em_posse)
WITH base AS (
    SELECT ci.*,
           CASE WHEN ci.status IN ('ENVIADO', 'ENTREGUE', 'EM_CONSIGNACAO')
                THEN ci.quantidade_enviada - ci.quantidade_vendida - ci.quantidade_devolvida
                ELSE 0 END AS qtd_posse
    FROM staging.consignacao_item ci
)
SELECT
    b.id_item_consignado,
    b.id_consignacao,
    TO_CHAR(b.criado_em,     'YYYYMMDD')::INTEGER,
    TO_CHAR(b.data_envio,    'YYYYMMDD')::INTEGER,
    TO_CHAR(b.data_retorno,  'YYYYMMDD')::INTEGER,
    de.estudio_sk,
    dp.produto_sk,
    dt.tamanho_sk,
    dsc.status_consignacao_sk,
    b.quantidade_enviada,
    b.quantidade_vendida,
    b.quantidade_devolvida,
    b.qtd_posse,
    b.preco_unitario,
    ROUND(b.quantidade_enviada * b.preco_unitario, 2),
    ROUND(b.quantidade_vendida * b.preco_unitario, 2),
    ROUND(b.qtd_posse          * b.preco_unitario, 2)
FROM base b
JOIN dw.dim_estudio            de  ON de.estudio_nk  = b.id_estudio
JOIN dw.dim_produto            dp  ON dp.variacao_nk = b.id_variacao
JOIN dw.dim_tamanho            dt  ON dt.tamanho     = b.tamanho
JOIN dw.dim_status_consignacao dsc ON dsc.status = b.status AND dsc.tipo_entrega = b.tipo_entrega;

-- fact_estoque_mov
INSERT INTO dw.fact_estoque_mov (estoque_nk, data_sk, produto_sk, tamanho_sk, tipo_movimentacao_sk,
                                 data_movimentacao, quantidade)
SELECT
    em.id_estoque,
    TO_CHAR(em.data_movimentacao, 'YYYYMMDD')::INTEGER,
    dp.produto_sk,
    dt.tamanho_sk,
    dtm.tipo_movimentacao_sk,
    em.data_movimentacao,
    em.quantidade
FROM staging.estoque_mov em
JOIN dw.dim_produto           dp  ON dp.variacao_nk = em.id_variacao
JOIN dw.dim_tamanho           dt  ON dt.tamanho     = em.tamanho
JOIN dw.dim_tipo_movimentacao dtm ON dtm.tipo_movimentacao = em.tipo_movimentacao
                                 AND dtm.sentido = CASE WHEN em.quantidade > 0 THEN 'ENTRADA' ELSE 'SAIDA' END;

COMMIT;

ANALYZE;


-- ============================================================
-- PARTE C - CONFERÊNCIAS DA CARGA
-- ============================================================

-- C.1  Contagem de linhas em cada etapa (origem = raw = staging = dw).
SELECT 'venda_item' AS entidade,
       (SELECT COUNT(*) FROM public.venda_item)       AS origem,
       (SELECT COUNT(*) FROM raw.venda_item)          AS raw,
       (SELECT COUNT(*) FROM staging.venda_item)      AS staging,
       (SELECT COUNT(*) FROM dw.fact_vendas)          AS dw
UNION ALL
SELECT 'consignacao_item',
       (SELECT COUNT(*) FROM public.consignacao_item),
       (SELECT COUNT(*) FROM raw.consignacao_item),
       (SELECT COUNT(*) FROM staging.consignacao_item),
       (SELECT COUNT(*) FROM dw.fact_consignacao)
UNION ALL
SELECT 'estoque',
       (SELECT COUNT(*) FROM public.estoque),
       (SELECT COUNT(*) FROM raw.estoque),
       (SELECT COUNT(*) FROM staging.estoque_mov),
       (SELECT COUNT(*) FROM dw.fact_estoque_mov)
UNION ALL
SELECT 'estudio',
       (SELECT COUNT(*) FROM public.estudio),
       (SELECT COUNT(*) FROM raw.estudio),
       (SELECT COUNT(*) FROM staging.estudio),
       (SELECT COUNT(*) FROM dw.dim_estudio)
UNION ALL
SELECT 'produto_variacao',
       (SELECT COUNT(*) FROM public.produto_variacao),
       (SELECT COUNT(*) FROM raw.produto_variacao),
       (SELECT COUNT(*) FROM staging.produto),
       (SELECT COUNT(*) FROM dw.dim_produto);

-- C.2  Totais financeiros: origem x DW (as diferenças devem ser 0,00;
--      pequenas diferenças de centavos podem vir do rateio por item).
SELECT
    (SELECT SUM(valor_total_bruto) FROM public.venda
      WHERE id_venda IN (SELECT id_venda FROM public.venda_item)) AS bruto_origem,
    (SELECT SUM(valor_bruto) FROM dw.fact_vendas)                 AS bruto_dw,
    (SELECT SUM(comissao) FROM public.venda
      WHERE id_venda IN (SELECT id_venda FROM public.venda_item)) AS comissao_origem,
    (SELECT SUM(comissao) FROM dw.fact_vendas)                    AS comissao_dw,
    (SELECT SUM(valor_liquido) FROM public.venda
      WHERE id_venda IN (SELECT id_venda FROM public.venda_item)) AS liquido_origem,
    (SELECT SUM(valor_liquido) FROM dw.fact_vendas)               AS liquido_dw;

-- C.3  Linhas por dimensão.
SELECT 'dim_data' AS dimensao, COUNT(*) AS linhas FROM dw.dim_data
UNION ALL SELECT 'dim_estudio',            COUNT(*) FROM dw.dim_estudio
UNION ALL SELECT 'dim_produto',            COUNT(*) FROM dw.dim_produto
UNION ALL SELECT 'dim_tamanho',            COUNT(*) FROM dw.dim_tamanho
UNION ALL SELECT 'dim_status_repasse',     COUNT(*) FROM dw.dim_status_repasse
UNION ALL SELECT 'dim_status_consignacao', COUNT(*) FROM dw.dim_status_consignacao
UNION ALL SELECT 'dim_tipo_movimentacao',  COUNT(*) FROM dw.dim_tipo_movimentacao;


-- ============================================================
-- PARTE D - CONSULTAS ANALÍTICAS
-- ============================================================

-- D.1  CUBE: receita por estúdio x categoria (todas as combinações de totais).
SELECT
    CASE WHEN GROUPING(e.nome_fantasia) = 1 THEN 'TODOS' ELSE e.nome_fantasia END AS estudio,
    CASE WHEN GROUPING(p.categoria)     = 1 THEN 'TODAS' ELSE p.categoria     END AS categoria,
    SUM(f.quantidade)              AS pecas,
    SUM(f.valor_bruto)::NUMERIC(12,2)   AS receita_bruta,
    SUM(f.valor_liquido)::NUMERIC(12,2) AS receita_proprietaria
FROM dw.fact_vendas f
JOIN dw.dim_estudio e ON e.estudio_sk = f.estudio_sk
JOIN dw.dim_produto p ON p.produto_sk = f.produto_sk
GROUP BY CUBE (e.nome_fantasia, p.categoria)
ORDER BY e.nome_fantasia NULLS LAST, p.categoria NULLS LAST;

-- D.2  ROLLUP: receita por ano > mês, com subtotal anual e total geral.
SELECT
    CASE WHEN GROUPING(d.ano) = 1 THEN 'TODOS' ELSE d.ano::TEXT END AS ano,
    CASE WHEN GROUPING(d.mes) = 1 THEN 'TODOS' ELSE d.nome_mes  END AS mes,
    COUNT(*)                       AS itens_vendidos,
    SUM(f.valor_bruto)::NUMERIC(12,2)   AS receita_bruta,
    SUM(f.comissao)::NUMERIC(12,2)      AS comissao_estudios,
    SUM(f.lucro_bruto)::NUMERIC(12,2)   AS lucro_bruto
FROM dw.fact_vendas f
JOIN dw.dim_data d ON d.data_sk = f.data_sk
GROUP BY ROLLUP (d.ano, (d.mes, d.nome_mes))
ORDER BY d.ano NULLS LAST, d.mes NULLS LAST;

-- D.3  Dias da semana mais fortes.
SELECT
    d.dia_semana,
    d.fim_de_semana,
    COUNT(*)                          AS itens_vendidos,
    SUM(f.valor_bruto)::NUMERIC(12,2) AS receita_bruta,
    ROUND(AVG(f.valor_bruto), 2)      AS ticket_medio_item
FROM dw.fact_vendas f
JOIN dw.dim_data d ON d.data_sk = f.data_sk
GROUP BY d.dia_semana_num, d.dia_semana, d.fim_de_semana
ORDER BY receita_bruta DESC;

-- D.4  Giro da consignação por estúdio (percentual vendido do que foi enviado).
SELECT
    e.nome_fantasia                       AS estudio,
    SUM(fc.quantidade_enviada)            AS enviadas,
    SUM(fc.quantidade_vendida)            AS vendidas,
    SUM(fc.quantidade_devolvida)          AS devolvidas,
    SUM(fc.quantidade_em_posse)           AS em_posse,
    ROUND(100.0 * SUM(fc.quantidade_vendida)
          / NULLIF(SUM(fc.quantidade_enviada), 0), 1) AS pct_vendido
FROM dw.fact_consignacao fc
JOIN dw.dim_estudio            e ON e.estudio_sk            = fc.estudio_sk
JOIN dw.dim_status_consignacao s ON s.status_consignacao_sk = fc.status_consignacao_sk
WHERE s.status IN ('ENVIADO', 'ENTREGUE', 'EM_CONSIGNACAO')
GROUP BY e.nome_fantasia
ORDER BY pct_vendido DESC, enviadas DESC;

-- D.5  ROLLUP: saldo de estoque por categoria > tamanho.
SELECT
    CASE WHEN GROUPING(p.categoria) = 1 THEN 'TODAS' ELSE p.categoria END AS categoria,
    CASE WHEN GROUPING(t.tamanho)   = 1 THEN 'TODOS' ELSE t.tamanho   END AS tamanho,
    SUM(m.quantidade) AS saldo
FROM dw.fact_estoque_mov m
JOIN dw.dim_produto p ON p.produto_sk = m.produto_sk
JOIN dw.dim_tamanho t ON t.tamanho_sk = m.tamanho_sk
GROUP BY ROLLUP (p.categoria, (t.ordem, t.tamanho))
ORDER BY p.categoria NULLS LAST, t.ordem NULLS LAST;
