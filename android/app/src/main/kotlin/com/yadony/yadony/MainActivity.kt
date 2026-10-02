package com.yadony.yadony

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
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
     * Android peut détruire ou relancer l'activité en arrière-plan (HyperOS le
     * fait en changeant les ressources de thème au verrouillage). Avec le
     * moteur possédé par l'activité, Dart repartait de zéro et un appel audio
     * en cours mourait sans prévenir l'autre partie. Le moteur est donc mis en
     * cache et référencé par identifiant : c'est le seul mode où le fragment
     * Flutter respecte `shouldDestroyEngineWithHost` (un moteur fourni par
     * `provideFlutterEngine` était quand même détruit, et l'écran relancé
     * plantait : « FlutterJNI is not attached to native »).
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        ensureEngine(this)
        liveInstances++
        super.onCreate(savedInstanceState)
    }

    override fun getCachedEngineId(): String = ENGINE_ID

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onDestroy() {
        super.onDestroy()
        liveInstances--
        // Sortie réelle de l'app (dernière instance) sans appel en cours : on
        // libère le moteur, comme avant. Pendant un appel (service d'appel
        // actif), il reste vivant pour que l'appel continue.
        if (liveInstances == 0 && isFinishing && !isChangingConfigurations &&
            !isCallServiceRunning()
        ) {
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

    companion object {
        private const val CHANNEL = "com.yadony.yadony/permissions"
        private const val CAMERA_REQUEST_CODE = 4711
        const val ENGINE_ID = "yadony_main"

        /** Instances de MainActivity vivantes : le moteur partagé n'est libéré qu'à la dernière. */
        var liveInstances = 0

        /** Crée et démarre le moteur partagé s'il n'existe pas encore. */
        fun ensureEngine(context: Context) {
            val cache = FlutterEngineCache.getInstance()
            if (cache.contains(ENGINE_ID)) return
            val engine = FlutterEngine(context.applicationContext)
            // Moteur en cache : le fragment ne lance pas Dart lui-même.
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            cache.put(ENGINE_ID, engine)
        }
    }
}
