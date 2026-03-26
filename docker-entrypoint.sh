#!/bin/sh
# ✅ Script de entrypoint para configurar Nginx lendo URL do assets/env

set -e

# ✅ Lê API_URL do arquivo env do Flutter
ENV_FILE="/usr/share/nginx/html/assets/env"

if [ -f "$ENV_FILE" ]; then
  # Extrai API_URL do arquivo (formato: API_URL=https://...)
  BACKEND_URL=$(grep "^API_URL=" "$ENV_FILE" | cut -d '=' -f2 | tr -d '\r\n')
  echo "🔧 Configurando Nginx para preview social..."
  echo "   Backend URL lida de assets/env: $BACKEND_URL"
else
  echo "⚠️ Arquivo $ENV_FILE não encontrado, usando URL padrão"
  BACKEND_URL="https://api.menuhub.com.br"
fi

# ✅ Substitui ${BACKEND_URL} no nginx.conf
envsubst '${BACKEND_URL}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "✅ Nginx configurado com sucesso!"
echo "📋 Crawlers detectados serão redirecionados para: $BACKEND_URL/app/stores/og/{slug}"
echo ""

# ✅ Inicia o Nginx
exec nginx -g 'daemon off;'
