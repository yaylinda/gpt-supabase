CREATE FUNCTION "public"."handle_game_created"() RETURNS "trigger"
    LANGUAGE "plpgsql"
AS
$$
begin

    insert into public.game_participants(game_id, user_id, status)
    select new.id, unnest(new.participants), 'INVITED';

    update public.game_participants
    set status = 'READY'
    where game_id = new.id and user_id = new.created_by and status = 'INVITED';




    return new;
end
$$;

ALTER FUNCTION "public"."handle_game_created"() OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."handle_game_created"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_game_created"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_game_created"() TO "service_role";

CREATE TRIGGER "on_game_insert"
    AFTER INSERT
    ON "public"."games"
    FOR EACH ROW
EXECUTE FUNCTION "public"."handle_game_created"();
