import 'package:flutter/services.dart';

class ArCoreBridge {
  static const platform = MethodChannel('com.example.ar_app/ar_core');

  Future<bool> isCloudAnchorSupported() async {
    try {
      final bool result = await platform.invokeMethod('isCloudAnchorSupported');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get support status: '${e.message}'.");
      return false;
    }
  }

  // Future methods: hostCloudAnchor, resolveCloudAnchor, etc.
  Future<String?> hostCloudAnchor(String anchorId) async {
    try {
      final String? result = await platform.invokeMethod('hostCloudAnchor', {
        'anchorId': anchorId,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to host cloud anchor: '${e.message}'.");
      return null;
    }
  }

  Future<bool> resolveCloudAnchor(String cloudAnchorId) async {
    try {
      final bool result = await platform.invokeMethod('resolveCloudAnchor', {
        'cloudAnchorId': cloudAnchorId,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to resolve cloud anchor: '${e.message}'.");
      return false;
    }
  }

  Future<void> enableOcclusion(bool enable) async {
    try {
      await platform.invokeMethod('enableOcclusion', {'enable': enable});
    } on PlatformException catch (e) {
      print("Failed to set occlusion: '${e.message}'.");
    }
  }

  Future<void> enableLightEstimation(bool enable) async {
    try {
      await platform.invokeMethod('enableLightEstimation', {'enable': enable});
    } on PlatformException catch (e) {
      print("Failed to set light estimation: '${e.message}'.");
    }
  }

  Future<void> updateNodeTexture(String nodeName, String textureUrl) async {
    try {
      await platform.invokeMethod('updateNodeTexture', {
        'nodeName': nodeName,
        'textureUrl': textureUrl,
      });
    } on PlatformException catch (e) {
      print("Failed to update node texture: '${e.message}'.");
    }
  }

  Future<bool> isDepthMeshSupported() async {
    try {
      final bool supported = await platform.invokeMethod(
        'isDepthMeshSupported',
      );
      return supported;
    } on PlatformException catch (e) {
      print("Failed to check depth mesh support: '${e.message}'.");
      return false;
    }
  }

  Future<void> enableDepthMesh(bool enable) async {
    try {
      await platform.invokeMethod('enableDepthMesh', {'enable': enable});
    } on PlatformException catch (e) {
      print("Failed to enable depth mesh: '${e.message}'.");
    }
  }
}
