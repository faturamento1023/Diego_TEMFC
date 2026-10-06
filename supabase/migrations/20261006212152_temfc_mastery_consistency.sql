create or replace function private.grade_answer(sid uuid, pos integer) returns void language plpgsql set search_path='' as $$
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
    streak:=p.consecutive_correct+1; level:=least(5,greatest(streak,p.mastery));
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
