package com.example.vaultly

import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PersistableBundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Implemented by [PasskeyActivity] when Vaultly was opened for a passkey request. */
interface PasskeyRequestHandler {
    fun describe(): Map<String, Any?>?
    fun complete(responseJson: String)
    fun unlocked()
    fun cancel(message: String?)
}

/** The `app.vaultly/native` channel used by lib/data/native_bridge.dart. */
object NativeChannel {
    private const val NAME = "app.vaultly/native"

    fun register(activity: Activity, engine: FlutterEngine, handler: PasskeyRequestHandler?) {
        MethodChannel(engine.dartExecutor.binaryMessenger, NAME).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "copySensitive" -> {
                        copySensitive(activity, call.arguments as String)
                        result.success(true)
                    }
                    "clearClipboard" -> {
                        clearClipboard(activity)
                        result.success(true)
                    }
                    "passkey.pendingRequest" -> result.success(handler?.describe())
                    "passkey.updateIndex" -> {
                        @Suppress("UNCHECKED_CAST")
                        PasskeyIndex.update(call.arguments as Map<String, Any?>)
                        result.success(null)
                    }
                    "passkey.complete" -> {
                        handler?.complete(call.arguments as String)
                        result.success(null)
                    }
                    "passkey.unlocked" -> {
                        handler?.unlocked()
                        result.success(null)
                    }
                    "passkey.cancel" -> {
                        handler?.cancel(call.arguments as String?)
                        result.success(null)
                    }
                    "passkey.openSettings" -> result.success(openProviderSettings(activity))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native_error", e.message, null)
            }
        }
    }

    /** Marks the clip as sensitive so Android 13+ hides it from previews and keyboards. */
    private fun copySensitive(activity: Activity, text: String) {
        val cm = activity.getSystemService(ClipboardManager::class.java) ?: return
        val clip = ClipData.newPlainText("Vaultly", text)
        clip.description.extras = PersistableBundle().apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            } else {
                putBoolean("android.content.extra.IS_SENSITIVE", true)
            }
        }
        cm.setPrimaryClip(clip)
    }

    private fun clearClipboard(activity: Activity) {
        val cm = activity.getSystemService(ClipboardManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            cm.clearPrimaryClip()
        } else {
            cm.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    /** Opens "Passwords, passkeys & accounts" so the user can enable Vaultly. */
    private fun openProviderSettings(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < 34) return false
        return try {
            val intent = Intent("android.settings.CREDENTIAL_PROVIDER")
                .setData(Uri.parse("package:${activity.packageName}"))
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
