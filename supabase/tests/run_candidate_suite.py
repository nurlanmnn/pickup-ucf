"""Verify pending migrations plus SQL/RLS tests in a local rollback transaction.

Requires the existing local Supabase Docker database. No remote URL, schema reset,
production connection, or credential argument is accepted. Migration history and
existing local data are preserved, including on failure.
"""
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
COMMAND = ['docker', 'exec', '-i', 'supabase_db_pickup-ucf', 'psql', '-U', 'postgres',
           '-d', 'postgres', '-v', 'ON_ERROR_STOP=1']


def expand(path):
    output = []
    for line in path.read_text().splitlines():
        if line.startswith('\\ir '):
            output.append(expand(path.parent / line[4:]))
        elif line not in ['BEGIN;', 'ROLLBACK;', '\\set ON_ERROR_STOP on']:
            output.append(line)
    return '\n'.join(output)


def main():
    current = subprocess.run(COMMAND + ['-Atc', 'SELECT version FROM supabase_migrations.schema_migrations'],
                             text=True, capture_output=True, check=True)
    applied = set(current.stdout.splitlines())
    pending = [p for p in sorted((ROOT / 'migrations').glob('*.sql')) if p.name.split('_')[0] not in applied]
    print('Local pending migrations:', ', '.join(p.name for p in pending) or 'none', flush=True)
    statement = 'BEGIN;\n' + '\n'.join(p.read_text() for p in pending)
    statement += '\n' + expand(ROOT / 'tests' / 'run_all.sql') + '\nROLLBACK;'
    subprocess.run(COMMAND, input=statement, text=True, check=True)
    print('Local candidate SQL/RLS suite passed; all changes rolled back.')


if __name__ == '__main__':
    main()
