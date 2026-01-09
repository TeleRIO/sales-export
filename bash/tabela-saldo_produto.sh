#!/bin/bash

#################################################################
# Busca pelo saldo dos produtos em estoque em cada filial:
#     "codigo": "AA1001001",
#     "ean": "1234567890123",
#     "descricao": "NomeDoProduto",
#     "fabricante": "NomeDoFabricante",
#     "codigo_filial": "0199",
#     "dt_kpi": "20251223"              (formato YYYYMMDD, data mínima: 20251223)
#
# Os parâmetros de busca são opcionais, ou seja, podem ser passados ou não.
# Quando combinados, serão sempre aplicados em conjunto com AND na busca.
#
# IMPORTANTE: A coluna dt_kpi funciona como filtro e suporta apenas datas a partir de 20251223.
# Se uma data anterior for informada, o result_set virá vazio.
#

API_ENDPOINT=""
API_KEY=""

execute_query() {
    local payload=$1

    printf "Input Payload:\n"
    echo $payload | jq .
    printf "\n\n"

    # Executa a query
    local response=$(curl -X POST -s \
                    -H "Content-Type: application/json" \
                    -H "X-API-Key: $API_KEY" \
                    -d "$payload" \
                    $API_ENDPOINT)

    printf "Response Payload:\n"
    echo $response | jq .
    printf "\n\n"

    # Captura o ID da execução e o status da execução
    local exec_id=$(jq -r '.query_exec_id' <<< "$response")
    local exec_status=$(jq -r '.query_status' <<< "$response")

    printf "ID da execução: $exec_id\n"
    printf "Status da execução: $exec_status\n"

    printf "..................................\n"

    # A busca dos dados/status de execução da query é feita passando o ID da execução
    # Na resposta com sucesso, será possível verificar a quantidade de páginas de dados
    # Opcionalmente, pode-se passar a página de dados que se deseja buscar
    #
    # Exemplo de payload para busca do status da execução:
    # {
    #     "query_exec_id": "1234567890"
    # }
    #
    # Exemplo de payload para busca do status da execução e dados da página 1:
    # {
    #     "query_exec_id": "1234567890",
    #     "page": 1
    # }
    payload="{ \"query_exec_id\": \"$exec_id\" }"

    printf "Verificando status da execução da query\n"

    printf "Input Payload:\n"
    echo $payload | jq .
    printf "\n\n"

    # Loop para verificar o status da execução
    #    QUEUED - Aguardando execução
    #    RUNNING - Executando
    #    SUCCEEDED - Execução concluída com sucesso
    #    FAILED - Execução falhou
    #    CANCELED - Execução cancelada
    while true; do 
        sleep 1
        response=$(curl -X POST -s \
                    -H "Content-Type: application/json" \
                    -H "X-API-Key: $API_KEY" \
                    -d "$payload" \
                    "$API_ENDPOINT")

        exec_status=$(echo $response | jq -r '.query_status')
        printf "Status da execução: $exec_status\n"

        # Verifica se a execução foi concluída
        if [[ $exec_status == "SUCCEEDED" || $exec_status == "FAILED" ]]; then
            break
        fi
    done

    printf "Response Payload:\n"
    echo $response | jq .
    printf "\n\n"
}

# Exemplo de payload para primeira carga de saldo_produto, que trará as saldos de todos os produtos
# {
#     "query": "saldo_produto"
# }
DATA="{ \"query\": \"saldo_produto\" }"
printf "Executando a query saldo_produto full\n"

execute_query "$DATA"

# Exemplo de payload de busca por saldo_produto específicos
# {
#     "query": "saldo_produto",
#     "filtros": {
#         "codigo": "AA1001001",
#         "ean": "1234567890123",
#         "descricao": "NomeDoProduto",
#         "fabricante": "NomeDoFabricante",
#         "codigo_filial": "0199",
#         "dt_kpi": "20251223"
#     }
# }

DATA="{ \"query\": \"saldo_produto\", \"filtros\": { \"codigo\": \"AA1001001\" }"
printf "Executando a query saldo_produto / Busca Pontual\n"

execute_query "$DATA"

# Exemplo de payload para carga diária incremental
# Após carga das vendas, pra todos os produtos que foram faturados buscar por seu código
# É possível filtrar também pela dt_kpi (formato YYYYMMDD, mínimo: 20251223)
# {
#     "query": "saldo_produto",
#     "filtros": {
#         "codigo": "AA1001001",
#         "dt_kpi": "20251223"
#     }
# }

DATA="{ \"query\": \"saldo_produto\", \"filtros\": { \"codigo\": \"AA1001001\" } }"
printf "Executando a query saldo_produto / Update diário Incremental\n"

execute_query "$DATA"

