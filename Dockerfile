FROM alpine
LABEL maintainer="Gabe Cook <gabe565@gmail.com>"

ARG DOCKER_VERSION=18.09.3

RUN set -x \
    && apk add \
        bash \
        jq \
    && apk add --virtual .build-deps \
        curl \
        tar \
    && curl -s -o docker.tgz -L "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
    && tar -xzf docker.tgz -C /usr/local/bin docker/docker --strip-components=1 \
    && rm docker.tgz \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

WORKDIR /app
COPY hoster.sh /app/

CMD ["bash", "/app/hoster.sh"]
