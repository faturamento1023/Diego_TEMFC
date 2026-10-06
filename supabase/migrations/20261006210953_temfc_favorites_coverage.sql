-- Favorite collections preserve annulled official content, without scoring it.
create or replace function private.start_session(mode_value text, count_value integer, settings jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); sid uuid; picks text[]; n integer:=least(1000,greatest(1,count_value));
  how text:=coalesce(settings->>'correction','immediate'); label text; seconds_limit integer; avg_time numeric; maintenance text;
begin
  if u is null then raise exception 'Login required' using errcode='42501'; end if;
  if mode_value not in ('adaptive','quick','review','mock','favorites','bank') then raise exception 'Invalid mode'; end if;
  perform pg_advisory_xact_lock(hashtext(u::text));
  if settings ? 'request_id' then
    select id into sid from public.study_sessions where user_id=u and config->>'request_id'=settings->>'request_id';
    if sid is not null then return private.session_bundle(sid); end if;
  end if;
  if mode_value='adaptive' and coalesce((settings->>'resume')::boolean,true) then
    select id into sid from public.study_sessions where user_id=u and status='active' and mode in ('adaptive','quick') order by updated_at desc limit 1;
    if sid is not null then return private.session_bundle(sid); end if;
  end if;
  if settings->>'minutes'='10' then
    select avg(spent_seconds) into avg_time from public.user_answers where user_id=u and spent_seconds between 15 and 300;
    n:=least(20,greatest(3,floor(600/coalesce(avg_time,60))::integer));
  end if;
  if mode_value='mock' then
    how:='final'; label:='Simulado completo';
    if coalesce(settings->>'exam_id','') <> '' then
      select array_agg(id order by position) into picks from public.questions where exam_id=settings->>'exam_id';
      select title into label from public.exams where id=settings->>'exam_id';
    else
      select array_agg(id) into picks from (select id from public.questions where not annulled order by random() limit n) q;
      label:='Simulado misto';
    end if;
  elsif mode_value='bank' then
    select array_agg(id order by position) into picks from public.questions where id=settings->>'question_id';
    label:='Questão do banco';
  else
    label:=case mode_value when 'adaptive' then 'Preparação inteligente' when 'quick' then 'Modo rápido'
      when 'review' then 'Revisar erros' else 'Questões favoritas' end;
    if settings ? 'source_session_id' and not exists(select 1 from public.study_sessions
      where id=(settings->>'source_session_id')::uuid and user_id=u and status='completed') then
      raise exception 'Invalid review source' using errcode='42501';
    end if;
    with topic_stats as (
      select q.topic_id,sum(p.correct_count)::numeric/nullif(sum(p.attempts),0) as rate,sum(p.attempts) as attempts
      from public.question_progress p join public.questions q on q.id=p.question_id where p.user_id=u group by q.topic_id
    ), candidates as (
      select q.id,q.topic_id, p.mastery,
        case when p.next_review_at<=now() then 0 when p.error_count>=2 and p.mastery<4 then 1
          when ts.attempts>=3 and ts.rate<0.65 and coalesce(p.mastery,0)<4 then 2
          when p.user_id is null then 3 else 4 end as priority,random() as random_order
      from public.questions q left join public.question_progress p on p.question_id=q.id and p.user_id=u
      left join topic_stats ts on ts.topic_id=q.topic_id where (not q.annulled or mode_value='favorites')
      and (coalesce(settings->>'exam_id','')='' or q.exam_id=settings->>'exam_id')
      and (coalesce(settings->>'topic_id','')='' or q.topic_id=settings->>'topic_id')
      and (mode_value<>'favorites' or exists(select 1 from public.favorites f where f.user_id=u and f.question_id=q.id))
      and (mode_value<>'review' or (p.error_count>0
        and (coalesce(settings->>'filter','all')<>'recent' or p.last_error_at>=now()-interval '7 days')
        and (coalesce(settings->>'filter','all')<>'repeated' or p.error_count>=2)
        and (coalesce(settings->>'filter','all')<>'unmastered' or p.mastery<4)
        and (coalesce(settings->>'filter','all')<>'mastered' or p.mastery>=4)
        and (not (settings ? 'source_session_id') or exists(select 1 from public.session_questions sq
          where sq.session_id=(settings->>'source_session_id')::uuid and sq.user_id=u and sq.question_id=q.id and sq.is_correct=false))))
    ), diverse as (
      select *,row_number() over(partition by topic_id order by priority,random_order) as within_topic from candidates
    ), ordered as (
      select * from diverse order by priority,case when within_topic<=greatest(2,ceil(n*0.4)) then 0 else 1 end,random_order limit n
    ) select array_agg(id order by priority,random_order) into picks from ordered;
    -- Keep one already learned item for maintenance, after higher-priority items.
    if mode_value in ('adaptive','quick') and coalesce(array_length(picks,1),0)=n and n>=5 then
      select q.id into maintenance from public.question_progress p join public.questions q on q.id=p.question_id
        where p.user_id=u and p.mastery>=4 and not q.annulled and not(q.id=any(picks)) order by random() limit 1;
      if maintenance is not null then picks[n]:=maintenance; end if;
    end if;
  end if;
  n:=coalesce(array_length(picks,1),0);
  if n=0 then raise exception 'Nenhuma questão encontrada para esta seleção.'; end if;
  if how not in ('immediate','final') then raise exception 'Invalid correction'; end if;
  seconds_limit:=nullif(settings->>'time_limit_seconds','')::integer;
  if seconds_limit is not null and seconds_limit not between 60 and 43200 then raise exception 'Invalid time limit'; end if;
  insert into public.study_sessions(user_id,mode,correction,title,question_count,config,expires_at)
    values(u,mode_value,how,label,n,settings,case when mode_value='mock' and seconds_limit is not null
      then now()+make_interval(secs=>seconds_limit) else null end) returning id into sid;
  insert into public.session_questions(session_id,user_id,position,question_id)
    select sid,u,ordinality::integer,id from unnest(picks) with ordinality as picked(id,ordinality);
  return private.session_bundle(sid);
end $$;

