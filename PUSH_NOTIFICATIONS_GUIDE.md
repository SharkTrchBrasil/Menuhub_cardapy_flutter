# 📱 Guia de Implementação de Notificações Push no Totem

## 🔔 Como Funcionam as Notificações Push

### Cenários Suportados:

1. **App Fechado (mas usuário logado)** ✅
   - Quando você recebe uma notificação push, o sistema operacional "acorda" o app
   - Ao tocar na notificação, o app abre automaticamente
   - Você pode navegar diretamente para a tela relevante (ex: detalhes do pedido)

2. **App em Segundo Plano** ✅
   - Notificação aparece no topo da tela
   - Ao tocar, o app volta para primeiro plano
   - Dados são atualizados automaticamente

3. **App em Primeiro Plano** ✅
   - Você pode escolher: mostrar notificação no topo OU apenas atualizar os dados silenciosamente

---

## 🛠️ O Que Precisamos Implementar

### 1. **Firebase Cloud Messaging (FCM)**
- ✅ Firebase já está configurado no projeto
- ❌ Falta adicionar o pacote `firebase_messaging`
- ❌ Falta configurar os handlers de notificação

### 2. **Backend: Armazenar Tokens FCM**
- O app precisa enviar o token FCM para o backend quando o usuário faz login
- O backend armazena o token vinculado ao `customer_id`

### 3. **Backend: Enviar Notificações**
- Quando um evento importante acontece (ex: status do pedido mudou)
- O backend busca os tokens FCM do cliente
- Envia notificação via Firebase Admin SDK

### 4. **Frontend: Tratar Notificações**
- Quando a notificação chega → abrir a tela correta
- Quando o usuário toca na notificação → navegar para o pedido

---

## 📋 Passo a Passo de Implementação

### **PASSO 1: Adicionar Dependências**

No arquivo `totem/pubspec.yaml`, adicione:

```yaml
dependencies:
  firebase_messaging: ^14.7.10  # ✅ ADICIONAR
```

Execute:
```bash
flutter pub get
```

---

### **PASSO 2: Configuração Android**

1. **Adicione ao `android/app/build.gradle`:**
```gradle
android {
    defaultConfig {
        // ...
        minSdkVersion 21  // ✅ FCM requer pelo menos API 21
    }
}

dependencies {
    // ✅ Adicione se não existir
    implementation 'com.google.firebase:firebase-messaging:23.0.0'
}
```

2. **Crie o arquivo `android/app/src/main/AndroidManifest.xml`:**
```xml
<manifest>
    <!-- ✅ Adicione estas permissões -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/> <!-- Android 13+ -->
    
    <application>
        <!-- ✅ Service para notificações em background -->
        <service
            android:name="com.google.firebase.messaging.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
        
        <!-- ✅ Metadados do Firebase -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="pedidos_channel" />
    </application>
</manifest>
```

3. **Baixe `google-services.json` do Firebase Console:**
   - Firebase Console → Configurações do Projeto
   - Seus apps → Android
   - Baixe o arquivo `google-services.json`
   - Coloque em `android/app/google-services.json`

---

### **PASSO 3: Configuração iOS**

1. **No `ios/Runner/Info.plist`, adicione:**
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

2. **No `ios/Runner/AppDelegate.swift`, adicione:**
```swift
import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    // ✅ Solicita permissão de notificação
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    }
    
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // ✅ Recebe token FCM
  override func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }
}
```

3. **Baixe `GoogleService-Info.plist` do Firebase Console:**
   - Coloque em `ios/Runner/GoogleService-Info.plist`

---

### **PASSO 4: Criar Serviço de Notificações no Totem**

