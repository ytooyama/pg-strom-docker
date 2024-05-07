# PG-Strom Containers

## これは何？

"[PG-Strom](https://github.com/heterodb/pg-strom)"をコンテナの中で実行する試みです。

## ソフトウェア要件

- ホストOS: Red Hat Enterprise Linux 8.8もしくは9.2以降
- Docker engine 26.1.1以降
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#install-guide) の要件

## どうやって動かすか

- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/overview.html) をセットアップ
- Dockerfileを記述

例えば...

- コンテナイメージを作成

```bash
# cd pg-strom-docker/docker
# docker image build --compress -t mypg15-rocky8:latest -f Dockerfile .
```

- コンテナを起動

`--shm-size` オプションを使用して、適切な共有メモリをコンテナーに設定します。

```bash
# docker container run --gpus all --shm-size=8gb --memory=8gb -p 5432:5432 -itd --name=cont1 mypg16-rocky8:latest
# docker container exec -it cont1 /bin/bash
```

- initdbコマンドをコンテナで実行

```bash
# su - postgres
$ /usr/pgsql-16/bin/initdb -D /var/lib/pgsql/16/data
```

- パラメータの変更

例えば...

```bash
$ vi /var/lib/pgsql/16/data/postgresql.conf
...
shared_preload_libraries = '$libdir/pg_strom'
max_worker_processes = 100
shared_buffers = 4GB
work_mem = 1GB
```

- PostgreSQL Serverを起動

```bash
$ /usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/16/data -l logfile start
$ cat /var/lib/pgsql/logfile 
2024-05-07 08:12:30.823 UTC [148] LOG:  HeteroDB Extra module loaded [api_version=20240418,cufile=off,nvme_strom=off,githash=3ffc65428c07bb3c9d0e5c75a2973389f91dfcd4]
2024-05-07 08:12:30.823 UTC [148] LOG:  PG-Strom version 5.12.el8 built for PostgreSQL 16 (githash: )
2024-05-07 08:12:32.481 UTC [148] LOG:  PG-Strom binary built for CUDA 12.4 (CUDA runtime 12.4)
2024-05-07 08:12:32.481 UTC [148] LOG:  PG-Strom: GPU0 NVIDIA GeForce GTX 1650 SUPER (20 SMs; 1725MHz, L2 1024kB), RAM 3720MB (128bits, 5.72GHz), PCI-E Bar1 0MB, CC 7.5
2024-05-07 08:12:32.482 UTC [148] LOG:  [0000:01:00:0] GPU0 (NVIDIA GeForce GTX 1650 SUPER; GPU-44a7564d-a1a1-bc4e-699a-db8cec30ee7d)
2024-05-07 08:12:32.482 UTC [148] LOG:  [0000:02:00:0] nvme0 (CL1-3D256-Q11 NVMe SSSTC 256GB) --> GPU0 [dist=5]
2024-05-07 08:12:32.522 UTC [148] LOG:  redirecting log output to logging collector process
2024-05-07 08:12:32.522 UTC [148] HINT:  Future log output will appear in directory "log".
```

- 試してみましょう

