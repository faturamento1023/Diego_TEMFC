#!/usr/bin/env python3
"""Fail closed on incomplete or altered data; independently verify PDF keys."""
import hashlib
import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import pdfplumber

ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def independent_key(edition, pages):
    result = {}
    with pdfplumber.open(ROOT/f"data/sources/temfc-{edition}.pdf") as doc:
        for pn in pages:
            text = doc.pages[pn-1].extract_text()
            pattern = (r"(?m)^(\d+)\s+(\d+)\s+([ABCD])\s*$" if edition == 36
                       else r"\b(\d+)\s+([ABCD])\b")
            for match in re.finditer(pattern,text):
                num, answer = int(match[1]), match[len(match.groups())]
                require(num not in result, f"Repeated independent key {edition}/{num}")
                result[num] = answer
    return result


def main():
    bank = json.loads((ROOT/"data/questions.json").read_text())
    exams = json.loads((ROOT/"data/exams.json").read_text())
    topics = json.loads((ROOT/"data/topics.json").read_text())
    require(len(bank) == 320, "Expected 320 source questions")
    require(len({q["id"] for q in bank}) == 320,"Duplicate global IDs")
    require(len({(q["edition"],q["original_number"]) for q in bank}) == 320,"Duplicate source numbers")
    topic_ids = {t["id"] for t in topics}
    results = []
    for exam in exams:
        edition = exam["edition"]
        questions = [q for q in bank if q["edition"] == edition]
        numbers = [q["original_number"] for q in questions]
        expected = list(range(31,111) if edition == 37 else range(1,81))
        require(numbers == expected,f"Missing or reordered questions in {edition}")
        require([q["position"] for q in questions] == list(range(1,81)),f"Invalid positions in {edition}")
        require(len(questions) == exam["question_count"] == exam["answer_key_count"] == 80,"Invalid exam count")
        require(len({q["original_item_code"] for q in questions}) == 80,"Repeated source item code")
        key = independent_key(edition,exam["key_pages"])
        require(set(key) == set(expected),f"Independent key coverage mismatch for {edition}")
        require(hashlib.sha256((ROOT/f"data/sources/temfc-{edition}.pdf").read_bytes()).hexdigest()
                == exam["source_sha256"],"Changed source PDF")
        for q in questions:
            require(q["stem"].strip(),f"Empty stem: {q['id']}")
            require([a["label"] for a in q["alternatives"]] == list("ABCD"),f"Bad alternatives: {q['id']}")
            require(all(a["text"].strip() for a in q["alternatives"]),f"Empty option: {q['id']}")
            require(q["official_answer"] == key[q["original_number"]],f"Wrong key: {q['id']}")
            require(q["topic_id"] in topic_ids and q["subtopic"],f"Missing classification: {q['id']}")
            require(q["explanation"] is None,"Source does not supply an explanation")
            require("Resposta correta" not in q["stem"] and all("Resposta correta" not in a["text"]
                    for a in q["alternatives"]),"Correction badge leaked into study content")
            checksum = hashlib.sha256(json.dumps({k:q[k] for k in
                ["stem","alternatives","official_answer","annulled"]},
                ensure_ascii=False,sort_keys=True).encode()).hexdigest()
            require(checksum == q["content_sha256"],f"Source content altered after extraction: {q['id']}")
            for asset in q["media"]:
                data = (ROOT/asset["path"]).read_bytes()
                require(hashlib.sha256(data).hexdigest() == asset["sha256"],f"Corrupt figure: {asset['path']}")
            require(q["source"]["start_page"] <= q["source"]["end_page"],"Invalid page range")
        require([q["original_number"] for q in questions if q["annulled"]] == exam["annulled_numbers"],
                "Incorrect annulment metadata")
        results.append({"edition":edition,"year":exam["year"],"questions":len(questions),
                        "alternatives":sum(len(q["alternatives"]) for q in questions),
                        "independently_verified_keys":len(key),
                        "annulled":exam["annulled_numbers"],"status":"passed"})
        # Keep independent per-exam import units small, preserving the source order.
        (ROOT/f"data/temfc-{edition}.json").write_text(json.dumps(questions,ensure_ascii=False,indent=2)+"\n")
    report = {"validated_at":datetime.now(timezone.utc).isoformat(),"status":"passed",
              "exams":results,"total_questions":len(bank),"total_alternatives":1280,
              "valid_scoring_questions":sum(not q["annulled"] for q in bank),
              "total_figures":sum(len(q["media"]) for q in bank),
              "total_topics":len(topics),"topic_distribution":dict(Counter(q["topic"] for q in bank)),
              "duplicate_ids":0,"missing_questions":0,"unmatched_keys":0,
              "empty_alternatives":0,"modified_content_checksums":0,
              "issues":[
                  {"question_id":"temfc-34-q-025","kind":"annulled_with_letter_in_key","letter":"C"},
                  {"question_id":"temfc-35-q-060","kind":"annulled_with_letter_in_key","letter":"A"},
                  {"question_id":"temfc-35-q-060","kind":"ecg_missing_in_supplied_pdf"}],
              "live_supabase_validation":"pending_authorization_to_create_dedicated_project"}
    (ROOT/"docs/bank-validation.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({k:v for k,v in report.items() if k not in ["topic_distribution"]},ensure_ascii=False,indent=2))


if __name__ == "__main__":
    main()
