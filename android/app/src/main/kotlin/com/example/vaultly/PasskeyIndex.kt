package com.example.vaultly

/**
 * Passkey *metadata* (no private keys) for the system account picker. It only
 * lives in memory and is filled by the Dart side while the vault is unlocked;
 * it is cleared when the vault locks or the process dies.
 */
object PasskeyIndex {
    data class Entry(
        val itemId: String,
        val rpId: String,
        val userName: String,
        val displayName: String,
        val credentialId: String,
        val lastUsed: Long?,
    )

    @Volatile var unlocked: Boolean = false
        private set

    @Volatile var entries: List<Entry> = emptyList()
        private set

    fun update(data: Map<String, Any?>) {
        unlocked = data["unlocked"] as? Boolean ?: false
        @Suppress("UNCHECKED_CAST")
        val items = data["items"] as? List<Map<String, Any?>> ?: emptyList()
        entries = if (!unlocked) emptyList() else items.map {
            Entry(
                itemId = it["itemId"] as String,
                rpId = it["rpId"] as String,
                userName = it["userName"] as? String ?: "",
                displayName = it["displayName"] as? String ?: "",
                credentialId = it["credentialId"] as String,
                lastUsed = (it["lastUsed"] as? Number)?.toLong(),
            )
        }
    }

    fun matching(rpId: String, allowCredentialIds: Set<String>): List<Entry> =
        entries.filter {
            it.rpId == rpId && (allowCredentialIds.isEmpty() || it.credentialId in allowCredentialIds)
        }
}
