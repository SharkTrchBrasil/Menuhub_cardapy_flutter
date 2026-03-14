# 🎨 Configuração de Preview Social no Coolify

## 🎯 Objetivo

Fazer com que links compartilhados no WhatsApp, Telegram e Facebook mostrem:
- **Nome da loja** (título)
- **Descrição da loja** (subtítulo)
- **Logo da loja** (imagem)

---

## 🏗️ Arquitetura Implementada

### Fluxo de Requests

```
┌─────────────────────────────────────────────────────────────┐
│                    Request para Totem                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
           ┌───────────────────────┐
           │   Nginx detecta       │
           │   User-Agent          │
           └───────────┬───────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
┌──────────────┐              ┌─────────────────┐
│   Crawler?   │              │  Usuário Real?  │
│  (WhatsApp,  │              │   (Browser)     │
│   Facebook)  │              │                 │
└──────┬───────┘              └────────┬────────┘
       │                               │
       ▼                               ▼
┌──────────────────┐          ┌──────────────────┐
│  Backend FastAPI │          │  Flutter Web     │
│  /app/stores     │          │  (index.html)    │
│                  │          │                  │
│  • store_meta.   │          │  • App normal    │
│    html template │          │  • JavaScript    │
│  • Meta tags SSR │          │    dinâmico      │
└──────────────────┘          └──────────────────┘
```

---

## 📁 Arquivos Modificados

### 1. `nginx.conf.template`
```nginx
# Map para detectar crawlers
map $http_user_agent $is_crawler {
  default 0;
  "~*WhatsApp" 1;
  "~*facebookexternalhit" 1;
  # ... outros crawlers
}

location / {
  if ($is_crawler = 1) {
    proxy_pass ${BACKEND_URL}/app/stores;
    # ... headers de proxy
  }
  
  try_files $uri $uri/ /index.html;
}
```

### 2. `docker-entrypoint.sh`
```bash
#!/bin/sh
# Substitui ${BACKEND_URL} no nginx.conf.template
envsubst '${BACKEND_URL}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
exec nginx -g 'daemon off;'
```

### 3. `Dockerfile`
```dockerfile
FROM nginx:alpine
RUN apk add --no-cache gettext
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.sh
ENV BACKEND_URL=https://api.menuhub.com.br
ENTRYPOINT ["/docker-entrypoint.sh"]
```

---

## ⚙️ Configuração no Coolify

### Variáveis de Ambiente

Adicione no Coolify (ou `.env`):

```bash
BACKEND_URL=https://api.menuhub.com.br
```

**⚠️ IMPORTANTE:** A URL deve ser **acessível do container Docker** (não `localhost`).

### Build & Deploy

1. **Build da imagem:**
   ```bash
   docker build -t totem:latest .
   ```

2. **Run local (teste):**
   ```bash
   docker run -p 8080:80 \
     -e BACKEND_URL=https://api.menuhub.com.br \
     totem:latest
   ```

3. **Deploy no Coolify:**
   - Push código para Git
   - Coolify detecta Dockerfile automaticamente
   - Define `BACKEND_URL` nas variáveis de ambiente
   - Deploy!

---

## 🧪 Testando

### 1. Verificar Configuração do Nginx

```bash
# SSH no container
docker exec -it <container_id> sh

# Ver nginx.conf gerado
cat /etc/nginx/nginx.conf

# Deve mostrar URL real (não ${BACKEND_URL})
```

### 2. Testar com Curl (Simular Crawler)

```bash
# Simular WhatsApp
curl -H "User-Agent: WhatsApp/2.23.20.0" \
  https://lanchonetejeitomineiro.menuhub.com.br/

# Deve retornar HTML com meta tags <og:title>, <og:description>, etc.
```

### 3. Testar com Usuário Normal

```bash
# Navegador normal
curl -H "User-Agent: Mozilla/5.0" \
  https://lanchonetejeitomineiro.menuhub.com.br/

# Deve retornar index.html do Flutter
```

### 4. Facebook Debugger

```
https://developers.facebook.com/tools/debug/
```
Cole a URL da loja e veja se aparece:
- ✅ Título correto (nome da loja)
- ✅ Descrição correta
- ✅ Imagem correta (logo)

### 5. WhatsApp Real

Envie o link em qualquer conversa:
```
https://lanchonetejeitomineiro.menuhub.com.br/
```

Deve aparecer preview rico com logo, nome e descrição! 🎉

---

## 📊 Logs de Sucesso

**Nginx detectando crawler:**
```
10.0.1.6 - - [14/Mar/2026:15:53:30] "GET / HTTP/1.1" 200 XXXX "-" "WhatsApp/2.23.20.0"
```

**Backend servindo HTML:**
```
INFO: GET /app/stores - 200 OK (store: lanchonetejeitomineiro)
```

**Usuário normal:**
```
10.0.1.6 - - [14/Mar/2026:15:52:03] "GET / HTTP/1.1" 200 1717 "-" "Mozilla/5.0 ..."
```

---

## 🔧 Troubleshooting

### Problema: Preview não aparece no WhatsApp

**Solução 1:** Limpar cache do WhatsApp
- Delete a conversa
- Envie o link novamente

**Solução 2:** Verificar logs do Nginx
```bash
docker logs <totem_container> | grep WhatsApp
```

**Solução 3:** Verificar se backend está acessível
```bash
curl https://api.menuhub.com.br/app/stores \
  -H "Host: lanchonetejeitomineiro.menuhub.com.br"
```

### Problema: Nginx não substitui ${BACKEND_URL}

**Solução:** Verificar se `envsubst` foi executado
```bash
# Ver entrypoint logs
docker logs <container_id> | grep "Configurando Nginx"

# Deve mostrar:
# 🔧 Configurando Nginx para preview social...
#    Backend URL: https://api.menuhub.com.br
# ✅ Nginx configurado com sucesso!
```

### Problema: CORS error no proxy

**Solução:** Backend já tem CORS configurado para subdomínios `.menuhub.com.br`

Verificar em `Backend/src/api/app/security/domain_validator.py`:
```python
ALLOWED_DOMAINS = ["*.menuhub.com.br"]
```

---

## 🎯 Checklist de Deploy

- [ ] Variável `BACKEND_URL` configurada no Coolify
- [ ] Dockerfile atualizado com entrypoint customizado
- [ ] `nginx.conf.template` com detecção de crawlers
- [ ] `docker-entrypoint.sh` com permissão de execução
- [ ] Build e push para produção
- [ ] Testar com Facebook Debugger
- [ ] Testar com WhatsApp real
- [ ] Verificar logs do Nginx

---

## 📚 Crawlers Detectados

- ✅ **WhatsApp** (`WhatsApp/`)
- ✅ **Facebook** (`facebookexternalhit`, `Facebot`)
- ✅ **Twitter** (`Twitterbot`)
- ✅ **LinkedIn** (`LinkedInBot`)
- ✅ **Telegram** (`TelegramBot`)
- ✅ **Slack** (`Slackbot`)
- ✅ **Discord** (`Discord`)

Adicionar mais em `nginx.conf.template` se necessário.

---

## 🚀 Resultado Final

**Antes:**
```
TotemPRO - Soluções de autoatendimento
lanchonetejeitomineiro.menuhub.com.br
```

**Depois:**
```
[🖼️ Logo Colorido]
Lanchonete Jeito Mineiro
Delivery abençoado da cidade
lanchonetejeitomineiro.menuhub.com.br
```

---

**Status:** ✅ Implementado e pronto para deploy!
**Última atualização:** 2026-03-14
