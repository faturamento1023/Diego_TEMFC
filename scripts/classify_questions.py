#!/usr/bin/env python3
"""Apply reviewed editorial topic labels; never modify source question content."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOPICS = {
    "aps": "APS e Medicina de Família", "sus": "SUS e saúde coletiva",
    "crianca": "Saúde da criança e adolescente", "mulher": "Saúde da mulher",
    "prenatal": "Pré-natal e puerpério", "has": "Hipertensão",
    "diabetes": "Diabetes", "mental": "Saúde mental",
    "infecto": "Infectologia", "geriatria": "Geriatria",
    "prevencao": "Prevenção e promoção da saúde", "epidemio": "Epidemiologia e evidências",
    "urgencia": "Urgências", "cardio": "Cardiologia", "pneumo": "Pneumologia",
    "gastro": "Gastroenterologia", "nefro": "Nefrologia", "dermato": "Dermatologia",
    "osteo": "Musculoesquelético e reumatologia", "neuro": "Neurologia",
    "endocrino": "Endocrinologia e nutrição", "uro": "Urologia",
    "vascular": "Angiologia", "oftalmo": "Oftalmologia", "otorrino": "Otorrinolaringologia",
    "bucal": "Saúde bucal", "procedimentos": "Procedimentos na APS",
    "paliativos": "Cuidados paliativos e domiciliares",
    "sexualidade": "Saúde sexual e diversidade", "pics": "Práticas integrativas",
    "trabalho": "Saúde do trabalhador", "hemato": "Hematologia",
}

# Source numbers, not internal codes: TEMFC 37 begins at code 31.
# Classification is an editorial aid and is kept separate from original content.
REVIEWED = {
34: """
1|infecto|Tuberculose e efeitos adversos
2|gastro|Refluxo gastroesofágico
3|urgencia|Hemorragia digestiva
4|crianca|Alergia à proteína do leite de vaca
5|infecto|Giardíase
6|infecto|Dengue e sinais de alarme
7|infecto|Sífilis e seguimento sorológico
8|infecto|HIV e seguimento laboratorial
9|mental|Transtorno de pânico
10|diabetes|Diabetes e doença renal
11|crianca|Cefaleia e sinais de alerta
12|crianca|Criptorquidia
13|crianca|Choro e cólicas do lactente
14|crianca|Violência e proteção infantil
15|urgencia|Aspiração de corpo estranho
16|crianca|Dor abdominal recorrente
17|aps|Características da APS
18|aps|Grupos Balint
19|aps|Autonomia e relação clínica
20|geriatria|Risco e vulnerabilidade domiciliar
21|mental|Insônia e hipnóticos
22|mental|Uso de álcool e redução de danos
23|diabetes|Neuropatia diabética
24|urgencia|Cefaleia de início súbito
25|aps|Competência cultural
26|osteo|Cervicalgia e radiculopatia
27|osteo|Epicondilite lateral
28|osteo|Fascite plantar
29|osteo|Osteoporose
30|osteo|Fibromialgia
31|aps|Espiritualidade e cuidado centrado na pessoa
32|aps|Entrevista motivacional
33|sus|PNAB e planejamento da equipe
34|nefro|Estadiamento da doença renal crônica
35|hemato|Linfadenopatia e investigação
36|dermato|Infecções cutâneas
37|aps|Registro orientado por problemas e ReSOAP
38|geriatria|Polifarmácia e desprescrição
39|sus|Saúde das pessoas privadas de liberdade
40|sexualidade|Comunicação afirmativa e nome social
41|aps|Teleconsulta e segurança assistencial
42|mulher|Doença de Paget da mama
43|crianca|Atraso puberal
44|aps|Método clínico centrado na pessoa
45|prevencao|Prevenção quaternária
46|aps|Grupos Balint
47|aps|Comunicação de notícias difíceis
48|prevencao|Prevenção quaternária e bioética
49|sus|Processo de trabalho e notificação
50|aps|Apoio matricial
51|dermato|Onicomicose
52|mulher|Contracepção e risco tromboembólico
53|urgencia|Queimaduras
54|procedimentos|Remoção de anel
55|mulher|DIU em pessoas vivendo com HIV
56|oftalmo|Erros refrativos
57|oftalmo|Pterígio
58|otorrino|Disfonia
59|otorrino|Zumbido
60|bucal|Neoplasias bucais
61|sexualidade|Cuidado reprodutivo de pessoas trans
62|sexualidade|Diversidade e ciclo de vida
63|mulher|Dor pélvica
64|aps|Comunicação clínica sem julgamento
65|procedimentos|Unha encravada
66|has|Diagnóstico e monitorização da pressão
67|urgencia|Isquemia aguda de membro
68|cardio|Fibrilação atrial e anticoagulação
69|dermato|Molusco contagioso
70|dermato|Pitiríase versicolor
71|sus|Determinantes sociais da saúde
72|aps|Raciocínio clínico e diagnóstico
73|sus|Vigilância em saúde
74|sus|Participação e controle social
75|geriatria|Estratégia ICOPE
76|geriatria|Fragilidade e escala FRAIL
77|gastro|Investigação de sangramento e câncer colorretal
78|mental|Agitação psicomotora
79|urgencia|Intoxicação infantil
80|urgencia|Traumatismo cranioencefálico infantil
""",
35: """
1|sus|PNAB e responsabilidades municipais
2|sus|Ouvidoria e participação social
3|aps|Estimativa rápida e diagnóstico comunitário
4|procedimentos|Hipodermóclise
5|paliativos|Nutrição enteral domiciliar
6|pneumo|DPOC e cuidado domiciliar
7|aps|Coordenação e projeto terapêutico singular
8|infecto|Infecção urinária em idosa
9|paliativos|Índice prognóstico paliativo
10|prevencao|Prevenção quaternária
11|crianca|Desenvolvimento do recém-nascido
12|hemato|Anemia e deficiência de vitamina B12
13|neuro|Síndrome extrapiramidal medicamentosa
14|mental|Uso de cannabis na adolescência
15|aps|Territorialização
16|aps|Grupos Balint
17|diabetes|Controle glicêmico e nefroproteção
18|has|Tratamento e risco cardiovascular
19|gastro|Icterícia e neoplasia pancreática
20|diabetes|Neuropatia diabética
21|crianca|Refluxo do lactente
22|hemato|Doença falciforme
23|mulher|Cuidado após abortamento
24|mulher|Terapia hormonal na menopausa
25|geriatria|Investigação de demências
26|vascular|Úlcera venosa
27|uro|Incontinência urinária
28|crianca|Sífilis congênita
29|mulher|Amenorreia
30|mulher|Contracepção de emergência
31|crianca|Otite média aguda
32|prenatal|Hipertensão na gestação
33|prenatal|Exames de rotina
34|sus|Saúde indígena
35|urgencia|Animais peçonhentos
36|aps|Comunicação e experiência de doença
37|crianca|Doença de Kawasaki
38|paliativos|Planejamento de visitas domiciliares
39|oftalmo|Olho vermelho e glaucoma
40|sus|Política de saúde da população negra
41|crianca|Violência e notificação
42|crianca|Artrite idiopática juvenil
43|urgencia|Agitação e uso de cocaína
44|crianca|Enurese
45|diabetes|Hiperglicemia e doença renal
46|mental|Transtornos alimentares
47|aps|Método clínico centrado na pessoa
48|infecto|Doença de Chagas
49|pneumo|Diagnóstico de DPOC
50|crianca|Alergia à proteína do leite de vaca
51|urgencia|Acidente isquêmico transitório
52|osteo|Síndrome do desfiladeiro torácico
53|crianca|Hérnia umbilical
54|cardio|Insuficiência cardíaca
55|aps|APS ribeirinha e longitudinalidade
56|dermato|Acne
57|prevencao|Cessação do tabagismo
58|prevencao|Rastreamento do câncer de colo uterino
59|cardio|Fibrilação atrial
60|urgencia|Síndrome coronariana aguda
61|mental|Saúde mental no sistema prisional
62|aps|Grupos e abordagem comunitária
63|prevencao|Saúde planetária
64|osteo|Fibromialgia
65|sus|Saúde da população em situação de rua
66|dermato|Dermatite atópica
67|aps|Abordagem e intervenções familiares
68|uro|Infecção urinária recorrente
69|paliativos|Ansiedade e cuidado no fim da vida
70|prenatal|Epilepsia na gestação
71|geriatria|Tontura e prevenção de quedas
72|otorrino|Lavagem otológica
73|urgencia|Ingestão de cáusticos
74|prevencao|Saúde planetária
75|osteo|Artrite reumatoide
76|mulher|Medicamentos durante a amamentação
77|sexualidade|Comunicação afirmativa
78|aps|Apoio matricial
79|aps|Desafios da Medicina de Família
80|mental|TDAH na infância
""",
36: """
1|mulher|Síndrome dos ovários policísticos
2|crianca|Asma e seguimento
3|geriatria|Avaliação funcional
4|cardio|Angina e investigação
5|aps|Cuidado integral no sistema prisional
6|aps|Competência cultural
7|prenatal|Diabetes gestacional
8|prenatal|Hipertensão gestacional
9|sus|Programa Acesso Mais Seguro
10|sexualidade|Hormonização de homens trans
11|mental|Avaliação de risco de suicídio
12|diabetes|Diabetes e tratamento da tuberculose
13|endocrino|Tratamento da obesidade
14|aps|Articulação da rede e cuidado do HIV
15|sexualidade|Disforia de gênero
16|infecto|PrEP para HIV
17|dermato|Melanoma
18|crianca|Otite média aguda
19|mulher|Contracepção natural
20|endocrino|Hipotireoidismo
21|geriatria|Lesão por pressão
22|prenatal|Vacinação na gestação
23|dermato|Escabiose
24|crianca|Puberdade precoce
25|infecto|Investigação de hepatite C
26|mulher|Tricomoníase
27|prevencao|Prevenção quaternária
28|mulher|Gravidez não planejada
29|aps|Diagnóstico comunitário por demanda
30|mulher|Infertilidade e infecção genital
31|diabetes|Diabetes e doença renal
32|vascular|Insuficiência venosa
33|crianca|Síndrome hemolítico-urêmica
34|aps|Método clínico centrado na pessoa
35|otorrino|Rinite alérgica
36|geriatria|Violência e sobrecarga do cuidador
37|sus|Racismo institucional
38|nefro|Lesão renal aguda e calor extremo
39|pneumo|Asma e redução terapêutica
40|mental|Uso de cocaína e autonomia
41|geriatria|Delirium
42|prevencao|Rastreamento do câncer colorretal
43|mental|TDAH em adultos
44|mulher|Sangramento uterino
45|osteo|Osteoporose
46|has|Tratamento inicial
47|mulher|Terapia hormonal na menopausa
48|aps|Comunicação clínica e anabolizantes
49|aps|Violência e articulação da rede social
50|cardio|Bloqueio atrioventricular
51|urgencia|Parada cardiorrespiratória
52|dermato|Onicomicose
53|aps|Acesso e organização da agenda
54|uro|Infertilidade masculina
55|pneumo|Pneumonia comunitária
56|dermato|Infecção de tecidos moles
57|mental|Psicose
58|vascular|Trombose venosa profunda
59|aps|Competência cultural e saúde indígena
60|prevencao|Saúde planetária e zoonoses
61|crianca|Crescimento e alimentação
62|prevencao|Vacinação de adultos
63|mental|Tratamento do uso de cocaína
64|osteo|Osteoartrite e infiltração
65|sexualidade|Contracepção em homens trans
66|oftalmo|Estrabismo infantil
67|crianca|Diarreia e desidratação
68|uro|Sintomas urinários na pós-menopausa
69|aps|Mediação de conflitos na equipe
70|osteo|Lombalgia
71|crianca|Bronquiolite
72|infecto|Hanseníase
73|aps|Abordagem familiar e genograma
74|mental|Deslocamento climático e saúde mental
75|prevencao|Saúde planetária e vulnerabilidade
76|prevencao|Saúde planetária e gestação
77|infecto|Dengue e sinais de alarme
78|mental|Insônia
79|diabetes|Investigação de diabetes na infância
80|aps|Coordenação do cuidado
""",
37: """
31|mulher|Violência sexual
32|crianca|Convulsão febril
33|mulher|Dor pélvica e endometriose
34|mental|Psicose e uso de substâncias
35|neuro|Cefaleia e sinais de alerta
36|mental|Insônia
37|osteo|Osteoporose e prevenção de fraturas
38|endocrino|Nódulo tireoidiano
39|paliativos|Dispneia refratária
40|cardio|Palpitações
41|aps|Método clínico centrado na pessoa
42|uro|Nefrolitíase
43|infecto|Sarampo
44|bucal|Leucoplasia oral
45|osteo|Gota
46|prenatal|Parasitoses na gestação
47|dermato|Acne e isotretinoína
48|crianca|Diarreia e desidratação
49|infecto|Prevenção da malária
50|aps|APS rural e atributos
51|paliativos|Elegibilidade para atenção domiciliar
52|neuro|Paralisia facial periférica
53|geriatria|Perda de peso involuntária
54|sus|Racismo institucional
55|infecto|PrEP para HIV
56|has|Metas pressóricas em idosos
57|dermato|Herpes-zóster
58|mental|Transtorno bipolar
59|procedimentos|Drenagem de abscesso
60|diabetes|Tratamento do diabetes tipo 2
61|cardio|Insuficiência cardíaca
62|aps|Entrevista motivacional e obesidade infantil
63|mental|Insônia e fitoterapia
64|mulher|Implante contraceptivo
65|mulher|Inserção de DIU
66|prevencao|Rastreamento do câncer de colo uterino
67|crianca|Refluxo do lactente
68|aps|Pessoas que consultam frequentemente
69|trabalho|Perda auditiva ocupacional
70|sus|Racismo e equidade no cuidado
71|aps|Competência cultural e asma infantil
72|vascular|Doença arterial periférica
73|geriatria|Desprescrição
74|has|Estratificação do risco cardiovascular
75|gastro|Investigação de sangue oculto nas fezes
76|has|Efeitos adversos dos anti-hipertensivos
77|mental|Abstinência de álcool
78|epidemio|Intervalo de confiança e ensaio clínico
79|uro|Síndrome de dor pélvica crônica
80|crianca|Sangramento intestinal
81|mulher|Mastalgia e alterações fibrocísticas
82|aps|Abordagem familiar e genograma
83|aps|Entrevista motivacional
84|osteo|Cervicalgia
85|pics|Homeopatia
86|geriatria|Polifarmácia e desprescrição
87|sexualidade|Disforia de gênero
88|crianca|Violência sexual e rede de cuidado
89|prenatal|Seguimento de risco habitual
90|prenatal|Hipertensão no puerpério
91|sus|Equidade e pré-natal quilombola
92|prevencao|Escolas promotoras de saúde
93|prenatal|Vacinação contra VSR
94|aps|Estimativa rápida
95|sexualidade|Comunicação clínica sobre sexualidade
96|geriatria|Desprescrição e efeitos adversos
97|aps|Determinantes sociais e cuidado infantil
98|infecto|Doença de Chagas
99|epidemio|Risco relativo e estudos de coorte
100|cardio|Estenose aórtica
101|pneumo|Pneumonia no idoso
102|mulher|Terapia hormonal na menopausa
103|mental|Luto complicado
104|paliativos|Náuseas induzidas por opioides
105|prevencao|Cessação do tabagismo
106|sexualidade|Disfunção sexual
107|infecto|Diagnóstico laboratorial de sífilis
108|aps|Acesso e participação social
109|sus|Política de saúde prisional
110|sexualidade|Hormonização de mulheres trans
""",
}


def main():
    mappings = {}
    for edition, rows in REVIEWED.items():
        mappings[edition] = {}
        for row in rows.strip().splitlines():
            number, topic, subtopic = row.split("|", 2)
            assert topic in TOPICS
            assert int(number) not in mappings[edition]
            mappings[edition][int(number)] = (topic,subtopic)
        assert len(mappings[edition]) == 80
    path = ROOT/"data/questions.json"
    bank = json.loads(path.read_text())
    for q in bank:
        topic, subtopic = mappings[q["edition"]][q["original_number"]]
        q.update({"topic_id":topic,"topic":TOPICS[topic],"subtopic":subtopic,
                  "classification_method":"editorial_review_of_source",
                  "source_warnings":[]})
        if q["annulled"]:
            q["source_warnings"].append("Questão marcada como ANULADA no enunciado; o gabarito também contém uma letra. A letra foi preservada, mas a questão não deve compor a pontuação ou a revisão por erro.")
        if q["edition"] == 35 and q["original_number"] == 60:
            q["source_warnings"].append("O enunciado menciona ECG abaixo, mas a imagem não consta no PDF fornecido.")
    path.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
    (ROOT/"data/topics.json").write_text(json.dumps([
        {"id":k,"name":v,"question_count":sum(q["topic_id"]==k for q in bank)}
        for k,v in TOPICS.items()],ensure_ascii=False,indent=2)+"\n")
    print(f"Classified {len(bank)} questions in {len(TOPICS)} topics.")


if __name__ == "__main__":
    main()
