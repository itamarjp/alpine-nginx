#!/bin/sh
# Teste de fumaça da imagem nos três modos de uso: padrão (site estático),
# listagem de diretório (examples/autoindex.conf) e redirect (examples/redirect.conf).
# Cada modo sobe como no Kubernetes: somente leitura, /tmp gravável, site montado ro.
# Uso: tests/smoke.sh <imagem>
set -eu

IMAGE="${1:?uso: tests/smoke.sh <imagem>}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
NAME="alpine-nginx-smoke-$$"
DATA=$(mktemp -d)

cleanup() {
  docker logs "$NAME" 2>&1 | tail -20 || true
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  rm -rf "$DATA"
}
trap cleanup EXIT

# No GitHub Actions, os resultados viram anotações visíveis no PR.
fail() {
  echo "FALHOU: $*" >&2
  [ -n "${GITHUB_ACTIONS:-}" ] && echo "::error title=smoke::$(echo "$*" | tr '\n' ' ')"
  exit 1
}
ok() {
  echo "ok: $*"
  [ -n "${GITHUB_ACTIONS:-}" ] && echo "::notice title=smoke::$*" || true
}

# Sobe o container com o default.conf da imagem, ou com outro montado por cima.
start() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  if [ -n "${1:-}" ]; then
    set -- -v "$ROOT/$1:/etc/nginx/http.d/default.conf:ro"
  fi
  docker run -d --read-only --tmpfs /tmp -v "$DATA:/var/www/html:ro" "$@" --name "$NAME" "$IMAGE" >/dev/null
  sleep 2
  [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = "true" ] \
    || fail "o container não ficou de pé: $(docker logs "$NAME" 2>&1 | tail -5)"
}
# Um container auxiliar com curl compartilha a rede do container testado.
get() {
  docker run --rm --network "container:$NAME" curlimages/curl:latest \
    -sS --retry 10 --retry-connrefused --retry-delay 1 --max-time 30 "$@"
}
code() { get -o /dev/null -w '%{http_code}' "http://127.0.0.1:8080$1"; }
no_hidden() {
  for path in /.git/config /.git/ /.env /pub/.env; do
    c=$(code "$path")
    [ "$c" = "404" ] || fail "$1: $path devolveu $c, esperado 404"
  done
}

# --- imagem ---
EXPECTED_UID="${EXPECTED_UID:-101}"
uid=$(docker run --rm --entrypoint id "$IMAGE" -u)
user=$(docker run --rm --entrypoint id "$IMAGE" -un)
[ "$user" = "nginx" ] || fail "o container roda como '$user', esperado 'nginx'"
[ "$uid" = "$EXPECTED_UID" ] || fail "UID é $uid, esperado $EXPECTED_UID"
ok "roda como $user (UID $uid)"

for conf in "" examples/autoindex.conf examples/redirect.conf; do
  set --
  [ -n "$conf" ] && set -- -v "$ROOT/$conf:/etc/nginx/http.d/default.conf:ro"
  out=$(docker run --rm "$@" --entrypoint nginx "$IMAGE" -t -e /dev/stderr 2>&1) \
    || fail "configuração inválida (${conf:-padrão}): $out"
done
ok "configuração válida nos três modos"

# Site de exemplo com arquivos ocultos que nunca podem sair.
mkdir -p "$DATA/pub" "$DATA/.git"
echo "<h1>pagina-inicial</h1>" > "$DATA/index.html"
echo "conteudo-de-teste" > "$DATA/pub/arquivo.txt"
echo "[core]" > "$DATA/.git/config"
echo "segredo" > "$DATA/.env"
echo "segredo" > "$DATA/pub/.env"
chmod -R a+rX "$DATA"

# --- modo padrão: site estático ---
start
get "http://127.0.0.1:8080/" | grep -q "pagina-inicial" || fail "padrão: página inicial não veio"
[ "$(get http://127.0.0.1:8080/pub/arquivo.txt)" = "conteudo-de-teste" ] || fail "padrão: download falhou"
c=$(code /pub/); [ "$c" = "403" ] || [ "$c" = "404" ] || fail "padrão: /pub/ devolveu $c, esperado sem listagem"
no_hidden padrão
headers=$(get -o /dev/null -D - "http://127.0.0.1:8080/")
echo "$headers" | grep -qi "Server: nginx/" && fail "padrão: versão do nginx exposta no Server"
echo "$headers" | grep -qi "X-Content-Type-Options: nosniff" || fail "padrão: falta o cabeçalho nosniff"
ok "padrão: página, download, sem listagem, ocultos com 404, cabeçalhos ok"

# --- listagem de diretório ---
start examples/autoindex.conf
listing=$(get "http://127.0.0.1:8080/pub/")
echo "$listing" | grep -q "arquivo.txt" || fail "autoindex: listagem não mostra arquivo.txt"
echo "$listing" | grep -q "\.env" && fail "autoindex: listagem mostra o .env"
[ "$(get http://127.0.0.1:8080/pub/arquivo.txt)" = "conteudo-de-teste" ] || fail "autoindex: download falhou"
no_hidden autoindex
loc=$(get -o /dev/null -D - "http://127.0.0.1:8080/pub" | tr -d '\r' | sed -n 's/^[Ll]ocation: //p')
[ "$loc" = "/pub/" ] || fail "autoindex: /pub sem barra deveria redirecionar para '/pub/' (relativo), veio '$loc'"
ok "autoindex: listagem sem ocultos, download, ocultos com 404, redirect de pasta relativo"

# --- redirect ---
start examples/redirect.conf
headers=$(get -o /dev/null -D - "http://127.0.0.1:8080/teste?x=1")
echo "$headers" | grep -q " 301" || fail "redirect: esperado 301; resposta: $headers"
echo "$headers" | grep -qi "Location: https://example.com/teste?x=1" || fail "redirect: Location errado; $headers"
ok "redirect: 301 mantendo caminho e query"

[ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = "true" ] || fail "o container parou"
ok "continua rodando com o sistema de arquivos somente leitura"
