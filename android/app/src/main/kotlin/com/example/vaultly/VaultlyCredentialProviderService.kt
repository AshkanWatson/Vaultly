package com.example.vaultly

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.CancellationSignal
import android.os.OutcomeReceiver
import androidx.annotation.RequiresApi
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.CreateCredentialUnsupportedException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.provider.AuthenticationAction
import androidx.credentials.provider.BeginCreateCredentialRequest
import androidx.credentials.provider.BeginCreateCredentialResponse
import androidx.credentials.provider.BeginCreatePublicKeyCredentialRequest
import androidx.credentials.provider.BeginGetCredentialRequest
import androidx.credentials.provider.BeginGetCredentialResponse
import androidx.credentials.provider.BeginGetPublicKeyCredentialOption
import androidx.credentials.provider.CreateEntry
import androidx.credentials.provider.CredentialEntry
import androidx.credentials.provider.CredentialProviderService
import androidx.credentials.provider.ProviderClearCredentialStateRequest
import androidx.credentials.provider.PublicKeyCredentialEntry
import org.json.JSONObject
import java.time.Instant
import java.util.concurrent.atomic.AtomicInteger

/**
 * Android 14+ Credential Manager provider: lets apps and browsers create and
 * use passkeys stored in Vaultly. This service only lists entries; the actual
 * WebAuthn work happens in Dart (lib/core/passkey) inside [PasskeyActivity]
 * after the user unlocks the vault.
 */
@RequiresApi(34)
class VaultlyCredentialProviderService : CredentialProviderService() {

    override fun onBeginCreateCredentialRequest(
        request: BeginCreateCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginCreateCredentialResponse, CreateCredentialException>,
    ) {
        if (request !is BeginCreatePublicKeyCredentialRequest) {
            callback.onError(CreateCredentialUnsupportedException("Vaultly only stores passkeys here"))
            return
        }
        val entry = CreateEntry.Builder(
            "Vaultly",
            PasskeyActivity.pendingIntent(this, PasskeyActivity.ACTION_CREATE, null),
        ).setDescription("Save the passkey in your offline vault").build()
        callback.onResult(BeginCreateCredentialResponse.Builder().addCreateEntry(entry).build())
    }

    override fun onBeginGetCredentialRequest(
        request: BeginGetCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginGetCredentialResponse, GetCredentialException>,
    ) {
        val options = request.beginGetCredentialOptions
            .filterIsInstance<BeginGetPublicKeyCredentialOption>()
        if (options.isEmpty()) {
            callback.onResult(BeginGetCredentialResponse.Builder().build())
            return
        }
        if (!PasskeyIndex.unlocked) {
            val action = AuthenticationAction(
                "Unlock Vaultly",
                PasskeyActivity.pendingIntent(this, PasskeyActivity.ACTION_UNLOCK, null),
            )
            callback.onResult(
                BeginGetCredentialResponse.Builder().addAuthenticationAction(action).build(),
            )
            return
        }
        callback.onResult(
            BeginGetCredentialResponse.Builder()
                .setCredentialEntries(credentialEntries(this, options))
                .build(),
        )
    }

    override fun onClearCredentialStateRequest(
        request: ProviderClearCredentialStateRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<Void?, ClearCredentialException>,
    ) {
        callback.onResult(null)
    }

    companion object {
        private val requestCodes = AtomicInteger(1000)

        fun nextRequestCode(): Int = requestCodes.incrementAndGet()

        /** One entry per stored passkey matching each option's rpId / allow list. */
        fun credentialEntries(
            context: Context,
            options: List<BeginGetPublicKeyCredentialOption>,
        ): List<CredentialEntry> = options.flatMap { option ->
            val json = JSONObject(option.requestJson)
            val rpId = json.optString("rpId")
            val allow = mutableSetOf<String>()
            json.optJSONArray("allowCredentials")?.let { arr ->
                for (i in 0 until arr.length()) allow.add(arr.getJSONObject(i).optString("id"))
            }
            PasskeyIndex.matching(rpId, allow).map { e ->
                val builder = PublicKeyCredentialEntry.Builder(
                    context,
                    e.userName.ifEmpty { e.displayName },
                    PasskeyActivity.pendingIntent(context, PasskeyActivity.ACTION_GET, e.itemId),
                    option,
                ).setDisplayName(e.displayName)
                e.lastUsed?.let { builder.setLastUsedTime(Instant.ofEpochMilli(it)) }
                builder.build()
            }
        }
    }
}

internal fun pendingIntentFlags(): Int =
    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT

internal fun Intent.withItem(itemId: String?): Intent {
    if (itemId != null) putExtra(PasskeyActivity.EXTRA_ITEM_ID, itemId)
    return this
}
