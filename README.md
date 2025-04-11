# Sales Export

Nessa área você vai encontrar documentação sobre como utilizar as APIs de exportação dos dados de venda. Nesse momento temos alguns scripts de exemplo, escritos em bash, pra facilitar o entendimento de como as APIs funcionam, mas uma vez que estamos falando de APIs escritas em REST, você pode utilizar qualquer linguagem de programação que tenha suporte a requisições HTTP.

## Entidades

Suportamos 4 entidades nesse momento:
- **filial**: busca as filiais da Tele RIO com seu status, código, cnpj, endereço, entre outros dados.
- **funcionario**: busca todos os funcionarios, ativos ou inativos, com seu status, código, cpf, nome, entre outros dados.
- **saldo_produto**: busca o saldo de produtos por filial, com seu status, código, nome, entre outros dados.
- **venda**: busca as vendas realizadas, sumarizadas pelo produto, suas quantidades, filial, vendedor, entre outros dados.


## Autenticação
Ela é feita por uma ApiKey que você receberá por e-mail assim que sua conta for criada. Tal ApiKey fica associada às suas marcas, de forma que você só consegue buscar dados de saldo em estoque e vendas de produtos que nosso comercial associou à sua conta.

## Endpoints
Também serão enviados por e-mail assim que sua conta for criada.


### FILIAL
Faça uma carga inicial completa das filiais e cargas recorrentes semanais, para buscar possíveis atualizações. Na tabela das filiais, temos uma coluna com o TIMESTAMP em que foi feita a última atualização. Nas buscas semanais, basta pesquisar pelas filiais que tenham tal data maior ou igual a maior data que você tem na sua base. Dessa forma, você trará apenas os dados incrementais, para UPSERT local. No script ./bash/tabela-filial.sh, é possível ver exemplos de como fazer a carga FULL e como fazer tais cargas incrementais.

### FUNCIONARIO
Faça carga inicial completa dos funcionários e cargas incrementais semanais e diárias. A carga semanal pode ser feita buscando funcionários admitidos ou demitidos desde sua última carga semanal. Tal atualização garantirá que os novos colaboradores e colaboradores desligados sejam atualizados na sua base local. Diariamente, quando você fizer a carga das vendas, sugerimos que pra todos os códigos de vendedores que sejam listados, você faça a busca por ele nessa API. Isso vai garantir que as movimentações de colaboradores entre filiais, ou mudanças de cargo sejam atualizadas na sua base local. No script ./bash/tabela-funcionario.sh, é possível ver exemplos de como fazer a carga FULL e como fazer tais cargas incrementais.

#### ***ATENÇÃO***
A associação dos funcionários às filiais em que trabalha pode ser obtida pelo código da filial. Essa associação funciona com todos os cargos, menos no caso dos supervisores, pois a associação deles não é com uma única filial, mas sim pela regional que eles supervisionam. Nesses casos, a identificação das filiais associadas ao supervisor envolve a listagem das filiais, que possue a identificação da regional, e a listagem dos supervisores, que também possuem a identificação da regional. Através dessa informação, você conseguirá associar os supervisores às filiais que eles supervisionam.

### SALDO_PRODUTO
Faça a carga inicial completa dos produtos com seus saldos em estoque por filial e cargas incrementais diárias, buscando pelos produtos que foram listados como vendidos na busca das vendas. No script ./bash/tabela-saldo_produto.sh, é possível ver exemplos de como fazer a carga FULL e como fazer tais cargas incrementais.

### VENDA
A carga completa trará as vendas faturadas ou não desde 01/JAN/2025, das marcas associadas à sua conta. Diariamente, faça duas buscas. Uma que será pela dt_emissao igual a data de ontem, de forma que você verá todas as vendas do dia anterior. Não armazene esses dados, mas os utilize para buscar os dados incrementais de funcionários e saldo dos produtos. Em seguida faça a segunda busca, dessa vez pela dt_faturamento igual a data de ontem. Esses são os dados que você deverá armazenar como as vendas efetivadas. Por essa segunda pesquisa, você poderá processar o seu programa de pontos, por exemplo. No script ./bash/tabela-venda.sh, é possível ver exemplos de como fazer a carga FULL e como fazer tais cargas incrementais.



## Bom trabalho!
### Marcelo Sequeiros

