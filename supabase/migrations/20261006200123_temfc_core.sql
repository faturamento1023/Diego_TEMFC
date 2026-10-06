-- TEMFC: catalog immutable to students; all personal data belongs to auth.uid().
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Estudante' check (length(display_name) between 1 and 80),
  daily_goal integer not null default 10 check (daily_goal between 1 and 200),
  timezone text not null default 'America/Sao_Paulo' check (timezone in ('America/Sao_Paulo','UTC')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.exams (
  id text primary key, edition integer not null unique, year integer not null,
  title text not null, question_count integer not null check(question_count > 0),
  official_duration_seconds integer, source jsonb not null
);
create table public.topics (id text primary key, name text not null unique);
create table public.questions (
  id text primary key, exam_id text not null references public.exams(id),
  position integer not null check(position > 0), original_number integer not null,
  original_item_code integer not null, topic_id text not null references public.topics(id),
  subtopic text not null, stem text not null check(length(stem) > 0),
  annulled boolean not null default false, media jsonb not null default '[]',
  source jsonb not null, source_warnings jsonb not null default '[]',
  content_sha256 text not null check(length(content_sha256) = 64),
  unique(exam_id,position), unique(exam_id,original_number), unique(exam_id,original_item_code),
  check(jsonb_typeof(media) = 'array'), check(jsonb_typeof(source_warnings) = 'array')
);
create index questions_topic_idx on public.questions(topic_id,exam_id);
create table public.question_options (
  question_id text not null references public.questions(id) on delete cascade,
  label text not null check(label in ('A','B','C','D')),
  original_marker text not null, text text not null check(length(text)>0),
  primary key(question_id,label)
);
create table private.answer_keys (
  question_id text primary key references public.questions(id) on delete cascade,
  official_answer text not null check(official_answer in ('A','B','C','D')),
  explanation text, explanation_source text,
  check(explanation is null or explanation_source is not null),
  foreign key(question_id,official_answer) references public.question_options(question_id,label)
    deferrable initially deferred
);
alter table private.answer_keys enable row level security;

create table public.study_sessions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  mode text not null check(mode in ('adaptive','quick','review','mock','favorites','bank')),
  correction text not null check(correction in ('immediate','final')),
  status text not null default 'active' check(status in ('active','completed')),
  title text not null, question_count integer not null check(question_count between 1 and 1000),
  current_position integer not null default 1, elapsed_seconds integer not null default 0 check(elapsed_seconds>=0),
  revision integer not null default 0 check(revision>=0), config jsonb not null default '{}',
  started_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  finished_at timestamptz, expires_at timestamptz,
  unique(id,user_id), check(current_position between 1 and question_count),
  check(mode <> 'mock' or correction = 'final'),
  check((status = 'completed') = (finished_at is not null))
);
create index sessions_owner_status_idx on public.study_sessions(user_id,status,updated_at desc);
create table public.session_questions (
  session_id uuid not null, user_id uuid not null references public.profiles(id) on delete cascade,
  position integer not null check(position > 0), question_id text not null references public.questions(id),
  selected_answer text check(selected_answer in ('A','B','C','D')), marked boolean not null default false,
  graded boolean not null default false, is_correct boolean,
  answered_at timestamptz, graded_at timestamptz, spent_seconds integer not null default 0 check(spent_seconds>=0),
  primary key(session_id,position), unique(session_id,question_id),
  foreign key(session_id,user_id) references public.study_sessions(id,user_id) on delete cascade,
  foreign key(question_id,selected_answer) references public.question_options(question_id,label),
  check(graded or is_correct is null)
);
create index session_questions_owner_idx on public.session_questions(user_id,question_id);
create table public.user_answers (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid not null, position integer not null, question_id text not null references public.questions(id),
  selected_answer text not null check(selected_answer in ('A','B','C','D')), is_correct boolean,
  annulled boolean not null, spent_seconds integer not null check(spent_seconds>=0),
  answered_at timestamptz not null, graded_at timestamptz not null default now(),
  unique(session_id,position), foreign key(session_id,position) references public.session_questions(session_id,position),
  foreign key(session_id,user_id) references public.study_sessions(id,user_id) on delete cascade,
  foreign key(question_id,selected_answer) references public.question_options(question_id,label),
  check((is_correct is null) = annulled)
);
create index answers_owner_date_idx on public.user_answers(user_id,answered_at desc);
create index answers_question_idx on public.user_answers(question_id);
create table public.question_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  question_id text not null references public.questions(id),
  attempts integer not null default 0 check(attempts>=0), correct_count integer not null default 0 check(correct_count>=0),
  error_count integer not null default 0 check(error_count>=0), consecutive_correct integer not null default 0 check(consecutive_correct>=0),
  mastery integer not null default 0 check(mastery between 0 and 5),
  interval_days numeric not null default 0 check(interval_days>=0),
  last_answer text check(last_answer in ('A','B','C','D')), last_correct boolean,
  first_answered_at timestamptz not null, last_answered_at timestamptz not null,
  last_error_at timestamptz, last_review_at timestamptz, next_review_at timestamptz,
  primary key(user_id,question_id), check(attempts = correct_count + error_count)
);
create index progress_due_idx on public.question_progress(user_id,next_review_at);
create index progress_question_idx on public.question_progress(question_id);
create table public.review_queue (
  user_id uuid not null references public.profiles(id) on delete cascade, question_id text not null references public.questions(id),
  next_due_at timestamptz not null, interval_days numeric not null check(interval_days>=0),
  status text not null check(status in ('learning','mastered')), last_review_at timestamptz not null,
  primary key(user_id,question_id)
);
create index review_due_idx on public.review_queue(user_id,next_due_at);
create index review_question_idx on public.review_queue(question_id);
create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade, question_id text not null references public.questions(id),
  created_at timestamptz not null default now(), primary key(user_id,question_id)
);
create index favorites_question_idx on public.favorites(question_id);
create table public.daily_progress (
  user_id uuid not null references public.profiles(id) on delete cascade, day date not null,
  answered_count integer not null default 0, correct_count integer not null default 0, error_count integer not null default 0,
  study_seconds integer not null default 0, goal integer not null default 10,
  primary key(user_id,day), check(answered_count = correct_count + error_count),
  check(answered_count>=0 and correct_count>=0 and error_count>=0 and study_seconds>=0)
);
create table public.sync_operations (
  user_id uuid not null references public.profiles(id) on delete cascade, operation_id uuid not null,
  result jsonb not null, created_at timestamptz not null default now(), primary key(user_id,operation_id)
);