```bash
# su - postgres
Last login: Wed Nov  9 02:52:33 UTC 2022 on pts/0
$ psql
psql (16.2)
Type "help" for help.

postgres=# CREATE DATABASE testdb2;
CREATE DATABASE

postgres=# \c testdb2
You are now connected to database "testdb2" as user "postgres".
testdb2=#

testdb2=# CREATE extension pg_strom;
CREATE EXTENSION

testdb2=# CREATE TABLE t_test AS SELECT id, id % 10 AS ten, id % 20 AS twenty
          FROM generate_series(1, 25000000) AS id
          ORDER BY id;

testdb2=# CREATE TABLE t_join AS SELECT *
       FROM   t_test
       ORDER BY random()
       LIMIT 1000000;

testdb2=# VACUUM FULL t_test;
testdb2=# VACUUM FULL t_join;

testdb2=# SELECT pg_size_pretty(pg_relation_size('t_test'));
 pg_size_pretty 
----------------
 1056 MB
(1 row)

testdb2=# SELECT pg_size_pretty(pg_relation_size('t_join'));
 pg_size_pretty 
----------------
 42 MB
(1 row)

testdb2=# SET pg_strom.enabled=off;
testdb2=# explain analyze SELECT count(*) FROM t_test AS a, t_join AS b WHERE a.id = b.id GROUP BY a.ten;
                                                                         QUERY PLAN

------------------------------------------------------------------------------------------------------------------------------
-------------------------------
 Finalize GroupAggregate  (cost=389641.98..389692.65 rows=200 width=12) (actual time=2039.033..2044.305 rows=10 loops=1)
   Group Key: a.ten
   ->  Gather Merge  (cost=389641.98..389688.65 rows=400 width=12) (actual time=2039.027..2044.297 rows=30 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Sort  (cost=388641.96..388642.46 rows=200 width=12) (actual time=2037.315..2037.317 rows=10 loops=3)
               Sort Key: a.ten
               Sort Method: quicksort  Memory: 25kB
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=388632.32..388634.32 rows=200 width=12) (actual time=2037.303..2037.306 rows=1
0 loops=3)
                     Group Key: a.ten
                     Batches: 1  Memory Usage: 40kB
                     Worker 0:  Batches: 1  Memory Usage: 40kB
                     Worker 1:  Batches: 1  Memory Usage: 40kB
                     ->  Parallel Hash Join  (cost=14781.00..336548.98 rows=10416667 width=4) (actual time=72.352..2002.739 ro
ws=333333 loops=3)
                           Hash Cond: (a.id = b.id)
                           ->  Parallel Seq Scan on t_test a  (cost=0.00..239302.67 rows=10416667 width=8) (actual time=0.044.
.425.452 rows=8333333 loops=3)
                           ->  Parallel Hash  (cost=9572.67..9572.67 rows=416667 width=4) (actual time=71.343..71.344 rows=333333 loops=
3)
                                 Buckets: 1048576  Batches: 1  Memory Usage: 47392kB
                                 ->  Parallel Seq Scan on t_join b  (cost=0.00..9572.67 rows=416667 width=4) (actual time=0.010..24.377
rows=333333 loops=3)
 Planning Time: 0.077 ms
 Execution Time: 2044.331 ms
(23 rows)

testdb2=# SET pg_strom.enabled=on;
testdb2=# explain analyze SELECT count(*) FROM t_test AS a, t_join AS b WHERE a.id = b.id GROUP BY a.ten;
                                                                     QUERY PLAN

------------------------------------------------------------------------------------------------------------------------------
-----------------------
 HashAggregate  (cost=82655.55..82657.55 rows=200 width=12) (actual time=921.113..921.163 rows=10 loops=1)
   Group Key: a.ten
   Batches: 1  Memory Usage: 40kB
   ->  Gather  (cost=82632.55..82654.55 rows=200 width=12) (actual time=921.099..921.153 rows=10 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Parallel Custom Scan (GpuPreAgg) on t_test a  (cost=81632.55..81634.55 rows=200 width=12) (actual time=905.828..9
05.831 rows=3 loops=3)
               GPU Projection: pgstrom.nrows(), a.ten
               GPU Join Quals [1]: (a.id = b.id) ... [plan: 10416670 -> 10416670, exec: 25000000 -> 1000000]
               GPU Outer Hash [1]: a.id
               GPU Inner Hash [1]: b.id
               ->  Parallel Seq Scan on t_join b  (cost=0.00..9572.67 rows=416667 width=4) (actual time=0.008..22.373 rows=333
333 loops=3)
 Planning Time: 0.116 ms
 Execution Time: 921.749 ms
(14 rows)
```
