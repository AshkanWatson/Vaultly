package com.example.vaultly

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.view.WindowManager
import androidx.annotation.RequiresApi
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.provider.BeginGetCredentialRequest
import androidx.credentials.provider.BeginGetCredentialResponse
import androidx.credentials.provider.BeginGetPublicKeyCredentialOption
import androidx.credentials.provider.CallingAppInfo
import androidx.credentials.provider.PendingIntentHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import java.security.MessageDigest

/**
 * Opened by the system (via [VaultlyCredentialProviderService]) to create or
 * use a passkey. It runs the normal Flutter app, which shows the lock screen
 * and then a confirmation screen, and hands the WebAuthn response back here.
 */
class PasskeyActivity : FlutterFragmentActivity(), PasskeyRequestHandler {

    private var request: Map<String, Any?>? = null
    private var beginGetRequest: BeginGetCredentialRequest? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        if (Build.VERSION.SDK_INT >= 34) request = parse(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeChannel.register(this, flutterEngine, this)
    }

    override fun describe(): Map<String, Any?>? = request

    @RequiresApi(34)
    private fun parse(intent: Intent): Map<String, Any?>? = when (intent.action) {
        ACTION_CREATE -> {
            val r = PendingIntentHandler.retrieveProviderCreateCredentialRequest(intent)
            val call = r?.callingRequest as? CreatePublicKeyCredentialRequest
            if (r == null || call == null) null else mapOf(
                "type" to "create",
                "requestJson" to call.requestJson,
                "origin" to appOrigin(r.callingAppInfo),
                "packageName" to r.callingAppInfo.packageName,
                "clientDataHash" to call.clientDataHash?.let(::b64url),
            )
        }
        ACTION_GET -> {
            val r = PendingIntentHandler.retrieveProviderGetCredentialRequest(intent)
            val option = r?.credentialOptions
                ?.filterIsInstance<GetPublicKeyCredentialOption>()?.firstOrNull()
            if (r == null || option == null) null else mapOf(
                "type" to "get",
                "requestJson" to option.requestJson,
                "origin" to appOrigin(r.callingAppInfo),
                "packageName" to r.callingAppInfo.packageName,
                "clientDataHash" to option.clientDataHash?.let(::b64url),
                "itemId" to intent.getStringExtra(EXTRA_ITEM_ID),
            )
        }
        ACTION_UNLOCK -> {
            beginGetRequest = PendingIntentHandler.retrieveBeginGetCredentialRequest(intent)
            mapOf("type" to "unlock", "requestJson" to "{}", "origin" to "")
        }
        else -> null
    }

    override fun complete(responseJson: String) {
        if (Build.VERSION.SDK_INT < 34) return finish()
        val result = Intent()
        when (request?.get("type")) {
            "create" -> PendingIntentHandler.setCreateCredentialResponse(
                result, CreatePublicKeyCredentialResponse(responseJson),
            )
            "get" -> PendingIntentHandler.setGetCredentialResponse(
                result, GetCredentialResponse(PublicKeyCredential(responseJson)),
            )
        }
        setResult(RESULT_OK, result)
        finish()
    }

    /** The vault is open: return the passkey list for the original request. */
    override fun unlocked() {
        if (Build.VERSION.SDK_INT < 34) return finish()
        val options = beginGetRequest?.beginGetCredentialOptions
            ?.filterIsInstance<BeginGetPublicKeyCredentialOption>() ?: emptyList()
        val response = BeginGetCredentialResponse.Builder()
            .setCredentialEntries(
                VaultlyCredentialProviderService.credentialEntries(this, options),
            )
            .build()
        val result = Intent()
        PendingIntentHandler.setBeginGetCredentialResponse(result, response)
        setResult(RESULT_OK, result)
        finish()
    }

    override fun cancel(message: String?) {
        if (Build.VERSION.SDK_INT >= 34) {
            val result = Intent()
            when (request?.get("type")) {
                "create" -> PendingIntentHandler.setCreateCredentialException(
                    result, CreateCredentialCancellationException(message),
                )
                "get" -> PendingIntentHandler.setGetCredentialException(
                    result, GetCredentialCancellationException(message),
                )
            }
            setResult(RESULT_CANCELED, result)
        } else {
            setResult(RESULT_CANCELED)
        }
        finish()
    }

    companion object {
        const val ACTION_CREATE = "app.vaultly.passkey.CREATE"
        const val ACTION_GET = "app.vaultly.passkey.GET"
        const val ACTION_UNLOCK = "app.vaultly.passkey.UNLOCK"
        const val EXTRA_ITEM_ID = "app.vaultly.passkey.ITEM_ID"

        fun pendingIntent(context: Context, action: String, itemId: String?): PendingIntent {
            val intent = Intent(context, PasskeyActivity::class.java)
                .setAction(action)
                .setPackage(context.packageName)
                .withItem(itemId)
            return PendingIntent.getActivity(
                context,
                VaultlyCredentialProviderService.nextRequestCode(),
                intent,
                pendingIntentFlags(),
            )
        }

        private fun b64url(bytes: ByteArray): String =
            Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

        /**
         * WebAuthn origin of a native Android caller. Browsers pass their own
         * clientDataHash (and replace clientDataJSON), so for them this value
         * is not used in the signature.
         */
        @RequiresApi(34)
        private fun appOrigin(info: CallingAppInfo): String {
            val signers = info.signingInfo.apkContentsSigners
            if (signers.isEmpty()) return ""
            val digest = MessageDigest.getInstance("SHA-256").digest(signers[0].toByteArray())
            return "android:apk-key-hash:${b64url(digest)}"
        }
    }
}
