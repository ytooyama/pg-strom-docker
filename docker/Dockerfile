FROM docker.io/nvidia/cuda:12.0.1-devel-rockylinux8

RUN curl -LO https://heterodb.github.io/swdc/yum/rhel8-noarch/heterodb-swdc-1.2-1.el8.noarch.rpm && \
    curl -LO https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    curl -LO https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    rpm -i heterodb-swdc-1.2-1.el8.noarch.rpm && \
    rpm -i epel-release-latest-8.noarch.rpm && \
    rpm -i pgdg-redhat-repo-latest.noarch.rpm && \
    rm -rf heterodb-swdc-1.2-1.el8.noarch.rpm epel-release-latest-8.noarch.rpm pgdg-redhat-repo-latest.noarch.rpm

#If you want to use the full version of PG-Strom, Please Remove the Comments.
# COPY heterodb.license /etc/heterodb.license

RUN dnf -y module disable postgresql && \
    dnf install --enablerepo=powertools -y postgresql15-devel postgresql15-server postgresql-alternatives pg_strom-PG15 postgis32_15 && \
    dnf clean all && dnf clean metadata

ENV PATH /usr/pgsql-15/bin:$PATH
ENV PGDATA /var/lib/pgsql/15/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/pgsql/15/data

EXPOSE 5432
