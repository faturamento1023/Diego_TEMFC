#!/usr/bin/env python3
"""Extract the supplied TEMFC PDFs without OCR or generated question content.

Only page furniture, item metadata and the explicit correction badge in TEMFC 36
are removed. Original wording, spelling and punctuation are kept. Text wrapping
is preserved in ``stem`` and each alternative. The source hashes and page
coordinates make every record traceable. Run from the repository root.
"""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
SOURCES = DATA / "sources"
MEDIA = DATA / "media"
YEARS = {34: 2024, 35: 2024, 36: 2025, 37: 2026}
DRIVE_IDS = {
    34: "1yff-tn1l4bTMh57ZLIqOhFJD_iQo2Po7",
    35: "1LKtfYSCbQyBBmxGDT4h1R7WyhKJABnQx",
    36: "1JHVRrliUtdwUD4XxgbomVcSAXAwMWSjH",
    37: "1Paxm3M5kI25Yl4A5xAJvA7Z6ZwSg38C3",
}


def page_lines(page, edition):
    """Return native PDF lines in the PDF's content order, with provenance."""
    lower, upper = {34: (85, 735), 35: (119, 755),
                    36: (35, 798), 37: (110, 744)}[edition]
    lines = []
    for block in page.get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            text = "".join(span["text"] for span in line["spans"]).strip()
            bbox = line["bbox"]
            if text and lower <= bbox[1] < upper:
                lines.append({"text": text, "page": page.number + 1,
                              "bbox": [round(v, 3) for v in bbox]})
    return lines


def parse_key(doc, edition):
    pages = [p for p in doc if ("GABARITO" in p.get_text().upper()
                               or "Posição do" in p.get_text())]
    # TEMFC 37's answer table continues for two more pages.
    if edition == 37:
        pages = list(doc)[pages[0].number:]
    text = "\n".join(p.get_text() for p in pages)
    pairs = (re.findall(r"(?m)^\s*(\d+)\s*\n\s*(\d+)\s*\n\s*([ABCD])\s*$", text)
             if edition == 36 else
             re.findall(r"(?m)^\s*(\d+)\s*\n\s*([ABCD])\s*$", text))
    keys = {}
    codes = {}
    for pair in pairs:
        number, answer = int(pair[0]), pair[-1]
        if number in keys:
            raise ValueError(f"Duplicate key: TEMFC {edition}, question {number}")
        keys[number] = answer
        if edition == 36:
            codes[number] = int(pair[1])
    return keys, codes, [p.number + 1 for p in pages]


def meaningful_images(page, edition):
    """Ignore logos, separators and rasterized page wrappers."""
    boxes = []
    for info in page.get_image_info():
        r = fitz.Rect(info["bbox"])
        if edition == 34:
            keep = r.y0 > 100 and r.height > 35 and r.width > 50
        elif edition == 35:
            keep = r.y0 > 125 and r.height > 35 and r.width > 50
        elif edition == 36:
            # This PDF wraps question 50 in a full-page screenshot, with OCR.
            # Only the innermost original ECG is a question figure.
            keep = 200 < r.y0 < 300 and 150 < r.height < 250 and r.width > 300
        else:
            keep = r.y0 > 135 and r.y1 < 744 and r.height > 35 and r.width > 50
        if keep and not any(abs(r.x0-b.x0) < 1 and abs(r.y0-b.y0) < 1 for b in boxes):
            boxes.append(r)
    return boxes


