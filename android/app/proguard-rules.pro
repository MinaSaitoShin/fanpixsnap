# 保護対象のライブラリ
-keep class com.baseflow.** { *; }
-keep class com.google.android.gms.** { *; }

# 警告を抑制
-dontwarn com.baseflow.**
-dontwarn com.google.android.gms.**
