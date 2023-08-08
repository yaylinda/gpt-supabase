SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgsodium" WITH SCHEMA "pgsodium";

CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public";

CREATE FUNCTION "public"."after_profiles_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
AS
$$
begin
    INSERT INTO public.purchases (user_id,
                                  chat_id,
                                  type,
                                  num_credits,
                                  product,
                                  platform,
                                  customer_info,
                                  applied)
    SELECT new.id,
           null,
           'chats',
           initial_chat_credits,
           null,
           new.platform,
           null,
           true
    FROM (SELECT initial_chat_credits FROM public.admin_settings LIMIT 1) AS subquery;

    return NEW;
end;
$$;

ALTER FUNCTION "public"."after_profiles_insert"() OWNER TO "postgres";

CREATE FUNCTION "public"."after_purchases_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
AS
$$
begin
    IF (NEW.applied is false) THEN
        IF (NEW.type = 'chats') THEN
            update public.profiles
            set num_chat_credits_total = num_chat_credits_total + NEW.num_credits
            where id = new.user_id;
        ELSEIF (NEW.type = 'messages') THEN
            update public.chats
            set num_message_credits_total = num_message_credits_total + NEW.num_credits
            where id = new.chat_id;
        END IF;

        update public.purchases
        set applied = true
        where id = new.id;
    END IF;

    return NEW;
end;
$$;

ALTER FUNCTION "public"."after_purchases_insert"() OWNER TO "postgres";

CREATE FUNCTION "public"."before_purchases_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
AS
$$
begin
    IF (NEW.type = 'chats') THEN
        NEW.num_credits := (SELECT initial_chat_credits FROM public.admin_settings LIMIT 1);
    ELSEIF (NEW.type = 'messages') THEN
        NEW.num_credits := (SELECT initial_message_credits FROM public.admin_settings LIMIT 1);
    END IF;

    return NEW;
end;
$$;

ALTER FUNCTION "public"."before_purchases_insert"() OWNER TO "postgres";

CREATE FUNCTION "public"."handle_chat_created"() RETURNS "trigger"
    LANGUAGE "plpgsql"
AS
$$
begin

    update public.profiles
    set num_chat_credits_used = (select count(*)
                                 from public.chats
                                 where created_by = new.created_by)
    where id = new.created_by;

    insert into public.chat_members(user_id, chat_id)
    select unnest(new.members), new.id;

    return new;
end
$$;

ALTER FUNCTION "public"."handle_chat_created"() OWNER TO "postgres";

CREATE FUNCTION "public"."handle_chat_message_sent"() RETURNS "trigger"
    LANGUAGE "plpgsql"
AS
$$
begin

    if new.role <> 'system' then
        update public.chats
        set num_message_credits_used = (select count(*)
                                        from public.chat_messages
                                        where chat_id = new.chat_id
                                          and sender_id is not null),
            last_message             = jsonb_build_object(
                    'role', new.role,
                    'content', new.content,
                    'name', split_part(new.content, ':', 1),
                    'promptTokens', new.prompt_tokens,
                    'completionTokens', new.completion_tokens,
                    'totalTokens', new.total_tokens
                ),
            updated_at               = now(),
            num_tokens_used          = (select sum(total_tokens)
                                        from public.chat_messages cm
                                        where chat_id = new.chat_id)
        where id = new.chat_id;

    end if;

    return new;
end
$$;

ALTER FUNCTION "public"."handle_chat_message_sent"() OWNER TO "postgres";

CREATE FUNCTION "public"."handle_friend_request_accepted"() RETURNS "trigger"
    LANGUAGE "plpgsql"
AS
$$
begin

    if new.request_accepted is true then

        update public.profiles
        set num_friends = (select count(*)
                           from public.friends f
                           where (
                                       f.requester = new.requester
                                   or f.requestee = new.requester
                               )
                             and f.request_accepted is true)
        where id = new.requester;

        update public.profiles
        set num_friends = (select count(*)
                           from public.friends f
                           where (
                                       f.requester = new.requestee
                                   or f.requestee = new.requestee
                               )
                             and f.request_accepted is true)
        where id = new.requestee;

    end if;

    return new;
end
$$;

ALTER FUNCTION "public"."handle_friend_request_accepted"() OWNER TO "postgres";

