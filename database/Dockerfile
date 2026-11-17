FROM postgres:16.16-alpine

# Keep the official entrypoint's privilege drop using Alpine's su-exec.
RUN rm /usr/local/bin/gosu /usr/local/bin/su-exec
RUN apk add --no-cache su-exec \
    && ln -s /sbin/su-exec /usr/local/bin/gosu

COPY init.sql /docker-entrypoint-initdb.d/01-init.sql
