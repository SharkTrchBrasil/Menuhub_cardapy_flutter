FROM ghcr.io/cirruslabs/flutter:stable AS build-env
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release --web-renderer html --pwa-strategy offline-first

FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]