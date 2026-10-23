"""Exercise host cancellation/capacity races in a fresh network-disabled DB.

Reads only schema and migration history from the existing local Docker database.
Never copies its rows, edits it, accepts a URL/credential, or contacts production.
The disposable container uses tmpfs and is removed in finally, including failures.
"""
import concurrent.futures
import json
import pathlib
import re
import subprocess
import tempfile
import threading
import time
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = 'supabase_db_pickup-ucf'
IMAGE = 'public.ecr.aws/supabase/postgres:17.6.1.121'


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def command(container):
    return ['docker', 'exec', '-i', container, 'psql', '-X', '-qAt', '-U', 'postgres',
            '-d', 'postgres', '-v', 'ON_ERROR_STOP=1']


def main():
    container = 'pickup-host-actions-' + uuid.uuid4().hex[:12]
    logs = pathlib.Path(tempfile.mkdtemp(prefix='pickup-host-actions-'))
    created = False

    def sql(statement, target=container):
        result = subprocess.run(command(target) + (['-h', '/tmp'] if target == container else []),
                                input=statement, text=True, capture_output=True, timeout=30)
        if result.returncode:
            path = logs / f'error-{uuid.uuid4().hex}.log'
            path.write_text(result.stderr)
            path.chmod(0o600)
            raise subprocess.CalledProcessError(result.returncode, 'local isolated SQL',
                                                output=result.stdout, stderr=result.stderr)
        return result.stdout.strip()

    try:
        subprocess.run(['docker', 'run', '-d', '--pull=never', '--name', container,
                        '--network', 'none', '--user', 'postgres', '--read-only',
                        '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
                        '--tmpfs', '/restore:rw,nosuid,nodev,mode=0700,uid=100,gid=101',
                        '--tmpfs', '/tmp:rw,nosuid,nodev,mode=1777', '--entrypoint', 'sh', IMAGE,
                        '-c', 'initdb -D /restore/db --auth-local=trust --auth-host=reject '
                        '>/tmp/init.log 2>&1 && exec postgres -D /restore/db -k /tmp '
                        '-c listen_addresses= -c shared_preload_libraries= -c max_worker_processes=0 '
                        '-c log_statement=none -c log_min_error_statement=panic -c log_min_messages=panic'],
                       check=True, capture_output=True, text=True, timeout=30)
        created = True
        for _ in range(40):
            ready = subprocess.run(['docker', 'exec', container, 'pg_isready', '-h', '/tmp', '-U', 'postgres'],
                                   capture_output=True, timeout=5)
            if ready.returncode == 0:
                break
            time.sleep(0.1)
        else:
            raise AssertionError('Disposable database did not start')
        settings = json.loads(subprocess.check_output(['docker', 'inspect', container], text=True))[0]
        assert settings['HostConfig']['NetworkMode'] == 'none'
        assert settings['HostConfig']['ReadonlyRootfs'] and not settings['Mounts']
        assert not settings['HostConfig']['PortBindings']
        assert sql("SELECT current_setting('listen_addresses')='', "
                   "current_setting('shared_preload_libraries')='', current_setting('max_worker_processes')='0'") == 't|t|t'

        # Establish isolation before reading even schema-only source material.
        baseline = subprocess.run(['docker', 'exec', SOURCE, 'pg_dump', '-U', 'postgres', '-d', 'postgres',
                                   '--schema-only', '--no-owner', '--schema=auth', '--schema=public',
                                   '--schema=pickup_private'], capture_output=True, text=True, check=True, timeout=30).stdout
        roles = ['anon', 'authenticated', 'service_role', 'dashboard_user', 'supabase_auth_admin',
                 'supabase_admin', 'supabase_storage_admin', 'supabase_realtime_admin', 'authenticator', 'pgbouncer']
        sql(';'.join('CREATE ROLE ' + role + ' NOLOGIN' for role in roles) + ';'
            'CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; '
            'CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions;')
        if re.search(r'^CREATE SCHEMA public;', baseline, re.M):
            sql('DROP SCHEMA public;')
        sql(baseline)
        assert sql('SELECT count(*) FROM auth.users') == '0', 'Schema-only source unexpectedly contained rows'
        applied = set(sql('SELECT version FROM supabase_migrations.schema_migrations', SOURCE).splitlines())
        for migration in sorted((ROOT / 'migrations').glob('*.sql')):
            if migration.name.split('_')[0] not in applied:
                sql('BEGIN;\n' + migration.read_text() + '\nCOMMIT;')
        assert sql("SELECT NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname IN ('pg_cron','pg_net')), "
                   "NOT EXISTS (SELECT 1 FROM pg_subscription), (SELECT count(*) FROM public.profiles)=0") == 't|t|t'

        users = [str(uuid.uuid4()) for _ in range(4)]
        for user in users:
            sql(f"INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) "
                f"VALUES('00000000-0000-0000-0000-000000000000',{quote(user)},'authenticated','authenticated',"
                f"{quote(user+'@ucf.edu')},'',now(),now(),now()); "
                f"INSERT INTO public.profiles(id,display_name) VALUES({quote(user)},'Host Race Test');")

        def authenticated(user, action):
            return ("BEGIN; SET LOCAL statement_timeout='8s'; SET LOCAL lock_timeout='4s'; SET LOCAL role authenticated; "
                    f"SELECT set_config('request.jwt.claim.sub',{quote(user)},true); "
                    f"SELECT set_config('request.jwt.claims',{quote(json.dumps(dict(sub=user,email=user+'@ucf.edu')))},true); " + action)

        def game(capacity=2, occupied=1):
            session = str(uuid.uuid4())
            status = 'full' if capacity == occupied else 'open'
            sql(f"INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,player_count,skill_level,status) "
                f"VALUES({quote(session)},{quote(users[0])},'basketball',now()+interval '2 hours',now()+interval '3 hours',"
                f"{capacity},{occupied},'any',{quote(status)}); "
                f"INSERT INTO public.session_participants(session_id,user_id,role,status) "
                f"VALUES({quote(session)},{quote(users[0])},'host','joined');")
            if occupied == 2:
                sql(f"INSERT INTO public.session_participants(session_id,user_id,role,status) "
                    f"VALUES({quote(session)},{quote(users[1])},'player','joined');")
            return session

        def invariant(session, cancelled=False):
            row = sql(f"SELECT player_count,capacity,status,(SELECT count(*) FROM public.session_participants "
                      f"WHERE session_id=s.id AND status='joined') FROM public.sessions s WHERE id={quote(session)}").split('|')
            count, capacity, status, joined = int(row[0]), int(row[1]), row[2], int(row[3])
            assert count == joined and 1 <= count <= capacity, 'Membership/count/capacity drift'
            assert status == ('cancelled' if cancelled else ('full' if count == capacity else 'open')), 'Lifecycle drift'

        def ordered(leader, follower, expected_error=None):
            process = subprocess.Popen(command(container) + ['-h', '/tmp'], stdin=subprocess.PIPE,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                process.stdin.write(leader + " SELECT 'LOCKED'; SELECT pg_sleep(0.4); COMMIT;")
                process.stdin.close()
                while True:
                    line = process.stdout.readline()
                    if line.strip() == 'LOCKED':
                        break
                    if not line:
                        raise AssertionError('Leader failed before lock marker')
                try:
                    sql(follower + ' COMMIT;')
                    assert expected_error is None, 'Expected competing action to reject'
                except subprocess.CalledProcessError as error:
                    assert expected_error and expected_error in error.stderr, 'Unexpected competing action error'
                assert process.wait(timeout=10) == 0, 'Leader transaction failed'
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)

        def join(session, user=users[2]):
            return authenticated(user, f'SELECT public.join_session({quote(session)});')

        def cancel(session):
            return authenticated(users[0], f"UPDATE public.sessions SET status='cancelled' WHERE id={quote(session)};")

        session = game()
        ordered(cancel(session), join(session), 'session_not_joinable')
        invariant(session, cancelled=True)
        session = game()
        ordered(join(session), cancel(session))
        invariant(session, cancelled=True)
        session = game(capacity=3, occupied=2)
        reduce = authenticated(users[0], f'UPDATE public.sessions SET capacity=2 WHERE id={quote(session)};')
        ordered(reduce, join(session))
        invariant(session)
        assert sql(f"SELECT status FROM public.session_participants WHERE session_id={quote(session)} AND user_id={quote(users[2])}") == 'waitlist'
        session = game(capacity=3, occupied=2)
        reduce = authenticated(users[0], f'UPDATE public.sessions SET capacity=2 WHERE id={quote(session)};')
        ordered(join(session), reduce, 'violates check constraint')
        invariant(session)

        for _ in range(12):
            session = game()
            barrier = threading.Barrier(2)

            def race(action):
                barrier.wait(timeout=5)
                try:
                    sql(action + ' COMMIT;')
                except subprocess.CalledProcessError as error:
                    assert 'session_not_joinable' in error.stderr, 'Unexpected cancellation/join race error'

            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                list(pool.map(race, [join(session), cancel(session)]))
            invariant(session, cancelled=True)

        session = game(capacity=2, occupied=2)
        sql(join(session) + ' COMMIT;')
        sql(f"UPDATE public.session_participants SET joined_at=now()-interval '2 minutes' "
            f"WHERE session_id={quote(session)} AND user_id={quote(users[2])};")
        before = sql(f"SELECT joined_at FROM public.session_participants WHERE session_id={quote(session)} AND user_id={quote(users[2])}")
        barrier = threading.Barrier(6)

        def retry(_):
            barrier.wait(timeout=5)
            sql(join(session) + ' COMMIT;')

        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            list(pool.map(retry, range(6)))
        after = sql(f"SELECT joined_at FROM public.session_participants WHERE session_id={quote(session)} AND user_id={quote(users[2])}")
        assert before == after, 'Concurrent retries reset waitlist priority'
        invariant(session)
        print('Isolated host actions: 4 ordered races, 12 cancellation/join races, 6 waitlist retries passed.')
    finally:
        if created:
            subprocess.run(['docker', 'rm', '-f', container], check=True, capture_output=True, timeout=15)
        print('Private diagnostics:', logs)


if __name__ == '__main__':
    main()
