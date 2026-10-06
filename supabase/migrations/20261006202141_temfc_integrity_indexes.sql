-- Cover every catalog/owner composite FK and explicitly deny key access.
create index answer_key_option_idx on private.answer_keys(question_id,official_answer);
create index session_question_option_idx on public.session_questions(question_id,selected_answer);
create index session_question_session_owner_idx on public.session_questions(session_id,user_id);
create index answer_option_idx on public.user_answers(question_id,selected_answer);
create index answer_session_owner_idx on public.user_answers(session_id,user_id);
create policy answer_keys_no_client_access on private.answer_keys for select to authenticated using(false);
revoke all on private.answer_keys from anon,authenticated;
