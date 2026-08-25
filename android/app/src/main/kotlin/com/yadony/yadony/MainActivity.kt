package com.yadony.yadony

import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Pont de permission caméra pour les WebView.
 *
 * La page Stripe Identity réclame la caméra au niveau web, et
 * `webview_flutter_android` se contente de relayer `PermissionRequest.grant()`
 * sans jamais demander la permission Android correspondante : son code ne
 * contient ni `checkSelfPermission` ni `requestPermissions`. Sans ce pont, le
 * bouton « Accorder l'accès » de Stripe reste sans effet — la page se croit
 * autorisée, le système refuse, et la vérification d'identité s'arrête là.
 *
 * Android seulement : sur iOS, WKWebView demande lui-même l'autorisation à
 * partir de `NSCameraUsageDescription`.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingCameraResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestCamera" -> requestCamera(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestCamera(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        // Une seule demande à la fois. Un second appel pendant que la boîte de
        // dialogue système est ouverte perdrait sa réponse, et le canal
        // resterait avec deux `Result` pour un seul retour.
        if (pendingCameraResult != null) {
            result.success(false)
            return
        }
        pendingCameraResult = result
        requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_REQUEST_CODE) return
        val result = pendingCameraResult ?: return
        pendingCameraResult = null
        result.success(
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
    }

    private companion object {
        const val CHANNEL = "com.yadony.yadony/permissions"
        const val CAMERA_REQUEST_CODE = 4711
    }
}
