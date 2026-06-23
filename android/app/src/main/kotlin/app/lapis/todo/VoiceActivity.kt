package app.lapis.todo

import android.app.Activity
import android.content.Intent
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class VoiceActivity : FlutterActivity() {
    private val VOICE_CHANNEL = "app.lapis.todo/voice"
    private var pendingVoiceText: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        intent?.getStringExtra("taskName")?.let { pendingVoiceText = it }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingCommand" -> {
                    result.success(pendingVoiceText)
                    pendingVoiceText = null
                }
                "showToast" -> {
                    val message = call.argument<String>("message") ?: ""
                    Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
                    result.success(true)
                }
                "finishActivity" -> {
                    finishAndRemoveTask()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
