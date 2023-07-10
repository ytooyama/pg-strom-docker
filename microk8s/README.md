# Using PG-Strom with MicroK8s

## Setup the Host Environments

- Install the Ubuntu Server 22.04.2 or later.
- [Install CUDA Driver](https://developer.nvidia.com/cuda-12-0-1-download-archive) on the Host Machine.
- [Create a container image for PG-Storm](https://github.com/ytooyama/pg-strom-docker) .

Create Dockerfile:

```Dockerfile
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

Build the image:

```shell
sudo docker image build --compress -t mypg14-rocky8:test1 -f Dockerfile .
```

- [Deploy Docker](https://docs.docker.com/engine/install/ubuntu/) and [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on Host Machine.
- [Check the GPU Operator Component Matrix](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#supported-operating-systems-and-kubernetes-platforms) to deploy supported MicroK8s versions.
- Install the confirmed version of [Microk8s](https://microk8s.io/#install-microk8s) .

```shell
sudo snap install microk8s --classic --channel=1.26/stable
sudo microk8s.start
```

- Add [gpu](https://microk8s.io/docs/addon-gpu) and [registry](https://microk8s.io/docs/registry-built-in) and [hostpath-storage](https://microk8s.io/docs/addon-hostpath-storage) add-ons.

```shell
sudo microk8s enable gpu registry hostpath-storage
```

## Setup the Container Environments

- Register the created PG-Storm container image in the Local registry.

```shell
docker tag mypg14-rocky8:test1 localhost:32000/mypg14-rocky8:test1 
docker push localhost:32000/mypg14-rocky8:test1 
```

- Create the Pod.

```shell
$ kubectl apply -f pgstrom-pod-manifest.yaml
persistentvolumeclaim/test-pvc created
pod/pgstrom-test created

$ kubectl get -f pgstrom-pod-manifest.yaml
NAME                             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/test-pvc   Bound    pvc-e614a758-5766-4a00-b0b4-524e18f0e463   3Gi        RWO            microk8s-hostpath   28s

NAME               READY   STATUS    RESTARTS   AGE
pod/pgstrom-test   1/1     Running   0          28s
```

## Setup the PG-Strom

- Configure the PostgreSQL, and Start the PostgreSQL!

```shell
$ kubectl exec -it pgstrom-test -- bash

//fix the permittion
# chown postgres.postgres /var/lib/pgsql/14/data

//change user
$ su - postgres

//initdb
$ /usr/pgsql-14/bin/initdb -D /var/lib/pgsql/14/data
...

//Postgres confings
$ vi /var/lib/pgsql/14/data/postgresql.conf
...
$ Add settings for extensions here
shared_preload_libraries = '$libdir/pg_strom'
max_worker_processes = 100
shared_buffers = 4GB
work_mem = 1GB

//start the postgres
$ /usr/pgsql-14/bin/pg_ctl -D /var/lib/pgsql/14/data -l logfile start
...
waiting for server to start..... done
server started

$ /usr/pgsql-14/bin/pg_ctl -D /var/lib/pgsql/14/data -l logfile status
pg_ctl: server is running (PID: 149)
/usr/pgsql-14/bin/postgres "-D" "/var/lib/pgsql/14/data"
```

## Check the PG-Strom

```shell
$ psql -U postgres
psql (14.8)
Type "help" for help.

postgres=# CREATE EXTENSION pg_strom;
CREATE EXTENSION
```

## QA

### Why is Rocky Linux used in the container, but the host OS is Ubuntu?

- I remember that Ubuntu was required to use microk8s GPU add-on.
