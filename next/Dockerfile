FROM docker.io/nvidia/cuda:11.8.0-devel-rockylinux8 as base
WORKDIR /root

RUN dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

RUN dnf -y module disable postgresql
RUN dnf install -y postgresql15-devel postgresql15-server && \
    dnf install -y redhat-rpm-config rpm-build git

RUN git clone https://github.com/heterodb/pg-strom && cd /root/pg-strom/src && \
    export PATH=/usr/pgsql-15/bin:$PATH && \
    mkdir -p /root/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} && make rpm


FROM docker.io/nvidia/cuda:11.8.0-devel-rockylinux8
WORKDIR /root
COPY --from=base /root/rpmbuild/RPMS/x86_64/pg_strom-PG15-3.4-devel*.rpm .

RUN curl -LO https://heterodb.github.io/swdc/yum/rhel8-noarch/heterodb-swdc-1.2-1.el8.noarch.rpm && \
    curl -LO https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    curl -LO https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

RUN rpm -i heterodb-swdc-1.2-1.el8.noarch.rpm && \
    rpm -i epel-release-latest-8.noarch.rpm && \
    rpm -i pgdg-redhat-repo-latest.noarch.rpm

#If you want to use the full version of PG-Strom, Please Remove the Comments.
#COPY heterodb.license /etc/heterodb.license
#RUN dnf install -y heterodb-extra

RUN dnf -y module disable postgresql
RUN dnf install -y postgresql15-devel postgresql15-server postgresql-alternatives && \
    dnf install -y ./pg_strom-PG15-3.4-devel.el8.x86_64.rpm

ENV PATH /usr/pgsql-15/bin:$PATH
ENV PGDATA /var/lib/pgsql/15/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/pgsql/15/data

EXPOSE 5432
