package network.mostro.app

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "mostro/logs"
    private val EVENT_CHANNEL = "mostro/logsStream"

    private var logJob: Job? = null
    private var eventSink: EventChannel.EventSink? = null

    // Se asegura de registrar correctamente los canales
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel para iniciar/parar captura
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLogCapture" -> {
                        startLogCapture()
                        result.success(null)
                    }
                    "stopLogCapture" -> {
                        stopLogCapture()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // EventChannel para enviar logs a Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun startLogCapture() {
        stopLogCapture() // Evita duplicados
        logJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("logcat", "-v", "time", "MostroApp:D", "*:S"))
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                var line: String?
                while (isActive) {
                    line = reader.readLine()
                    if (line != null) {
                        withContext(Dispatchers.Main) {
                            eventSink?.success(line)
                        }
                    } else {
                        delay(100)
                    }
                }
                process.destroy()
            } catch (e: Exception) {
                Log.e("MostroLogCapture", "Error capturing logs", e)
            }
        }
    }

    private fun stopLogCapture() {
        logJob?.cancel()
        logJob = null
    }
}
