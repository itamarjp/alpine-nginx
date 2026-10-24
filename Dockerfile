FROM alpine:edge

RUN apk upgrade --no-cache \
    && apk add --no-cache nginx

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/snippets/ /etc/nginx/snippets/
COPY conf/http.d/default.conf /etc/nginx/http.d/default.conf

# Usuário criado pelo próprio pacote do Alpine (UID 101). O Nginx escuta na 8080,
# então não precisa de root. O pid e os arquivos temporários ficam em /tmp,
# o que permite readOnlyRootFilesystem com um emptyDir em /tmp.
USER nginx
EXPOSE 8080

CMD ["nginx", "-e", "/dev/stderr", "-g", "daemon off;"]
