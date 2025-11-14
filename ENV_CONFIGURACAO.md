# 📝 Configuração de Variáveis de Ambiente

## ❓ Qual arquivo usar?

### ✅ **USE: `assets/env`**

Este é o arquivo que o código está configurado para usar:

```dart
// main.dart linha 35
await dotenv.load(fileName: 'assets/env');
```

**Por quê usar `assets/env`?**
- ✅ Está listado no `pubspec.yaml` como asset (linha 99)
- ✅ É incluído automaticamente no build do Flutter
- ✅ Funciona em todas as plataformas (Web, Android, iOS, Desktop)
- ✅ É carregado quando o app inicia

### ❌ **NÃO USE: `.env` na raiz**

O arquivo `.env` na raiz:
- ❌ **NÃO** é carregado pelo código atual
- ❌ Está no `.gitignore` (não vai para o repositório)
- ❌ Não funciona em Flutter Web sem configuração adicional

---

## 🔧 Solução Recomendada

### Opção 1: Use apenas `assets/env` (Recomendado)

1. **Certifique-se que `assets/env` tem todas as variáveis**
2. **Mantenha `assets/env` atualizado**
3. **Ignore o `.env` da raiz** (já está no `.gitignore`)

### Opção 2: Sincronizar ambos

Se você quiser manter os dois arquivos sincronizados:
- Use `assets/env` como fonte principal
- Copie conteúdo para `.env` quando necessário
- Mas lembre-se: o código usa apenas `assets/env`

---

## ⚠️ Importante

**O código NÃO está lendo o `.env` da raiz!**

Se você adicionou variáveis no `.env` da raiz, elas **não estão sendo usadas**.  
Copie o conteúdo para `assets/env` para que funcionem.

---

## 📋 Estrutura de Arquivos

```
totem/
├── assets/
│   └── env          ← ✅ ESTE é o arquivo que o código LÊ
├── .env             ← ❌ Este arquivo NÃO é usado pelo código
└── .gitignore       ← Já tem .env listado (linha 46)
```

---

## ✅ Checklist

- [ ] `assets/env` contém todas as variáveis necessárias
- [ ] `assets/env` está listado no `pubspec.yaml` (linha 99)
- [ ] `.env` na raiz pode ser ignorado ou removido
- [ ] Após mudanças em `assets/env`, faça **hot restart** (não apenas hot reload)

---

## 🚀 Resumo

**Use apenas `assets/env`** - este é o arquivo correto que funciona no Flutter.
