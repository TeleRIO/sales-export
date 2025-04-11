#!/bin/bash

#################################################################
# Busca por uma filial específica:
#     "cod_filial": "0199",
#     "statusfilial": "ATIVA",
#     "regional": "Regional X",
#     "cidade": "nome da cidade",
#     "ultima_atualizacao": "2023-10-01 00:00:00"
#
# Os parâmetros de busca são opcionais, ou seja, podem ser passados ou não.
# Quando combinados, serão sempre aplicados em conjunto com AND na busca.
# O ultima_atualizacao trarão os com >= a data informada.
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

# Exemplo de payload para primeira carga das filiais
# {
#     "query": "filial"
# }
DATA="{ \"query\": \"filial\" }"
printf "Executando a query FILIAL full\n"

execute_query "$DATA"

# Exemplo de payload de busca por uma filial específica:
# {
#     "query": "filial",
#     "filtros": {
#         "cod_filial": "0199",
#         "statusfilial": "ATIVA",
#         "regional": "Regional X",
#         "cidade": "nome da cidade",
#         "ultima_atualizacao": "2023-10-01 00:00:00"
#     }
# }

DATA="{ \"query\": \"filial\", \"filtros\": { \"cod_filial\": \"0199\" } }"
printf "Executando a query FILIAL / Busca Pontual\n"

execute_query "$DATA"

# Exemplo de payload para carga semanal incremental, usando a ultima_atualizacao feita como referência:
# {
#     "query": "filial",
#     "filtros": {
#         "ultima_atualizacao": "2024-06-01 00:00:00"
#     }
# }

DATA="{ \"query\": \"filial\", \"filtros\": { \"ultima_atualizacao\": \"2024-06-01 00:00:00\" } }"
printf "Executando a query FILIAL / Update Semanal Incremental\n"

execute_query "$DATA"
