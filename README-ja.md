# pg-strom-docker

# これは何？

"PG-Strom"をコンテナの中で実行する試みです。

## ソフトウェア要件

- ホストOS: Red Hat Enterprise Linux 8.6以降
- Docker engine 20.10.21以降
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#install-guide) の要件 

## How does it work?

- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/overview.html) をセットアップ 
- Dockerfileを記述

例えば...

```
FROM docker.io/nvidia/cuda:11.8.0-devel-ubi8

RUN curl -LO https://heterodb.github.io/swdc/yum/rhel8-noarch/heterodb-swdc-1.2-1.el8.noarch.rpm && \
    curl -LO https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    curl -LO https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

RUN rpm -i heterodb-swdc-1.2-1.el8.noarch.rpm && \
    rpm -i epel-release-latest-8.noarch.rpm && \
    rpm -i pgdg-redhat-repo-latest.noarch.rpm

RUN dnf install -y postgresql13-devel postgresql13-server postgresql-alternatives pg_strom-PG13

EXPOSE 5432
```

- コンテナイメージを作成

```
# docker image build --compress -t mypg13-ubi8:latest -f Dockerfile .
```

- コンテナを起動

Use the `--shm-size` option to set the appropriate shared memory to the container.

```
# docker container run --gpus all --privileged --shm-size=8gb --memory=8gb --cpus=1.5 -p 5432:5432 -v ~/pg13data:/var/lib/pgsql/13/data -d --name=cont1 mypg13-ubi8:latest /sbin/init

# docker container exec -it cont1 /bin/bash
```

- initdbコマンドをコンテナで実行

```
# su - postgres
$ initdb -D /var/lib/pgsql/13/data
```

- パラメータの変更

例えば...

```
$ vi /var/lib/pgsql/13/data/postgresql.conf
...
shared_preload_libraries = '$libdir/pg_strom'
max_worker_processes = 100
shared_buffers = 4GB
work_mem = 1GB
```

- PostgreSQL Serverを起動

```
[root@db91f908338a /]# systemctl start postgresql-13
[root@db91f908338a /]# systemctl status postgresql-13
● postgresql-13.service - PostgreSQL 13 database server
   Loaded: loaded (/usr/lib/systemd/system/postgresql-13.service; disabled; vendor preset: disabled)
  Drop-In: /etc/systemd/system/postgresql-13.service.d
           └─pg_strom.conf
   Active: active (running) since Tue 2022-11-08 08:44:43 UTC; 3s ago
     Docs: https://www.postgresql.org/docs/13/static/
  Process: 138 ExecStartPre=/usr/pgsql-13/bin/postgresql-13-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
 Main PID: 143 (postmaster)
    Tasks: 14 (limit: 100585)
   Memory: 291.5M
   CGroup: /docker/34b9137688438bee441586c0d5e3ac3d2dfa9841fba60d9049a479dabfd6266b/system.slice/postgresql-13.service
           ├─143 /usr/pgsql-13/bin/postmaster -D /var/lib/pgsql/13/data/
           ├─146 postgres: logger 
           ├─148 postgres: PG-Strom Program Builder-1 
           ├─149 postgres: PG-Strom Program Builder-0 
           ├─150 postgres: GPU0 memory keeper 
           ├─151 postgres: checkpointer 
           ├─152 postgres: background writer 
           ├─153 postgres: walwriter 
           ├─154 postgres: autovacuum launcher 
           ├─155 postgres: stats collector 
           └─156 postgres: logical replication launcher 

Nov 08 08:44:42 34b913768843 systemd[1]: Starting PostgreSQL 13 database server...
Nov 08 08:44:43 34b913768843 postmaster[143]: 2022-11-08 08:44:43.040 UTC [143] LOG:  NVRTC 11.8 is successfully loaded.
Nov 08 08:44:43 34b913768843 postmaster[143]: 2022-11-08 08:44:43.040 UTC [143] LOG:  HeteroDB Extra module is not available
Nov 08 08:44:43 34b913768843 postmaster[143]: 2022-11-08 08:44:43.040 UTC [143] LOG:  PG-Strom version 3.3 built for PostgreSQL 13 (git: v3.3-2)
Nov 08 08:44:43 34b913768843 postmaster[143]: 2022-11-08 08:44:43.292 UTC [143] LOG:  PG-Strom: GPU0 NVIDIA GeForce GTX 1050 Ti (6 SMs; 1417MHz, L2 1024kB), RAM 4040MB (128bits>
Nov 08 08:44:43 34b913768843 postmaster[143]: 2022-11-08 08:44:43.365 UTC [143] LOG:  redirecting log output to logging collector process
Nov 08 08:44:43 34b913768843 postmaster[143]: 2022-11-08 08:44:43.365 UTC [143] HINT:  Future log output will appear in directory "log".
Nov 08 08:44:43 34b913768843 systemd[1]: Started PostgreSQL 13 database server.
```

- 試してみましょう


```
[root@7510416bd1ee /]# su - postgres
Last login: Wed Nov  9 02:52:33 UTC 2022 on pts/0
[postgres@7510416bd1ee ~]$ psql -U postgres -d postgres
psql (13.8)
Type "help" for help.

postgres=# CREATE DATABASE testdb2;
CREATE DATABASE

postgres=# \c testdb2
You are now connected to database "testdb2" as user "postgres".
testdb2=#

testdb2=# CREATE extension pg_strom;
CREATE EXTENSION

testdb2=# CREATE TABLE t_test1 AS
 SELECT       x, 'a'::char(100) AS y, 'b'::char(100) AS z
 FROM   generate_series(1, 5000000) AS x
 ORDER BY random();
SELECT 5000000

testdb2=# SELECT pg_size_pretty(pg_relation_size('t_test1'));
 pg_size_pretty 
----------------
 1149 MB
(1 row)

testdb2=# VACUUM t_test;
VACUUM

testdb2=# EXPLAIN ANALYZE SELECT count(*)
 FROM   t_test1
 WHERE sqrt(x) > 0
 GROUP BY y;
                                                                        QUERY PLAN                                                                         
-----------------------------------------------------------------------------------------------------------------------------------------------------------
 GroupAggregate  (cost=100031.53..100031.56 rows=1 width=109) (actual time=2005.630..2009.869 rows=1 loops=1)
   Group Key: y
   ->  Sort  (cost=100031.53..100031.53 rows=2 width=109) (actual time=2005.609..2009.848 rows=3 loops=1)
         Sort Key: y
         Sort Method: quicksort  Memory: 25kB
         ->  Gather  (cost=100031.31..100031.52 rows=2 width=109) (actual time=1907.862..2009.776 rows=3 loops=1)
               Workers Planned: 2
               Workers Launched: 2
               ->  Parallel Custom Scan (GpuPreAgg) on t_test1  (cost=99031.31..99031.32 rows=1 width=109) (actual time=1856.234..1856.241 rows=1 loops=3)
                     Reduction: GroupBy (Global+Local [nrooms: 1974])
                     Group keys: y
                     Outer Scan: t_test1  (cost=2833.33..98814.29 rows=694445 width=101) (actual time=170.140..4400.335 rows=5000000 loops=1)
                     Outer Scan Filter: (sqrt((x)::double precision) > '0'::double precision)
 Planning Time: 0.246 ms
 Execution Time: 2053.813 ms
(15 rows)
```
