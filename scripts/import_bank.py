#!/usr/bin/env python3
"""Render bounded, idempotent SQL import batches from verified source JSON.

Used with the connected Supabase execute_sql tool. Never uses a privileged
credential in the app. New exams can be appended to data/temfc-*.json.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def literal(value):
    data = json.dumps(value,ensure_ascii=False,separators=(',',':'))
    assert '$temfc_json$' not in data
    return '$temfc_json$'+data+'$temfc_json$::jsonb'


def catalog():
    exams=json.loads((ROOT/'data/exams.json').read_text())
    topics=json.loads((ROOT/'data/topics.json').read_text())
    return f"""do $import$
declare exams jsonb:={literal(exams)}; topics jsonb:={literal(topics)};
begin
  insert into public.exams(id,edition,year,title,question_count,official_duration_seconds,source)
    select e->>'id',(e->>'edition')::integer,(e->>'year')::integer,e->>'title',(e->>'question_count')::integer,
      case when e->>'edition'='36' then 18000 else null end,e
    from jsonb_array_elements(exams) e on conflict(id) do nothing;
  insert into public.topics(id,name) select t->>'id',t->>'name' from jsonb_array_elements(topics) t on conflict(id) do nothing;
end $import$;"""


def batch(number,size=20):
    bank=[]
    for p in sorted((ROOT/'data').glob('temfc-*.json')):
        bank.extend(json.loads(p.read_text()))
    values=bank[number*size:(number+1)*size]
    if not values:raise ValueError('Empty batch')
    return f"""do $import$
declare items jsonb:={literal(values)};
begin
  if exists(select 1 from jsonb_array_elements(items) i join public.questions q on q.id=i->>'id'
    where q.content_sha256<>i->>'content_sha256') then raise exception 'Existing question differs from source'; end if;
  insert into public.questions(id,exam_id,position,original_number,original_item_code,topic_id,subtopic,stem,annulled,media,source,source_warnings,content_sha256)
    select i->>'id',i->>'exam_id',(i->>'position')::integer,(i->>'original_number')::integer,(i->>'original_item_code')::integer,
      i->>'topic_id',i->>'subtopic',i->>'stem',(i->>'annulled')::boolean,i->'media',i->'source',i->'source_warnings',i->>'content_sha256'
    from jsonb_array_elements(items) i on conflict(id) do nothing;
  insert into public.question_options(question_id,label,original_marker,text)
    select i->>'id',o->>'label',o->>'original_marker',o->>'text'
    from jsonb_array_elements(items) i cross join lateral jsonb_array_elements(i->'alternatives') o
    on conflict(question_id,label) do nothing;
  insert into private.answer_keys(question_id,official_answer)
    select i->>'id',i->>'official_answer' from jsonb_array_elements(items) i on conflict(question_id) do nothing;
end $import$;
select count(*) as imported_questions from public.questions;"""


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--catalog',action='store_true')
    parser.add_argument('--batch',type=int,default=0)
    args=parser.parse_args()
    print(catalog() if args.catalog else batch(args.batch))
