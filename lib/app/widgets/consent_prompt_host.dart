import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/consent_prompt.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/presentation/widgets/analytics_consent_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Ouvre la feuille de consentement quand [ConsentPrompt] la demande et que
/// l'écran qui l'héberge est au premier plan : jamais pour un visiteur, jamais
/// par-dessus une autre feuille, au plus une fois par lancement de l'app.
class ConsentPromptHost extends StatefulWidget {
  const ConsentPromptHost({required this.child, super.key});

  final Widget child;

  static bool _shownThisLaunch = false;

  @visibleForTesting
  static void resetForTest() => _shownThisLaunch = false;

  @override
  State<ConsentPromptHost> createState() => _ConsentPromptHostState();
}

class _ConsentPromptHostState extends State<ConsentPromptHost> {
  late final ValueListenable<bool> _wanted;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _wanted = getIt<ConsentPrompt>().wanted..addListener(_maybeShow);
    _maybeShow();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // S'abonne à la route : relance l'essai quand l'écran redevient courant.
    ModalRoute.of(context);
    _maybeShow();
  }

  @override
  void dispose() {
    _wanted.removeListener(_maybeShow);
    super.dispose();
  }

  void _maybeShow() {
    if (_scheduled || ConsentPromptHost._shownThisLaunch || !_wanted.value) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          ConsentPromptHost._shownThisLaunch ||
          !_wanted.value ||
          !getIt<FirebaseSessionProbe>().hasRealSession) {
        return;
      }
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ConsentPromptHost._shownThisLaunch = true;
      AnalyticsConsentSheet.show(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
