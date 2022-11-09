FROM docker.io/nvidia/cuda:11.8.0-devel-ubi8

RUN curl -LO https://heterodb.github.io/swdc/yum/rhel8-noarch/heterodb-swdc-1.2-1.el8.noarch.rpm && \ 
    curl -LO https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \ 
    curl -LO https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

RUN rpm -i heterodb-swdc-1.2-1.el8.noarch.rpm && \ 
    rpm -i epel-release-latest-8.noarch.rpm && \ 
    rpm -i pgdg-redhat-repo-latest.noarch.rpm

RUN dnf install -y postgresql13-devel postgresql13-server postgresql-alternatives pg_strom-PG13

EXPOSE 5432
