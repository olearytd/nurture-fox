package com.toleary.babyclock

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object EncryptionManager {
    private const val KEY_ALIAS = "BabyClockDbWrapper"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val PREFS_NAME = "SecureStorage"
    private const val ENCRYPTED_PASS_KEY = "encrypted_db_pass"
    private const val IV_KEY = "encryption_iv"

    fun getDatabasePassphrase(context: Context): ByteArray {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val encryptedPassBase64 = prefs.getString(ENCRYPTED_PASS_KEY, null)
        val ivBase64 = prefs.getString(IV_KEY, null)

        return if (encryptedPassBase64 != null && ivBase64 != null) {
            // Decrypt the existing passphrase
            decrypt(Base64.decode(encryptedPassBase64, Base64.DEFAULT), Base64.decode(ivBase64, Base64.DEFAULT))
        } else {
            // Generate a new random 32-byte (256-bit) passphrase
            val newPassphrase = java.security.SecureRandom().generateSeed(32)
            val encryptionResult = encrypt(newPassphrase)

            prefs.edit()
                .putString(ENCRYPTED_PASS_KEY, Base64.encodeToString(encryptionResult.first, Base64.DEFAULT))
                .putString(IV_KEY, Base64.encodeToString(encryptionResult.second, Base64.DEFAULT))
                .apply()

            newPassphrase
        }
    }

    private fun getSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (!keyStore.containsAlias(KEY_ALIAS)) {
            val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
            keyGenerator.init(
                KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .build()
            )
            keyGenerator.generateKey()
        }
        return keyStore.getKey(KEY_ALIAS, null) as SecretKey
    }

    private fun encrypt(data: ByteArray): Pair<ByteArray, ByteArray> {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getSecretKey())
        return Pair(cipher.doFinal(data), cipher.iv)
    }

    private fun decrypt(data: ByteArray, iv: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, getSecretKey(), GCMParameterSpec(128, iv))
        return cipher.doFinal(data)
    }
}