FROM docker.io/nvidia/cuda:12.3.2-devel-rockylinux8

RUN curl -LO https://heterodb.github.io/swdc/yum/rhel8-noarch/heterodb-swdc-1.3-1.el8.noarch.rpm && \
    curl -LO https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    curl -LO https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    rpm -i heterodb-swdc-1.3-1.el8.noarch.rpm && \
    rpm -i epel-release-latest-8.noarch.rpm && \
    rpm -i pgdg-redhat-repo-latest.noarch.rpm && \
    rm -rf heterodb-swdc-1.3-1.el8.noarch.rpm epel-release-latest-8.noarch.rpm pgdg-redhat-repo-latest.noarch.rpm

RUN dnf -y module disable postgresql && \
    dnf -y install --enablerepo=powertools postgresql16-devel postgresql16-server pg_strom-PG16 && \
    # If you want to use the full version of PG-Strom, Please Remove the Comments.
    # COPY heterodb.license /etc/heterodb.license && \
    # RUN dnf install -y heterodb-extra && \ 
    dnf clean all && dnf clean metadata

ENV PATH /usr/pgsql-16/bin:$PATH
ENV PGDATA /var/lib/pgsql/16/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/pgsql/16/data

EXPOSE 5432
