# ProGuard / R8 keep rules

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# MainActivity (MethodChannel 入口)
-keep class com.zai.app.MainActivity { *; }

# 原生前台保活服务
-keep class com.zai.app.GenerateForegroundService { *; }