CREATE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
AS
$$-- triggered when new auth.users row is inserted when supabase.auth.signUp is called
begin
    INSERT INTO public.profiles (id,
                                 username,
                                 discriminator,
                                 num_chat_credits_total,
                                 initial_message_credits,
                                 email,
                                 platform)
    VALUES (new.id,
            new.raw_user_meta_data ->> 'username',
            new.raw_user_meta_data ->> 'discriminator',
            (SELECT initial_chat_credits FROM public.admin_settings LIMIT 1),
            (SELECT initial_message_credits FROM public.admin_settings LIMIT 1),
            new.email,
            new.raw_user_meta_data ->> 'platform');

    return new;
end;
$$;

ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

CREATE TABLE "public"."chat_messages"
(
    "id"                    "uuid"                   DEFAULT "extensions"."uuid_generate_v1"() NOT NULL,
    "timestamp"             timestamp with time zone DEFAULT "now"()                           NOT NULL,
    "chat_id"               "uuid"                                                             NOT NULL,
    "sender_id"             "uuid",
    "content"               "text"                                                             NOT NULL,
    "role"                  "text"                                                             NOT NULL,
    "response_to_sender_id" "text",
    "prompt_tokens"         integer                  DEFAULT 0                                 NOT NULL,
    "completion_tokens"     integer                  DEFAULT 0                                 NOT NULL,
    "total_tokens"          integer                  DEFAULT 0                                 NOT NULL,
    "embedding"             "public"."vector"(1536)
);

ALTER TABLE "public"."chat_messages"
    OWNER TO "postgres";

CREATE FUNCTION "public"."search_messages"("chat_id" "uuid", "query_embedding" "public"."vector",
                                           "similarity_threshold" double precision, "max_rows" integer,
                                           "exclude_id" "uuid") RETURNS SETOF "public"."chat_messages"
    LANGUAGE "plpgsql"
AS
$$
BEGIN
    RETURN QUERY select *
                 from (SELECT *
                       FROM chat_messages
                       WHERE (
                                         chat_messages.chat_id = search_messages.chat_id
                                     AND
                                         1 - (chat_messages.embedding <=> search_messages.query_embedding) >
                                         search_messages.similarity_threshold
                                     AND
                                         chat_messages.timestamp < (select timestamp
                                                                    from chat_messages cm1
                                                                    where cm1.id = search_messages.exclude_id
                                                                    limit 1)
                                 )
                       ORDER BY 1 - (chat_messages.embedding <=> search_messages.query_embedding) DESC
                       LIMIT search_messages.max_rows) cm
                 order by cm.timestamp asc;
END;
$$;

ALTER FUNCTION "public"."search_messages"("chat_id" "uuid", "query_embedding" "public"."vector", "similarity_threshold" double precision, "max_rows" integer, "exclude_id" "uuid") OWNER TO "postgres";

CREATE TABLE "public"."admin_settings"
(
    "initial_chat_credits"    integer DEFAULT 3  NOT NULL,
    "initial_message_credits" integer DEFAULT 10 NOT NULL
);

ALTER TABLE "public"."admin_settings"
    OWNER TO "postgres";

CREATE TABLE "public"."chat_members"
(
    "user_id" "uuid" NOT NULL,
    "chat_id" "uuid" NOT NULL
);

ALTER TABLE "public"."chat_members"
    OWNER TO "postgres";

CREATE TABLE "public"."chats"
(
    "id"                        "uuid"                   DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name"                      "text"                                                             NOT NULL,
    "created_at"                timestamp with time zone DEFAULT "now"()                           NOT NULL,
    "created_by"                "uuid"                                                             NOT NULL,
    "members"                   "uuid"[],
    "updated_at"                timestamp with time zone DEFAULT "now"()                           NOT NULL,
    "last_message"              "jsonb",
    "ai_name"                   "text"                                                             NOT NULL,
    "gpt_chat_model"            "text"                                                             NOT NULL,
    "num_message_credits_used"  integer                  DEFAULT 0                                 NOT NULL,
    "num_message_credits_total" integer                  DEFAULT 0                                 NOT NULL,
    "num_tokens_used"           integer                  DEFAULT 0                                 NOT NULL,
    "gpt_embed_model"           "text"                                                             NOT NULL,
    "prompt_message_content"    "text"                   DEFAULT ''::"text"                        NOT NULL,
    "initial_message_credits"   integer                  DEFAULT 0                                 NOT NULL
);

ALTER TABLE "public"."chats"
    OWNER TO "postgres";

