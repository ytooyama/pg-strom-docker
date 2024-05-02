FROM docker.io/nvidia/cuda:12.3.2-devel-rockylinux8
WORKDIR /root

RUN curl -LO https://heterodb.github.io/swdc/yum/rhel8-noarch/heterodb-swdc-1.3-1.el8.noarch.rpm && \
    curl -LO https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    curl -LO https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    rpm -i heterodb-swdc-1.2-1.el8.noarch.rpm && \
    rpm -i epel-release-latest-8.noarch.rpm && \
    rpm -i pgdg-redhat-repo-latest.noarch.rpm && \
    rm -rf heterodb-swdc-1.3-1.el8.noarch.rpm epel-release-latest-8.noarch.rpm pgdg-redhat-repo-latest.noarch.rpm

RUN dnf -y module disable postgresql && \
    dnf install --enablerepo=powertools -y postgresql15-devel postgresql15-server postgresql-alternatives postgis32_15
    
RUN dnf groupinstall -y 'Development Tools' && dnf clean all && dnf clean metadata

RUN git clone https://github.com/heterodb/pg-strom && cd /root/pg-strom/src && \
    make PG_CONFIG=/usr/pgsql-15/bin/pg_config && \
    make install PG_CONFIG=/usr/pgsql-15/bin/pg_config

ENV PATH /usr/pgsql-15/bin:$PATH
ENV PGDATA /var/lib/pgsql/15/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/pgsql/15/data

EXPOSE 5432