-- Catalog SELECT only. Personal tables SELECT only, mutations go through atomic RPCs.
do $$ declare t text; begin
  foreach t in array array['exams','topics','questions','question_options'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from anon, authenticated',t);
    execute format('grant select on public.%I to authenticated',t);
    execute format('create policy catalog_read on public.%I for select to authenticated using (true)',t);
  end loop;
  foreach t in array array['study_sessions','session_questions','user_answers','question_progress','review_queue','favorites','daily_progress','sync_operations'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from anon, authenticated',t);
    execute format('grant select on public.%I to authenticated',t);
    execute format('create policy owner_read on public.%I for select to authenticated using ((select auth.uid()) = user_id)',t);
  end loop;
end $$;
alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update(display_name,daily_goal,timezone) on public.profiles to authenticated;
create policy profile_read on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profile_update on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create function private.create_profile() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_schema <> 'auth' or tg_table_name <> 'users' then raise exception 'Invalid trigger'; end if;
  insert into public.profiles(id,display_name) values(new.id,
    left(coalesce(nullif(new.raw_user_meta_data->>'display_name',''),'Estudante'),80));
  return new;
end $$;
revoke all on function private.create_profile() from public, anon, authenticated;
create trigger auth_user_profile after insert on auth.users for each row execute function private.create_profile();

create function private.touch_profile() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at := now(); return new; end $$;
revoke all on function private.touch_profile() from public, anon, authenticated;
create trigger profile_updated before update on public.profiles for each row execute function private.touch_profile();

create function private.validate_options() returns trigger language plpgsql set search_path='' as $$
declare q text; begin
  if tg_table_name = 'questions' then q:=new.id;
  else q:=coalesce(new.question_id,old.question_id); end if;
  if exists(select 1 from public.questions where id=q) and
     (select count(*) from public.question_options where question_id=q) <> 4 then
    raise exception 'Question % must have exactly four alternatives',q;
  end if;
  return null;
end $$;
revoke all on function private.validate_options() from public, anon, authenticated;
create constraint trigger questions_four_options after insert or update on public.questions
  deferrable initially deferred for each row execute function private.validate_options();
create constraint trigger options_four_options after insert or update or delete on public.question_options
  deferrable initially deferred for each row execute function private.validate_options();

create function private.add_study_time(u uuid, seconds integer) returns void language plpgsql set search_path='' as $$
declare d date; g integer; begin
  if u is distinct from auth.uid() then raise exception 'Unauthorized' using errcode='42501'; end if;
  select (now() at time zone timezone)::date,daily_goal into d,g from public.profiles where id=u;
  if seconds > 0 then
    insert into public.daily_progress(user_id,day,study_seconds,goal) values(u,d,seconds,g)
    on conflict(user_id,day) do update set study_seconds=public.daily_progress.study_seconds+excluded.study_seconds;
  end if;
end $$;
revoke all on function private.add_study_time(uuid,integer) from public, anon, authenticated;

create function private.grade_answer(sid uuid, pos integer) returns void language plpgsql set search_path='' as $$
declare u uuid:=auth.uid(); item record; p public.question_progress%rowtype;
  ok boolean; streak integer; level integer; days numeric; due timestamptz; d date; goal_value integer;
begin
  if u is null then raise exception 'Login required' using errcode='42501'; end if;
  select sq.*,q.annulled,k.official_answer into item from public.session_questions sq
    join public.questions q on q.id=sq.question_id join private.answer_keys k on k.question_id=q.id
    where sq.session_id=sid and sq.position=pos and sq.user_id=u for update of sq;
  if not found or item.graded then return; end if;
  ok := case when item.annulled or item.selected_answer is null then null else item.selected_answer=item.official_answer end;
  update public.session_questions set graded=true,is_correct=ok,graded_at=now() where session_id=sid and position=pos and user_id=u;
  if item.selected_answer is null then return; end if;
  insert into public.user_answers(user_id,session_id,position,question_id,selected_answer,is_correct,annulled,spent_seconds,answered_at)
    values(u,sid,pos,item.question_id,item.selected_answer,ok,item.annulled,item.spent_seconds,coalesce(item.answered_at,now()));
  insert into public.question_progress(user_id,question_id,first_answered_at,last_answered_at,last_answer)
    values(u,item.question_id,coalesce(item.answered_at,now()),coalesce(item.answered_at,now()),item.selected_answer)
    on conflict(user_id,question_id) do nothing;
  select * into p from public.question_progress where user_id=u and question_id=item.question_id for update;
  if item.annulled then
    update public.question_progress set last_answer=item.selected_answer,last_answered_at=coalesce(item.answered_at,now())
      where user_id=u and question_id=item.question_id;
    return;
  end if;
  if ok then
    streak:=p.consecutive_correct+1; level:=least(5,streak);
    days:=case streak when 1 then 1 when 2 then 3 when 3 then 7 when 4 then 14 when 5 then 30
      else least(90,greatest(30,p.interval_days*1.8)) end;
  else
    streak:=0; level:=greatest(0,p.mastery-2);
    days:=greatest(1.0/96,least(1,p.interval_days/2));
  end if;
  due:=now()+make_interval(secs=>days::double precision*86400);
  update public.question_progress set attempts=attempts+1,correct_count=correct_count+case when ok then 1 else 0 end,
    error_count=error_count+case when ok then 0 else 1 end,consecutive_correct=streak,mastery=level,interval_days=days,
    last_answer=item.selected_answer,last_correct=ok,last_answered_at=coalesce(item.answered_at,now()),
    last_error_at=case when ok then last_error_at else now() end,last_review_at=now(),next_review_at=due
    where user_id=u and question_id=item.question_id;
  insert into public.review_queue(user_id,question_id,next_due_at,interval_days,status,last_review_at)
    values(u,item.question_id,due,days,case when level>=4 then 'mastered' else 'learning' end,now())
    on conflict(user_id,question_id) do update set next_due_at=excluded.next_due_at,interval_days=excluded.interval_days,
      status=excluded.status,last_review_at=excluded.last_review_at;
  select (coalesce(item.answered_at,now()) at time zone timezone)::date,daily_goal into d,goal_value from public.profiles where id=u;
  insert into public.daily_progress(user_id,day,answered_count,correct_count,error_count,goal)
    values(u,d,1,case when ok then 1 else 0 end,case when ok then 0 else 1 end,goal_value)
    on conflict(user_id,day) do update set answered_count=public.daily_progress.answered_count+1,
      correct_count=public.daily_progress.correct_count+excluded.correct_count,error_count=public.daily_progress.error_count+excluded.error_count;
end $$;
revoke all on function private.grade_answer(uuid,integer) from public, anon, authenticated;

create function private.session_bundle(sid uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); s public.study_sessions%rowtype; items jsonb; begin
  if u is null then raise exception 'Login required' using errcode='42501'; end if;
  select * into s from public.study_sessions where id=sid and user_id=u;
  if not found then raise exception 'Session not found' using errcode='42501'; end if;
  select jsonb_agg(jsonb_build_object('position',sq.position,'selected_answer',sq.selected_answer,'marked',sq.marked,
    'graded',sq.graded,'is_correct',sq.is_correct,'spent_seconds',sq.spent_seconds,
    'question',to_jsonb(q)||jsonb_build_object('topic',t.name,'alternatives',
      (select jsonb_agg(to_jsonb(o)-'question_id' order by o.label) from public.question_options o where o.question_id=q.id)),
    'favorite',exists(select 1 from public.favorites f where f.user_id=u and f.question_id=q.id),
    'official_answer',case when s.status='completed' or (s.correction='immediate' and sq.graded) then k.official_answer else null end,
    'explanation',case when s.status='completed' or (s.correction='immediate' and sq.graded) then k.explanation else null end,
    'explanation_source',case when s.status='completed' or (s.correction='immediate' and sq.graded) then k.explanation_source else null end
    ) order by sq.position) into items
    from public.session_questions sq join public.questions q on q.id=sq.question_id join public.topics t on t.id=q.topic_id
    join private.answer_keys k on k.question_id=q.id where sq.session_id=sid and sq.user_id=u;
  return jsonb_build_object('session',to_jsonb(s),'items',items);
end $$;
revoke all on function private.session_bundle(uuid) from public, anon;
grant execute on function private.session_bundle(uuid) to authenticated;
create function public.get_study_session(p_session_id uuid) returns jsonb language sql security invoker set search_path=''
  as $$ select private.session_bundle(p_session_id); $$;

create function private.start_session(mode_value text, count_value integer, settings jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); sid uuid; picks text[]; n integer:=least(320,greatest(1,count_value));
  how text:=coalesce(settings->>'correction','immediate'); label text; seconds_limit integer; avg_time numeric; maintenance text;
begin
  if u is null then raise exception 'Login required' using errcode='42501'; end if;
  if mode_value not in ('adaptive','quick','review','mock','favorites','bank') then raise exception 'Invalid mode'; end if;
  perform pg_advisory_xact_lock(hashtext(u::text));
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
      select * from diverse order by case when within_topic<=greatest(2,ceil(n*0.4)) then 0 else 1 end,priority,random_order limit n
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
revoke all on function private.start_session(text,integer,jsonb) from public, anon;
grant execute on function private.start_session(text,integer,jsonb) to authenticated;
create function public.start_study_session(p_mode text default 'adaptive',p_count integer default 10,p_settings jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$ select private.start_session(p_mode,p_count,p_settings); $$;

create function private.save_action(op uuid,sid uuid,action text,payload jsonb,expected_revision integer) returns jsonb
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
    if s.status<>'active' then raise exception 'Esta sessão já foi finalizada. Recarregue para ver o resultado.' using errcode='40001'; end if;
    if action<>'heartbeat' and expected_revision is distinct from s.revision then
      raise exception 'Esta sessão foi alterada em outro aparelho. Recarregue antes de continuar.' using errcode='40001';
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
      if s.expires_at is not null and now()>s.expires_at then raise exception 'O tempo do simulado terminou. Finalize para corrigir.'; end if;
      answer_value:=nullif(payload->>'answer','');
      if answer_value is not null and answer_value not in ('A','B','C','D') then raise exception 'Invalid answer'; end if;
      if exists(select 1 from public.session_questions where session_id=sid and position=pos and user_id=u and graded) then
        raise exception 'Esta resposta já foi corrigida. Inicie uma revisão para tentar novamente.';
      end if;
      when_answered:=least(now(),greatest(now()-interval '30 days',coalesce((payload->>'answered_at')::timestamptz,now())));
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
revoke all on function private.save_action(uuid,uuid,text,jsonb,integer) from public, anon;
grant execute on function private.save_action(uuid,uuid,text,jsonb,integer) to authenticated;
create function public.save_study_action(p_operation_id uuid,p_session_id uuid,p_action text,p_payload jsonb,p_expected_revision integer default null)
returns jsonb language sql security invoker set search_path='' as $$
  select private.save_action(p_operation_id,p_session_id,p_action,p_payload,p_expected_revision); $$;

create view public.topic_performance with(security_invoker=true) as
  select a.user_id,q.topic_id,t.name,count(*)::integer as answered,
    count(*) filter(where a.is_correct)::integer as correct,count(*) filter(where not a.is_correct)::integer as errors,
    round(100.0*count(*) filter(where a.is_correct)/nullif(count(*),0),1) as percentage
  from public.user_answers a join public.questions q on q.id=a.question_id join public.topics t on t.id=q.topic_id
  where not a.annulled group by a.user_id,q.topic_id,t.name;
create view public.exam_performance with(security_invoker=true) as
  select a.user_id,q.exam_id,e.title,count(*)::integer as answered,
    count(*) filter(where a.is_correct)::integer as correct,count(*) filter(where not a.is_correct)::integer as errors,
    round(100.0*count(*) filter(where a.is_correct)/nullif(count(*),0),1) as percentage
  from public.user_answers a join public.questions q on q.id=a.question_id join public.exams e on e.id=q.exam_id
  where not a.annulled group by a.user_id,q.exam_id,e.title;
revoke all on public.topic_performance,public.exam_performance from anon,authenticated;
grant select on public.topic_performance,public.exam_performance to authenticated;

create function public.get_study_dashboard() returns jsonb language plpgsql security invoker set search_path='' as $$
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
    'streak',current_streak,'best_streak',best_streak,'bank_total',(select count(*) from public.questions),
    'studied_distinct',(select count(*) from public.question_progress where user_id=u and last_answer is not null),
    'unseen',(select count(*) from public.questions q where not exists(select 1 from public.question_progress p where p.question_id=q.id and p.user_id=u)),
    'due',(select count(*) from public.review_queue where user_id=u and next_due_at<=now()),
    'mastered',(select count(*) from public.question_progress where user_id=u and mastery>=4),
    'favorites',(select count(*) from public.favorites where user_id=u),
    'topic_stats',coalesce((select jsonb_agg(to_jsonb(t) order by t.percentage,t.answered desc) from public.topic_performance t where user_id=u),'[]'::jsonb),
    'exam_stats',coalesce((select jsonb_agg(to_jsonb(e) order by e.title) from public.exam_performance e where user_id=u),'[]'::jsonb),
    'daily',coalesce((select jsonb_agg(to_jsonb(d) order by d.day) from public.daily_progress d where user_id=u and day>=today_value-29),'[]'::jsonb),
    'sessions',coalesce((select jsonb_agg(to_jsonb(s) order by s.updated_at desc) from
      (select * from public.study_sessions where user_id=u order by updated_at desc limit 30) s),'[]'::jsonb));
end $$;

create function public.search_question_bank(p_filters jsonb default '{}',p_offset integer default 0,p_limit integer default 25)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare u uuid:=auth.uid(); results jsonb; total integer; begin
  if u is null then raise exception 'Login required' using errcode='42501'; end if;
  with filtered as (
    select q.*,t.name as topic,e.year,e.edition,e.title as exam_title,
      p.attempts,p.correct_count,p.error_count,p.mastery,p.last_correct,p.next_review_at,
      exists(select 1 from public.favorites f where f.user_id=u and f.question_id=q.id) as favorite
    from public.questions q join public.topics t on t.id=q.topic_id join public.exams e on e.id=q.exam_id
    left join public.question_progress p on p.question_id=q.id and p.user_id=u
    where (coalesce(p_filters->>'exam_id','')='' or q.exam_id=p_filters->>'exam_id')
      and (coalesce(p_filters->>'topic_id','')='' or q.topic_id=p_filters->>'topic_id')
      and (coalesce(p_filters->>'year','')='' or e.year::text=p_filters->>'year')
      and (coalesce(p_filters->>'query','')='' or q.stem ilike '%'||left(p_filters->>'query',100)||'%' or q.subtopic ilike '%'||left(p_filters->>'query',100)||'%')
      and case coalesce(p_filters->>'state','all')
        when 'answered' then p.user_id is not null when 'unseen' then p.user_id is null
        when 'correct' then p.last_correct=true when 'wrong' then p.error_count>0
        when 'repeated' then p.error_count>1 when 'recent' then p.error_count>0 and p.last_error_at>=now()-interval '7 days'
        when 'unmastered' then p.error_count>0 and p.mastery<4 when 'mastered' then p.mastery>=4
        when 'due' then p.next_review_at<=now()
        when 'favorites' then exists(select 1 from public.favorites f where f.user_id=u and f.question_id=q.id)
        else true end
  ) select jsonb_build_object('total',(select count(*) from filtered),'items',coalesce(
    (select jsonb_agg(to_jsonb(q) order by edition,position) from
      (select * from filtered order by edition,position offset greatest(0,p_offset) limit least(100,greatest(1,p_limit))) q),'[]'::jsonb)) into results;
  return results;
end $$;

revoke all on function public.get_study_session(uuid),public.start_study_session(text,integer,jsonb),
  public.save_study_action(uuid,uuid,text,jsonb,integer),public.get_study_dashboard(),public.search_question_bank(jsonb,integer,integer) from public,anon;
grant execute on function public.get_study_session(uuid),public.start_study_session(text,integer,jsonb),
  public.save_study_action(uuid,uuid,text,jsonb,integer),public.get_study_dashboard(),public.search_question_bank(jsonb,integer,integer) to authenticated;

-- Optional realtime events retain the same RLS boundary; polling is a fallback.
alter publication supabase_realtime add table public.study_sessions,public.favorites,public.question_progress;
