# 🚀 Guia de Otimização - Flutter Web Performance

## ✅ Otimizações Já Aplicadas no `index.html`

1. **Preconnect e DNS Prefetch**
   - Conecta antecipadamente aos servidores externos
   - Reduz latência de rede

2. **Spinner CSS Leve**
   - Substituiu GIF pesado por animação CSS
   - Reduz tamanho inicial em ~200KB

3. **Firebase Lazy Loading**
   - Carrega Firebase após 2 segundos
   - Não bloqueia carregamento inicial

4. **Google Maps On-Demand**
   - Carrega apenas quando necessário
   - Use `window.loadGoogleMaps()` antes de usar

5. **Renderer Otimizado**
   - Configurado como "auto" para melhor performance

---

## 🔧 Otimizações Adicionais Recomendadas

### 1. Build Otimizado para Produção

```bash
# ✅ Build com otimizações máximas
flutter build web --release --web-renderer auto --tree-shake-icons

# ✅ Build com split de código (reduz bundle inicial)
flutter build web --release --web-renderer auto --split-debug-info=build/debug-info --obfuscate
```

### 2. Configurar `web/manifest.json`

Adicione cache de recursos:

```json
{
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#EA1D2C",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}
```

### 3. Otimizar Imagens

```bash
# Comprimir imagens antes de adicionar ao projeto
# Use ferramentas como TinyPNG, ImageOptim, ou Squoosh
```

**No código:**
```dart
// ✅ Use cached_network_image para imagens de rede
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => Shimmer(...),
  errorWidget: (context, url, error) => Icon(Icons.error),
  maxWidthDiskCache: 800, // Limita tamanho do cache
  maxHeightDiskCache: 800,
)
```

### 4. Lazy Loading de Widgets Pesados

```dart
// ✅ Carrega widgets pesados sob demanda
class HeavyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: 100)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox.shrink();
        }
        return ActualHeavyWidget();
      },
    );
  }
}
```

### 5. Otimizar Dependências

**Remova pacotes não usados:**
```bash
flutter pub deps | grep "^├──"  # Lista dependências diretas
```

**Use imports específicos:**
```dart
// ❌ Evite
import 'package:flutter/material.dart';

// ✅ Prefira (quando possível)
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme, ThemeData;
```

### 6. Code Splitting (Lazy Loading de Rotas)

```dart
// ✅ Carrega rotas sob demanda
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/heavy-page',
      builder: (context, state) {
        // Carrega a página apenas quando necessário
        return FutureBuilder(
          future: Future.delayed(Duration.zero),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return CircularProgressIndicator();
            }
            return HeavyPage();
          },
        );
      },
    ),
  ],
);
```

### 7. Otimizar Google Fonts

```dart
// ❌ Evite carregar muitas fontes
GoogleFonts.roboto()
GoogleFonts.openSans()
GoogleFonts.lato()

// ✅ Use apenas 1-2 fontes
GoogleFonts.inter()
```

**Ou baixe e use fontes locais:**
```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: fonts/Inter-Regular.ttf
        - asset: fonts/Inter-Bold.ttf
          weight: 700
```

### 8. Configurar Servidor Web (Nginx/Apache)

**Nginx:**
```nginx
# Habilita compressão Gzip
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
gzip_min_length 1000;

# Cache de recursos estáticos
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# Cache do service worker
location /flutter_service_worker.js {
    expires off;
    add_header Cache-Control "no-cache, no-store, must-revalidate";
}
```

### 9. Análise de Performance

```bash
# ✅ Analisa tamanho do bundle
flutter build web --analyze-size

# ✅ Profile mode para debugging de performance
flutter run -d chrome --profile
```

### 10. Otimizar Bloc/Cubit

```dart
// ✅ Use Equatable para evitar rebuilds desnecessários
class MyState extends Equatable {
  final String data;
  
  const MyState(this.data);
  
  @override
  List<Object?> get props => [data];
}

// ✅ Use BlocSelector para rebuilds granulares
BlocSelector<MyCubit, MyState, String>(
  selector: (state) => state.specificField,
  builder: (context, specificField) {
    return Text(specificField);
  },
)
```

---

## 📊 Métricas de Performance Esperadas

Após aplicar todas as otimizações:

- **First Contentful Paint (FCP)**: < 1.5s
- **Largest Contentful Paint (LCP)**: < 2.5s
- **Time to Interactive (TTI)**: < 3.5s
- **Bundle Size**: < 2MB (comprimido)

---

## 🎯 Checklist de Otimização

- [x] Preconnect e DNS prefetch
- [x] Spinner CSS leve
- [x] Firebase lazy loading
- [x] Google Maps on-demand
- [ ] Build otimizado (`--release --tree-shake-icons`)
- [ ] Imagens otimizadas (WebP, compressão)
- [ ] Lazy loading de rotas pesadas
- [ ] Apenas 1-2 Google Fonts
- [ ] Servidor web com Gzip e cache
- [ ] Análise de bundle size

---

## 🚀 Comando de Build Final

```bash
# Build otimizado para produção
flutter build web \
  --release \
  --web-renderer auto \
  --tree-shake-icons \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --source-maps

# Deploy
# Copie o conteúdo de build/web/ para seu servidor
```

---

## 📝 Notas Importantes

1. **Renderer "auto"**: Flutter escolhe automaticamente entre HTML e CanvasKit
2. **Tree-shake-icons**: Remove ícones não usados (reduz ~200KB)
3. **Service Worker**: Desabilitado por padrão (habilite apenas se for PWA)
4. **Firebase**: Carrega após 2s para não bloquear UI inicial
5. **Google Maps**: Carrega sob demanda com `window.loadGoogleMaps()`

---

**Última atualização**: 2025-11-22
