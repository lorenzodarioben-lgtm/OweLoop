package com.oweloop.oweloop

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig
import com.it_nomads.fluttersecurestorage.NamespacedConfigSource
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val storageExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oweloop/secure_storage")
            .setMethodCallHandler { call, result ->
                if (call.method != "flush") {
                    result.notImplemented()
                } else {
                    storageExecutor.execute {
                        try {
                            // Public configuration APIs from the locked plugin keep
                            // data/config/wrapped-key namespaces aligned. Empty
                            // commits wait for outstanding apply() disk writes.
                            val config = FlutterSecureStorageConfig(emptyMap<String, Any>())
                            val context = applicationContext
                            val keys = context.getSharedPreferences(config.effectiveKeyStoragePrefsName, MODE_PRIVATE).edit().commit()
                            val algorithms = NamespacedConfigSource(context, config.effectiveDataPrefsName).edit().commit()
                            val data = context.getSharedPreferences(config.effectiveDataPrefsName, MODE_PRIVATE).edit().commit()
                            runOnUiThread { result.success(keys && algorithms && data) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("secure_storage_flush", "Secure storage persistence was not confirmed.", null) }
                        }
                    }
                }
            }
    }

    override fun onDestroy() {
        storageExecutor.shutdown()
        super.onDestroy()
    }
}
