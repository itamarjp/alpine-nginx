# alpine-nginx

[English](#english) · [Português](#português)

```text
ghcr.io/itamarjp/alpine-nginx:latest
```

---

## English

A small, non-root Nginx image (Alpine edge), ready for Kubernetes, to serve static sites,
file folders with directory listing, or redirects. Content and, when needed, a custom
`default.conf` come from outside the image.

### What the image does

- Runs as the Alpine package's `nginx` user (**UID 101**) and listens on port **8080**.
- Works with `readOnlyRootFilesystem: true` as long as `/tmp` is writable (an `emptyDir`).
- Never serves hidden files or folders (`.git`, `.env`, `.htpasswd`...): they return 404.
- Does not expose the Nginx version (`server_tokens off`).
- `sendfile`, `gzip`, and `nosniff`, `X-Frame-Options` and `Referrer-Policy` headers.

### Modes

| Mode | How |
|---|---|
| Static site | image default: serves `/var/www/html`, no listing |
| Directory listing | mount [`examples/autoindex.conf`](examples/autoindex.conf) |
| 301 redirect | mount [`examples/redirect.conf`](examples/redirect.conf) with your target |

To change the mode, mount another file at `/etc/nginx/http.d/default.conf`
(in Kubernetes, a ConfigMap with `subPath`). Every `server` block must have
`include /etc/nginx/snippets/common.conf;`, which brings the headers and the hidden-file block.

Content goes in `/var/www/html`, mounted read-only, and must be readable by UID 101
(for example, files `644` and folders `755`).

### Quick start

```sh
docker run --rm -p 8080:8080 --read-only --tmpfs /tmp \
  -v "$PWD/site:/var/www/html:ro" ghcr.io/itamarjp/alpine-nginx:latest
```

### Kubernetes example

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
  containers:
    - name: site
      image: ghcr.io/itamarjp/alpine-nginx:latest
      ports:
        - name: http
          containerPort: 8080
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      volumeMounts:
        - name: content
          mountPath: /var/www/html
          readOnly: true
        - name: nginx-conf          # only for non-default modes
          mountPath: /etc/nginx/http.d/default.conf
          subPath: default.conf
          readOnly: true
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir:
        medium: Memory
        sizeLimit: 4Mi
```

A ConfigMap mounted with `subPath` is not refreshed in a running pod: restart the pod after changing it.

### CI and tests

CI builds the image, runs `tests/smoke.sh`, and only then publishes it. The test starts the image in
all three modes, with a read-only filesystem and a sample site that contains `.git` and `.env`.
Every Friday the image is rebuilt without cache to pick up Alpine updates.

```sh
docker build -t alpine-nginx:test . && tests/smoke.sh alpine-nginx:test
```

---

## Português

Imagem Nginx enxuta (Alpine edge), sem root e pronta para Kubernetes, para servir sites
estáticos, pastas de arquivos com listagem ou redirects. O conteúdo e, quando preciso,
um `default.conf` próprio vêm de fora da imagem.

### O que a imagem faz

- Roda como o usuário `nginx` do pacote do Alpine (**UID 101**) e escuta na porta **8080**.
- Funciona com `readOnlyRootFilesystem: true` desde que `/tmp` seja gravável (um `emptyDir`).
- Nunca serve arquivos ou pastas ocultos (`.git`, `.env`, `.htpasswd`...): devolvem 404.
- Não expõe a versão do Nginx (`server_tokens off`).
- `sendfile`, `gzip` e cabeçalhos `nosniff`, `X-Frame-Options` e `Referrer-Policy`.

### Modos

| Modo | Como |
|---|---|
| Site estático | padrão da imagem: serve `/var/www/html`, sem listagem |
| Listagem de diretório | monte [`examples/autoindex.conf`](examples/autoindex.conf) |
| Redirect 301 | monte [`examples/redirect.conf`](examples/redirect.conf) com o destino |

Para mudar o modo, monte outro arquivo em `/etc/nginx/http.d/default.conf`
(no Kubernetes, um ConfigMap com `subPath`). Todo bloco `server` deve ter
`include /etc/nginx/snippets/common.conf;`, que traz os cabeçalhos e o bloqueio de ocultos.

O conteúdo vai em `/var/www/html`, montado somente leitura, e precisa ser legível pelo
UID 101 (por exemplo, arquivos `644` e pastas `755`).

### Início rápido

```sh
docker run --rm -p 8080:8080 --read-only --tmpfs /tmp \
  -v "$PWD/site:/var/www/html:ro" ghcr.io/itamarjp/alpine-nginx:latest
```

No Kubernetes, use o exemplo da seção em inglês acima: o YAML é o mesmo.
Um ConfigMap montado com `subPath` não é atualizado num pod em execução: reinicie o pod depois de mudá-lo.

### CI e testes

O CI constrói a imagem, roda `tests/smoke.sh` e só então publica. O teste sobe a imagem nos
três modos, com o sistema de arquivos somente leitura e um site de exemplo com `.git` e `.env`.
Toda sexta-feira a imagem é reconstruída sem cache, para pegar as atualizações do Alpine.

```sh
docker build -t alpine-nginx:test . && tests/smoke.sh alpine-nginx:test
```

---

AI agents: see [`AGENTS.md`](AGENTS.md). · Agentes de IA: veja o [`AGENTS.md`](AGENTS.md).
