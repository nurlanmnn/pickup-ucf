"""Local Docker only: synthetic fixtures; restore the original leave RPC in finally.

--baseline reproduces concurrent duplicate leave before the fix. Default applies
only the candidate leave function temporarily, then restores its definition.
No production connection, reset, credentials, or arbitrary SQL arguments accepted.
"""
import concurrent.futures
import pathlib
import json
import subprocess
import sys
import threading
import uuid

CONTAINER = 'supabase_db_pickup-ucf'


def sql(statement):
    result = subprocess.run(['docker', 'exec', '-i', CONTAINER, 'psql', '-U', 'postgres',
                             '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1'],
                            input=statement, text=True, capture_output=True, check=True)
    return result.stdout.strip()


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def main():
    users = [str(uuid.uuid4()) for _ in range(4)]
    session = str(uuid.uuid4())
    suffix = uuid.uuid4().hex
    trigger = 'test_leave_' + suffix
    original = sql("SELECT pg_get_functiondef('public.leave_session(uuid)'::regprocedure)")
    original_join = sql("SELECT pg_get_functiondef('public.join_session(uuid)'::regprocedure)")
    lifecycle_candidate = next((pathlib.Path(__file__).parent.parent / 'migrations').glob('*_serialize_account_mutations_with_deletion.sql'))
    candidate = next((pathlib.Path(__file__).parent.parent / 'migrations').glob('*_serialize_session_leave.sql'))
    deletion = None
    try:
        if '--baseline' not in sys.argv:
            sql(candidate.read_text())
            sql(lifecycle_candidate.read_text().split('-- Atomic creation shares')[0])
        for i, user in enumerate(users):
            sql(f"""INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
                VALUES ('00000000-0000-0000-0000-000000000000',{quote(user)},'authenticated','authenticated',
                'concurrency-{suffix}-{i}@ucf.edu','',now(),now(),now());
                INSERT INTO public.profiles(id,display_name) VALUES({quote(user)},'Concurrency Test');""")
        sql(f"""INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,player_count,skill_level,status)
            VALUES({quote(session)},{quote(users[0])},'basketball',now()+interval '2 hours',now()+interval '3 hours',2,2,'any','full');
            INSERT INTO public.session_participants(session_id,user_id,role,status)
            VALUES({quote(session)},{quote(users[0])},'host','joined'),({quote(session)},{quote(users[1])},'player','joined');
            CREATE FUNCTION public.{trigger}() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
            BEGIN IF NEW.session_id={quote(session)}::uuid AND NEW.status='left' THEN PERFORM pg_sleep(0.4); END IF;
            RETURN NEW; END; $$;
            REVOKE ALL ON FUNCTION public.{trigger}() FROM PUBLIC,anon,authenticated;
            CREATE TRIGGER {trigger} BEFORE UPDATE ON public.session_participants FOR EACH ROW EXECUTE FUNCTION public.{trigger}();""")

        def race(actions):
            barrier = threading.Barrier(len(actions))
            def call(action):
                user, rpc = action
                barrier.wait(timeout=10)
                sql(f"""BEGIN; SET LOCAL role authenticated;
                    SELECT set_config('request.jwt.claim.sub',{quote(user)},true);
                    SELECT set_config('request.jwt.claims',{quote('{"sub":"'+user+'","email":"concurrency@ucf.edu"}')},true);
                    SELECT public.{rpc}({quote(session)}); COMMIT;""")
            with concurrent.futures.ThreadPoolExecutor(max_workers=len(actions)) as pool:
                list(pool.map(call, actions))

        def assert_counts():
            result = sql(f"""SELECT player_count,
                (SELECT count(*) FROM public.session_participants WHERE session_id=s.id AND status='joined'),capacity
                FROM public.sessions s WHERE id={quote(session)}""")
            count, joined, capacity = map(int, result.split('|'))
            assert count == joined and 1 <= count <= capacity, result

        race([(users[1], 'leave_session')] * 2)
        assert_counts()
        race([(users[2], 'join_session'), (users[3], 'join_session')])
        assert_counts()
        joined_user = sql(f"SELECT user_id FROM public.session_participants WHERE session_id={quote(session)} AND role='player' AND status='joined'")
        race([(joined_user, 'leave_session'), (joined_user, 'join_session')])
        assert_counts()
        sql(f"UPDATE public.sessions SET capacity=10,status='open' WHERE id={quote(session)};")
        deletion = subprocess.Popen(['docker','exec','-i',CONTAINER,'psql','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1'],
                                    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        deletion.stdin.write(f"BEGIN; SELECT id FROM auth.users WHERE id={quote(users[1])} FOR UPDATE; SELECT 'LOCKED'; SELECT pg_sleep(0.5); DELETE FROM auth.users WHERE id={quote(users[1])}; COMMIT;")
        deletion.stdin.close()
        while True:
            line = deletion.stdout.readline().strip()
            if line == 'LOCKED': break
            if deletion.poll() is not None: raise AssertionError('Deletion lock was not acquired')
        rejected = False
        try:
            claims = quote(json.dumps(dict(sub=users[1], email="concurrency@ucf.edu")))
            sql(f"BEGIN; SET LOCAL role authenticated; SELECT set_config('request.jwt.claim.sub',{quote(users[1])},true); SELECT set_config('request.jwt.claims',{claims},true); SELECT public.join_session({quote(session)}); COMMIT;")
        except subprocess.CalledProcessError as error:
            assert 'not_authenticated' in error.stderr, error.stderr
            rejected = True
        assert deletion.wait(timeout=10) == 0, deletion.stderr.read()
        assert rejected, 'A join raced past the deletion account lock'
        assert_counts()
        print('join/leave concurrency: duplicate leave, final slot joins, mixed retry and deletion exclusion OK')
    finally:
        if deletion is not None and deletion.poll() is None:
            deletion.wait(timeout=10)
        sql(f"DROP TRIGGER IF EXISTS {trigger} ON public.session_participants; DROP FUNCTION IF EXISTS public.{trigger}();")
        sql(original)
        sql(original_join)
        sql(f"DELETE FROM public.sessions WHERE id={quote(session)};")
        for user in users:
            sql(f"DELETE FROM auth.users WHERE id={quote(user)};")


if __name__ == '__main__':
    main()
