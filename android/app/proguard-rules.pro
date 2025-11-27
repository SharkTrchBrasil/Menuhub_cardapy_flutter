# ═══════════════════════════════════════════════════════════
# PROGUARD RULES - MENUHUB TOTEM
# ═══════════════════════════════════════════════════════════
# Regras de ofuscação e otimização para produção

# ═══════════════════════════════════════════════════════════
# FLUTTER
# ═══════════════════════════════════════════════════════════
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ═══════════════════════════════════════════════════════════
# KOTLIN
# ═══════════════════════════════════════════════════════════
-dontwarn kotlin.**
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }

# ═══════════════════════════════════════════════════════════
# GSON / JSON
# ═══════════════════════════════════════════════════════════
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ═══════════════════════════════════════════════════════════
# OKHTTP / RETROFIT (se usado)
# ═══════════════════════════════════════════════════════════
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ═══════════════════════════════════════════════════════════
# FIREBASE (se usado)
# ═══════════════════════════════════════════════════════════
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# ═══════════════════════════════════════════════════════════
# SEGURANÇA - Não expor nomes de classes sensíveis
# ═══════════════════════════════════════════════════════════
# Ofuscar completamente classes de segurança
-repackageclasses ''
-allowaccessmodification
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

# ═══════════════════════════════════════════════════════════
# DEBUG - Remover logs em release
# ═══════════════════════════════════════════════════════════
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
}

# ═══════════════════════════════════════════════════════════
# MANTER MODELOS DE DADOS
# ═══════════════════════════════════════════════════════════
# Se você tiver modelos que são serializados/deserializados
# -keep class com.seuapp.models.** { *; }

# ═══════════════════════════════════════════════════════════
# WARNINGS
# ═══════════════════════════════════════════════════════════
-dontwarn java.lang.invoke.*
-dontwarn **$$Lambda$*