Crie o arquivo `totem/lib/services/push_notification_service.dart`:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../core/di.dart';
import 'package:go_router/go_router.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  
  // ✅ Getter para o token FCM
  String? get fcmToken => _fcmToken;

  /// Inicializa o serviço de notificações push
  Future<void> initialize() async {
    // ✅ Solicita permissão
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Permissão de notificação concedida');
      
      // ✅ Obtém token FCM
      _fcmToken = await _messaging.getToken();
      print('📱 FCM Token: $_fcmToken');
      
      // ✅ Envia token para o backend
      await _sendTokenToBackend(_fcmToken!);
      
      // ✅ Configura handlers
      _setupNotificationHandlers();
      
      // ✅ Escuta atualizações do token
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _sendTokenToBackend(newToken);
      });
    } else {
      print('❌ Permissão de notificação negada');
    }
  }

  /// Configura os handlers de notificação
  void _setupNotificationHandlers() {
    // ✅ NOTIFICAÇÃO RECEBIDA COM APP EM PRIMEIRO PLANO
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📬 Notificação recebida (app em primeiro plano): ${message.notification?.title}');
      
      // Você pode mostrar um diálogo, atualizar UI, etc.
      // Exemplo: mostrar SnackBar ou navegar para o pedido
      _handleNotification(message);
    });

    // ✅ USUÁRIO TOCOU NA NOTIFICAÇÃO (app estava fechado ou em segundo plano)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('👆 Notificação tocada: ${message.data}');
      
      // Navega para a tela correta baseado nos dados da notificação
      _navigateFromNotification(message);
    });

    // ✅ APP ABERTO A PARTIR DE NOTIFICAÇÃO (quando estava completamente fechado)
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 App aberto via notificação: ${message.data}');
        _navigateFromNotification(message);
      }
    });
  }

  /// Envia o token FCM para o backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final authRepo = getIt<AuthRepository>();
      // ✅ Você precisa criar este endpoint no backend
      await authRepo.registerFcmToken(token);
      print('✅ Token FCM enviado para o backend');
    } catch (e) {
      print('❌ Erro ao enviar token FCM: $e');
    }
  }

  /// Trata notificação recebida
  void _handleNotification(RemoteMessage message) {
    // Extrai dados da notificação
    final data = message.data;
    final notification = message.notification;
    
    // Exemplo: Se for atualização de pedido
    if (data['type'] == 'order_status_changed') {
      final orderId = data['order_id'];
      final status = data['status'];
      
      print('📦 Pedido $orderId mudou para: $status');
      
      // Atualiza UI, mostra banner, etc.
      // Você pode usar um BlocListener ou similar
    }
  }

  /// Navega para a tela correta baseado na notificação
  void _navigateFromNotification(RemoteMessage message) {
    final data = message.data;
    
    // Exemplo: Navega para detalhes do pedido
    if (data['type'] == 'order_status_changed') {
      final orderPublicId = data['order_public_id'];
      if (orderPublicId != null) {
        // Navega usando go_router
        // Você precisará ter acesso ao contexto ou usar um GlobalKey
        // Exemplo (você precisará ajustar):
        // navigatorKey.currentContext?.go('/orders/$orderPublicId');
      }
    }
  }

  /// Remove o token (quando usuário faz logout)
  Future<void> unregister() async {
    try {
      final authRepo = getIt<AuthRepository>();
      await authRepo.unregisterFcmToken(_fcmToken);
      _fcmToken = null;
      print('✅ Token FCM removido');
    } catch (e) {
      print('❌ Erro ao remover token FCM: $e');
    }
  }
}

// ✅ HANDLER GLOBAL PARA NOTIFICAÇÕES EM BACKGROUND (Android/iOS)
// Este arquivo deve ser criado em: totem/lib/main.dart ou totem/lib/services/firebase_messaging_background.dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🌙 Notificação recebida em background: ${message.messageId}');
  // Aqui você pode processar dados, atualizar cache local, etc.
  // Mas NÃO pode atualizar UI diretamente
}
```

---

### **PASSO 5: Inicializar no `main.dart`**

```dart
import 'package:totem/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  // ... código existente ...
  
  // ✅ Após inicializar Firebase
  if (Firebase.apps.isNotEmpty) {
    // ✅ Registra handler de background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // ✅ Inicializa serviço de notificações
    await PushNotificationService().initialize();
  }
  
  // ... resto do código ...
}
```

---

### **PASSO 6: Backend - Armazenar Tokens FCM**

1. **Crie uma tabela no banco:**
```sql
CREATE TABLE customer_fcm_tokens (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_info JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(customer_id, fcm_token)
);
```

2. **Crie endpoint no backend:**
```python
# Backend/src/api/app/routes/notifications.py
from fastapi import APIRouter, Depends
from src.core.dependencies import GetCustomerDep
from src.core import models

