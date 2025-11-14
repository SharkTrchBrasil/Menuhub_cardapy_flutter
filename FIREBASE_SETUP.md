# 🔥 Configuração do Firebase

## Erro: `Firebase: Error (auth/invalid-api-key)`

Este erro ocorre quando as credenciais do Firebase não estão configuradas corretamente no arquivo `assets/env`.

---

## ✅ Solução

Adicione as seguintes variáveis ao arquivo `assets/env`:

```env
# API Backend
API_URL=https://api-pdvix-production.up.railway.app

# Firebase Configuration
FIREBASE_API_KEY=sua-api-key-aqui
FIREBASE_AUTH_DOMAIN=seu-projeto.firebaseapp.com
FIREBASE_PROJECT_ID=seu-projeto-id
FIREBASE_STORAGE_BUCKET=seu-projeto.appspot.com
FIREBASE_MESSAGING_SENDER_ID=seu-messaging-sender-id
FIREBASE_APP_ID=seu-app-id
FIREBASE_MEASUREMENT_ID=G-XXXXXXXXXX  # Opcional para Analytics
```

---

## 📝 Como obter as credenciais

1. Acesse o [Firebase Console](https://console.firebase.google.com/)
2. Selecione seu projeto (ou crie um novo)
3. Vá em **Configurações do Projeto** (ícone de engrenagem)
4. Role até a seção **Seus apps**
5. Selecione o app **Web** (ou crie um novo)
6. Copie as credenciais do objeto de configuração

Exemplo do objeto que você verá:
```javascript
const firebaseConfig = {
  apiKey: "AIza...",
  authDomain: "seu-projeto.firebaseapp.com",
  projectId: "seu-projeto",
  storageBucket: "seu-projeto.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abc123",
  measurementId: "G-XXXXXXXXXX"
};
```

---

## ⚠️ Importante

- O arquivo `assets/env` **NÃO** deve ser commitado no git (adicionar ao `.gitignore`)
- Use diferentes credenciais para desenvolvimento e produção
- Mantenha as credenciais seguras

---

## 🚀 Após adicionar as credenciais

1. Reinicie o aplicativo
2. O Firebase será inicializado automaticamente
3. O Google Sign-In estará disponível

---

## 📌 Nota

Se o Firebase não for necessário para o funcionamento básico do app, você pode deixar as variáveis vazias. O app continuará funcionando, mas o Google Sign-In não estará disponível.

