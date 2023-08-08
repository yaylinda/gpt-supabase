-- initial credits
insert into postgres.public.admin_settings (initial_chat_credits, initial_message_credits) values (3, 10);

-- drop and re-create the supabase_realtime publication with no tables
begin;
    drop publication if exists supabase_realtime;
    create publication supabase_realtime;
commit;

-- add tables to the publication
alter publication supabase_realtime add table public.chats;
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.friends;
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.purchases;
