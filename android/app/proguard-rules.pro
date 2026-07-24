# Règles R8 / ProGuard pour le build release de dony.
# Le plugin Gradle Flutter injecte déjà les keeps de base pour l'engine et
# io.flutter.** ; ce fichier ajoute les préservations spécifiques aux plugins
# qui utilisent la réflexion ou du code natif, sinon supprimés/renommés par R8.

# ── Flutter deferred components / Play Core ─────────────────────────────────
# Flutter référence Play Core (SplitCompat) même sans deferred components ;
# absent de nos deps → R8 avertit et peut casser. On ignore proprement.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── Stripe (SDK paiements + Identity, réflexion sur les modèles) ─────────────
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**
-keep class com.reactnativestripesdk.** { *; }

# ── Firebase (Auth, Messaging) ──────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── Annotations, génériques, signatures (réflexion / JSON) ──────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Enums (valueOf réflexif).
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelables (CREATOR requis à l'exécution).
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Méthodes natives (JNI).
-keepclasseswithmembernames class * {
    native <methods>;
}
