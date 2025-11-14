# 🔥 Debug Firebase - Invalid API Key

## Problema
Erro: `Firebase: Error (auth/invalid-api-key)`

## ✅ Correções Aplicadas

1. **Logs de Debug Adicionados:**
   - Verificação se arquivo `.env` foi carregado
   - Log das credenciais do Firebase na inicialização
   - Verificação se Firebase está inicializado antes de usar

2. **Uso Explícito da Instância do Firebase:**
   - Mudança de `FirebaseAuth.instance` para `FirebaseAuth.instanceFor(app: apps.first)`
   - Isso garante que estamos usando a instância corretamente inicializada

3. **Validações Adicionadas:**
   - Verificação se Firebase apps estão disponíveis antes de usar
   - Mensagens de erro mais descritivas

## 🔍 Como Debuggar

Quando o app iniciar, você verá nos logs:

1. ✅ Arquivo .env carregado com sucesso
   - API_URL: ...
   - FIREBASE_API_KEY: ...

2. 🔥 Firebase Inicializando...
   - API Key: AIzaSyAvI8...
   - Project ID: pdvix-c69fe
   - Auth Domain: pdvix-c69fe.firebaseapp.com

3. ✅ Firebase initialized successfully
   - App Name: [DEFAULT]
   - Options: pdvix-c69fe

4. Quando tentar fazer login:
   - 🔥 [AuthCubit] Firebase apps: 1
   - 🔥 [AuthCubit] Firebase project: pdvix-c69fe
   - 🔥 [AuthCubit] Firebase API key: AIzaSyAvI8...

## ⚠️ Possíveis Causas do Erro

1. **API Key Inválida:**
   - Verifique se a API key no Firebase Console está correta
   - Certifique-se de que não há espaços extras no arquivo `env`

2. **Domínio Não Autorizado:**
   - No Firebase Console, vá em Authentication > Settings > Authorized domains
   - Adicione `localhost` e seu domínio de produção

3. **Cache do Browser:**
   - Limpe o cache do navegador
   - Tente em modo anônimo/privado

4. **Arquivo .env não recarregado:**
   - Após modificar `assets/env`, faça hot restart (não apenas hot reload)
   - Ou pare completamente o app e inicie novamente

## 🚀 Próximos Passos

1. Reinicie o app completamente
2. Verifique os logs no console
3. Se ainda houver erro, verifique:
   - Firebase Console > Authentication > Settings
   - API Restrictions no Google Cloud Console
   - Domínios autorizados

