# Sales Export

Nessa área você vai encontrar documentação sobre como utilizar as APIs de exportação dos dados de venda. Nesse momento temos alguns scripts de exemplo, escritos em bash, pra facilitar o entendimento de como as APIs funcionam, mas uma vez que estamos falando de APIs escritas em REST, você pode utilizar qualquer linguagem de programação que tenha suporte a requisições HTTP.

## Entidades

Suportamos 5 entidades nesse momento:
- **filial**: busca as filiais da Tele RIO com seu status, código, cnpj, endereço, entre outros dados.
- **funcionario**: busca todos os funcionarios, ativos ou inativos, com seu status, código, cpf, nome, entre outros dados.
- **saldo_produto**: busca o saldo de produtos por filial, com seu status, código, nome, entre outros dados.
- **venda**: busca as vendas realizadas, sumarizadas pelo produto, suas quantidades, filial, vendedor, entre outros dados.
- **consolidado_venda**: busca a quantidade total vendida de cada sku em um mês, por data de venda ou de faturamento.

Além das entidades, a query especial **docs** devolve o catálogo das queries disponíveis, com seus filtros e colunas. Veja a seção [Catálogo de queries](#catálogo-de-queries-docs).


## Autenticação
Ela é feita por uma ApiKey que você receberá por e-mail assim que sua conta for criada. Tal ApiKey fica associada às suas marcas, de forma que você só consegue buscar dados de saldo em estoque e vendas de produtos que nosso comercial associou à sua conta.

## Endpoints
Também serão enviados por e-mail assim que sua conta for criada.

## Quotas
A API tem um limite de uso de 500 requisições por dia, sendo que é possível fazer até 10 requisições por segundo, sendo até 10 simultaneas. Caso você ultrapasse esse limite, você receberá um erro 429, indicando que o limite de uso foi excedido. Nesse caso, você deve aguardar até o dia seguinte para fazer novas requisições.

Se você ainda está em fase de desenvolvimento e testes, e tem excedido sua quota de forma recorrente, impedindo seu avanço, peça nossa ajuda, que buscaremos uma solução temporária.


## Catálogo de queries (docs)
A query `docs` devolve a documentação viva da API: quais queries existem, quais filtros cada uma aceita (tipo, formato e forma de comparação), quais regras se aplicam entre os filtros e quais colunas vêm no resultado. Use-a para descobrir queries novas sem depender deste documento.

Diferente das outras queries, `docs` **não é assíncrona**: não executa nada no Athena, não tem `query_exec_id` nem `query_status`, e a resposta vem na própria chamada. Ela exige a mesma ApiKey das demais queries e conta na quota diária de requisições.

Payload para o catálogo completo:
```json
{
    "query": "docs"
}
```
Payload para a documentação de uma única query (a resposta tem o mesmo formato, com uma só query na lista):
```json
{
    "query": "docs",
    "filtros": { "query": "venda" }
}
```
Se o nome informado em `filtros.query` não existir, a resposta é um erro 400 com a mensagem `Query inválida.`. O script ./bash/docs.sh mostra os dois usos.

Resposta (resumida):
```json
{
  "catalog_version": "a1b2c3d4",
  "queries": [
    {
      "id": "venda",
      "label": "Vendas",
      "description": "Itens vendidos por dia, produto, filial e vendedor, desde 01/01/2025.",
      "category": "vendas",
      "filters": [
        {
          "name": "dt_emissao",
          "label": "Data de emissão",
          "type": "date_range",
          "format": "YYYYMMDD",
          "params": { "exact": "dt_emissao", "start": "dt_emissao_start", "end": "dt_emissao_end" },
          "required": false
        },
        {
          "name": "codigo_produto",
          "label": "Código do produto",
          "type": "string",
          "match": "exact",
          "required": false
        }
      ],
      "rules": [],
      "output": {
        "columns": [
          { "name": "dt_emissao", "type": "string" },
          { "name": "quantidade", "type": "number" }
        ],
        "page_size": 100
      }
    }
  ]
}
```
Campos de cada query:
- `id`: valor a enviar no campo `query` das requisições.
- `label`, `description`, `category`: textos descritivos.
- `filters`: filtros aceitos no objeto `filtros`.
- `rules`: regras que envolvem mais de um filtro.
- `output`: colunas do resultado (`columns`, com `name` e `type`), tamanho de página (`page_size`) e, quando existir, uma observação (`note`).

Campos de cada filtro:
- `name`: nome do parâmetro em `filtros`. Para `date_range`, use os nomes de `params`.
- `label` e `description`: textos descritivos. A `description` aparece quando há algo a mais a saber, como a comparação sem diferenciar maiúsculas e minúsculas.
- `type`: `string`, `date`, `date_range`, `month` ou `datetime`. Os tipos `number`, `boolean` e `enum` fazem parte do formato, mas nenhuma query os usa hoje.
- `format`: formato do valor, `YYYYMMDD` (data), `YYYYMM` (mês) ou `YYYY-MM-DD HH:MM:SS` (timestamp). Todos os valores são enviados como texto.
- `match`: como o valor é comparado, para filtros `string` e `datetime`:

| match | Comparação |
|-------|------------|
| `exact` | igualdade (`=`) |
| `contains` | o texto contém o valor informado |
| `suffix` | o texto termina com o valor informado |
| `gte` | maior ou igual ao valor informado (`>=`) |

- `required`: indica se o filtro é obrigatório.
- `default`: valor aplicado pelo servidor quando o filtro é omitido. `"today"` é a data de hoje no fuso -03:00.
- `params` (só em `date_range`): nomes dos parâmetros para data exata (`exact`), início (`start`) e fim (`end`) do intervalo.

Regras (`rules`): o tipo `any_of_required` indica que ao menos um dos filtros listados em `filters` deve ser informado, senão a resposta é um erro 400 com a `message` da regra. Exemplo: `consolidado_venda` exige `mes_emissao` ou `mes_faturamento`.

`catalog_version` é um código curto calculado sobre o catálogo completo, igual nos dois modos de consulta. Ele só muda quando o catálogo muda. Guarde o valor e refaça a consulta ao catálogo apenas quando ele for diferente.

Todos os filtros são opcionais e combinados com AND, salvo o que `required` e `rules` indicarem.

## Tabelas
### FILIAL
Faça uma carga inicial completa das filiais e cargas recorrentes semanais, para buscar possíveis atualizações. Na tabela das filiais, temos uma coluna com o TIMESTAMP em que foi feita a última atualização. Nas buscas semanais, basta pesquisar pelas filiais que tenham tal data maior ou igual a maior data que você tem na sua base. Dessa forma, você trará apenas os dados incrementais, para UPSERT local. No script ./bash/tabela-filial.sh, é possível ver exemplos de como fazer a carga FULL e como fazer tais cargas incrementais.
  
Payload de exemplo para busca filtrada:
```json
{
    "query": "filial",
    "filtros": {
        "cod_filial": "0199",      // string
        "statusfilial": "ATIVA",   // string
        "regional": "Regional X",  // string
        "cidade": "nome da cidade",    // string
        "ultima_atualizacao": "2023-10-01 00:00:00"    // timestamp
    }
}
```

### FUNCIONARIO
Faça carga inicial completa dos funcionários e cargas incrementais semanais e diárias. A carga semanal pode ser feita buscando funcionários admitidos ou demitidos desde sua última carga semanal. Tal atualização garantirá que os novos colaboradores e colaboradores desligados sejam atualizados na sua base local. Diariamente, quando você fizer a carga das vendas, sugerimos que pra todos os códigos de vendedores que sejam listados, você faça a busca por ele nessa API. Isso vai garantir que as movimentações de colaboradores entre filiais, ou mudanças de cargo sejam atualizadas na sua base local. No script ./bash/tabela-funcionario.sh, é possível ver exemplos de como fazer a carga FULL e como fazer tais cargas incrementais.
  
Payload de exemplo para busca filtrada:
```json
{
    "query": "funcionario",
    "filtros": {
        "matricula": "009999",         // string
        "nome": "JOAO DA SILVA",       // string
        "cod_filial": "0199",          // string
        "regional": "Regional X",      // string
        "documento": "12345678901",    // string
        "dt_nascimento": "0106",       // string
        "dt_admissao": "20230101",     // string YYYYMMDD
        "dt_demissao": "20240101",     // string YYYYMMDD
        "cargo": "VENDEDOR",           // string
        "status_funcionario": "ATIVO"  // string
    }
}
```

##### ***ATENÇÃO***
A associação dos funcionários às filiais em que trabalha pode ser obtida pelo código da filial. Essa associação funciona com todos os cargos, menos no caso dos supervisores, pois a associação deles não é com uma única filial, mas sim pela regional que eles supervisionam. Nesses casos, a identificação das filiais associadas ao supervisor envolve a listagem das filiais, que possui a identificação da regional, e a listagem dos supervisores, que também possuem a identificação da regional. Através dessa informação você conseguirá associar os supervisores às filiais que eles supervisionam.

### SALDO_PRODUTO
Faça a carga inicial completa dos produtos com seus saldos em estoque por filial e cargas incrementais diárias, buscando pelos produtos que foram listados como vendidos na busca das vendas. No script ./bash/tabela-saldo_produto.sh, é possível ver exemplos de como fazer a carga FULL e como fazer tais cargas incrementais.

##### ***ATENÇÃO***
A coluna `dt_kpi` funciona como filtro e possui o formato YYYYMMDD. A data mais antiga suportada é 20251223. Caso o usuário solicite uma data anterior a essa, o result_set virá vazio.
  
Payload de exemplo para busca filtrada:
```json
{
    "query": "saldo_produto",
    "filtros": {
        "codigo": "AA1001001",         // string
        "ean": "1234567890123",        // string
        "descricao": "NomeDoProduto",  // string
        "fabricante": "NomeDoFabricante",  // string
        "codigo_filial": "0199",       // string
        "dt_kpi": "20251223"           // string YYYYMMDD
    }
}
```

### VENDA
A carga completa trará as vendas faturadas ou não desde 01/JAN/2025, das marcas associadas à sua conta. Para as cargas diárias incrementais, há possíveis lógicas de ingestão dos dados. Avalie qual é recomendada pra você, conforme sua necessidade.

1. Vendas Faturadas: 
Diariamente, faça duas buscas. Uma que será pela dt_emissao igual a data de ontem, de forma que você verá todas as vendas do dia anterior. Não armazene esses dados, mas os utilize para buscar os dados incrementais de funcionários e saldo dos produtos. Em seguida faça a segunda busca, dessa vez pela dt_faturamento igual a data de ontem. Esses são os dados que você deverá armazenar. O problema dessa estratégia é a consolidação dos programas de pontos, que geralmente são calculados sobre o período da venda, e não do faturamento. Então, se você tem um programa de pontos, essa estratégia pode não ser a ideal pra você.

2. Vendas Emitidas: 
Diariamente, faça a busca pela dt_emissao igual a data de ontem e armazene os dados obtidos. Com os contadores de vendas, você poderá processar o seu programa de pontos, que geralmente está associado à data da venda, e não a data de seu faturamento. Como vendas não faturadas ainda não foram entregues aos clientes, os dados de saldo dos produtos em estoque podem te parecer inconsistentes.

3. Vendas Emitidas e Faturadas em Tabelas Separadas:
Nesse cenário, você quer ter os contadores das vendas e os contadores dos faturamentos separadamente. Então, diariamente, você fará as duas buscas, uma pela dt_emissao igual a data de ontem, e outra pela dt_faturamento igual a data de ontem. Você armazenará os dados de ambas as buscas em tabelas diferentes. Você utilizará os dados de vendas para processar o seu programa de pontos e os dados de faturamento para controle da movimentação de estoque e planejamento do ressuprimento das suas linhas de produtos com a TeleRio.

4. Vendas Emitidas e Faturadas numa Tabela Unificada:
Nesse cenário, você quer ter os contadores das vendas e os contadores dos faturamentos numa única tabela. Então, diariamente, você fará a busca pela dt_emissao igual a data de ontem, e armazenará os dados obtidos. Numa segunda busca, filtrando pela dt_faturamento igual a data de ontem você trará dados para atualizar os dados que já armazenou antes. Utilize o campo codigo_orcamento como chave, e tuplas relacionadas às vendas, que ainda não tinham data do faturamento, serão gradualmente atualizadas com tais datas e medida que sejam entregues aos clientes.

No script ./bash/tabela-venda.sh, é possível ver exemplos de como fazer a carga FULL e como fazer tais cargas incrementais.

Payload de exemplo para busca filtrada pela data de venda (sugestão de primeira busca):
```json
{
    "query": "venda",
    "filtros": {
        "dt_emissao": "20250401"  // string YYYYMMDD
    }
}
```

Payload de exemplo para busca filtrada pelo faturamento da venda (sugestão de segunda busca):
```json
{
    "query": "venda",
    "filtros": {
        "dt_faturamento": "20250401"  // string YYYYMMDD
    }
}
```

Payload de exemplo para uma busca qualquer filtrada:
```json
{
    "query": "venda",
    "filtros": {
        "dt_emissao": "20250401",       // string YYYYMMDD
        "dt_faturamento": "20250401",   // string YYYYMMDD
        "codigo_produto": "AA1001001",  // string
        "codigo_orcamento": "00012345", // string
        "ean": "1234567890123",         // string
        "codigo_filial": "0199",        // string
        "codigo_vendedor": "009999"     // string
    }
}
```

Os filtros pelas datas de emissão e faturamento também suportam intervalos. 

Exemplos:
```json
{
    "query": "venda",
    "filtros": {
        "dt_emissao_start": "20250401", "dt_emissao_end": "20250430"       // string YYYYMMDD
    }
}
```

```json
{
    "query": "venda",
    "filtros": {
        "dt_faturamento_start": "20250401", "dt_faturamento_end": "20250430"   // string YYYYMMDD
    }
}
```

### CONSOLIDADO VENDA
É possível buscar os números de venda de cada sku, de forma consolidada, indicando o ano e mês. Você pode buscar o ano/mês da venda ou ano/mês do faturamento. A falta de definição de mês, seja venda ou faturamento, vai gerar um erro. As quantidades vendidas estarão agrupadas pelo sku, com o código do produto e seu ean.

Payload de exemplo para busca pelo mês da venda:
```json
{
    "query": "consolidado_venda",
    "filtros": {
        "mes_emissao": "202509", // string YYYYMM
        "codigo_produto": "AA1001001",  // string
        "ean": "1234567890123"         // string
    }
}
```

Payload de exemplo para busca pelo mês do faturamento:
```json
{
    "query": "consolidado_venda",
    "filtros": {
        "mes_faturamento": "202509", // string YYYYMM
        "codigo_produto": "AA1001001",  // string
        "ean": "1234567890123"         // string
    }
}
```

## Erros
Os erros são devolvidos com o código HTTP e uma mensagem em texto:

| Código | Quando acontece |
|--------|-----------------|
| 400 | Query inexistente (`Query inválida.`), `filtros` que não seja um objeto JSON, valor de filtro que não seja texto ou número, ou regra não atendida (ex.: `consolidado_venda` sem `mes_emissao` ou `mes_faturamento`). |
| 403 | ApiKey inválida, sem fornecedor associado ou sem marcas cadastradas. |
| 429 | Limite de uso excedido (veja Quotas). |
| 500 | Erro interno. |

Para evitar surpresas, siga os tipos e formatos indicados no catálogo e envie apenas filtros que existam na query. Hoje, filtros desconhecidos são ignorados, e valores fora do formato ou com mais de 100 caracteres são aceitos. Essa tolerância é temporária: depois de um período de acompanhamento, passarão a ser rejeitados com erro 400, indicando o filtro com problema. Aspas simples nos valores são sempre tratadas como texto.

## Exemplo de uso
A API funciona de forma assíncrona. Primeiro você faz a requisição, indicando qual a tabela, e quais os filtros são aplicáveis. Você receberá como resposta o ID e o status de execução da query (`query_exec_id` e `query_status`). 

```bash
#!/bin/bash

API_ENDPOINT=""
API_KEY=""
PAYLOAD="{ \"query\": \"filial\", \"filtros\": { \"statusfilial\": \"ATIVA\" } }"

curl -X POST -s -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" -d "$PAYLOAD" "$API_ENDPOINT"

```

Resposta:
```json
{
  "query_exec_id": "2396fbae-19f9-11f0-b718-00155d05f688",
  "query_status": "QUEUED"
}
```

Em seguida, você deve consultar o status da execução, utilizando tal ID de execução. Dependendo da tabela e do volume de dados requisitados, pode ser que a query demore menos ou mais tempo para que seja executada. E isso significa que você pode ter que consultar o status da execução mais de uma vez. Considere executar um loop requisitando o status com sleep de 1s a 5s entre as iterações. Os possíveis status são: QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELLED. Caso você veja como resposta as opções QUEUED ou RUNNING, você deve continuar consultando o status. Caso você veja como resposta as opções SUCCEEDED, FAILED ou CANCELLED, você já tem o status final da execução da query. 

```bash
#!/bin/bash

API_ENDPOINT=""
API_KEY=""
PAYLOAD="{ \"query_exec_id\": \"2396fbae-19f9-11f0-b718-00155d05f688\" }"

curl -X POST -s -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" -d "$PAYLOAD" "$API_ENDPOINT"
```

Resposta:
```json
{
  "query_exec_id": "2396fbae-19f9-11f0-b718-00155d05f688",
  "query_status": "SUCCEEDED",
  "page": 1,
  "total_pages": 10,
  "total_results": 1000,
  "rows": [
    ...
  ]
}
```

Pelos valores de `page`, `total_pages` e `total_results`, você consegue saber quantas páginas de dados você tem. Cada página tem por padrão até 100 linhas. Para buscar as próximas páginas, identifique qual página você precisa, repetindo a busca pelo ID da query.

```bash
#!/bin/bash

API_ENDPOINT=""
API_KEY=""
PAYLOAD="{ \"query_exec_id\": \"2396fbae-19f9-11f0-b718-00155d05f688\", \"page\": 2 }"

curl -X POST -s -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" -d "$PAYLOAD" "$API_ENDPOINT"
```

Resposta:
```json
{
  "query_exec_id": "2396fbae-19f9-11f0-b718-00155d05f688",
  "query_status": "SUCCEEDED",
  "page": 2,
  "total_pages": 10,
  "total_results": 1000,
  "rows": [
    ...
  ]
}
```






### Bom trabalho!
### Marcelo Sequeiros