CREATE TABLE "public"."friends"
(
    "friend_pair"      "text"                                   NOT NULL,
    "requester"        "uuid"                                   NOT NULL,
    "requestee"        "uuid"                                   NOT NULL,
    "requested_on"     timestamp with time zone DEFAULT "now"() NOT NULL,
    "request_accepted" boolean,
    "responded_on"     timestamp with time zone
);

ALTER TABLE "public"."friends"
    OWNER TO "postgres";

CREATE TABLE "public"."profiles"
(
    "id"                      "uuid"                                          NOT NULL,
    "created_at"              timestamp with time zone DEFAULT "now"()        NOT NULL,
    "username"                "text"                                          NOT NULL,
    "discriminator"           "text"                   DEFAULT '0000'::"text" NOT NULL,
    "num_chat_credits_used"   integer                  DEFAULT 0              NOT NULL,
    "num_chat_credits_total"  integer                  DEFAULT 0              NOT NULL,
    "num_friends"             integer                  DEFAULT 0              NOT NULL,
    "initial_message_credits" integer                  DEFAULT 0              NOT NULL,
    "email"                   "text"                   DEFAULT ''::"text"     NOT NULL,
    "platform"                "text",
    CONSTRAINT "display_name_length" CHECK (("char_length"("username") >= 3))
);

ALTER TABLE "public"."profiles"
    OWNER TO "postgres";

CREATE TABLE "public"."purchases"
(
    "id"            "uuid"                   DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id"       "uuid"                                               NOT NULL,
    "chat_id"       "uuid",
    "timestamp"     timestamp with time zone DEFAULT "now"()             NOT NULL,
    "type"          "text"                                               NOT NULL,
    "num_credits"   integer                                              NOT NULL,
    "product"       "jsonb",
    "platform"      "text"                                               NOT NULL,
    "customer_info" "jsonb",
    "applied"       boolean                  DEFAULT false               NOT NULL
);

ALTER TABLE "public"."purchases"
    OWNER TO "postgres";

ALTER TABLE ONLY "public"."chat_members"
    ADD CONSTRAINT "chat_members_pkey" PRIMARY KEY ("user_id", "chat_id");

ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."chats"
    ADD CONSTRAINT "chats_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_id_key" UNIQUE ("friend_pair");

ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_pkey" PRIMARY KEY ("friend_pair");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."purchases"
    ADD CONSTRAINT "purchases_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "unique_user1_user2" UNIQUE ("requester", "requestee");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "unique_username_discriminator" UNIQUE ("username", "discriminator");

CREATE INDEX "chat_messages_embedding_idx" ON "public"."chat_messages" USING "ivfflat" ("embedding" "public"."vector_cosine_ops") WITH ("lists"='100');

CREATE TRIGGER "on_after_profiles_insert"
    AFTER INSERT
    ON "public"."profiles"
    FOR EACH ROW
EXECUTE FUNCTION "public"."after_profiles_insert"();

CREATE TRIGGER "on_after_purchases_insert"
    AFTER INSERT
    ON "public"."purchases"
    FOR EACH ROW
EXECUTE FUNCTION "public"."after_purchases_insert"();

CREATE TRIGGER "on_before_purchases_insert"
    BEFORE INSERT
    ON "public"."purchases"
    FOR EACH ROW
EXECUTE FUNCTION "public"."before_purchases_insert"();

CREATE TRIGGER "on_chat_insert"
    AFTER INSERT
    ON "public"."chats"
    FOR EACH ROW
EXECUTE FUNCTION "public"."handle_chat_created"();

CREATE TRIGGER "on_chat_message_insert"
    AFTER INSERT
    ON "public"."chat_messages"
    FOR EACH ROW
EXECUTE FUNCTION "public"."handle_chat_message_sent"();

CREATE TRIGGER "on_friend_request_accepted"
    AFTER UPDATE
    ON "public"."friends"
    FOR EACH ROW
EXECUTE FUNCTION "public"."handle_friend_request_accepted"();

CREATE TRIGGER on_auth_user_created
    AFTER INSERT
    ON auth.users
    FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

