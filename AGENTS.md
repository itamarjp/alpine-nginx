# Instructions for AI agents

Generic, non-root Nginx container image on Alpine edge, published as
`ghcr.io/itamarjp/alpine-nginx`. This is a **public, general-purpose** repository:
keep it free of any specific site, domain, company or deployment.
Examples use `example.com`.

## How the repository works

```text
Dockerfile                    alpine:edge + nginx, USER nginx, port 8080
conf/nginx.conf               -> /etc/nginx/nginx.conf      (global settings)
conf/snippets/common.conf     -> /etc/nginx/snippets/       (security headers + hidden-file block)
conf/http.d/default.conf      -> /etc/nginx/http.d/         (default mode: static site)
examples/autoindex.conf       alternative default.conf: directory listing
examples/redirect.conf        alternative default.conf: 301 redirect
tests/smoke.sh                smoke test of the image in the three modes
.github/workflows/build.yml   build -> test -> publish
.github/dependabot.yml        weekly updates of the base image and actions
```

- Users change behavior **only** by mounting their own file over
  `/etc/nginx/http.d/default.conf` and their content at `/var/www/html` (read-only).
  Anything a user must not lose belongs in `nginx.conf` or `snippets/common.conf`, not in
  `default.conf`, because `default.conf` is meant to be replaced.
- Every `server` block (the default and both examples) must
  `include /etc/nginx/snippets/common.conf;`. It holds the security headers and the
  `location ~ /\. { return 404; }` block. An `add_header` inside a `location` cancels the
  inherited headers; if one is needed, repeat the include inside that location.

## Invariants (do not break)

- **Non-root.** The process runs as the `nginx` user created by the Alpine package,
  **UID 101** (UID 100 is taken by `klogd` in this base). Do not create another user and do
  not hardcode a different UID. If the package ever changes the UID, `tests/smoke.sh`
  fails (`EXPECTED_UID`) and the image is not published; update README and the test together.
- **Port 8080**, never a port below 1024.
- **Read-only root filesystem.** Everything written at runtime goes to `/tmp`:
  `pid /tmp/nginx.pid`, the `*_temp_path` directives, and `nginx -e /dev/stderr`, which
  avoids the compiled-in error log path at startup. Do not add paths outside `/tmp`.
- **Hidden files return 404** in every mode, including inside subfolders and in redirect mode.
- **`server_tokens off`.** No Nginx version in the `Server` header.
- Base image stays `alpine:edge`. CI rebuilds without cache weekly to pick up security fixes.

## CI and tests

- `build.yml` builds with `load: true` as `alpine-nginx:test`, runs `tests/smoke.sh`, and only
  then builds again with `push: true`, reusing the cache of the tested build (no `pull`, no
  `no-cache`) so that the published layers are the ones that passed. Pull requests are only
  tested, never published.
- `tests/smoke.sh` checks: user/UID, `nginx -t` in the three modes, and, with `--read-only
  --tmpfs /tmp` plus a sample site containing `.git` and `.env`: default mode (index, download,
  no listing, hidden 404, headers, no version), autoindex mode (listing without hidden files,
  download, hidden 404) and redirect mode (301 keeping path and query).
- Requests are made by a helper `curlimages/curl` container sharing the network of the tested
  container (BusyBox `wget` lacks options the test needs).
- Results are printed as GitHub annotations (`::notice::` / `::error::`), so a failure reason
  is visible on the PR without opening the job log.
- When you change `nginx.conf`, a snippet, the `Dockerfile` or an example, add a check to
  `tests/smoke.sh` for the new behavior. Run locally with
  `docker build -t alpine-nginx:test . && tests/smoke.sh alpine-nginx:test`.

## Documentation

- `README.md` is bilingual: English first, then Portuguese, with the same content.
  Update both when behavior changes.
- Commit messages and PR descriptions may be in Portuguese.

---

# Instruções para agentes de IA (resumo em português)

Imagem Nginx genérica, sem root, em Alpine edge, publicada como `ghcr.io/itamarjp/alpine-nginx`.
O repositório é **público e de uso geral**: não coloque nele nenhum site, domínio, empresa ou
deploy específico. Os exemplos usam `example.com`.

- O usuário muda o comportamento **só** montando o próprio `default.conf` em
  `/etc/nginx/http.d/default.conf` e o conteúdo em `/var/www/html`, somente leitura.
  O que não pode se perder vai no `nginx.conf` ou em `snippets/common.conf`.
- Todo `server` inclui `snippets/common.conf`, com os cabeçalhos e o 404 para ocultos.
- Invariantes: usuário `nginx` com **UID 101**, porta **8080**, tudo que é gravado em
  runtime vai para `/tmp`, ocultos com 404 em todos os modos, `server_tokens off` e base
  `alpine:edge`.
- O CI constrói, roda `tests/smoke.sh` nos três modos e só então publica, reaproveitando o
  cache do build testado. Ao mudar comportamento, acrescente uma verificação ao teste.
- O `README.md` é bilíngue (inglês e português). Atualize os dois.
