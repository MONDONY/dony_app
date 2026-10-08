package com.yadony.yadony

import android.app.Application
import android.util.Log
import com.flutter.stripe.StripeAndroidPlugin
import com.reactnativestripesdk.StripeSdkModule
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

/**
 * Rattache Stripe à l'activité recréée quand le moteur Flutter lui survit
 * (FLUTTER-CJ, G5, G6, G7).
 *
 * Depuis que [MainActivity] garde son moteur en cache (appels audio), une
 * activité recréée par le système (HyperOS change les ressources de thème au
 * verrouillage, ou « Ne pas conserver les activités ») réutilise le moteur.
 * `stripe_android` 12.x ne construit son module natif que dans
 * `onAttachedToActivity` et ignore `onReattachedToActivityForConfigChanges` :
 * il garde l'activité détruite, et `initPaymentSheet` échoue aussitôt sur
 * « FragmentManager has been destroyed ». Sur le chemin de détachement
 * complet, il recrée bien son module, mais sans clé publique.
 *
 * Ce plugin comble les deux cas : à un rattachement pour changement de
 * configuration, il refait l'attache de Stripe avec la nouvelle activité ; à
 * tout rattachement qui n'est pas le premier, il prévient Dart, qui relance
 * `Stripe.instance.applySettings()` (lib/core/services/stripe_reattach_listener.dart)
 * pour transmettre la clé au nouveau module.
 */
class StripeActivityReattachPlugin(private val engine: FlutterEngine) :
    FlutterPlugin,
    ActivityAware {
    private var channel: MethodChannel? = null
    private var attachedOnce = false

    /** Module Stripe de l'activité qui vient de se détacher, à libérer au rattachement. */
    private var staleModule: StripeSdkModule? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        // Stripe vient de recréer son module (sans clé) : Dart doit la renvoyer.
        if (attachedOnce) {
            releaseStaleModule(binding)
            notifyDart()
        }
        attachedOnce = true
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        // Stripe ignore ce rappel : on rejoue son attache complète pour qu'il
        // reconstruise son module autour de la nouvelle activité.
        (engine.plugins.get(StripeAndroidPlugin::class.java) as? ActivityAware)
            ?.onAttachedToActivity(binding)
        releaseStaleModule(binding)
        attachedOnce = true
        notifyDart()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        staleModule = currentStripeModule()
    }

    override fun onDetachedFromActivity() {
        staleModule = currentStripeModule()
    }

    private fun currentStripeModule(): StripeSdkModule? = try {
        engine.plugins.get(StripeAndroidPlugin::class.java)
            ?.let { (it as StripeAndroidPlugin).stripeSdk }
    } catch (_: Throwable) {
        null // module jamais créé (lateinit) : rien à libérer
    }

    /**
     * Désenregistre le rappel de cycle de vie que l'ancien module a posé sur
     * l'Application (`preventActivityRecreation`, dans `initialise`). Sans
     * cela, chaque recréation laissait un module, et par lui l'activité
     * détruite, référencé par l'Application.
     *
     * `stripe_android` 12.1.0 n'expose aucune API de libération : le champ
     * privé est lu par réflexion. En cas d'échec (champ renommé dans une
     * autre version), on journalise et on laisse la fuite, sans autre effet.
     * Désenregistrer un rappel jamais enregistré est sans effet.
     */
    private fun releaseStaleModule(binding: ActivityPluginBinding) {
        val stale = staleModule ?: return
        staleModule = null
        if (stale === currentStripeModule()) return // toujours le module actif
        try {
            val field = StripeSdkModule::class.java.getDeclaredField(LIFECYCLE_FIELD)
            field.isAccessible = true
            val callbacks = field.get(stale) as? Application.ActivityLifecycleCallbacks ?: return
            binding.activity.application.unregisterActivityLifecycleCallbacks(callbacks)
        } catch (error: Throwable) {
            Log.w(TAG, "Ancien module Stripe non libéré", error)
        }
    }

    private fun notifyDart() {
        channel?.invokeMethod(METHOD_REATTACHED, null)
    }

    companion object {
        const val CHANNEL = "com.yadony.yadony/activity"
        const val METHOD_REATTACHED = "activityReattached"
        private const val LIFECYCLE_FIELD = "activityLifecycleCallbacks"
        private const val TAG = "StripeReattach"
    }
}
