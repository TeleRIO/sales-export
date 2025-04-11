#!/bin/bash

#################################################################
# Busca por um funcionario específico:
#     "matricula": "009999",
#     "nome": "JOAO DA SILVA",
#     "cod_filial": "0199",
#     "regional": "Regional X",
#     "documento": "12345678901",
#     "dt_nascimento": "0106",
#     "dt_admissao": "20230101",
#     "dt_demissao": "20240101",
#     "cargo": 'VENDEDOR',
#     "status_funcionario": 'ATIVO',
#
# Os parâmetros de busca são opcionais, ou seja, podem ser passados ou não.
# Quando combinados, serão sempre aplicados em conjunto com AND na busca.
# Para a data de nascimento, passar apenas MÊS e DIA, ex: 0204 - serve pra buscar os aniversariantes do dia.
# As datas de admissão e demissão trarão os com >= a data informada.
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

# Exemplo de payload para primeira carga dos funcionários
# {
#     "query": "funcionario"
# }
DATA="{ \"query\": \"funcionario\" }"
printf "Executando a query funcionario full\n"

execute_query "$DATA"

# Exemplo de payload de busca por um funcionario específico:
# {
#     "query": "funcionario",
#     "filtros": {
#         "matricula": "009999",
#         "nome": "JOAO DA SILVA",
#         "cod_filial": "0199",
#         "regional": "Regional X",
#         "documento": "12345678901",
#         "dt_nascimento": "0106",
#         "dt_admissao": "20230101",
#         "dt_demissao": "20240101",
#         "cargo": 'VENDEDOR',
#         "status_funcionario": 'ATIVO'
#     }
# }

DATA="{ \"query\": \"funcionario\", \"filtros\": { \"matricula\": \"009999\" } }"
printf "Executando a query funcionario / Busca Pontual\n"

execute_query "$DATA"

# Exemplo de payload para carga semanal incremental, buscando os contratados desde a data informada:
# {
#     "query": "funcionario",
#     "filtros": {
#         "dt_admissao": "20250101"
#     }
# }

DATA="{ \"query\": \"funcionario\", \"filtros\": { \"dt_admissao\": \"20250101\" } }"
printf "Executando a query funcionario / Update Semanal Incremental\n"

execute_query "$DATA"

# Exemplo de payload para carga semanal incremental, buscando os demitidos desde a data informada:
# {
#     "query": "funcionario",
#     "filtros": {
#         "dt_demissao": "20250101"
#     }
# }
DATA="{ \"query\": \"funcionario\", \"filtros\": { \"dt_demissao\": \"20250101\" } }"
printf "Executando a query funcionario / Update Semanal Incremental\n"

execute_query "$DATA"
