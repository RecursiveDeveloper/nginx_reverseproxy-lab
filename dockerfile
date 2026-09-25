FROM nginx:1.30.0-alpine3.23

COPY nginx.conf /etc/nginx/nginx.conf

ARG DOMAIN_NAME

RUN apk add --no-cache openssl && \
    mkdir -p /etc/ssl/localcerts && \
    openssl req -new -x509 \
        -days 365 \
        -noenc \
        -out /etc/ssl/localcerts/nginx-selfsigned.crt \
        -keyout /etc/ssl/localcerts/nginx-selfsigned.key \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=${DOMAIN_NAME}" && \
    chmod 600 /etc/ssl/localcerts/nginx* && \
    sed -i "s|local_domain|${DOMAIN_NAME}|" /etc/nginx/nginx.conf

HEALTHCHECK --interval=30s \
    --timeout=5s \
    CMD curl -k -I https://localhost || exit 1

EXPOSE 80 443