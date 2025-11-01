package network.mostro.app

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {

    private val EVENT_CHANNEL = "native_logcat_stream"
    private var logcatProcess: Process? = null
    private var isCapturing = false
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel para streaming automático de logs nativos
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    startLogCapture(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopLogCapture()
                }
            })
    }

    private fun startLogCapture(eventSink: EventChannel.EventSink?) {
        if (isCapturing) return
        isCapturing = true

        Thread {
            try {
                // Limpiar logcat previo
                Runtime.getRuntime().exec("logcat -c").waitFor()

                // Capturar logs solo de esta app con timestamp
                logcatProcess = Runtime.getRuntime().exec(
                    arrayOf(
                        "logcat",
                        "-v", "time",
                        "--pid=${android.os.Process.myPid()}"
                    )
                )

                val reader = BufferedReader(InputStreamReader(logcatProcess?.inputStream))

                // 👇 CORRECCIÓN: Usar while con asignación inline
                while (isCapturing) {
                    val line = reader.readLine() ?: break

                    if (line.isNotEmpty()) {
                        handler.post {
                            eventSink?.success(line)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("MostroLogCapture", "Error capturing native logs", e)
                handler.post {
                    eventSink?.error("LOGCAT_ERROR", e.message, null)
                }
            } finally {
                isCapturing = false
            }
        }.start()
    }

    private fun stopLogCapture() {
        isCapturing = false
        logcatProcess?.destroy()
        logcatProcess = null
    }

    override fun onDestroy() {
        stopLogCapture()
        super.onDestroy()
    }
}