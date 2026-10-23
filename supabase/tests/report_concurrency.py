"""Exercise moderation report limits using the schema-only disposable harness.

No source DB rows/writes or production connections. A test-only BEFORE INSERT
delay widens the count/insert window; only committed report counts decide success.
"""
import concurrent.futures
import json
import subprocess
import threading
import uuid

from host_action_concurrency import ROOT, command, main as isolated_database, quote
from run_candidate_suite import expand


def exercise(sql, container):
    # Run the complete candidate suite here, never against the existing local DB.
    suite = subprocess.run(command(container) + ['-h', '/tmp'],
                           input='BEGIN;\n' + expand(ROOT / 'tests' / 'run_all.sql') + '\nROLLBACK;',
                           text=True, capture_output=True, timeout=60)
    assert suite.returncode == 0, suite.stderr
    notices = sum('NOTICE:' in line for line in suite.stderr.splitlines())
    assert notices >= 38, 'Candidate suite did not complete all known phases'
    print(f'Isolated candidate SQL/RLS: {notices} notices; rolled back.', flush=True)

    def user():
        identity = str(uuid.uuid4())
        sql(f"INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) "
            f"VALUES('00000000-0000-0000-0000-000000000000',{quote(identity)},'authenticated','authenticated',"
            f"{quote(identity+'@ucf.edu')},'',now(),now(),now()); "
            f"INSERT INTO public.profiles(id,display_name) VALUES({quote(identity)},'Report Race Test');")
        return identity

    targets = [user() for _ in range(6)]
    sql("CREATE FUNCTION public.test_report_delay() RETURNS trigger LANGUAGE plpgsql AS $$ "
        "BEGIN PERFORM pg_sleep(0.4); RETURN NEW; END $$; "
        "CREATE TRIGGER test_report_delay BEFORE INSERT ON public.moderation_reports "
        "FOR EACH ROW EXECUTE FUNCTION public.test_report_delay();")

    def authenticated(reporter):
        claims = json.dumps(dict(sub=reporter, email=reporter+'@ucf.edu'))
        return ("BEGIN; SET LOCAL statement_timeout='8s'; SET LOCAL lock_timeout='6s'; "
                "SET LOCAL role authenticated; "
                f"SELECT set_config('request.jwt.claim.sub',{quote(reporter)},true); "
                f"SELECT set_config('request.jwt.claims',{quote(claims)},true); ")

    def report(reporter, target):
        return authenticated(reporter) + f"SELECT public.submit_moderation_report('user',{quote(target)},'other',NULL);"

    def submit(statement, errors=('report_rate_limited',), sqlstate=None):
        try:
            sql('\\set VERBOSITY verbose\n' + statement + ' COMMIT;')
            return 'accepted'
        except subprocess.CalledProcessError as error:
            matched = [message for message in errors if message in error.stderr]
            assert len(matched) == 1, error.stderr
            if sqlstate:
                assert sqlstate + ':' in error.stderr, error.stderr
            return matched[0]

    def race(reporter):
        barrier = threading.Barrier(6)

        def request(target):
            barrier.wait(timeout=5)
            return submit(report(reporter, target))

        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            return list(pool.map(request, targets))

    reporter = user()
    results = race(reporter)
    count = int(sql(f"SELECT count(*) FROM public.moderation_reports WHERE reporter_id={quote(reporter)}"))
    print(f'Hourly race: {results.count("accepted")} accepted; {count} committed.', flush=True)
    assert count == 5 and results.count('report_rate_limited') == 1, 'Concurrent reports exceeded 5/hour'

    # Recovered hourly capacity must keep the old records and still count them daily.
    sql(f"UPDATE public.moderation_reports SET created_at=now()-interval '61 minutes' WHERE reporter_id={quote(reporter)};")
    assert submit(report(reporter, user())) == 'accepted'
    assert sql(f"SELECT count(*) FROM public.moderation_reports WHERE reporter_id={quote(reporter)}") == '6'

    reporter = user()
    sql(f"INSERT INTO public.moderation_reports(reporter_id,target_type,target_user_id,subject_user_id,category,target_snapshot,created_at,status) "
        f"SELECT {quote(reporter)},'user',{quote(targets[0])},{quote(targets[0])},'other','{{}}',"
        "now()-interval '2 hours','resolved' FROM generate_series(1,19);")
    results = race(reporter)
    count = int(sql(f"SELECT count(*) FROM public.moderation_reports WHERE reporter_id={quote(reporter)}"))
    print(f'Daily race: {results.count("accepted")} accepted; {count} committed.', flush=True)
    assert count == 20 and results.count('report_rate_limited') == 5, 'Concurrent reports exceeded 20/day'
    sql(f"UPDATE public.moderation_reports SET created_at=now()-interval '2 days',status='resolved' WHERE reporter_id={quote(reporter)};")
    assert submit(report(reporter, targets[0])) == 'accepted'
    assert sql(f"SELECT count(*) FROM public.moderation_reports WHERE reporter_id={quote(reporter)}") == '21'

    # Delay is solely race amplification; remove it before ordered lock checks.
    sql('DROP TRIGGER test_report_delay ON public.moderation_reports; DROP FUNCTION public.test_report_delay();')

    def ordered(leader, follower, errors=()):
        process = subprocess.Popen(command(container) + ['-h', '/tmp'], stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            process.stdin.write(leader + " SELECT 'LOCKED'; SELECT pg_sleep(1.5); COMMIT;")
            process.stdin.close()
            while True:
                line = process.stdout.readline()
                if line.strip() == 'LOCKED':
                    break
                assert line, 'Leader failed before lock marker'
            result = submit(follower, errors)
            assert process.wait(timeout=10) == 0, process.stderr.read()
            return result
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)

    first, second = user(), user()
    # An uncommitted report for A must not block B (500ms lock timeout).
    follower = authenticated(second) + "SET LOCAL lock_timeout='500ms'; "
    follower += f"SELECT public.submit_moderation_report('user',{quote(targets[0])},'other',NULL);"
    assert ordered(report(first, targets[0]), follower) == 'accepted'

    # Same-target conflicts retain their public error and do not consume quota.
    duplicate = user()
    assert ordered(report(duplicate, targets[0]), report(duplicate, targets[0]),
                   ('report_already_submitted',)) == 'report_already_submitted'
    assert submit(report(duplicate, targets[1])) == 'accepted'
    assert sql(f"SELECT count(*) FROM public.moderation_reports WHERE reporter_id={quote(duplicate)}") == '2'

    # Account deletion wins: the waiting stale caller is denied. Reverse order:
    # deletion waits for the accepted report and its audit survives account removal.
    deleted = user()
    delete = authenticated(deleted) + 'SELECT public.delete_own_account();'
    assert ordered(delete, report(deleted, targets[0]), ('not_authenticated',)) == 'not_authenticated'
    retained = user()
    delete = authenticated(retained) + 'SELECT public.delete_own_account();'
    assert ordered(report(retained, targets[0]), delete) == 'accepted'
    assert sql(f"SELECT count(*) FROM auth.users WHERE id={quote(retained)}") == '0'
    assert sql(f"SELECT count(*) FROM public.moderation_reports WHERE reporter_id={quote(retained)} AND target_snapshot->>'display_name'='Report Race Test'") == '1'

    # Reciprocal targets never lock the other reporter's account row.
    a, b = user(), user()
    barrier = threading.Barrier(2)

    def reciprocal(pair):
        barrier.wait(timeout=5)
        return submit(report(*pair))

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        assert list(pool.map(reciprocal, [(a, b), (b, a)])) == ['accepted', 'accepted']

    # Establish a transaction-wide snapshot before invoking the RPC. Both stronger
    # modes fail closed even if no competing report happened to commit yet.
    for isolation in ('REPEATABLE READ', 'SERIALIZABLE'):
        actor = user()
        statement = report(actor, targets[0]).replace('BEGIN;', f'BEGIN ISOLATION LEVEL {isolation};', 1)
        statement = statement.replace('SET LOCAL role authenticated;',
                                      "SET LOCAL role authenticated; SELECT pg_current_snapshot();")
        assert submit(statement, ('report_requires_read_committed',), '40001') == 'report_requires_read_committed'
        assert sql(f"SELECT count(*) FROM public.moderation_reports WHERE reporter_id={quote(actor)}") == '0'

    print('Report concurrency: independent/reciprocal reporters, duplicates, window recovery, both deletion orders, snapshot guards passed.', flush=True)


if __name__ == '__main__':
    isolated_database(exercise)
