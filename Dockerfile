FROM alpine:latest

RUN apk add --no-cache \
    bash \
    cuetools \
    flac \
    && apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing shntool

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME /watch

ENTRYPOINT ["/entrypoint.sh"]