router = APIRouter(prefix="/notifications", tags=["Notifications"])

@router.post("/register-token")
async def register_fcm_token(
    token: str,
    customer: GetCustomerDep,
    db: GetDBDep
):
    """Registra token FCM do dispositivo do cliente"""
    existing = db.query(models.CustomerFcmToken).filter(
        models.CustomerFcmToken.customer_id == customer.id,
        models.CustomerFcmToken.fcm_token == token
    ).first()
    
    if not existing:
        fcm_token = models.CustomerFcmToken(
            customer_id=customer.id,
            fcm_token=token
        )
        db.add(fcm_token)
        db.commit()
    
    return {"success": True}
```

---

### **PASSO 7: Backend - Enviar Notificações**

```python
# Backend/src/api/services/fcm_service.py
from firebase_admin import messaging
import firebase_admin

def send_order_status_notification(
    customer_id: int,
    order_public_id: str,
    new_status: str,
    db: Session
):
    """Envia notificação push quando status do pedido muda"""
    
    # ✅ Busca tokens FCM do cliente
    tokens = db.query(models.CustomerFcmToken.fcm_token).filter(
        models.CustomerFcmToken.customer_id == customer_id
    ).all()
    
    if not tokens:
        return
    
    # ✅ Monta a mensagem
    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title="Status do Pedido Atualizado",
            body=f"Seu pedido #{order_public_id} agora está {new_status}",
        ),
        data={
            "type": "order_status_changed",
            "order_public_id": order_public_id,
            "status": new_status,
        },
        tokens=[token.fcm_token for token in tokens],
    )
    
    # ✅ Envia
    response = messaging.send_multicast(message)
    print(f"✅ {response.success_count} notificações enviadas")
```

---

## ✅ Resumo do Fluxo

1. **Usuário faz login** → App obtém token FCM → Envia para backend
2. **Backend armazena token** vinculado ao `customer_id`
3. **Evento importante acontece** (ex: pedido mudou de status)
4. **Backend busca tokens** do cliente e envia notificação via FCM
5. **Firebase entrega notificação** ao dispositivo
6. **Sistema operacional "acorda" o app** (se estiver fechado)
7. **Usuário toca na notificação** → App abre → Navega para tela correta

---

## 🎯 Próximos Passos

1. Adicionar `firebase_messaging` ao `pubspec.yaml`
2. Configurar Android (google-services.json, AndroidManifest.xml)
3. Configurar iOS (GoogleService-Info.plist, AppDelegate.swift)
4. Criar `PushNotificationService` no Totem
5. Criar tabela `customer_fcm_tokens` no backend
6. Criar endpoints para registrar/remover tokens
7. Criar serviço FCM no backend para enviar notificações
8. Integrar envio de notificações nos eventos relevantes (status do pedido, etc.)

---

## 📌 Notas Importantes

- ✅ **Funciona mesmo com app fechado**: O Firebase Cloud Messaging gerencia isso
- ✅ **Funciona em segundo plano**: O sistema operacional cuida disso
- ✅ **Gratuito**: FCM é gratuito até milhões de mensagens por mês
- ⚠️ **Requer internet**: Cliente precisa estar online para receber
- ⚠️ **iOS requer certificados**: Precisa configurar APNs no Firebase Console

---

## 🔗 Links Úteis

- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
- [FlutterFire Messaging](https://firebase.flutter.dev/docs/messaging/overview)
- [Firebase Console](https://console.firebase.google.com/)


