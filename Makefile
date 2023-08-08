.PHONY: status start restart stop new_migration apply list init push reset

status:
	npx supabase status

start:
	npx supabase start

restart:
	npx supabase stop && npx supabase start

stop:
	npx supabase stop --no-backup

new_migration:
	npx supabase migration new $(name)

apply:
	npx supabase migration up && npx supabase db push && make gen

list:
	npx supabase migration list

init:
	npx supabase db remote commit

init_auth:
	npx supabase db remote commit -s auth

push:
	npx supabase db push

reset:
	npx supabase db reset

gen:
	npx supabase gen types typescript --local --schema public > ../app/src/gen.ts && npx supabase gen types typescript --local --schema public > functions/gen.ts

new_function:
	npx supabase functions new $(name)

serve:
	npx supabase functions serve

deploy:
	npx supabase functions deploy
