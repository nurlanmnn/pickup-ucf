"""Concurrent duplicate-request check against the local Docker database only.

Apply the atomic-creation migration to the local test DB first. Synthetic fixtures
are committed for concurrent connections, then removed in finally. No remote URL,
credentials, reset, or migration operation is accepted by this script.
"""
import concurrent.futures
import datetime
import json
import re
import subprocess
import threading
import uuid

CONTAINER = "supabase_db_pickup-ucf"


def sql(statement):
    result = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-v", "ON_ERROR_STOP=1", "-At", "-U", "postgres", "-d", "postgres"],
        input=statement, capture_output=True, text=True, check=True,
    )
    return result.stdout


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def main():
    owner = str(uuid.uuid4())
    request = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc)
    payload = json.dumps(dict(sport="tennis", skill_level="any", capacity=4,
                             starts_at=(now + datetime.timedelta(hours=2)).isoformat(),
                             ends_at=(now + datetime.timedelta(hours=3)).isoformat(),
                             custom_location="Synthetic concurrent court", custom_lat=28.6, custom_lng=-81.2))
    claims = json.dumps(dict(sub=owner, email="atomic-concurrent@ucf.edu"))
    owner_sql = quote(owner)
    try:
        sql(f"""BEGIN;
            INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
            VALUES ('00000000-0000-0000-0000-000000000000',{owner_sql},'authenticated','authenticated',
                    'atomic-concurrent@ucf.edu','',now(),now(),now());
            INSERT INTO public.profiles(id,display_name) VALUES({owner_sql},'Concurrent Test');
            COMMIT;""")
        barrier = threading.Barrier(6)

        def attempt(_):
            barrier.wait(timeout=10)
            output = sql(f"""BEGIN; SET LOCAL role authenticated;
                SELECT set_config('request.jwt.claim.sub',{owner_sql},true);
                SELECT set_config('request.jwt.claims',{quote(claims)},true);
                SELECT public.create_session({quote(request)},{quote(payload)}::jsonb);
                SELECT pg_sleep(0.2); COMMIT;""")
            return [line for line in output.splitlines() if re.fullmatch(r"[0-9a-f-]{36}", line)][-1]

        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            sessions = list(executor.map(attempt, range(6)))
        assert len(set(sessions)) == 1, sessions
        counts = sql(f"""SELECT
            (SELECT count(*) FROM public.sessions WHERE host_id={owner_sql}),
            (SELECT count(*) FROM public.session_participants WHERE user_id={owner_sql}),
            (SELECT count(*) FROM pickup_private.session_creation_requests WHERE host_id={owner_sql});""").strip()
        assert counts == "1|1|1", counts
        print("atomic creation concurrency: 6 simultaneous requests, one session, one host, one receipt OK")
    finally:
        sql(f"""BEGIN; DELETE FROM public.sessions WHERE host_id={owner_sql};
            DELETE FROM public.profiles WHERE id={owner_sql};
            DELETE FROM auth.users WHERE id={owner_sql}; COMMIT;""")


if __name__ == "__main__":
    main()
