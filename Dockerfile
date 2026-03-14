FROM ghcr.io/cirruslabs/flutter:stable AS build-env
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release

FROM nginx:alpine

# Instala gettext para envsubst (substituição de variáveis)
RUN apk add --no-cache gettext

# Copia arquivos do build Flutter
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Copia template do nginx (com variáveis ${BACKEND_URL})
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Copia script de entrypoint customizado
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80

# Usa entrypoint customizado que substitui variáveis e inicia nginx
ENTRYPOINT ["/docker-entrypoint.sh"]