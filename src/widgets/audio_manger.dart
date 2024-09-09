import 'package:flutter/services.dart';

class AudioManager {
  static const MethodChannel _channel = MethodChannel('com.github.cloudwebrtc.dart_sip_ua_example/audio');

  static Future<void> setSpeakerphoneOn(bool on) async {
    try {
      await _channel.invokeMethod('setSpeakerphoneOn', {'on': on});
    } on PlatformException catch (e) {
      print("Failed to set speakerphone: '${e.message}'.");
    }
  }
}
