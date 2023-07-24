# PG-Strom Containers

## What's This ?

Trying to run "[PG-Strom](https://github.com/heterodb/pg-strom)" in a container!

## Software Requirements

- Host OS: Red Hat Enterprise Linux 8.6 or above
- Docker engine 20.10.21 or above
- Environments that meet the [requirements of the NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#install-guide)

## How does it work?

- 1st, SETUP the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/overview.html) .
- Write the Dockerfile.

For Examples...

```dockerfile
FROM docker.io/nvidia/cuda:12.0.1-devel-rockylinux8

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

- Make the Container Image.

```bash
# docker image build --compress -t mypg14-rocky8:latest -f Dockerfile .
```

- Boot the Container

Use the `--shm-size` option to set the appropriate shared memory to the container.

```bash
# docker container run --gpus all --shm-size=8gb --memory=8gb -p 5432:5432 -itd --name=cont1 mypg14-rocky8:latest
# docker container exec -it cont1 /bin/bash
```

- Run initdb command in a container

```bash
# su - postgres
$ /usr/pgsql-14/bin/initdb -D /var/lib/pgsql/14/data
```

- Change the Params

For Examples...

```bash
$ vi /var/lib/pgsql/14/data/postgresql.conf
...
shared_preload_libraries = '$libdir/pg_strom'
max_worker_processes = 100
shared_buffers = 4GB
work_mem = 1GB
```

- Boot the PostgreSQL Server.

```bash
$ /usr/pgsql-14/bin/pg_ctl -D /var/lib/pgsql/14/data -l logfile start
$ cat /var/lib/pgsql/logfile 
2022-12-22 05:12:27.351 UTC [135] LOG:  NVRTC 11.8 is successfully loaded, but CUDA driver expects 12.0. Check /etc/ld.so.conf or LD_LIBRARY_PATH configuration.
2022-12-22 05:12:27.352 UTC [135] LOG:  HeteroDB Extra module is not available
2022-12-22 05:12:27.352 UTC [135] LOG:  PG-Strom version 3.4 built for PostgreSQL 14 (git: HEAD)
2022-12-22 05:12:27.684 UTC [135] LOG:  PG-Strom: GPU0 NVIDIA GeForce GTX 1050 Ti (6 SMs; 1417MHz, L2 1024kB), RAM 4038MB (128bits, 3.34GHz), PCI-E Bar1 0MB, CC 6.1
2022-12-22 05:12:27.817 UTC [135] LOG:  redirecting log output to logging collector process
2022-12-22 05:12:27.817 UTC [135] HINT:  Future log output will appear in directory "log".
```

- Let's Try One.

```bash
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
-------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=389641.98..389692.65 rows=200 width=12) (actual time=2075.182..2081.184 rows=10 loops=1)
   Group Key: a.ten
   ->  Gather Merge  (cost=389641.98..389688.65 rows=400 width=12) (actual time=2075.178..2081.177 rows=30 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Sort  (cost=388641.96..388642.46 rows=200 width=12) (actual time=2073.324..2073.326 rows=10 loops=3)
               Sort Key: a.ten
               Sort Method: quicksort  Memory: 25kB
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=388632.32..388634.32 rows=200 width=12) (actual time=2073.304..2073.308 rows=10 loops=3)
                     Group Key: a.ten
                     Batches: 1  Memory Usage: 40kB
                     Worker 0:  Batches: 1  Memory Usage: 40kB
                     Worker 1:  Batches: 1  Memory Usage: 40kB
                     ->  Parallel Hash Join  (cost=14781.00..336548.98 rows=10416667 width=4) (actual time=71.710..2038.765 rows=333333 loops=3)
                           Hash Cond: (a.id = b.id)
                           ->  Parallel Seq Scan on t_test a  (cost=0.00..239302.67 rows=10416667 width=8) (actual time=0.037..402.205 rows=8333333 loops=3)
                           ->  Parallel Hash  (cost=9572.67..9572.67 rows=416667 width=4) (actual time=70.618..70.619 rows=333333 loops=3)
                                 Buckets: 1048576  Batches: 1  Memory Usage: 47360kB
                                 ->  Parallel Seq Scan on t_join b  (cost=0.00..9572.67 rows=416667 width=4) (actual time=0.014..21.611 rows=333333 loops=3)
 Planning Time: 0.101 ms
 Execution Time: 2081.212 ms
(23 rows)

testdb2=# SET pg_strom.enabled=on;
testdb2=# explain analyze SELECT count(*) FROM t_test AS a, t_join AS b WHERE a.id = b.id GROUP BY a.ten;
                                                                      QUERY PLAN                                                                       
-------------------------------------------------------------------------------------------------------------------------------------------------------
 GroupAggregate  (cost=108350.02..108350.27 rows=10 width=12) (actual time=694.828..698.133 rows=10 loops=1)
   Group Key: a.ten
   ->  Sort  (cost=108350.02..108350.07 rows=20 width=12) (actual time=694.820..698.120 rows=30 loops=1)
         Sort Key: a.ten
         Sort Method: quicksort  Memory: 26kB
         ->  Gather  (cost=108347.49..108349.59 rows=20 width=12) (actual time=640.027..698.104 rows=30 loops=1)
               Workers Planned: 2
               Workers Launched: 2
               ->  Parallel Custom Scan (GpuPreAgg)  (cost=107347.49..107347.59 rows=10 width=12) (actual time=626.576..626.581 rows=10 loops=3)
                     Reduction: GroupBy (Global+Local [nrooms: 1974])
                     Group keys: ten
                     Combined GpuJoin: enabled
                     ->  Parallel Custom Scan (GpuJoin) on t_test a  (cost=33466.89..107217.28 rows=416667 width=4) (never executed)
                           Outer Scan: t_test a  (cost=0.00..239300.33 rows=10416433 width=8) (actual time=32.295..704.148 rows=25000000 loops=1)
                           Depth 1: GpuHashJoin(plan nrows: 10416433...1000000, actual nrows: 25000000...1000000)
                                    HashSize: 54.36MB (estimated: 29.01MB)
                                    HashKeys: a.id
                                    JoinQuals: (a.id = b.id)
                           ->  Parallel Seq Scan on t_join b  (cost=0.00..9572.67 rows=416667 width=4) (actual time=0.012..21.482 rows=333333 loops=3)
 Planning Time: 0.157 ms
 Execution Time: 736.040 ms
(21 rows)
```
