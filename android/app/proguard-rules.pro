# Proguard / R8 rules for Synco
# Prevent R8 from obfuscating youtubedl-android and related native dependencies

-dontobfuscate

-keep class com.yausername.** { *; }
-keep interface com.yausername.** { *; }
-keep class io.github.junkfood02.** { *; }
-keep class org.apache.commons.compress.** { *; }
-keep class com.example.synco.** { *; }

-dontwarn com.yausername.**
-dontwarn org.apache.commons.compress.**
