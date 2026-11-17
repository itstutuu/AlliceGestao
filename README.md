# Allice Gestão

## Equipe
| Integrante | RA |
|---|---:|
| Arthur Carvalho Araujo | 2041382521031 |
| Beatris Franklin Dantas Rodrigues | 2041382521021 |
| Camila Aparecida Leves Maneze | 2041382521027 |
| Gabriela Edmundo de Araújo | 2041382521025 |

Sistema desenvolvido no **Projeto Integrador III** da **FATEC Ipiranga – Pastor Enéas Tognini**, com o objetivo de apoiar a gestão da marca **Desejos de Allice**.

A aplicação centraliza informações de **produtos, estoque, estúdios parceiros, consignações, vendas e repasses**, facilitando o acompanhamento da circulação das peças entre a marca e os estúdios parceiros.

> Projeto acadêmico — 2026.

---

## Sobre o projeto

A Desejos de Allice trabalha com peças de *pole wear* e utiliza o modelo de consignação em estúdios parceiros. O Allice Gestão foi pensado para organizar esse processo e reduzir controles descentralizados, permitindo registrar e consultar as principais informações da operação comercial.

Entre os objetivos do sistema estão:

- cadastrar e consultar produtos;
- controlar estoque por produto, cor e tamanho;
- cadastrar e consultar estúdios parceiros;
- registrar remessas de peças em consignação;
- acompanhar peças enviadas, vendidas e devolvidas;
- registrar vendas consignadas e suas comissões;
- acompanhar repasses dos estúdios;
- consultar movimentações e saldos de estoque;
- disponibilizar informações para indicadores e análises gerenciais.

---

## Funcionalidades principais

### Produtos

- Cadastro e edição de produtos;
- Cadastro de cores e variações;
- Controle de tamanho e quantidade em estoque;
- Registro de imagens dos produtos;
- Ativação e desativação de produtos.

### Estúdios parceiros

- Cadastro de estúdios;
- Cadastro de endereço e informações de contato;
- Associação do estúdio a um usuário do sistema;
- Consulta das peças atualmente consignadas em cada estúdio.

### Consignações

O fluxo de uma remessa pode passar por estados como:

```text
EM_SEPARACAO -> ENVIADO -> ENTREGUE
```

O sistema registra:

- estúdio de destino;
- data de envio;
- produtos, variações e tamanhos enviados;
- quantidade enviada;
- quantidade vendida;
- quantidade devolvida;
- situação atual da consignação.

### Vendas e repasses

Quando uma peça consignada é vendida, o sistema registra a venda e calcula os valores financeiros relacionados à operação.

Na configuração atual do projeto, a regra utilizada é:

```text
30% -> comissão do estúdio
70% -> valor líquido da proprietária
```

Os repasses podem ser acompanhados por status, permitindo identificar valores pendentes e pagos.

### Estoque

O estoque é controlado por movimentações, preservando o histórico da operação. Exemplos:

```text
ENTRADA_INICIAL
SAIDA_CONSIGNACAO
DEVOLUCAO_CANCELAMENTO
AJUSTE_ENTRADA
AJUSTE_SAIDA
```

O saldo é calculado a partir das movimentações registradas.

---

## Tecnologias utilizadas

### Backend

- Python
- Flask
- Flask-CORS
- Psycopg2
- Python Dotenv

### Banco de dados

- PostgreSQL
- PL/pgSQL
- Views
- Functions
- Triggers
- Stored Procedures
- Cursores

### Frontend

- HTML5
- CSS
- JavaScript

---

## Estrutura principal do banco

O modelo relacional utilizado pelo sistema contém, entre outras, as seguintes entidades:

```text
usuario
  |
  +-- estudio
       +-- estudio_endereco
       +-- consignacao
            +-- consignacao_item

produto
  +-- produto_cores
  +-- produto_variacao
  +-- produto_imagens
  +-- estoque

venda
  +-- venda_item
```

A entidade `produto_variacao` complementa o modelo acadêmico para permitir que o aplicativo identifique corretamente combinações de **produto + cor + tamanho**.

---

## Estrutura dos arquivos

```text
AlliceGestao_Banco_Corrigido/
|
|-- index.html
|-- server.py
|-- README.md
|-- README_CORRECAO_BANCO.md
|-- 07_smoke_test_api.py
|
+-- database/
    |-- 01_schema_der_fiel.sql
    |-- 02_schema_recomendado_app.sql
    |-- 03_seed_recomendado.sql
    |-- 04_testes_integridade.sql
    |-- 05_seed_demo_completo.sql
    +-- 06_testes_funcionais.sql
```

### Scripts SQL

| Arquivo | Finalidade |
|---|---|
| `01_schema_der_fiel.sql` | Versão próxima ao DER acadêmico |
| `02_schema_recomendado_app.sql` | Estrutura recomendada para executar o sistema |
| `03_seed_recomendado.sql` | Dados mínimos para desenvolvimento |
| `04_testes_integridade.sql` | Verificações básicas de integridade |
| `05_seed_demo_completo.sql` | Massa de dados de demonstração |
| `06_testes_funcionais.sql` | Testes funcionais diretamente no PostgreSQL |

