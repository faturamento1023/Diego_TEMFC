# Diego_TEMFC

Projeto de preparação inteligente para o Título de Especialista em Medicina de
Família e Comunidade, com progresso individual no Supabase e acesso por celular
e computador.

**Estado atual: banco oficial importado e backend em operação.** Após a autorização
expressa, o projeto dedicado `Diego_TEMFC` foi criado. Cinco migrations, Supabase
Auth, RLS e funções de estudo estão aplicadas, e 320 questões foram importadas.
A interface completa foi desenvolvida no ambiente de execução, mas seu envio
final e a publicação foram interrompidos porque o ambiente ficou desconectado.
**Ainda não há aplicação publicada.** O estado exato está em
[docs/delivery-checkpoint.json](docs/delivery-checkpoint.json).

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

## Backend criado e validado

Projeto dedicado **Diego_TEMFC**, referência `ogdgoakussorayqbqayt`, região
`sa-east-1`, organização `mediflow_tec`. O projeto de outra finalidade permaneceu
intacto. As migrations foram efetivamente aplicadas pela conexão do Supabase;
não é necessário executar SQL manualmente.

O banco contém 13 tabelas públicas, uma tabela privada de gabaritos, duas views
com `security_invoker`, índices, FKs, constraints e triggers. RLS protege todas
as tabelas. O catálogo é somente leitura para estudantes, e os gabaritos só
são liberados quando a correção é permitida. O frontend preparado usa somente
URL e chave publishable pública, sem `service_role` ou senha de banco.

As funções guardadas implementam seleção adaptativa/rápida, revisão de erros,
favoritas, banco filtrado, originais completos e simulados mistos. Elas salvam
respostas, marcações, posição, tempo, progresso individual, metas, desempenho
e revisão espaçada; operações idempotentes evitam dupla contabilização, e a
versão de sessão impede sobrescrita entre aparelhos.

A validação remota confirmou 320 questões, 1.280 alternativas, 320 gabaritos,
32 temas, zero gabaritos ausentes ou inválidos e zero questões sem quatro
alternativas. Quatro testes de cálculos e 21 grupos de integração passaram.
Uma execução completa anterior de UI/PWA aprovou oito grupos, incluindo
responsividade em cinco larguras, dois processos de navegador, sincronização
offline e simulados. A última execução de UI, após ajustes finais, foi
interrompida pelo ambiente offline. As duas contas de teste foram removidas;
o banco está sem histórico fictício ou contas de estudantes pré-criadas.

[Validação remota](docs/supabase-validation.json) ·
[Estrutura e regras](docs/banco-de-dados.md) ·
[Estado da entrega](docs/delivery-checkpoint.json).

## Publicação pendente

A interface/PWA já existe no ambiente de execução, com estudo adaptativo,
modo rápido, revisão, simulados, resultados, retomada, desempenho, favoritas,
filtros, manifest, service worker e fila temporária de sincronização.
Seus arquivos finais ainda não estão na branch `main`. Os hashes e caminhos
pendentes estão registrados no checkpoint para retomar sem criar outro projeto.
Não existe URL de produção confirmada; o projeto Sites existente permanece
privado e sem publicação validada.

Não foram realizados testes em um Android físico ou entrega de e-mail para
um endereço real de Diego. SMTP/templates/redirecionamentos do Auth não são
administráveis pela conexão disponível. A interface local inclui validação
do link recebido dentro do aplicativo, cujo teste final foi interrompido.
O advisor aponta proteção contra senhas vazadas desabilitada por padrão:
[referência de configuração](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