ALTER TABLE ONLY "public"."chat_members"
    ADD CONSTRAINT "chat_members_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "public"."chats" ("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."chat_members"
    ADD CONSTRAINT "chat_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users" ("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "public"."chats" ("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users" ("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."chats"
    ADD CONSTRAINT "chats_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users" ("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_requestee_fkey" FOREIGN KEY ("requestee") REFERENCES "auth"."users" ("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_requester_fkey" FOREIGN KEY ("requester") REFERENCES "auth"."users" ("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users" ("id");

ALTER TABLE ONLY "public"."purchases"
    ADD CONSTRAINT "purchases_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "public"."chats" ("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."purchases"
    ADD CONSTRAINT "purchases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles" ("id") ON DELETE CASCADE;

CREATE POLICY "Allow all users to read" ON "public"."admin_settings" FOR SELECT USING (true);

CREATE POLICY "Enable insert for users for self or chat" ON "public"."purchases" FOR INSERT WITH CHECK ((
        ("auth"."uid"() = "user_id") OR ("auth"."uid"() IN (SELECT "cm"."user_id"
                                                            FROM "public"."chat_members" "cm"
                                                            WHERE ("cm"."chat_id" = "purchases"."chat_id")))));

CREATE POLICY "Enable insert if user is creator and has sufficient chat credit" ON "public"."chats" FOR INSERT WITH CHECK ((
        ("auth"."uid"() = "created_by") AND (EXISTS (SELECT "p"."id",
                                                            "p"."created_at",
                                                            "p"."username",
                                                            "p"."discriminator",
                                                            "p"."num_chat_credits_used",
                                                            "p"."num_chat_credits_total"
                                                     FROM "public"."profiles" "p"
                                                     WHERE (("p"."num_chat_credits_used" < "p"."num_chat_credits_total") AND
                                                            ("p"."id" = "auth"."uid"()))))));

CREATE POLICY "Enable insert if user is part of chat and sufficient credits" ON "public"."chat_messages" FOR INSERT WITH CHECK ((
        ("auth"."uid"() IN (SELECT "cm"."user_id"
                            FROM "public"."chat_members" "cm"
                            WHERE ("cm"."chat_id" = "chat_messages"."chat_id"))) AND
        (((SELECT "c1"."num_message_credits_used"
           FROM "public"."chats" "c1"
           WHERE ("c1"."id" = "chat_messages"."chat_id")) < (SELECT "c2"."num_message_credits_total"
                                                             FROM "public"."chats" "c2"
                                                             WHERE ("c2"."id" = "chat_messages"."chat_id"))) OR
         ("sender_id" IS NULL))));

CREATE POLICY "Enable read for users for self or chat" ON "public"."purchases" FOR SELECT USING ((
        ("auth"."uid"() = "user_id") OR ("auth"."uid"() IN (SELECT "cm"."user_id"
                                                            FROM "public"."chat_members" "cm"
                                                            WHERE ("cm"."chat_id" = "purchases"."chat_id")))));

CREATE POLICY "Enable select if user in chat" ON "public"."chats" FOR SELECT USING (("auth"."uid"() = ANY ("members")));

CREATE POLICY "Enable update for users for self or chat" ON "public"."purchases" FOR UPDATE USING ((
        ("auth"."uid"() = "user_id") OR ("auth"."uid"() IN (SELECT "cm"."user_id"
                                                            FROM "public"."chat_members" "cm"
                                                            WHERE ("cm"."chat_id" = "purchases"."chat_id"))))) WITH CHECK ((
        ("auth"."uid"() = "user_id") OR ("auth"."uid"() IN (SELECT "cm"."user_id"
                                                            FROM "public"."chat_members" "cm"
                                                            WHERE ("cm"."chat_id" = "purchases"."chat_id")))));

CREATE POLICY "Enable update if user in chat" ON "public"."chats" FOR UPDATE USING (("auth"."uid"() IN
                                                                                     (SELECT "cm"."user_id"
                                                                                      FROM "public"."chat_members" "cm"
                                                                                      WHERE ("cm"."chat_id" = "chats"."id")))) WITH CHECK ((
        "auth"."uid"() IN (SELECT "cm"."user_id"
                           FROM "public"."chat_members" "cm"
                           WHERE ("cm"."chat_id" = "chats"."id"))));

CREATE POLICY "Enable update if user is part of chat" ON "public"."chat_messages" FOR UPDATE USING (("auth"."uid"() IN
                                                                                                     (SELECT "cm"."user_id"
                                                                                                      FROM "public"."chat_members" "cm"
                                                                                                      WHERE ("cm"."chat_id" = "cm"."chat_id"))));

CREATE POLICY "Public profiles are viewable by anyone" ON "public"."profiles" FOR SELECT USING (true);

CREATE POLICY "Users can get chat member mappings for themselves" ON "public"."chat_members" FOR SELECT USING (("auth"."uid"() = "user_id"));

CREATE POLICY "Users can insert a chat membership" ON "public"."chat_members" FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can insert their own friendships/requests" ON "public"."friends" FOR INSERT WITH CHECK ((("auth"."uid"() = "requester") OR ("auth"."uid"() = "requestee")));

CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));

CREATE POLICY "Users can update friends/requests for themselves" ON "public"."friends" FOR UPDATE USING ((("auth"."uid"() = "requester") OR ("auth"."uid"() = "requestee")));

CREATE POLICY "Users can update own or friends profile." ON "public"."profiles" FOR UPDATE USING ((
        ("auth"."uid"() = "id") OR (EXISTS (SELECT 1
                                            FROM "public"."friends" "f"
                                            WHERE ((("f"."requester" = "auth"."uid"()) AND
                                                    ("f"."requestee" = "profiles"."id")) OR
                                                   (("f"."requestee" = "auth"."uid"()) AND
                                                    ("f"."requester" = "profiles"."id")))))));

CREATE POLICY "Users can view chat messages where they are recipients" ON "public"."chat_messages" FOR SELECT USING ((
        "auth"."uid"() IN (SELECT "cm"."user_id"
                           FROM "public"."chat_members" "cm"
                           WHERE ("cm"."chat_id" = "cm"."chat_id"))));

CREATE POLICY "Users can view friends/requests for themselves" ON "public"."friends" FOR SELECT USING ((("auth"."uid"() = "requester") OR ("auth"."uid"() = "requestee")));

ALTER TABLE "public"."admin_settings"
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."chat_members"
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."chat_messages"
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."chats"
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."friends"
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles"
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."purchases"
    ENABLE ROW LEVEL SECURITY;

REVOKE USAGE ON SCHEMA "public" FROM PUBLIC;
GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "service_role";

GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."after_profiles_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."after_profiles_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."after_profiles_insert"() TO "service_role";

GRANT ALL ON FUNCTION "public"."after_purchases_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."after_purchases_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."after_purchases_insert"() TO "service_role";

GRANT ALL ON FUNCTION "public"."before_purchases_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."before_purchases_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."before_purchases_insert"() TO "service_role";

GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."handle_chat_created"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_chat_created"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_chat_created"() TO "service_role";

GRANT ALL ON FUNCTION "public"."handle_chat_message_sent"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_chat_message_sent"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_chat_message_sent"() TO "service_role";

GRANT ALL ON FUNCTION "public"."handle_friend_request_accepted"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_friend_request_accepted"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_friend_request_accepted"() TO "service_role";

GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";

GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "service_role";

GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON TABLE "public"."chat_messages" TO "anon";
GRANT ALL ON TABLE "public"."chat_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_messages" TO "service_role";

GRANT ALL ON FUNCTION "public"."search_messages"("chat_id" "uuid", "query_embedding" "public"."vector", "similarity_threshold" double precision, "max_rows" integer, "exclude_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."search_messages"("chat_id" "uuid", "query_embedding" "public"."vector", "similarity_threshold" double precision, "max_rows" integer, "exclude_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_messages"("chat_id" "uuid", "query_embedding" "public"."vector", "similarity_threshold" double precision, "max_rows" integer, "exclude_id" "uuid") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "service_role";

GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "service_role";

GRANT ALL ON TABLE "public"."admin_settings" TO "anon";
GRANT ALL ON TABLE "public"."admin_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_settings" TO "service_role";

GRANT ALL ON TABLE "public"."chat_members" TO "anon";
GRANT ALL ON TABLE "public"."chat_members" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_members" TO "service_role";

GRANT ALL ON TABLE "public"."chats" TO "anon";
GRANT ALL ON TABLE "public"."chats" TO "authenticated";
GRANT ALL ON TABLE "public"."chats" TO "service_role";

GRANT ALL ON TABLE "public"."friends" TO "anon";
GRANT ALL ON TABLE "public"."friends" TO "authenticated";
GRANT ALL ON TABLE "public"."friends" TO "service_role";

GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";

GRANT ALL ON TABLE "public"."purchases" TO "anon";
GRANT ALL ON TABLE "public"."purchases" TO "authenticated";
GRANT ALL ON TABLE "public"."purchases" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";

RESET ALL;
