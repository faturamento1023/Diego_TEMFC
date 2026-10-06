# Auditoria inicial — 06/10/2026

## Fontes lidas

Pasta fornecida: https://drive.google.com/drive/folders/1VISheGOQ9HWohQgt12jA3xYV-NbaJma5

Foram encontrados exatamente os quatro PDFs solicitados. A extração percorreu
integralmente a camada de texto e as imagens de todos os PDFs: 254 páginas no
total, incluindo instruções e gabaritos. Nenhuma questão foi criada ou corrigida.

| Edição | Páginas do PDF | Páginas do gabarito | Numeração das questões |
|---|---:|---|---|
| 34 | 54 | 54 | 1–80 |
| 35 | 48 | 48 | 1–80 |
| 36 | 89 | 82–88 | Posição 1–80; código 31–110 |
| 37 | 63 | 61–63 | Código 31–110 |

As páginas acima são posições no arquivo PDF, iniciando em 1; a numeração
impressa de algumas páginas difere dessa posição.

## Verificação independente

A extração principal usa PyMuPDF. Uma segunda leitura, com pdfplumber,
verificou independentemente cada uma das 320 letras do gabarito. Na TEMFC 36,
também foram comparados os 80 marcadores de correção junto às alternativas,
sem divergências. Todos os registros têm quatro alternativas não vazias,
identificador único e gabarito correspondente. Os hashes de conteúdo permanecem
iguais antes e depois da classificação editorial dos temas.

O resultado detalhado está em `bank-validation.json`. A classificação em 32
temas é uma ferramenta editorial para estudo; não é uma classificação oficial
da banca e não modifica o conteúdo dos itens.

## Inconsistências encontradas

1. TEMFC 34, questão 25: anulada no enunciado, letra C no gabarito.
2. TEMFC 35, questão 60: anulada no enunciado, letra A no gabarito.
3. TEMFC 35, questão 60: o ECG citado pelo enunciado não está presente no PDF.

Os três fatos estão registrados nos próprios dados. A aplicação deverá
preservar e sinalizar as anuladas, sem contabilizá-las como erro ou acerto.
Não há tentativa de preencher a imagem ausente ou de produzir justificativas
para as respostas fornecidas pela banca.

## Repositório e Supabase

O repositório `faturamento1023/Diego_TEMFC` foi inspecionado antes da primeira
escrita. A API retornou que o repositório estava vazio, com branch padrão `main`
e permissão de escrita. Nenhum arquivo existente foi apagado.

A conexão Supabase retornou somente o projeto **Marmita Facil**, inativo e de
outra finalidade. Esse projeto não foi modificado. A única organização
disponível é **mediflow_tec**, no plano Free. A consulta de custo para um novo
projeto nessa organização retornou `amount: 0`, `recurrence: monthly`.

Após a autorização explícita “sim pode criar no Diego_TEMFC”, o projeto
foi criado em `sa-east-1`, referência `ogdgoakussorayqbqayt`. Cinco migrations
foram aplicadas e as 320 questões, 1.280 alternativas e 320 gabaritos foram
importados e comparados com a fonte auditada. Quatro testes de cálculos e 21
grupos de integração passaram. Uma execução completa de UI/PWA aprovou oito
grupos; a última execução, após ajustes finais de histórico e página inicial,
foi interrompida porque o ambiente de execução ficou desconectado.

As duas contas descartáveis foram removidas por UUID e marcador de QA; seus
históricos foram apagados em cascata. A conferência remota posterior manteve
320 questões e confirmou zero usuários de QA, perfis e sessões. Não foi criado
um usuário real de Diego sem seu e-mail.

O código completo da interface ainda está no ambiente de execução, pendente
de envio final ao GitHub e publicação. Não há URL de produção confirmada.
O checkpoint e a validação remota estão em `delivery-checkpoint.json` e
`supabase-validation.json`.
