## 🚀 About Me

I'm a junior DevOps engineer with some expertise in BackEnd development using Java and Node.js; scripting skills with Python, Bash and JavaScript; besides CI/CD and cloud knowledge of AWS and Azure DevOps.

<p align="center">
<img src="https://c4.wallpaperflare.com/wallpaper/694/164/1000/digital-art-animals-eagle-bird-of-prey-birds-hd-wallpaper-preview.jpg" alt="Logo" width="400" height="230">
</p>

![linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![python](https://img.shields.io/badge/Python-3774AB?style=for-the-badge&logo=python&logoColor=white)
![javascript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![nodejs](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)
![mysql](https://img.shields.io/badge/MySQL-005C84?style=for-the-badge&logo=mysql&logoColor=white)
![jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=Jenkins&logoColor=white)
![aws](https://img.shields.io/badge/Amazon_AWS-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![azuredevops](https://img.shields.io/badge/Azure_DevOps-0078D7?style=for-the-badge&logo=azure-devops&logoColor=white)

## 🔗 Portfolio

[![portfolio](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/RecursiveDeveloper)
[![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/jhoan-jesus-ortiz-sandoval-a66152198/)

# Nginx Reverse Proxy Lab

Lab environment for experimenting with **Nginx as a TLS-terminating reverse proxy**: a hardened `nginx.conf`, a self-signed certificate generated at build time, and a single container started with one script.

## Folder Structure

```
nginx_reverseproxy-lab/
├── dockerfile               # Builds nginx:1.30.0-alpine3.23 + self-signed cert
├── nginx.conf               # Custom config: TLS server block, static file root
├── start.sh                 # Build the image, run the container, verify TLS
└── destroy.sh               # Remove ALL containers and images on the host
```

There is no application code yet — the reverse proxy is the subject of the lab, not a consumer of it. Static content from `/usr/share/nginx/html` (the stock Nginx welcome page) is what gets served.

## Architecture

A single container, one image, two server blocks:

- **Build stage** — `nginx.conf` replaces the image's main config. `openssl` (installed via `apk`, it is not in the base image) generates a self-signed key pair for the domain passed in `DOMAIN_NAME`, and a `sed` replaces the `local_domain` placeholder in the config with that domain.
- **Port 80** — served by the base image's own `conf.d/default.conf`, which survives because `nginx.conf` still does `include /etc/nginx/conf.d/*.conf`. Serves the stock welcome page.
- **Port 443** — served by the `server` block in `nginx.conf`. TLS-only, static files from `/usr/share/nginx/html`, no HTTP redirect and no `proxy_pass` (that is the next step of the lab).
- **Healthcheck** — `curl -k -I https://localhost` every 30s. `curl` is already present in the base image, so no extra package is needed.

## Configuration

Everything is driven by three values at the top of `start.sh`:

| Variable         | Default                  | Description                                              |
|------------------|--------------------------|----------------------------------------------------------|
| `DOMAIN_NAME`    | `www.devopslab.com`      | Server name, cert CN, and the name resolved in-container |
| `IMAGE_NAME`     | `nginx:test`             | Tag for the locally built image                          |
| `CONTAINER_NAME` | `nginx_reverse_proxy`    | Name of the running container                            |

`DOMAIN_NAME` is passed to the build as an `ARG`, so it is baked into the image: the certificate's subject CN and the `server_name` directive both end up matching it. Changing it requires a rebuild — `start.sh` already uses `--no-cache` to guarantee that.

Port publishing is also set in `start.sh`:

| Container port | Host port | Reached by                              | Serves                                    |
|----------------|-----------|-----------------------------------------|-------------------------------------------|
| 80             | 8080      | `http://localhost:8080`                 | Stock welcome page (`conf.d/default.conf`) |
| 443            | *none*    | `docker exec` only (see below)          | Custom TLS server block (`nginx.conf`)     |

> **Port 443 is not published to the host.** The run command only maps `8080:80`, so HTTPS is reachable from inside the container network, not from your machine. This is deliberate in the current setup: `start.sh` verifies TLS with `docker exec ... curl -kI https://${DOMAIN_NAME}` instead. To hit it from the host, change the mapping to `-p 8080:80 -p 8443:443` and use `https://localhost:8443` (or map `443:443` if nothing else owns that port).

## Prerequisites

- Docker
- `bash` (both scripts are Bash and use `echo -e`)

No Node.js, no package install, no `.env` — the only input is the build argument.

## Environment Setup

Nothing to create. Clone the repository and make sure the scripts are executable:

```bash
chmod +x start.sh destroy.sh
```

To use a different domain, edit `DOMAIN_NAME` in `start.sh`. The certificate is generated for that name, so the name must also resolve to the container — `start.sh` handles it with:

```bash
--add-host="${DOMAIN_NAME}:127.0.0.1"
```

This writes the entry into the **container's** `/etc/hosts`, which is enough for the in-container `curl` check. Your host machine does not learn the mapping; add a real DNS or hosts entry there if you later publish 443 and browse to the domain directly.

## Running the Application

```bash
./start.sh
```

The script builds the image, starts the container detached, and then runs the TLS check from inside the container. Expected output ends with a `200 OK` response from `https://www.devopslab.com`.

| Step             | What it does                                                            |
|------------------|-------------------------------------------------------------------------|
| `docker build`   | Installs `openssl`, generates the self-signed cert, patches `server_name` |
| `docker run -d`  | Starts `nginx_reverse_proxy` with `-p 8080:80` and the `--add-host` entry |
| `docker exec`    | `curl -kI https://${DOMAIN_NAME}` to confirm TLS answers                 |

Check the container and its health status:

```bash
docker ps                       # STATUS shows (health: starting), then (healthy)
docker inspect --format '{{.State.Health.Status}}' nginx_reverse_proxy
```

The healthcheck has no `--start-period`, so the first probe runs 30 seconds after the container starts — expect `health: starting` for the first half minute.

## Verification

Since the interesting server block is on 443, the checks below are run from inside the container unless noted:

```bash
# TLS server block (in-container)
docker exec -it nginx_reverse_proxy curl -kI https://www.devopslab.com

# Port 80, from the host — stock welcome page
curl -I http://localhost:8080

# Certificate details: subject CN and validity
docker exec -it nginx_reverse_proxy openssl x509 \
  -in /etc/ssl/localcerts/nginx-selfsigned.crt -noout -subject -dates

# Effective config after the build-time sed
docker exec -it nginx_reverse_proxy nginx -T | grep -n server_name
```

`curl -k` is required everywhere: the certificate is self-signed, so verification fails by design.

## TLS Details

| Setting            | Value                                                          |
|--------------------|----------------------------------------------------------------|
| Certificate        | Self-signed, 365 days, generated during `docker build`          |
| Key permissions    | `chmod 600` on `/etc/ssl/localcerts/nginx*`                    |
| Protocols          | `TLSv1.2 TLSv1.3` (TLS 1.0/1.1 disabled)                       |
| Ciphers            | `HIGH:!aNULL:!MD5`                                             |
| Certificate paths  | `/etc/ssl/localcerts/nginx-selfsigned.crt` / `.key`            |

> Self-signed certificates and `HIGH:!aNULL:!MD5` are fine for a lab and are **not** a production configuration. Real deployments should use a certificate from a CA (or Let's Encrypt), add OCSP stapling, and keep the key material out of the image.

## Cleanup

```bash
./destroy.sh
```

> **Read before running.** `destroy.sh` executes `docker rm -f $(docker ps -aq)` and `docker rmi -f $(docker images -q)`. It is not scoped to this lab — it deletes **every container and every image on the host**, including anything unrelated to this project. If you only want to tear down the lab:

```bash
docker rm -f nginx_reverse_proxy
docker rmi -f nginx:test
```

## Next Steps

- Add an upstream application and a `proxy_pass` location block to make this an actual reverse proxy.
- Redirect port 80 to 443 instead of serving the stock welcome page.
- Publish 443 so the domain can be tested from a browser.
