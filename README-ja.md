# PG-Strom Containers

## これは何？

"[PG-Strom](https://github.com/heterodb/pg-strom)"をコンテナの中で実行する試みです。

## ソフトウェア要件

- ホストOS: Red Hat Enterprise Linux 8.6以降
- Docker engine 20.10.21以降
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#install-guide) の要件

## どうやって動かすか

- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/overview.html) をセットアップ
- Dockerfileを記述

例えば...

```
FROM docker.io/nvidia/cuda:11.8.0-devel-rockylinux8

RUN curl -LO https://heterodb.github.io/swdc/yum/rhel8-noarch/heterodb-swdc-1.2-1.el8.noarch.rpm && \
    curl -LO https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    curl -LO https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

RUN rpm -i heterodb-swdc-1.2-1.el8.noarch.rpm && \
    rpm -i epel-release-latest-8.noarch.rpm && \
    rpm -i pgdg-redhat-repo-latest.noarch.rpm

RUN dnf -y module disable postgresql
RUN dnf install --enablerepo=powertools -y postgresql14-devel postgresql14-server postgresql-alternatives pg_strom-PG14

ENV PATH /usr/pgsql-14/bin:$PATH
ENV PGDATA /var/lib/pgsql/14/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/pgsql/14/data

#If you want to use the full version of PG-Strom, Please Remove the Comments.
# COPY heterodb.license /etc/heterodb.license
# RUN dnf install -y heterodb-extra
# RUN dnf --enablerepo=powertools install -y postgis32_14

EXPOSE 5432
```

- コンテナイメージを作成

```
# docker image build --compress -t mypg14-rocky8:latest -f Dockerfile .
```

- コンテナを起動

`--shm-size` オプションを使用して、適切な共有メモリをコンテナーに設定します。

```
# docker container run --gpus all --shm-size=8gb --memory=8gb -p 5432:5432 -itd --name=cont1 mypg14-rocky8:latest
# docker container exec -it cont1 /bin/bash
```

- initdbコマンドをコンテナで実行

```
# su - postgres
$ /usr/pgsql-14/bin/initdb -D /var/lib/pgsql/14/data
```

- パラメータの変更

例えば...

```
$ vi /var/lib/pgsql/14/data/postgresql.conf
...
shared_preload_libraries = '$libdir/pg_strom'
max_worker_processes = 100
shared_buffers = 4GB
work_mem = 1GB
```

- PostgreSQL Serverを起動

```
$ /usr/pgsql-14/bin/pg_ctl -D /var/lib/pgsql/14/data -l logfile start
$ cat /var/lib/pgsql/logfile 
2022-12-22 05:12:27.351 UTC [135] LOG:  NVRTC 11.8 is successfully loaded, but CUDA driver expects 12.0. Check /etc/ld.so.conf or LD_LIBRARY_PATH configuration.
2022-12-22 05:12:27.352 UTC [135] LOG:  HeteroDB Extra module is not available
2022-12-22 05:12:27.352 UTC [135] LOG:  PG-Strom version 3.4 built for PostgreSQL 14 (git: HEAD)
2022-12-22 05:12:27.684 UTC [135] LOG:  PG-Strom: GPU0 NVIDIA GeForce GTX 1050 Ti (6 SMs; 1417MHz, L2 1024kB), RAM 4038MB (128bits, 3.34GHz), PCI-E Bar1 0MB, CC 6.1
2022-12-22 05:12:27.817 UTC [135] LOG:  redirecting log output to logging collector process
2022-12-22 05:12:27.817 UTC [135] HINT:  Future log output will appear in directory "log".
```

- 試してみましょう

```
[root@7510416bd1ee /]# su - postgres
Last login: Wed Nov  9 02:52:33 UTC 2022 on pts/0
[postgres@7510416bd1ee ~]$ psql -U postgres -d postgres
psql (14.8)
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

testdb2=# VACUUM t_test1;
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
