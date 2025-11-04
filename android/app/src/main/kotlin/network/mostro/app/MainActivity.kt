package network.mostro.app

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {

    private val EVENT_CHANNEL = "native_logcat_stream"
    private var logcatProcess: Process? = null
    private val isCapturing = AtomicBoolean(false)
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for automatic native log streaming
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
        // Use compareAndSet for thread-safe check-and-set operation
        if (!isCapturing.compareAndSet(false, true)) return

        Thread({
            var reader: BufferedReader? = null
            try {
                // Capture logs only for this app with timestamp
                logcatProcess = Runtime.getRuntime().exec(
                    arrayOf(
                        "logcat",
                        "-v", "time",
                        "--pid=${android.os.Process.myPid()}"
                    )
                )

                reader = BufferedReader(
                    InputStreamReader(logcatProcess?.inputStream)
                )

                // Use inline assignment in while loop
                while (isCapturing.get()) {
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
                reader?.close()
                logcatProcess?.destroy()
                // Forcibly kill if not terminated after brief wait
                try {
                    if (logcatProcess?.waitFor(100, java.util.concurrent.TimeUnit.MILLISECONDS) == false) {
                        logcatProcess?.destroyForcibly()
                    }
                } catch (e: Exception) {
                    Log.w("MostroLogCapture", "Error waiting for process termination", e)
                }
                isCapturing.set(false)
            }
        }, "mostro-logcat").start()
    }

    private fun stopLogCapture() {
        isCapturing.set(false)
        logcatProcess?.let { process ->
            process.destroy()
            // Force kill if still alive after brief wait
            Thread {
                try {
                    if (!process.waitFor(200, java.util.concurrent.TimeUnit.MILLISECONDS)) {
                        process.destroyForcibly()
                    }
                } catch (e: Exception) {
                    Log.w("MostroLogCapture", "Process cleanup interrupted", e)
                }
            }.start()
        }
        logcatProcess = null
    }

    override fun onDestroy() {
        stopLogCapture()
        super.onDestroy()
    }
}