---

## Como executar o projeto

### 1. Criar o banco de dados

No PostgreSQL/pgAdmin, crie um banco chamado:

```text
AlliceGestaoDB
```

Conecte-se ao banco e execute, nesta ordem:

```text
database/02_schema_recomendado_app.sql
database/03_seed_recomendado.sql
```

Para carregar uma base de demonstração mais completa, execute também:

```text
database/05_seed_demo_completo.sql
```

---

### 2. Preparar o ambiente Python

Crie um ambiente virtual:

```bash
python -m venv .venv
```

No Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

Instale as dependências principais:

```bash
pip install Flask Flask-Cors psycopg2-binary python-dotenv
```

---

### 3. Configurar a conexão

Crie um arquivo `.env` na raiz do projeto:

```env
DATABASE_URL=postgresql://postgres:SUA_SENHA@localhost:5432/AlliceGestaoDB

EMAIL_REMETENTE=
EMAIL_SENHA_APP=
EMAIL_DESTINO=
```

> O arquivo `.env` pode conter credenciais e não deve ser enviado para repositórios públicos.

---

### 4. Iniciar o servidor

```bash
python server.py
```

Por padrão, o backend do projeto pode ser validado pelo endpoint:

```text
http://localhost:5002/api/health
```

Uma resposta esperada é semelhante a:

```json
{
  "status": "ok",
  "database_connection": "ok",
  "engine": "PostgreSQL"
}
```

---

## Login para desenvolvimento

Após executar o seed de desenvolvimento:

```text
E-mail: admin@allice.local
Senha: TroqueEstaSenha123!
```

> Essas credenciais são destinadas apenas ao ambiente local de desenvolvimento.

---

## Dados de demonstração

O arquivo:

```text
database/05_seed_demo_completo.sql
```

cria uma massa de dados fictícia com produtos, estoque, estúdios, consignações, vendas e repasses.

Entre os estúdios fictícios utilizados nos testes estão:

- Movimento Vertical Studio;
- Aérea Pole Studio;
- Pole Art Lab;
- Corpo Livre Pole;
- Giro Studio.

Os registros são exclusivamente demonstrativos e não representam dados reais das empresas ou parceiros da Desejos de Allice.

---

## Testes

### Testes do banco de dados

Execute no pgAdmin:

```text
database/06_testes_funcionais.sql
```

O script verifica, entre outros pontos:

- usuários e autenticação por consulta;
- produtos, cores e variações;
- estoque e saldo;
- estúdios e endereços;
- consignações;
- vendas e comissões;
- repasses;
- views;
- functions;
- triggers;
- stored procedure com cursor;
- operações CRUD de teste com `ROLLBACK`.

### Smoke test da API

Com o servidor em execução:

```bash
python 07_smoke_test_api.py
```

O script percorre um fluxo integrado de cadastro, edição, consignação, venda, repasse, dashboard e validações de erro.

---

## Requisitos funcionais trabalhados

O projeto foi desenvolvido considerando os seguintes requisitos principais:

| ID | Requisito |
|---|---|
| RF01 | Cadastrar e consultar produtos com tamanho, preço e quantidade inicial |
| RF02 | Cadastrar e consultar estúdios parceiros |
| RF03 | Registrar remessas de peças para um estúdio |
| RF04 | Registrar venda consignada e comissão vinculada ao estúdio |
| RF05 | Registrar devoluções/ajustes e atualizar o saldo |
| RF06 | Consultar saldos e movimentações de produtos |
| RF07 | Consolidar registros para utilização analítica |
| RF08 | Exibir indicadores de vendas e estoque |
| RF09 | Permitir filtros dos indicadores e identificar atualização dos dados |

---

## Contexto acadêmico

O Allice Gestão dá continuidade a uma aplicação web desenvolvida em etapa anterior do Projeto Integrador II. 
O projeto contempla conteúdos relacionados a diferentes disciplinas, especialmente **Laboratório de Programação I**, **Programação em Banco de Dados I**, **Estatística e Probabilidade II**, **Inteligência Artificial II**, **Gestão de Projetos** e **Inteligência Competitiva**.

---

## Observações

Este repositório possui finalidade acadêmica. Dados presentes nos scripts de demonstração são fictícios e existem apenas para testes do sistema.

Antes de utilizar o projeto fora do ambiente acadêmico, recomenda-se revisar principalmente:

- armazenamento seguro de senhas com hash;
- regras de autenticação e autorização;
- proteção das credenciais do banco;
- validação dos dados recebidos pela API;
- tratamento de erros e logs;
- estratégia de backup do PostgreSQL;
- regras financeiras e percentuais de comissão utilizadas em produção.

---

## Licença e uso

Projeto acadêmico desenvolvido pela equipe **Allice Gestão** para o **Projeto Integrador III da FATEC Ipiranga**.
