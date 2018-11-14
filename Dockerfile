FROM alpine

RUN apk add --no-cache \
        bash \
        curl \
        jq \
    && rm -rf /var/cache/apk/*

WORKDIR /app
COPY hoster.sh /app/

CMD ["bash", "/app/hoster.sh"]
