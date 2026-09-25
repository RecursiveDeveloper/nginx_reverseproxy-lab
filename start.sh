#!/bin/bash

IMAGE_NAME="nginx:test"
CONTAINER_NAME="nginx_reverse_proxy"
DOMAIN_NAME="www.devopslab.com"

docker build --build-arg DOMAIN_NAME="${DOMAIN_NAME}" \
    --no-cache \
    -t ${IMAGE_NAME} .

docker run -d \
    -p 8080:80 \
    --add-host="${DOMAIN_NAME}:127.0.0.1"\
    --name ${CONTAINER_NAME} ${IMAGE_NAME}

echo -e "\nTesting ${DOMAIN_NAME} website inside ${CONTAINER_NAME} container\n"
docker exec -it ${CONTAINER_NAME} curl -kI "https://${DOMAIN_NAME}"