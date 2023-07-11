# PG-Strom 5.x Containers

Building Images

```shell
docker image build --shm-size=8gb --compress -t mypg15-rocky8:test1 -f Dockerfile .
```

Bootstrapping...

```shell
docker container run --gpus all --shm-size=8gb --memory=8gb -p 5432:5432 -itd --name=cont1 mypg15-rocky8:test1
```

Configure...

```shell
$ docker container exec -it cont1 bash
# su - postgres

$ /usr/pgsql-15/bin/initdb -D /var/lib/pgsql/15/data
$ vi /var/lib/pgsql/15/data/postgresql.conf
...
shared_preload_libraries = '$libdir/pg_strom'
max_worker_processes = 100
shared_buffers = 4GB
work_mem = 1GB

$ /usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l logfile start
waiting for server to start.... done
server started

$ /usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l logfile status
pg_ctl: server is running (PID: 172)
/usr/pgsql-15/bin/postgres "-D" "/var/lib/pgsql/15/data"
```
