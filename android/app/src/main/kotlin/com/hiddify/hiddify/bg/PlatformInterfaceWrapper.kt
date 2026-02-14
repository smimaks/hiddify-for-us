package com.hiddify.hiddify.bg

import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import androidx.annotation.RequiresApi
import com.hiddify.hiddify.Application
import com.hiddify.core.libbox.InterfaceUpdateListener
import com.hiddify.core.libbox.NetworkInterfaceIterator
import com.hiddify.core.libbox.PlatformInterface
import com.hiddify.core.libbox.StringIterator
import com.hiddify.core.libbox.TunOptions
import com.hiddify.core.libbox.WIFIState
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.net.InterfaceAddress
import java.net.NetworkInterface
import java.util.Enumeration
import com.hiddify.core.libbox.NetworkInterface as LibboxNetworkInterface

interface PlatformInterfaceWrapper : PlatformInterface {

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {}

    override fun openTun(options: TunOptions): Int = error("invalid argument")

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int
    ): Int {
        val uid = Application.connectivity.getConnectionOwnerUid(
            ipProtocol,
            InetSocketAddress(sourceAddress, sourcePort),
            InetSocketAddress(destinationAddress, destinationPort)
        )
        if (uid == Process.INVALID_UID) error("android: connection owner not found")
        return uid
    }

    override fun packageNameByUid(uid: Int): String {
        val packages = Application.packageManager.getPackagesForUid(uid)
        return packages?.firstOrNull() ?: ""
    }

    override fun uidByPackageName(packageName: String): Int {
        return try {
            Application.packageManager.getPackageUid(packageName, 0)
        } catch (e: PackageManager.NameNotFoundException) {
            -1
        }
    }

    override fun usePlatformDefaultInterfaceMonitor(): Boolean = true

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        DefaultNetworkMonitor.setListener(listener)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        DefaultNetworkMonitor.setListener(null)
    }

    override fun usePlatformInterfaceGetter(): Boolean = true

    override fun getInterfaces(): NetworkInterfaceIterator {
        return InterfaceArray(NetworkInterface.getNetworkInterfaces())
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun clearDNSCache() {}

    override fun readWIFIState(): WIFIState? = null

    private class InterfaceArray(private val iterator: Enumeration<NetworkInterface>) :
        NetworkInterfaceIterator {

        override fun hasNext(): Boolean {
            return iterator.hasMoreElements()
        }

        override fun next(): LibboxNetworkInterface? {
            val element = iterator.nextElement()
            return LibboxNetworkInterface().apply {
                name = element.name
                index = element.index
                runCatching {
                    mtu = element.mtu
                }
                addresses = StringArray(element.interfaceAddresses.map { it.toPrefix() })
            }
        }

        private fun InterfaceAddress.toPrefix(): String {
            return if (address is Inet6Address) {
                "${Inet6Address.getByAddress(address.address).hostAddress}/${networkPrefixLength}"
            } else {
                "${address.hostAddress}/${networkPrefixLength}"
            }
        }
    }

    private class StringArray(private val list: List<String>) : StringIterator {
        private val iterator = list.iterator()
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): String = iterator.next()
    }

}