# Diego_TEMFC

Projeto de preparação inteligente para o Título de Especialista em Medicina de
Família e Comunidade, com progresso individual no Supabase e acesso por celular
e computador.

**Estado atual: auditoria e banco de questões concluídos.** A criação do projeto
Supabase dedicado depende da autorização expressamente solicitada pelo usuário.
Nenhum projeto de outra finalidade foi alterado. Ainda não há aplicação
publicada, autenticação configurada ou questões importadas no Supabase.

## Banco oficial auditado

| Prova | Ano | Questões | Alternativas | Gabaritos verificados | Anuladas |
|---|---:|---:|---:|---:|---|
| TEMFC 34 | 2024 | 80 | 320 | 80 | 25 |
| TEMFC 35 | 2024 | 80 | 320 | 80 | 60 |
| TEMFC 36 | 2025 | 80 | 320 | 80 | — |
| TEMFC 37 | 2026 | 80 | 320 | 80 | — |
| **Total** | | **320** | **1.280** | **320** | **2** |

São 318 questões pontuáveis e 32 temas classificados editorialmente. Os quatro
arquivos `data/temfc-*.json` preservam a ordem da prova, o enunciado, as quatro
alternativas, a letra do gabarito e a proveniência de cada item. Não há
explicações clínicas geradas: os arquivos fornecidos não apresentam justificativas.

As quebras de linha do texto extraído são mantidas. Não se corrigem grafia,
pontuação, nomes, valores ou condutas clínicas do conteúdo original. Cabeçalhos,
rodapés, metadados do sistema de aplicação e o selo “Resposta correta” da TEMFC
36 são removidos do texto destinado ao estudo. Os códigos e páginas continuam
registrados separadamente.

### Particularidades dos PDFs

- TEMFC 34: a questão 25 está marcada como anulada, mas o gabarito contém C.
- TEMFC 35: a questão 60 está marcada como anulada, mas o gabarito contém A.
  O enunciado menciona um ECG que não consta no arquivo fornecido.
- TEMFC 36: a posição de prova é 1–80 e o código do item é 31–110. Os 80
  marcadores de resposta presentes junto às alternativas coincidem com o
  gabarito final. A questão 80 compartilha uma página com o início do gabarito.
- TEMFC 37: a numeração original é **31–110**, e não 1–80. O campo `position`
  representa a ordem 1–80; `original_number` preserva o código da questão.
- Sete figuras originais foram preservadas em `data/media`, com coordenadas,
  posição de inserção no enunciado e hash de integridade.

As anuladas devem ser exibidas como conteúdo original, mas excluídas da
pontuação de desempenho e da repetição por erro. A letra original permanece
registrada como dado de proveniência, sem ser tratada como resposta pontuável.

## Estrutura preparada

- `data/exams.json`: metadados, páginas e hashes das provas.
- `data/temfc-34.json` a `data/temfc-37.json`: banco oficial por edição.
- `data/topics.json`: temas e contagem por assunto.
- `data/media/`: figuras recortadas dos próprios PDFs.
- `scripts/extract_questions.py`: extração determinística a partir dos PDFs.
- `scripts/classify_questions.py`: classificação editorial separada do texto.
- `scripts/validate_bank.py`: validação de cobertura, alternativas, IDs, hashes
  e gabaritos usando um segundo leitor de PDFs independente.
- `docs/bank-validation.json`: resultado da validação automática.
- `docs/auditoria.md`: evidências e pendências da auditoria inicial.

## Reproduzir a auditoria

Os PDFs originais permanecem na pasta do Drive fornecida pelo usuário. Para uma
nova extração, copie-os para `data/sources/temfc-34.pdf` a `temfc-37.pdf`, instale
as versões fixadas em `requirements.txt` e execute, nesta ordem:

```sh
python scripts/extract_questions.py
python scripts/classify_questions.py
python scripts/validate_bank.py
```

Qualquer questão ausente, gabarito divergente, alternativa vazia ou alteração
posterior do conteúdo faz a validação falhar. Os PDFs e os textos intermediários
não são versionados; seus hashes e identificadores do Drive permitem rastreio.

## Próxima etapa autorizável

Criar `Diego_TEMFC` na organização Supabase `mediflow_tec`. A consulta de custo
em 06/10/2026 retornou **US$ 0 por mês** para a criação deste projeto, na
organização atualmente no plano Free. A criação ainda não foi realizada.

Após a autorização: configurar Supabase Auth, aplicar e verificar migrations,
RLS e funções, importar os registros auditados, implementar a aplicação e a
PWA, verificar isolamento de usuários, salvamento, retomada, repetição espaçada
e sincronização entre aparelhos, e publicar a aplicação. O Supabase será a
fonte oficial de progresso desde a primeira versão funcional; credenciais
privilegiadas não serão incluídas no frontend nem no repositório.
