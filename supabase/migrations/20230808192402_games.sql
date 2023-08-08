create table if not exists public.games (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    created_by uuid not null,
    type text not null,
    status text not null,
    participants uuid[] not null default array[]::uuid[],
    name text not null,
    is_multiplayer bool not null default false,
    constraint games_pkey primary key (id),
    constraint games_created_by_fkey foreign key (created_by) references profiles (id) on delete cascade
);

create table if not exists public.game_participants (
    game_id uuid not null references games(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    status text not null,
    constraint game_participants_pkey primary key (game_id, user_id)
);

create table if not exists public.game_actions (
    id uuid not null default gen_random_uuid (),
    game_id uuid not null references games(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    action text not null,
    metadata jsonb not null,
    created_at timestamp with time zone not null default now(),
    constraint game_actions_pkey primary key (id)
);

--

ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_actions ENABLE ROW LEVEL SECURITY;

--

CREATE POLICY "Users can insert games they created." ON "public"."games" FOR INSERT WITH CHECK (("auth"."uid"() = "created_by"));

CREATE POLICY "Users can update games they created" ON "public"."games" FOR UPDATE USING (("auth"."uid"() = "created_by"));

create policy "Users can read games they are participants" on games
    as permissive
    for select
    using (auth.uid() = ANY (participants));

--

create policy "Game creator can insert" on public.game_participants for insert with check (auth.uid() = (select g.created_by from games g where g.id = game_id));

create policy "Game participants can update own row" on public.game_participants for update using (auth.uid() = user_id);

create policy "Game participants can read all"
    on public.game_participants
    as permissive
    for select
    using (auth.uid() = ANY (select unnest(g.participants) from games g where g.id = game_id));

--

create policy "Game participants can insert" on public.game_actions for insert with check (auth.uid() = any (select unnest(g.participants) from games g where g.id = game_id));

create policy "Game participants can update own row" on public.game_actions for update using (auth.uid() = user_id);

create policy "Game participants can read all" on public.game_actions as permissive for select using (auth.uid() = any (select unnest(g.participants) from games g where g.id = game_id));

--

alter publication supabase_realtime add table public.games;
alter publication supabase_realtime add table public.game_actions;
alter publication supabase_realtime add table public.game_participants;
