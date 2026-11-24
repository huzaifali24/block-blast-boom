# Keep rules for release builds (R8 code shrinking).

# WorkManager (used by the Google Mobile Ads SDK) creates its Room database
# by reflection; without these the app crashes on launch with
# "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# Google Mobile Ads / User Messaging Platform.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }

# flutter_local_notifications: scheduled reminders are stored with Gson.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
