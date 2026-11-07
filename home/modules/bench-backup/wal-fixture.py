#!/usr/bin/env python3

"""Exercise a SQLite snapshot while committed data remains in its WAL."""

import os
import sqlite3
import subprocess
import sys


database = os.path.join(os.environ['DATABASE_DIR'], 'votes.sqlite')
with sqlite3.connect(database) as source:
    source.execute('PRAGMA journal_mode=WAL')
    source.execute('PRAGMA wal_autocheckpoint=0')
    source.execute('CREATE TABLE votes (value TEXT)')
    source.execute('INSERT INTO votes VALUES (?)', ('committed vote',))
    source.commit()
    assert os.path.getsize(database + '-wal') > 0
    subprocess.run([sys.argv[1], '--no-config-file', '-c', sys.argv[2]], check=True)
    target = os.path.join(os.environ['SNAPSHOT'], 'local-votes.sqlite')
    assert os.stat(target).st_mode & 0o777 == 0o600
    with sqlite3.connect(target) as snapshot:
        assert snapshot.execute('PRAGMA integrity_check').fetchone() == ('ok',)
        assert snapshot.execute('SELECT value FROM votes').fetchall() == [
            ('committed vote',)
        ]
    assert source.execute('SELECT count(*) FROM votes').fetchone() == (1,)
