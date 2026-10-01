import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Lanceur d'URL de test : enregistre chaque ouverture et son mode, rend
/// [result] (ou lève si [throws]).
final class RecordingUrlLauncher extends UrlLauncherPlatform {
  RecordingUrlLauncher({this.result = true, this.throws = false});

  bool result;
  final bool throws;
  final urls = <String>[];
  final modes = <PreferredLaunchMode>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => result;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (throws) {
      throw Exception('launch failed');
    }
    urls.add(url);
    modes.add(options.mode);
    return result;
  }
}

/// Installe [launcher] comme lanceur de la plateforme le temps du test.
void installUrlLauncher(
  RecordingUrlLauncher launcher,
  void Function(void Function()) addTearDown,
) {
  final previous = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = previous);
}
