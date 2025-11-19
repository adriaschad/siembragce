# Evita que R8 falle por clases de anotaciones usadas por Tink / Security Crypto
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn javax.annotation.concurrent.**

# Mantén Tink y protobuf (usados por Security Crypto bajo el capó)
-keep class com.google.crypto.tink.** { *; }
-keep class com.google.protobuf.** { *; }

# (Opcional) Evita warnings de InsecureSecretKeyAccess y amigos
-dontwarn com.google.crypto.tink.**
