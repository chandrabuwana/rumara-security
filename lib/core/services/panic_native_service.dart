import 'dart:io';
import 'package:flutter/services.dart';

class PanicNativeService {
  static const MethodChannel _channel =
      MethodChannel('com.rumarasecurity.app/panic');

  /// Stop the native PanicOverlayService (stops alarm sound and vibration)
  static Future<bool> stopPanicService() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('stopPanicService');
      return result ?? false;
    } catch (e) {
      print('⚠️ [PanicNativeService] Error stopping panic service: $e');
      return false;
    }
  }
}
