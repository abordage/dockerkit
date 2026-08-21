# syntax=docker/dockerfile:1.4
# check=error=true

ARG POSTGRES_VERSION=17

FROM postgres:${POSTGRES_VERSION}

# Official 18+ images store data at /var/lib/postgresql/MAJOR/docker and declare
# VOLUME /var/lib/postgresql. 13-17 still use /var/lib/postgresql/data as VOLUME,
# so a parent-directory mount does not persist. Pin the 18+ layout for every major
# so compose can always mount postgres_data at /var/lib/postgresql.
ENV PGDATA=/var/lib/postgresql/${PG_MAJOR}/docker
