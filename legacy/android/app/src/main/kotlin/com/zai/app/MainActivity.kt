package com.zai.app

import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.zai.app/foreground"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val title = call.argument<String>("title") ?: "AI 任务进行中"
                    val body = call.argument<String>("body") ?: "请稍候..."
                    GenerateForegroundService.start(this, title, body)
                    result.success(true)
                }
                "stop" -> {
                    GenerateForegroundService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
