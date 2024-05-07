# PG-Strom Trunk Containers

Building Images

```shell
docker image build --shm-size=8gb --compress -t mypg16-rocky8:test1 -f Dockerfile .
```

Bootstrapping...

```shell
docker container run --gpus all --shm-size=8gb --memory=8gb -p 5432:5432 -itd --name=test1 mypg16-rocky8:test1
```

Configure...

```shell
$ docker container exec -it test1 bash
# su - postgres

$ /usr/pgsql-16/bin/initdb -D /var/lib/pgsql/16/data
$ vi /var/lib/pgsql/16/data/postgresql.conf
...
shared_preload_libraries = '$libdir/pg_strom'
max_worker_processes = 100
shared_buffers = 4GB
work_mem = 1GB

$ /usr/pgsql-16/bin/pg_ctl -D /var/lib/pgsql/16/data -l logfile start
waiting for server to start.... done
server started

$ /usr/pgsql-16/bin/pg_ctl -D /var/lib/pgsql/16/data -l logfile status
pg_ctl: server is running (PID: 172)
/usr/pgsql-16/bin/postgres "-D" "/var/lib/pgsql/16/data"

$ cat /var/lib/pgsql/logfile
2024-05-07 09:27:35.210 UTC [172] LOG:  HeteroDB Extra module is not available
2024-05-07 09:27:35.210 UTC [172] LOG:  PG-Strom version 5.1.2 built for PostgreSQL 16 (githash: dee74cd260583b013851e568a41be2f7572adc60)
2024-05-07 09:27:36.854 UTC [172] LOG:  PG-Strom binary built for CUDA 12.3 (CUDA runtime 12.4)
...
```
