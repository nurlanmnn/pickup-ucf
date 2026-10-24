"""Exercise Live Activity lifecycle ordering in a schema-only disposable DB.

No source rows or production connections. Ordered races observe the follower's
actual database lock wait before releasing the leader, rather than relying on sleep.
"""
import concurrent.futures
import json
import subprocess
import time
import uuid

from host_action_concurrency import ROOT, command, main as isolated_database, quote
from run_candidate_suite import expand


def exercise(sql, container):
    suite = subprocess.run(command(container) + ['-h', '/tmp'],
                           input='BEGIN;\n' + expand(ROOT / 'tests' / 'run_all.sql') + '\nROLLBACK;',
                           text=True, capture_output=True, timeout=60)
    assert suite.returncode == 0, suite.stderr
    notices = sum('NOTICE:' in line for line in suite.stderr.splitlines())
    assert notices >= 38, 'Candidate suite did not complete all known phases'
    print(f'Isolated candidate SQL/RLS: {notices} notices; rolled back.', flush=True)

    def user():
        actor = str(uuid.uuid4())
        sql(f"INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) "
            f"VALUES('00000000-0000-0000-0000-000000000000',{quote(actor)},'authenticated','authenticated',"
            f"{quote(actor+'@ucf.edu')},'',now(),now(),now()); "
            f"INSERT INTO public.profiles(id,display_name) VALUES({quote(actor)},'Activity Race Test');")
        return actor

    def game(host, player):
        session = str(uuid.uuid4())
        sql(f"INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,player_count,skill_level,status) "
            f"VALUES({quote(session)},{quote(host)},'basketball',now()+interval '30 minutes',now()+interval '90 minutes',3,2,'any','open'); "
            f"INSERT INTO public.session_participants(session_id,user_id,role,status) VALUES "
            f"({quote(session)},{quote(host)},'host','joined'),({quote(session)},{quote(player)},'player','joined');")
        return session

    def authenticated(actor, action):
        claims = json.dumps(dict(sub=actor, email=actor+'@ucf.edu'))
        return ("BEGIN; SET LOCAL statement_timeout='8s'; SET LOCAL lock_timeout='6s'; SET LOCAL role authenticated; "
                f"SELECT set_config('request.jwt.claim.sub',{quote(actor)},true); "
                f"SELECT set_config('request.jwt.claims',{quote(claims)},true); " + action)

    def register(actor, session, token):
        return authenticated(actor, f"SELECT public.register_live_activity_token({quote(session)},{quote(token)});")

    def submit(statement, expected_error=None, sqlstate=None):
        try:
            sql('\\set VERBOSITY verbose\n' + statement + ' COMMIT;')
            assert expected_error is None, f'Expected {expected_error}'
            return 'accepted'
        except subprocess.CalledProcessError as error:
            assert expected_error and expected_error in error.stderr, error.stderr
            if sqlstate:
                assert sqlstate + ':' in error.stderr, error.stderr
            return expected_error

    def ordered(leader, follower, expected_error=None, wait=True):
        process = subprocess.Popen(command(container) + ['-h', '/tmp'], stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        pool = concurrent.futures.ThreadPoolExecutor(max_workers=1)
        try:
            process.stdin.write(leader + " SELECT 'LOCKED';\n")
            process.stdin.flush()
            while True:
                line = process.stdout.readline()
                if line.strip() == 'LOCKED':
                    break
                assert line, 'Leader failed before lock marker: ' + process.stderr.read()
            name = 'activity-follower-' + uuid.uuid4().hex
            follower = follower.replace('BEGIN;', f"BEGIN; SET LOCAL application_name={quote(name)};", 1)
            pending = pool.submit(submit, follower, expected_error)
            if wait:
                deadline = time.monotonic() + 4
                while sql(f"SELECT count(*) FROM pg_stat_activity WHERE application_name={quote(name)} "
                          "AND wait_event_type='Lock'") != '1':
                    assert not pending.done(), 'Follower completed before lifecycle lock was released'
                    assert time.monotonic() < deadline, 'Follower never entered a lock wait'
                    time.sleep(0.02)
            else:
                # Compatible registrations must finish while the first remains uncommitted.
                assert pending.result(timeout=4) == 'accepted'
            process.stdin.write('COMMIT;\n')
            process.stdin.close()
            assert process.wait(timeout=10) == 0, process.stderr.read()
            return pending.result(timeout=10)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            pool.shutdown(wait=True)

    def active(session):
        return int(sql(f"SELECT count(*) FROM public.live_activity_tokens WHERE session_id={quote(session)} "
                       "AND ended_at IS NULL AND ends_at>now();"))

    def aligned(session):
        assert sql(f"SELECT bool_and((t.starts_at,t.ends_at)=(s.starts_at,s.ends_at)) "
                   f"FROM public.live_activity_tokens t JOIN public.sessions s ON s.id=t.session_id "
                   f"WHERE s.id={quote(session)}") == 't', 'Token schedule drifted'

    host, player = user(), user()
    for action in ('cancel', 'leave', 'schedule', 'outside_window'):
        for registration_first in (False, True):
            session, token = game(host, player), uuid.uuid4().hex * 2
            registration = register(player, session, token)
            if action == 'leave':
                lifecycle = authenticated(player, f'SELECT public.leave_session({quote(session)});')
            else:
                change = {'cancel': "status='cancelled'", 'schedule': "starts_at=starts_at+interval '10 minutes',ends_at=ends_at+interval '10 minutes'",
                          'outside_window': "starts_at=starts_at+interval '2 hours',ends_at=ends_at+interval '2 hours'"}[action]
                lifecycle = authenticated(host, f'UPDATE public.sessions SET {change} WHERE id={quote(session)};')
            if registration_first:
                assert ordered(registration, lifecycle) == 'accepted'
            else:
                expected = None if action == 'schedule' else 'live_activity_session_not_available'
                assert ordered(lifecycle, registration, expected) == (expected or 'accepted')
            if action == 'schedule':
                assert active(session) == 1
                aligned(session)
            else:
                assert active(session) == 0, f'{action} retained a future active token'
    print('Lifecycle: both orders of cancellation, leave, schedule and eligibility-window edit passed.', flush=True)

    session = game(host, player)
    first, second = uuid.uuid4().hex * 2, uuid.uuid4().hex * 2
    ordered(register(player, session, first), register(player, session, second), wait=False)
    assert active(session) == 2, 'Distinct device registrations interfered'
    third = uuid.uuid4().hex * 2
    ordered(register(player, session, third), register(player, session, third))
    assert active(session) == 3, 'Duplicate retry created another token'
    sql(f"UPDATE public.live_activity_tokens SET started_at=now(),needs_update=false WHERE apns_token={quote(first)}")
    before = sql(f"SELECT row_to_json(t) FROM public.live_activity_tokens t WHERE apns_token={quote(first)}")
    submit(register(player, session, first.upper()))
    assert before == sql(f"SELECT row_to_json(t) FROM public.live_activity_tokens t WHERE apns_token={quote(first)}"), 'Retry reset delivery state'
    submit(register(host, session, first), 'invalid_live_activity_token')
    other = game(host, player)
    submit(register(player, other, first), 'invalid_live_activity_token')
    for ended in (True, False):
        token = uuid.uuid4().hex * 2
        submit(register(player, session, token))
        terminal = 'ended_at=now()' if ended else "ends_at=now()-interval '1 minute'"
        sql(f'UPDATE public.live_activity_tokens SET {terminal} WHERE apns_token={quote(token)}')
        before = sql(f'SELECT row_to_json(t) FROM public.live_activity_tokens t WHERE apns_token={quote(token)}')
        submit(register(player, session, token))
        assert before == sql(f'SELECT row_to_json(t) FROM public.live_activity_tokens t WHERE apns_token={quote(token)}'), 'Retry resurrected a terminal token'
    print('Tokens: simultaneous devices, duplicate retries, ownership, normalization and terminal-state preservation passed.', flush=True)

    for deleting in ('player', 'host'):
        for registration_first in (False, True):
            owner, member = user(), user()
            session, token = game(owner, member), uuid.uuid4().hex * 2
            actor = member if deleting == 'player' else owner
            registration = register(member, session, token)
            deletion = authenticated(actor, 'SELECT public.delete_own_account();')
            if registration_first:
                ordered(registration, deletion)
            else:
                expected = 'not_authenticated' if deleting == 'player' else 'live_activity_session_not_available'
                ordered(deletion, registration, expected)
            assert active(session) == 0, 'Account deletion retained a future active token'
            assert sql(f'SELECT count(*) FROM auth.users WHERE id={quote(actor)}') == '0'
            if deleting == 'player':
                submit(registration, 'not_authenticated')
    # A host's own registration shares the same account-before-session order.
    owner, member = user(), user()
    session = game(owner, member)
    ordered(register(owner, session, uuid.uuid4().hex * 2), authenticated(owner, 'SELECT public.delete_own_account();'))
    assert active(session) == 0
    print('Deletion: both player/host deletion orders, stale caller and host-own registration passed.', flush=True)

    for isolation in ('REPEATABLE READ', 'SERIALIZABLE'):
        statement = register(player, game(host, player), uuid.uuid4().hex * 2)
        statement = statement.replace('BEGIN;', f'BEGIN ISOLATION LEVEL {isolation}; SELECT count(*) FROM public.sessions;', 1)
        submit(statement, 'live_activity_requires_read_committed', sqlstate='40001')
    print('Snapshot guards: repeatable-read and serializable fail closed with 40001.', flush=True)


if __name__ == '__main__':
    isolated_database(exercise)
