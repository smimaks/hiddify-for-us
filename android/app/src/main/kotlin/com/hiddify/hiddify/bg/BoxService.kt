package com.hiddify.hiddify.bg

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import androidx.lifecycle.MutableLiveData
import com.hiddify.hiddify.Application
import com.hiddify.hiddify.R
import com.hiddify.hiddify.Settings
import com.hiddify.hiddify.constant.Action
import com.hiddify.hiddify.constant.Alert
import com.hiddify.hiddify.constant.Status
import go.Seq
import com.hiddify.core.libbox.CommandServer
import com.hiddify.core.libbox.CommandServerHandler
import com.hiddify.core.libbox.Libbox
import com.hiddify.core.libbox.PlatformInterface
import com.hiddify.core.libbox.SystemProxyStatus
import com.hiddify.core.mobile.Mobile
import com.hiddify.core.mobile.SetupOptions as MobileSetupOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.io.File

class BoxService(
        private val service: Service,
        private val platformInterface: PlatformInterface
) : CommandServerHandler {

    companion object {
        private const val TAG = "A/BoxService"

        private var initializeOnce = false
        private lateinit var workingDir: File
        fun initialize(platformInterface: PlatformInterface) {
            if (initializeOnce) return
            val baseDir = Application.application.filesDir
            baseDir.mkdirs()
            workingDir = Application.application.getExternalFilesDir(null) ?: return
            workingDir.mkdirs()
            val tempDir = Application.application.cacheDir
            tempDir.mkdirs()
            Log.d(TAG, "base dir: ${baseDir.path}")
            Log.d(TAG, "working dir: ${workingDir.path}")
            Log.d(TAG, "temp dir: ${tempDir.path}")
            val opt = MobileSetupOptions()
            opt.setBasePath(baseDir.path)
            opt.setWorkingDir(workingDir.path)
            opt.setTempDir(tempDir.path)
            opt.setDebug(false)
            try {
                Mobile.setupPaths(opt.basePath, opt.workingDir, opt.tempDir, opt.debug)
            } catch (e: Exception) {
                Log.w(TAG, e)
                return
            }
            Libbox.redirectStderr(File(workingDir, "stderr.log").path)
            initializeOnce = true
        }

        fun parseConfig(path: String, tempPath: String, debug: Boolean): String {
            return try {
                Mobile.parse(path, tempPath, debug)
                ""
            } catch (e: Exception) {
                Log.w(TAG, e)
                e.message ?: "invalid config"
            }
        }

        private fun normalizeConfigInboundsAddress(content: String): String {
            if (!content.trimStart().startsWith("{")) return content
            return try {
                val json = org.json.JSONObject(content)
                if (json.has("inbounds")) {
                    val inbounds = json.getJSONArray("inbounds")
                    for (i in 0 until inbounds.length()) {
                        val obj = inbounds.getJSONObject(i)
                        if (obj.has("address")) {
                            obj.put("listen", obj.get("address"))
                            obj.remove("address")
                        }
                        obj.remove("route_exclude_address")
                    }
                }
                if (json.has("outbounds")) {
                    val outbounds = json.getJSONArray("outbounds")
                    for (i in 0 until outbounds.length()) {
                        val ob = outbounds.getJSONObject(i)
                        if (ob.optString("type") != "vless") continue
                        if (!ob.has("tls")) continue
                        val tls = ob.getJSONObject("tls")
                        if (!tls.has("reality")) continue
                        if (tls.has("utls")) continue
                        val utls = org.json.JSONObject()
                        utls.put("enabled", true)
                        utls.put("fingerprint", "chrome")
                        tls.put("utls", utls)
                    }
                }
                json.toString()
            } catch (_: Exception) {
                content
            }
        }

        fun buildConfig(path: String, options: String): String {
            return try {
                val raw = File(path).readText()
                val normalized = normalizeConfigInboundsAddress(raw)
                Libbox.formatConfig(normalized)
            } catch (e: Exception) {
                Log.w(TAG, e)
                throw e
            }
        }

        fun start() {
            val intent = runBlocking {
                withContext(Dispatchers.IO) {
                    Intent(Application.application, Settings.serviceClass())
                }
            }
            ContextCompat.startForegroundService(Application.application, intent)
        }

        fun stop() {
            Application.application.sendBroadcast(
                    Intent(Action.SERVICE_CLOSE).setPackage(
                            Application.application.packageName
                    )
            )
        }

        fun reload() {
            Application.application.sendBroadcast(
                    Intent(Action.SERVICE_RELOAD).setPackage(
                            Application.application.packageName
                    )
            )
        }
    }

    var fileDescriptor: ParcelFileDescriptor? = null

    private val status = MutableLiveData(Status.Stopped)
    private val binder = ServiceBinder(status)
    private val notification = ServiceNotification(status, service)
    private var commandServer: CommandServer? = null
    private var receiverRegistered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Action.SERVICE_CLOSE -> {
                    stopService()
                }

                Action.SERVICE_RELOAD -> {
                    serviceReload()
                }

                PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        serviceUpdateIdleMode()
                    }
                }
            }
        }
    }

    private fun startCommandServer() {
        val cmdServer = Libbox.newCommandServer(this, 300)
        cmdServer.start()
        this.commandServer = cmdServer
    }

    private var activeProfileName = ""
    private suspend fun startService(delayStart: Boolean = false) {
        try {
            Log.d(TAG, "starting service")
            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_starting)
            }

            val selectedConfigPath = Settings.activeConfigPath
            if (selectedConfigPath.isBlank()) {
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            activeProfileName = Settings.activeProfileName

            val configOptions = Settings.configOptions
            if (configOptions.isBlank()) {
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            val content = try {
                buildConfig(selectedConfigPath, configOptions)
            } catch (e: Exception) {
                Log.w(TAG, e)
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            if (Settings.debugMode) {
                File(workingDir, "current-config.json").writeText(content)
            }

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_starting)
                binder.broadcast {
                    it.onServiceResetLogs(listOf())
                }
            }

            DefaultNetworkMonitor.start()
            Libbox.setMemoryLimit(!Settings.disableMemoryLimit)

            if (delayStart) {
                delay(1000L)
            }

            try {
                Mobile.startService(content, platformInterface)
            } catch (e: Exception) {
                stopAndAlert(Alert.CreateService, e.message)
                return
            }
            status.postValue(Status.Started)

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_started)
            }
            notification.start()
        } catch (e: Exception) {
            stopAndAlert(Alert.StartService, e.message)
            return
        }
    }

    override fun serviceReload() {
        notification.close()
        status.postValue(Status.Starting)
        val pfd = fileDescriptor
        if (pfd != null) {
            pfd.close()
            fileDescriptor = null
        }
        try {
            Mobile.stop()
        } catch (e: Exception) {
            writeLog("service: error when closing: $e")
        }
        runBlocking {
            startService(true)
        }
    }

    override fun postServiceClose() {}

    private fun serviceStop() {
        stopService()
    }

    private fun writeDebugMessage(msg: String) {
        writeLog(msg)
    }

    override fun getSystemProxyStatus(): SystemProxyStatus {
        val status = SystemProxyStatus()
        if (service is VPNService) {
            status.available = service.systemProxyAvailable
            status.enabled = service.systemProxyEnabled
        }
        return status
    }

    override fun setSystemProxyEnabled(isEnabled: Boolean) {
        serviceReload()
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun serviceUpdateIdleMode() {}

    private fun stopService() {
        if (status.value != Status.Started) return
        status.value = Status.Stopping
        if (receiverRegistered) {
            service.unregisterReceiver(receiver)
            receiverRegistered = false
        }
        notification.close()
        GlobalScope.launch(Dispatchers.IO) {
            val pfd = fileDescriptor
            if (pfd != null) {
                pfd.close()
                fileDescriptor = null
            }
            try {
                Mobile.stop()
            } catch (e: Exception) {
                writeDebugMessage("service: error when closing: $e")
            }
            DefaultNetworkMonitor.stop()
            commandServer?.close()
            commandServer = null
            Settings.startedByUser = false
            withContext(Dispatchers.Main) {
                status.value = Status.Stopped
                service.stopSelf()
            }
        }
    }

    private suspend fun stopAndAlert(type: Alert, message: String? = null) {
        Settings.startedByUser = false
        withContext(Dispatchers.Main) {
            if (receiverRegistered) {
                service.unregisterReceiver(receiver)
                receiverRegistered = false
            }
            notification.close()
            binder.broadcast { callback ->
                callback.onServiceAlert(type.ordinal, message)
            }
            status.value = Status.Stopped
        }
    }

    fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (status.value != Status.Stopped) return Service.START_NOT_STICKY
        status.value = Status.Starting

        if (!receiverRegistered) {
            ContextCompat.registerReceiver(service, receiver, IntentFilter().apply {
                addAction(Action.SERVICE_CLOSE)
                addAction(Action.SERVICE_RELOAD)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
                }
            }, ContextCompat.RECEIVER_NOT_EXPORTED)
            receiverRegistered = true
        }

        GlobalScope.launch(Dispatchers.IO) {
            Settings.startedByUser = true
            initialize(platformInterface)
            try {
                startCommandServer()
            } catch (e: Exception) {
                stopAndAlert(Alert.StartCommandServer, e.message)
                return@launch
            }
            startService()
        }
        return Service.START_NOT_STICKY
    }

    fun onBind(intent: Intent): IBinder {
        return binder
    }

    fun onDestroy() {
        binder.close()
    }

    fun onRevoke() {
        stopService()
    }

    fun writeLog(message: String) {
        binder.broadcast {
            it.onServiceWriteLog(message)
        }
    }

}