# Flutter's default rules.
-dontwarn io.flutter.embedding.**
-keep class io.flutter.embedding.** { *; }

# Your existing Stripe rules
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
-keep class com.stripe.** { *; }

# --- Add rules for other common plugins below ---

# Firebase Core, Auth, Firestore, etc. 🔥
# This is crucial for most Firebase services to work correctly.
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.auth.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Google Mobile Ads (AdMob)
# Prevents crashes related to ad loading, like the NullPointerException you saw.
-keep public class com.google.android.gms.ads.** {
   public *;
}

# Google Maps 🗺️
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.maps.** { *; }

# OkHttp (used by many networking libraries)
-dontwarn okio.**
-dontwarn retrofit2.Platform$Java8
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.squareup.okhttp3.** { *; }
-keep interface com.squareup.okhttp3.** { *; }