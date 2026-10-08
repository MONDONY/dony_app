package com.yadony.yadony

import com.flutter.stripe.StripeAndroidPlugin
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

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        // Stripe vient de recréer son module (sans clé) : Dart doit la renvoyer.
        if (attachedOnce) notifyDart()
        attachedOnce = true
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        // Stripe ignore ce rappel : on rejoue son attache complète pour qu'il
        // reconstruise son module autour de la nouvelle activité.
        (engine.plugins.get(StripeAndroidPlugin::class.java) as? ActivityAware)
            ?.onAttachedToActivity(binding)
        attachedOnce = true
        notifyDart()
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onDetachedFromActivity() {}

    private fun notifyDart() {
        channel?.invokeMethod(METHOD_REATTACHED, null)
    }

    companion object {
        const val CHANNEL = "com.yadony.yadony/activity"
        const val METHOD_REATTACHED = "activityReattached"
    }
}
