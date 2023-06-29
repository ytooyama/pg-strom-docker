# Make the  PG-Strom environment with Docker Compose V2

- Create the Project Directory and `docker-compose.yml`.

```shell
$ mkdir ~/pgstrom-compose
$ cd ~/pgstrom-compose
$ vi docker-compose.yml
```

- And `docker compose up -d`.

```shell
$ sudo docker compose up -d
[+] Building 0.0s (0/0)                                                                                        
[+] Running 2/2
 ✔ Volume "pgstrom-compose_db-data"  Created                                                              0.0s 
 ✔ Container pgstrom-compose-db-1    Started                                                              0.3s 
$ sudo docker compose ps 
NAME                   IMAGE                  COMMAND                  SERVICE             CREATED             STATUS              PORTS
pgstrom-compose-db-1   mypg14-rocky8:latest   "/opt/nvidia/nvidia_…"   db                  11 seconds ago      Up 10 seconds       0.0.0.0:5432->5432/tcp, :::5432->5432/tcp
```

- Once PostgreSQL & PG-Strom is configured in the same way as Docker, it can be used in containers.
