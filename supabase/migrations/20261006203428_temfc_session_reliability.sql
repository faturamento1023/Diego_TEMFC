-- Idempotent starts, all incomplete sessions, strict due priority and offline timestamps.
create unique index session_request_idx on public.study_sessions(user_id,(config->>'request_id')) where config ? 'request_id';
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
      left join topic_stats ts on ts.topic_id=q.topic_id where not q.annulled
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

create or replace function private.save_action(op uuid,sid uuid,action text,payload jsonb,expected_revision integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); s public.study_sessions%rowtype; saved jsonb; pos integer; seconds_value integer;
  answer_value text; item record; response jsonb; when_answered timestamptz;
begin
  if u is null then raise exception 'Login required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtext(u::text||op::text));
  select result into saved from public.sync_operations where user_id=u and operation_id=op;
  if found then return saved; end if;
  if action='favorite' then
    if (payload->>'value')::boolean then
      insert into public.favorites(user_id,question_id) values(u,payload->>'question_id') on conflict do nothing;
    else delete from public.favorites where user_id=u and question_id=payload->>'question_id'; end if;
    response:=jsonb_build_object('favorite',(payload->>'value')::boolean);
  else
    select * into s from public.study_sessions where id=sid and user_id=u for update;
    if not found then raise exception 'Session not found' using errcode='42501'; end if;
    if s.status<>'active' then raise exception 'Esta sessão já foi finalizada. Recarregue para ver o resultado.' using errcode='PT409'; end if;
    if action<>'heartbeat' and expected_revision is distinct from s.revision then
      raise exception 'Esta sessão foi alterada em outro aparelho. Recarregue antes de continuar.' using errcode='PT409';
    end if;
    seconds_value:=least(300,greatest(0,coalesce((payload->>'seconds')::integer,0)));
    if seconds_value>0 then
      update public.study_sessions set elapsed_seconds=elapsed_seconds+seconds_value where id=sid and user_id=u;
      update public.session_questions set spent_seconds=spent_seconds+seconds_value
        where session_id=sid and user_id=u and position=s.current_position;
      perform private.add_study_time(u,seconds_value);
    end if;
    pos:=coalesce((payload->>'position')::integer,s.current_position);
    if pos not between 1 and s.question_count then raise exception 'Invalid question position'; end if;
    if action='answer' then
      answer_value:=nullif(payload->>'answer','');
      if answer_value is not null and answer_value not in ('A','B','C','D') then raise exception 'Invalid answer'; end if;
      if exists(select 1 from public.session_questions where session_id=sid and position=pos and user_id=u and graded) then
        raise exception 'Esta resposta já foi corrigida. Inicie uma revisão para tentar novamente.';
      end if;
      when_answered:=least(now(),greatest(now()-interval '30 days',coalesce((payload->>'answered_at')::timestamptz,now())));
      if s.expires_at is not null and when_answered>s.expires_at then raise exception 'O tempo do simulado terminou. Finalize para corrigir.'; end if;
      update public.session_questions set selected_answer=answer_value,answered_at=case when answer_value is null then null else when_answered end
        where session_id=sid and position=pos and user_id=u;
      if s.correction='immediate' and answer_value is not null then perform private.grade_answer(sid,pos); end if;
    elsif action='cursor' then
      update public.study_sessions set current_position=pos where id=sid and user_id=u;
    elsif action='mark' then
      update public.session_questions set marked=coalesce((payload->>'value')::boolean,false) where session_id=sid and position=pos and user_id=u;
    elsif action='finish' then
      for item in select position from public.session_questions where session_id=sid and user_id=u order by position loop
        perform private.grade_answer(sid,item.position);
      end loop;
      update public.study_sessions set status='completed',finished_at=now(),
        elapsed_seconds=case when mode='mock' then greatest(elapsed_seconds,extract(epoch from now()-started_at)::integer) else elapsed_seconds end
        where id=sid and user_id=u;
    elsif action<>'heartbeat' then raise exception 'Invalid action'; end if;
    update public.study_sessions set revision=revision+case when action='heartbeat' then 0 else 1 end,
      updated_at=now() where id=sid and user_id=u;
    response:=jsonb_build_object('revision',s.revision+case when action='heartbeat' then 0 else 1 end);
    if action='answer' and s.correction='immediate' then
      select jsonb_build_object('position',sq.position,'is_correct',sq.is_correct,'graded',sq.graded,
        'official_answer',case when sq.graded then k.official_answer else null end,
        'explanation',case when sq.graded then k.explanation else null end,
        'explanation_source',case when sq.graded then k.explanation_source else null end)
        into saved from public.session_questions sq join private.answer_keys k on k.question_id=sq.question_id
        where sq.session_id=sid and sq.position=pos and sq.user_id=u;
      response:=response||saved;
    end if;
  end if;
  insert into public.sync_operations(user_id,operation_id,result) values(u,op,response);
  return response;
end $$;

create or replace function public.get_study_dashboard() returns jsonb language plpgsql security invoker set search_path='' as $$
declare u uuid:=auth.uid(); profile public.profiles%rowtype; totals jsonb; today_value date; day_data jsonb; current_streak integer; best_streak integer;
begin
  if u is null then raise exception 'Login required' using errcode='42501'; end if;
  select * into profile from public.profiles where id=u;
  today_value:=(now() at time zone profile.timezone)::date;
  select jsonb_build_object('answered',count(*),'correct',count(*) filter(where is_correct),
    'errors',count(*) filter(where not is_correct),'percentage',round(100.0*count(*) filter(where is_correct)/nullif(count(*),0),1))
    into totals from public.user_answers where user_id=u and not annulled;
  with days as(select day,row_number() over(order by day)::integer as rn from public.daily_progress where user_id=u and answered_count>0),
    groups as(select min(day) as first,max(day) as last,count(*)::integer as size from days group by day-rn)
    select coalesce(max(size) filter(where last>=today_value-1),0),coalesce(max(size),0) into current_streak,best_streak from groups;
  select to_jsonb(d) into day_data from public.daily_progress d where user_id=u and day=today_value;
  return jsonb_build_object('profile',to_jsonb(profile),'totals',totals,'today',coalesce(day_data,'{}'::jsonb),
    'streak',current_streak,'best_streak',best_streak,'bank_total',(select count(*) from public.questions),'bank_valid',(select count(*) from public.questions where not annulled),
    'studied_distinct',(select count(*) from public.question_progress where user_id=u and last_answer is not null),
    'unseen',(select count(*) from public.questions q where not exists(select 1 from public.question_progress p where p.question_id=q.id and p.user_id=u)),
    'due',(select count(*) from public.review_queue where user_id=u and next_due_at<=now()),
    'mastered',(select count(*) from public.question_progress where user_id=u and mastery>=4),
    'favorites',(select count(*) from public.favorites where user_id=u),
    'topic_stats',coalesce((select jsonb_agg(to_jsonb(t) order by t.percentage,t.answered desc) from public.topic_performance t where user_id=u),'[]'::jsonb),
    'exam_stats',coalesce((select jsonb_agg(to_jsonb(e) order by e.title) from public.exam_performance e where user_id=u),'[]'::jsonb),
    'daily',coalesce((select jsonb_agg(to_jsonb(d) order by d.day) from public.daily_progress d where user_id=u and day>=today_value-29),'[]'::jsonb),
    'sessions',coalesce((select jsonb_agg(to_jsonb(s) order by s.updated_at desc) from
      (select * from public.study_sessions where user_id=u and status='active' union all
       (select * from public.study_sessions where user_id=u and status='completed' order by updated_at desc limit 30)) s),'[]'::jsonb));
end $$;

