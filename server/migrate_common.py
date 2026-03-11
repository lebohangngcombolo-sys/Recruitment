import tempfile
from collections import defaultdict, deque

import psycopg2


SRC = {
    "host": "dpg-d62tb67pm1nc738h8jv0-a.oregon-postgres.render.com",
    "db": "recruitement_deploy",
    "user": "recruitement_deploy_user",
    "pass": "tHkpCaJ8nxQpN1tCItF7BEXNvzLrkgiQ",
}

DST = {
    "host": "dpg-d64aam8gjchc739jpt5g-a.oregon-postgres.render.com",
    "db": "recruitment_db_vexi",
    "user": "recruitment_db_vexi_user",
    "pass": "UcI5op62mjxTmneB9ZThvaxoC4EGMspu",
}


def connect(cfg):
    return psycopg2.connect(
        host=cfg["host"],
        dbname=cfg["db"],
        user=cfg["user"],
        password=cfg["pass"],
    )


def fetch_tables(cur):
    cur.execute(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        """
    )
    return {row[0] for row in cur.fetchall()}


def fetch_columns(cur, table):
    cur.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = %s
        ORDER BY ordinal_position
        """,
        (table,),
    )
    return [row[0] for row in cur.fetchall()]


def fetch_fks(cur):
    cur.execute(
        """
        SELECT tc.table_name, ccu.table_name AS foreign_table_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu
          ON ccu.constraint_name = tc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'public'
        """
    )
    return cur.fetchall()


def topo_sort(tables, fks):
    graph = defaultdict(set)
    indeg = defaultdict(int)
    for table in tables:
        indeg[table] = 0
    for child, parent in fks:
        if child in tables and parent in tables and parent != child:
            if child not in graph[parent]:
                graph[parent].add(child)
                indeg[child] += 1
    queue = deque([t for t in tables if indeg[t] == 0])
    order = []
    while queue:
        table = queue.popleft()
        order.append(table)
        for nxt in graph[table]:
            indeg[nxt] -= 1
            if indeg[nxt] == 0:
                queue.append(nxt)
    for table in tables:
        if table not in order:
            order.append(table)
    return order


def update_sequences(cur):
    cur.execute(
        """
        SELECT sequence_schema, sequence_name
        FROM information_schema.sequences
        WHERE sequence_schema = 'public'
        """
    )
    for schema, seq in cur.fetchall():
        if not seq.endswith("_id_seq"):
            continue
        table = seq[:-7]
        cur.execute(f'SELECT MAX(id) FROM "{table}"')
        max_id = cur.fetchone()[0] or 1
        cur.execute(f"SELECT setval('\"{schema}\".\"{seq}\"', {max_id})")


def main():
    with connect(SRC) as src_conn, connect(DST) as dst_conn:
        src_cur = src_conn.cursor()
        dst_cur = dst_conn.cursor()

        src_tables = fetch_tables(src_cur)
        dst_tables = fetch_tables(dst_cur)
        common_tables = sorted(src_tables & dst_tables)

        print(f"Common tables: {len(common_tables)}")
        if not common_tables:
            print("No common tables found.")
            return

        fks = fetch_fks(dst_cur)
        order = topo_sort(common_tables, fks)

        print("Truncating destination tables...")
        for table in reversed(order):
            dst_cur.execute(f'TRUNCATE TABLE "{table}" CASCADE;')
        dst_conn.commit()

        for table in order:
            src_cols = fetch_columns(src_cur, table)
            dst_cols = fetch_columns(dst_cur, table)
            common_cols = [c for c in src_cols if c in dst_cols]
            if not common_cols:
                print(f"SKIP {table}: no common columns")
                continue

            cols_csv = ",".join([f'"{c}"' for c in common_cols])
            with tempfile.NamedTemporaryFile(mode="w+b", delete=True) as tmp:
                src_cur.copy_expert(
                    f'COPY (SELECT {cols_csv} FROM "{table}") TO STDOUT WITH CSV',
                    tmp,
                )
                tmp.seek(0)
                dst_cur.copy_expert(
                    f'COPY "{table}"({cols_csv}) FROM STDIN WITH CSV',
                    tmp,
                )
            dst_conn.commit()
            print(f"MIGRATED {table}")

        print("Updating sequences...")
        update_sequences(dst_cur)
        dst_conn.commit()
        print("Done.")


if __name__ == "__main__":
    main()
