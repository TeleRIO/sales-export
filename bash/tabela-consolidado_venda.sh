#!/bin/bash

#################################################################
# Busca por vendas específicas:
#     "mes_emissao": "202504",
#     "mes_faturamento": "202504",
#     "codigo_produto": "AA1001001",
#     "ean": "1234567890123"
#
# Os parâmetros de busca são opcionais, ou seja, podem ser passados ou não.
# Quando combinados, serão sempre aplicados em conjunto com AND na busca.
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

# Exemplo de payload de busca do consolidado de venda pelo mês da venda
# {
#     "query": "consolidado_venda",
#     "filtros": {
#         "mes_emissao": "202504"
#     }
# }

DATA="{ \"query\": \"consolidado_venda\", \"filtros\": { \"mes_emissao\": \"202504\" } }"
printf "Executando a query consolidado venda\n"

execute_query "$DATA"

