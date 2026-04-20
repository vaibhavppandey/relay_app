import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'relay_app',
    dartOut: 'lib/pigeons/generated/media_saver.g.dart',
    swiftOut: 'ios/Runner/MediaSaver.g.swift',
    kotlinOut: 'android/app/src/main/kotlin/com/vaibhavp/relay/MediaSaver.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.vaibhavp.relay'),
  ),
)
@HostApi()
abstract class MediaSaverApi {
  @async
  bool saveFile(String path, String name, String mime);

  @async
  void shareFile(String path, String mime);

  @async
  List<String> pickFiles(bool allowMultiple);
}
