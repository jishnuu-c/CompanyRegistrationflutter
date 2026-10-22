package com.example.company_reg_flutter

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val BIOMETRIC_CHANNEL = "com.example.company_reg_flutter/biometric_detect"

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BIOMETRIC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBiometricHardwareInfo" -> {
                    try {
                        val pm = packageManager
                        val hasFingerprintFeature = pm.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
                        
                        var isFingerprintHardwareDetected = false
                        var hasEnrolledFingerprints = false

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            @Suppress("DEPRECATION")
                            val fpManager = getSystemService(Context.FINGERPRINT_SERVICE) as? FingerprintManager
                            if (fpManager != null) {
                                isFingerprintHardwareDetected = fpManager.isHardwareDetected
                                hasEnrolledFingerprints = fpManager.hasEnrolledFingerprints()
                            }
                        }

                        val hasFaceFeature = pm.hasSystemFeature("android.hardware.biometrics.face") ||
                                             pm.hasSystemFeature("android.hardware.face")

                        val info = mapOf(
                            "hasFingerprintFeature" to hasFingerprintFeature,
                            "isFingerprintHardwareDetected" to isFingerprintHardwareDetected,
                            "hasEnrolledFingerprints" to hasEnrolledFingerprints,
                            "hasFaceFeature" to hasFaceFeature
                        )
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("BIOMETRIC_CHECK_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}