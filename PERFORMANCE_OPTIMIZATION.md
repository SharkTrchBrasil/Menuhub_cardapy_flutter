# 🚀 Guia de Otimização de Performance - Flutter Web (Totem)

> Última atualização: 21/12/2025

## 📊 Problemas Corrigidos

| Problema | Status | Economia/Impacto |
|----------|--------|------------------|
| Erro `_flutter_bootstrap is not defined` | ✅ Corrigido | Crítico - página carrega |
| Firebase duplicado no index.html | ✅ Removido | ~13-52 KiB |
| `font_awesome_flutter` não usado | ✅ Removido | ~50 KiB |
| `mobile_scanner` não usado | ✅ Removido | ~100 KiB |
| `animated_text_kit` não usado | ✅ Removido | ~50 KiB |
| `percent_indicator` não usado | ✅ Removido | ~30 KiB |
| `robots.txt` inválido | ✅ Criado | SEO melhorado |
| Meta tags SEO incompletas | ✅ Adicionadas | SEO melhorado |

**Economia total estimada: ~300-400 KiB** 🎉

---

## 📁 Arquivos Criados/Modificados

| Arquivo | Descrição |
|---------|-----------|
| `web/index.html` | Loader Flutter corrigido, Firebase removido, SEO melhorado |
| `web/robots.txt` | Novo arquivo para SEO |
| `pubspec.yaml` | Dependências não usadas removidas |
| `build_web_optimized.ps1` | Script de build otimizado |
| `nginx.conf.example` | Configuração de cache para servidor |

---

## ⚡ Problemas que Dependem do Servidor

Estes problemas precisam ser configurados no servidor de produção:

### 1. **Cache do `flutter_bootstrap.js`** (Cache TTL = None)

O Lighthouse mostra que `flutter_bootstrap.js` não tem cache configurado.
Use a configuração do `nginx.conf.example` para configurar:

```nginx
location ~* flutter_bootstrap\.js$ {
    expires 1h;
    add_header Cache-Control "public, must-revalidate";
}
```

### 2. **Compressão Gzip/Brotli**

Ativar no servidor:
```nginx
gzip on;
gzip_types text/plain application/javascript application/wasm;
```

---

## 🔧 JavaScript Não Usado (1.6 MB)

O Lighthouse mostra `main.dart.js` com ~2MB e 1.6MB não usado. Isso é **normal** para Flutter Web porque:

1. **Flutter compila todo o código Dart para JavaScript** - não há tree-shaking perfeito
2. **Widgets Material/Cupertino** são incluídos mesmo se não usados diretamente
3. **Dependências pesadas** como `flutter_map`, `geolocator`, `video_player` adicionam peso

### Soluções Adicionais (Avançadas):

#### A) **Usar Deferred Loading** (Code Splitting)
```dart
// Carregar sob demanda
import 'package:totem/pages/checkout/checkout_page.dart' deferred as checkout;

// No widget
FutureBuilder(
  future: checkout.loadLibrary(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.done) {
      return checkout.CheckoutPage();
    }
    return CircularProgressIndicator();
  },
)
```

#### B) **Usar WASM** (Flutter 3.22+)
O WASM reduz o bundle em ~30% e melhora performance:
```powershell
.\build_web_optimized.ps1 -WasmMode
```

#### C) **Avaliar Dependências Pesadas**
Se possível, substituir por alternativas mais leves:
- `flutter_map` → Usar imagem estática do mapa
- `video_player` → Usar `<video>` HTML nativo
- `geolocator` → Usar Geolocation API do browser

---

## 📈 Métricas Alvo

| Métrica | Atual* | Alvo |
|---------|--------|------|
| LCP (Largest Contentful Paint) | ~930ms | < 2.5s ✅ |
| Práticas Recomendadas | 96/100 | ≥ 90 ✅ |
| Bundle Size (comprimido) | ~500KB | < 1MB ✅ |
| JavaScript Não Usado | 1.6MB | Normal para Flutter |

*Valores aproximados do Lighthouse

---

## 🚀 Como Fazer Deploy

### 1. Build Otimizado
```powershell
cd c:\Users\Sharkcode\Documents\Menuhub\totem
.\build_web_optimized.ps1
```

### 2. Testar Localmente
```powershell
cd build\web
python -m http.server 8080
# Abrir http://localhost:8080
```

### 3. Deploy
- Copie `build/web/` para o servidor
- Configure nginx usando `nginx.conf.example`
- Verifique com Lighthouse

---

## 📚 Referências

- [Flutter Web Performance](https://docs.flutter.dev/perf/rendering/web)
- [Deferred Loading](https://dart.dev/language/libraries#lazily-loading-a-library)
- [Web Vitals](https://web.dev/vitals/)
