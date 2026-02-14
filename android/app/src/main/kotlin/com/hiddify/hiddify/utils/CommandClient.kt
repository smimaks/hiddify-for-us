package com.hiddify.hiddify.utils

import go.Seq
import com.hiddify.core.libbox.CommandClient
import com.hiddify.core.libbox.CommandClientHandler
import com.hiddify.core.libbox.CommandClientOptions
import com.hiddify.core.libbox.Libbox
import com.hiddify.core.libbox.OutboundGroup
import com.hiddify.core.libbox.OutboundGroupIterator
import com.hiddify.core.libbox.StatusMessage
import com.hiddify.core.libbox.StringIterator
import com.hiddify.hiddify.ktx.toList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

open class CommandClient(
    private val scope: CoroutineScope,
    private val connectionType: ConnectionType,
    private val handler: Handler
) {

    enum class ConnectionType {
        Status, Groups, Log, ClashMode, GroupOnly
    }

    interface Handler {

        fun onConnected() {}
        fun onDisconnected() {}
        fun updateStatus(status: StatusMessage) {}
        fun updateGroups(groups: List<OutboundGroup>) {}
        fun clearLog() {}
        fun appendLog(message: String) {}
        fun initializeClashMode(modeList: List<String>, currentMode: String) {}
        fun updateClashMode(newMode: String) {}

    }


    private var commandClient: com.hiddify.core.libbox.CommandClient? = null
    private val clientHandler = ClientHandler()
    fun connect() {
        disconnect()
        val options = CommandClientOptions()
        when (connectionType) {
            ConnectionType.Status -> options.command = Libbox.CommandStatus
            ConnectionType.Groups -> options.command = Libbox.CommandGroup
            ConnectionType.Log -> options.command = Libbox.CommandLog
            ConnectionType.ClashMode -> options.command = Libbox.CommandClashMode
            ConnectionType.GroupOnly -> options.command = Libbox.CommandGroup
        }
        options.statusInterval = 2 * 1000 * 1000 * 1000L
        val commandClient = Libbox.newCommandClient(clientHandler, options)
        scope.launch(Dispatchers.IO) {
            for (i in 1..10) {
                delay(100 + i.toLong() * 50)
                try {
                    commandClient.connect()
                } catch (ignored: Exception) {
                    continue
                }
                if (!isActive) {
                    runCatching {
                        commandClient.disconnect()
                    }
                    return@launch
                }
                this@CommandClient.commandClient = commandClient
                return@launch
            }
            runCatching {
                commandClient.disconnect()
            }
        }
    }

    fun disconnect() {
        commandClient?.apply {
            runCatching { disconnect() }
            Seq.destroyRef(refnum)
        }
        commandClient = null
    }

    private inner class ClientHandler : CommandClientHandler {

        override fun connected() {
            handler.onConnected()
        }

        override fun disconnected(message: String?) {
            handler.onDisconnected()
        }

        override fun writeGroups(message: OutboundGroupIterator?) {
            if (message == null) {
                return
            }
            val groups = mutableListOf<OutboundGroup>()
            while (message.hasNext()) {
                message.next()?.let { groups.add(it) }
            }
            handler.updateGroups(groups)
        }

        override fun clearLog() {
            handler.clearLog()
        }

        override fun writeLog(message: String?) {
            if (message != null) handler.appendLog(message)
        }

        override fun writeStatus(message: StatusMessage?) {
            if (message == null) {
                return
            }
            handler.updateStatus(message)
        }

        override fun initializeClashMode(modeList: StringIterator?, currentMode: String?) {
            handler.initializeClashMode(modeList?.toList() ?: emptyList(), currentMode ?: "")
        }

        override fun updateClashMode(newMode: String?) {
            handler.updateClashMode(newMode ?: "")
        }

    }

}