def extract_exam(edition):
    source = SOURCES / f"temfc-{edition}.pdf"
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    doc = fitz.open(source)
    key, key_codes, key_pages = parse_key(doc, edition)
    # TEMFC 36 has question 80 and the beginning of its key on the same page.
    stop_page = min(key_pages) if edition == 36 else min(key_pages)-1
    events = [line for p in doc[:stop_page] for line in page_lines(p, edition)]
    if edition == 36:
        summary = next(i for i,e in enumerate(events) if e["text"] == "Resumo")
        events = events[:summary]
    lines = [e["text"] for e in events]
    starts = []
    for i, text in enumerate(lines):
        if edition < 36 and text == "QUESTÃO":
            number = int(lines[i+1])
            code = int(re.fullmatch(r"Cod\s*-\s*(\d+)", lines[i+2])[1])
            starts.append((i, i+3, number, code))
        elif edition == 36 and (m := re.fullmatch(r"Posição:\s*(\d+)", text)):
            code = int(re.fullmatch(r"Código do Item:\s*(\d+)", lines[i+1])[1])
            body = next(j for j in range(i+1, i+10)
                        if lines[j] == "escolha - Resposta Única") + 1
            starts.append((i, body, int(m[1]), code))
        elif edition == 37 and (m := re.fullmatch(r"CÓDIGO DA QUESTÃO\s*[–-]\s*(\d+)", text)):
            starts.append((i, i+1, int(m[1]), int(m[1])))

    questions = []
    for index, (start, body, number, code) in enumerate(starts):
        end = starts[index+1][0] if index+1 < len(starts) else len(events)
        part = events[body:end]
        option_re = {34:r"([ABCD])\s*-\s*(.*)",35:r"([ABCD])\s*-\s*(.*)",
                     36:r"([ABCD])\.",37:r"([ABCD])\)\s*(.*)"}[edition]
        markers = [(i,re.fullmatch(option_re,e["text"])) for i,e in enumerate(part)]
        markers = [(i,m) for i,m in markers if m]
        if [m[1] for i,m in markers] != list("ABCD"):
            raise ValueError(f"Invalid alternatives: TEMFC {edition} / {number}: {markers}")
        stem_events = [e for e in part[:markers[0][0]] if e["text"] != "Resposta correta"]
        opts = []
        badges = []
        for a, (pos, match) in enumerate(markers):
            stop = markers[a+1][0] if a < 3 else len(part)
            if edition == 36 and pos and part[pos-1]["text"] == "Resposta correta":
                badges.append(match[1])
            content = ([] if edition == 36 else [match[2]])
            content += [e["text"] for e in part[pos+1:stop] if e["text"] != "Resposta correta"]
            opts.append({"label":match[1], "original_marker":
                         match[1]+({34:" -",35:" -",36:".",37:")"}[edition]),
                         "text":"\n".join(content).strip()})
        if edition == 36 and (badges != [key[number]] or key_codes[number] != code):
            raise ValueError(f"Inline answer / official table mismatch: {edition}/{number}")
        if number not in key:
            raise ValueError(f"Missing key: TEMFC {edition}, question {number}")
        qid = f"temfc-{edition}-q-{number:03d}"
        media = []
        # Native diagram content may occupy whitespace in the text layer.
        first_page, last_page = events[start]["page"], events[end-1]["page"]
        for pn in range(first_page, last_page+1):
            page = doc[pn-1]
            start_y = events[start]["bbox"][1] if pn == first_page else 0
            end_y = events[end]["bbox"][1] if end < len(events) and events[end]["page"] == pn else 744
            for rect in meaningful_images(page, edition):
                if rect.y0 >= start_y and rect.y0 < end_y:
                    asset = f"{qid}-{len(media)+1}.png"
                    page.get_pixmap(matrix=fitz.Matrix(2,2),clip=rect,alpha=False).save(MEDIA/asset)
                    prior = sum(1 for e in stem_events
                                if e["page"] < pn or (e["page"] == pn and e["bbox"][1] < rect.y0))
                    media.append({"path":f"data/media/{asset}","page":pn,
                                  "bbox":[round(v,3) for v in rect],
                                  "after_stem_line":prior,
                                  "sha256":hashlib.sha256((MEDIA/asset).read_bytes()).hexdigest()})
        stem = "\n".join(e["text"] for e in stem_events)
        q = {"id":qid,"exam_id":f"temfc-{edition}","edition":edition,"year":YEARS[edition],
             "position":index+1,"original_number":number,"original_item_code":code,
             "stem":stem,"alternatives":opts,"official_answer":key[number],
             "annulled":bool(re.search(r"ANULADA",stem)),"media":media,
             "source":{"drive_id":DRIVE_IDS[edition],
                       "filename":f"TEMFC {edition} - {YEARS[edition]} - Prova teórica com gabarito.pdf",
                       "local_filename":source.name,
                       "sha256":source_hash,"start_page":first_page,"end_page":last_page,
                       "key_pages":key_pages},"explanation":None,
             "explanation_status":"not_provided_by_source"}
        q["content_sha256"] = hashlib.sha256(json.dumps(
            {k:q[k] for k in ["stem","alternatives","official_answer","annulled"]},
            ensure_ascii=False,sort_keys=True).encode()).hexdigest()
        questions.append(q)
    expected = set(range(31,111) if edition == 37 else range(1,81))
    actual = {q["original_number"] for q in questions}
    if actual != expected or actual != set(key) or len(questions) != 80:
        raise ValueError(f"Question/key coverage mismatch in TEMFC {edition}: {actual ^ expected}; {actual ^ set(key)}")
    exam = {"id":f"temfc-{edition}","edition":edition,"year":YEARS[edition],
            "title":f"TEMFC {edition} — {YEARS[edition]}","question_count":len(questions),
            "answer_key_count":len(key),"pdf_pages":len(doc),"key_pages":key_pages,
            "source_drive_id":DRIVE_IDS[edition],"source_sha256":source_hash,
            "annulled_numbers":[q["original_number"] for q in questions if q["annulled"]]}
    return exam, questions


def main():
    MEDIA.mkdir(exist_ok=True)
    exams, bank = [], []
    for edition in YEARS:
        exam, questions = extract_exam(edition)
        exams.append(exam)
        bank.extend(questions)
        print(json.dumps(exam,ensure_ascii=False))
    if len({q["id"] for q in bank}) != len(bank):
        raise ValueError("Duplicate global question ID")
    (DATA/"questions.json").write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
    (DATA/"exams.json").write_text(json.dumps(exams,ensure_ascii=False,indent=2)+"\n")
    print(f"Extracted {len(bank)} questions; {sum(len(q['media']) for q in bank)} native figures.")


if __name__ == "__main__":
    main()
