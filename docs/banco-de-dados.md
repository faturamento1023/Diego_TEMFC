# Banco e regras de progresso

Projeto **Diego_TEMFC**, `ogdgoakussorayqbqayt`, PostgreSQL 17 no Supabase.

| Tabela | Finalidade |
|---|---|
| `profiles` | Perfil de Auth, nome, meta diária e fuso |
| `exams` | Edição, ano e proveniência |
| `topics` | 32 temas editoriais |
| `questions` | Conteúdo original, ordem, tema, figuras e anuladas |
| `question_options` | Quatro alternativas A–D por questão |
| `private.answer_keys` | Gabaritos oficiais protegidos |
| `study_sessions` | Modo, estado, posição, tempo e versão |
| `session_questions` | Ordem fixa, respostas e marcações |
| `user_answers` | Tentativas corrigidas por sessão |
| `question_progress` | Acertos, erros, domínio e revisões |
| `review_queue` | Revisões futuras e manutenção |
| `favorites` | Estrelas individuais |
| `daily_progress` | Respostas, acertos, erros, tempo e meta por dia |
| `sync_operations` | Recibos idempotentes de alterações |

RLS está habilitada nas 14 tabelas. Estudantes somente leem o catálogo e
somente acessam seu próprio progresso. As views `topic_performance` e
`exam_performance` usam `security_invoker=true`. Escritas de progresso passam
por funções com guardas de `auth.uid()`, `search_path` vazio, nomes qualificados
 e transações. Gabaritos privados não têm acesso direto para estudantes.

FKs compostas impedem associar itens à sessão de outra pessoa. Constraints e
triggers diferíveis exigem quatro alternativas, gabarito válido, contadores
consistentes, domínio de 0–5 e correção ao final em simulados. Trigger de Auth
cria o perfil, com meta padrão de 10 questões e fuso de Brasília.

## Funções públicas

- `start_study_session`: seleção adaptativa, rápida, revisão, favoritas, banco
  ou simulado; `request_id` torna o início idempotente.
- `get_study_session`: estado completo somente do proprietário; gabaritos
  ocultos até a correção permitida.
- `save_study_action`: resposta, posição, marcação, tempo, favorita ou
  finalização numa transação. UUID evita repetir contabilização.
- `get_study_dashboard`: métricas, temas, provas, metas, evolução, sequência e
  sessões incompletas; últimas 30 sessões concluídas no resumo.
- `search_question_bank`: filtros e paginação; histórico anterior continua
  disponível por leitura paginada com RLS.

Mudanças substantivas incrementam `revision`; versões antigas retornam `PT409`
para conciliação. Heartbeats não invalidam respostas. Realtime respeita RLS.
O Supabase é a fonte oficial de progresso; a interface local preparada mantém
somente tokens de Auth, cache estático e operações ainda não confirmadas.

## Seleção e repetição espaçada

Prioridade: revisões vencidas, erros repetidos, temas fracos com ao menos três
respostas e menos de 65% de acertos, não vistas e manutenção de dominadas.
Há variedade de temas dentro da prioridade. Simulados originais conservam as
80 questões, ordem e anuladas; mistos selecionam itens pontuáveis sem duplicar.

| Acertos consecutivos | Intervalo inicial | Nível inicial de domínio |
|---:|---|---:|
| 1 | 1 dia | 1 |
| 2 | 3 dias | 2 |
| 3 | 7 dias | 3 |
| 4 | 14 dias | 4, dominada |
| 5 | 30 dias | 5 |
| 6 ou mais | Intervalo × 1,8, limitado a 90 dias | 5 |

Um erro zera acertos consecutivos, reduz domínio em dois níveis e divide o
intervalo por dois, com teto de um dia e piso de 15 minutos. Um acerto preserva
o maior entre o domínio retido e o nível da nova sequência, portanto nunca
reduz domínio. Intervalos seguem a nova sequência. Acertos também recebem
manutenção futura. Anuladas não geram acerto, erro, meta ou repetição por erro.
Brancos não criam uma tentativa ou erro fictício.

Resultado: acertos/questões válidas, com brancos no denominador e anuladas
excluídas. Desempenho geral: acertos/respostas válidas, incluindo tentativas
repetidas. Banco visto: questões distintas, incluindo anuladas respondidas.
Datas seguem o fuso do perfil; sequência atual admite estudo hoje ou ontem;
a melhor sequência usa dias consecutivos com respostas válidas.

## Migrations aplicadas

- `20261006200123_temfc_core`: esquema, RLS, funções, triggers e views.
- `20261006202246_temfc_integrity_indexes`: cobertura de FKs e gabaritos privados.
- `20261006203428_temfc_session_reliability`: idempotência, retomada e prioridade.
- `20261006210953_temfc_favorites_coverage`: favoritas incluem anuladas originais.
- `20261006212152_temfc_mastery_consistency`: acertos preservam domínio retido.

As três migrations posteriores foram recuperadas do histórico efetivamente
aplicado no Supabase quando o ambiente ficou offline. Não há SQL pendente de
execução manual. Consulte `supabase-validation.json` para a verificação real.
