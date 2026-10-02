package com.yadony.yadony

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
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

    /**
     * Moteur Flutter partagé entre les instances de l'activité.
     *
     * Android peut détruire l'activité en arrière-plan (HyperOS le fait quand
     * il change les ressources de thème au verrouillage). Avec le moteur
     * possédé par l'activité, Dart repartait de zéro et un appel audio en
     * cours mourait sans prévenir l'autre partie (resté « en appel », puis
     * appel manqué). Le moteur fourni ici survit à l'activité et la nouvelle
     * instance s'y rattache : l'appel continue.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        return cache.get(ENGINE_ID) ?: FlutterEngine(context.applicationContext)
            .also { cache.put(ENGINE_ID, it) }
    }

    // Sans ça, le fragment Flutter détruit lui-même le moteur partagé à
    // chaque relance de l'activité (changement de thème HyperOS au
    // déverrouillage) : l'appel tombait et l'écran relancé plantait
    // (« FlutterJNI is not attached to native »). La libération est faite
    // à la main dans onDestroy, seulement à la vraie sortie de l'app.
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onDestroy() {
        super.onDestroy()
        // Sortie réelle de l'app sans appel en cours : on libère le moteur,
        // comme avant. Pendant un appel (service d'appel actif), il reste
        // vivant pour que l'appel continue.
        if (isFinishing && !isChangingConfigurations && !isCallServiceRunning()) {
            FlutterEngineCache.getInstance().get(ENGINE_ID)?.destroy()
            FlutterEngineCache.getInstance().remove(ENGINE_ID)
        }
    }

    @Suppress("DEPRECATION") // getRunningServices reste valable pour ses propres services.
    private fun isCallServiceRunning(): Boolean {
        val manager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        return manager.getRunningServices(Int.MAX_VALUE).any {
            it.service.packageName == packageName &&
                it.service.className.endsWith("StreamCallService")
        }
    }

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
        const val ENGINE_ID = "yadony_main"
    }
}
