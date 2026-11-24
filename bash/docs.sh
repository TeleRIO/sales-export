#!/bin/bash
#################################################################
# Documentação das queries disponíveis (catálogo) e dos filtros aceitos.
#
# Não executa nada no Athena: a resposta é imediata e não possui query_exec_id.
#
# Payload para o catálogo completo:
# {
#     "query": "docs"
# }
#
# Payload para a documentação de uma única query:
# {
#     "query": "docs",
#     "filtros": { "query": "venda" }
# }
#
# A resposta traz "catalog_version" (hash do catálogo completo, muda quando o catálogo muda)
# e "queries", com label, description, filters, rules e output de cada query.
#
API_ENDPOINT=""
API_KEY=""

docs() {
    local payload=$1
    printf "Input Payload:\n"
    echo $payload | jq .
    printf "\n\n"

    local response=$(curl -X POST -s \
                    -H "Content-Type: application/json" \
                    -H "X-API-Key: $API_KEY" \
                    -d "$payload" \
                    $API_ENDPOINT)

    printf "Response Payload:\n"
    echo $response | jq .
    printf "\n\n"
}

DATA="{ \"query\": \"docs\" }"
printf "Catálogo completo\n"
docs "$DATA"

DATA="{ \"query\": \"docs\", \"filtros\": { \"query\": \"venda\" } }"
printf "Documentação da query venda\n"
docs "$DATA"
