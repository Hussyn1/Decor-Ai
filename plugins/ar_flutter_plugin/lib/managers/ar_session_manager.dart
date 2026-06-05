import 'dart:math' show sqrt;
import 'dart:typed_data';

import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/light_estimate.dart';
import 'package:ar_flutter_plugin/models/detected_plane.dart';
import 'package:ar_flutter_plugin/utils/json_converters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

// Type definitions to enforce a consistent use of the API
typedef ARHitResultHandler = void Function(List<ARHitTestResult> hits);
typedef ARLightEstimateHandler = void Function(LightEstimate estimate);
typedef ARPlanesDetectedHandler = void Function(List<DetectedPlane> planes);

/// Manages the session configuration, parameters and events of an [ARView]
class ARSessionManager {
  /// Platform channel used for communication from and to [ARSessionManager]
  late MethodChannel _channel;

  /// Debugging status flag. If true, all platform calls are printed. Defaults to false.
  final bool debug;

  /// Context of the [ARView] widget that this manager is attributed to
  final BuildContext buildContext;

  /// Determines the types of planes ARCore and ARKit should show
  final PlaneDetectionConfig planeDetectionConfig;

  /// Receives hit results from user taps with tracked planes or feature points
  ARHitResultHandler? onPlaneOrPointTap;

  /// Receives continuous light estimation updates
  ARLightEstimateHandler? onLightEstimate;

  /// Receives continuous plane detection updates (for room scanning)
  ARPlanesDetectedHandler? onPlanesDetected;

  ARSessionManager(int id, this.buildContext, this.planeDetectionConfig,
      {this.debug = false}) {
    _channel = MethodChannel('arsession_$id');
    _channel.setMethodCallHandler(_platformCallHandler);
    if (debug) {
      print("ARSessionManager initialized");
    }
  }

  /// Returns the camera pose in Matrix4 format with respect to the world coordinate system of the [ARView]
  Future<Matrix4?> getCameraPose() async {
    try {
      final serializedCameraPose =
          await _channel.invokeMethod<List<dynamic>>('getCameraPose', {});
      return MatrixConverter().fromJson(serializedCameraPose!);
    } catch (e) {
      print('Error caught: ' + e.toString());
      return null;
    }
  }

  /// Returns the given anchor pose in Matrix4 format with respect to the world coordinate system of the [ARView]
  Future<Matrix4?> getPose(ARAnchor anchor) async {
    try {
      if (anchor.name.isEmpty) {
        throw Exception("Anchor can not be resolved. Anchor name is empty.");
      }
      final serializedCameraPose =
          await _channel.invokeMethod<List<dynamic>>('getAnchorPose', {
        "anchorId": anchor.name,
      });
      return MatrixConverter().fromJson(serializedCameraPose!);
    } catch (e) {
      print('Error caught: ' + e.toString());
      return null;
    }
  }

  /// Returns the distance in meters between @anchor1 and @anchor2.
  Future<double?> getDistanceBetweenAnchors(
      ARAnchor anchor1, ARAnchor anchor2) async {
    var anchor1Pose = await getPose(anchor1);
    var anchor2Pose = await getPose(anchor2);
    var anchor1Translation = anchor1Pose?.getTranslation();
    var anchor2Translation = anchor2Pose?.getTranslation();
    if (anchor1Translation != null && anchor2Translation != null) {
      return getDistanceBetweenVectors(anchor1Translation, anchor2Translation);
    } else {
      return null;
    }
  }

  /// Returns the distance in meters between @anchor and device's camera.
  Future<double?> getDistanceFromAnchor(ARAnchor anchor) async {
    Matrix4? cameraPose = await getCameraPose();
    Matrix4? anchorPose = await getPose(anchor);
    Vector3? cameraTranslation = cameraPose?.getTranslation();
    Vector3? anchorTranslation = anchorPose?.getTranslation();
    if (anchorTranslation != null && cameraTranslation != null) {
      return getDistanceBetweenVectors(anchorTranslation, cameraTranslation);
    } else {
      return null;
    }
  }

  /// Returns the distance in meters between @vector1 and @vector2.
  double getDistanceBetweenVectors(Vector3 vector1, Vector3 vector2) {
    num dx = vector1.x - vector2.x;
    num dy = vector1.y - vector2.y;
    num dz = vector1.z - vector2.z;
    double distance = sqrt(dx * dx + dy * dy + dz * dz);
    return distance;
  }

  Future<void> _platformCallHandler(MethodCall call) {
    if (debug) {
      print('_platformCallHandler call ${call.method} ${call.arguments}');
    }
    try {
      switch (call.method) {
        case 'onError':
          if (onError != null) {
            onError(call.arguments[0]);
            print(call.arguments);
          }
          break;
        case 'onPlaneOrPointTap':
          if (onPlaneOrPointTap != null) {
            final rawHitTestResults = call.arguments as List<dynamic>;
            final serializedHitTestResults = rawHitTestResults
                .map(
                    (hitTestResult) => Map<String, dynamic>.from(hitTestResult))
                .toList();
            final hitTestResults = serializedHitTestResults.map((e) {
              return ARHitTestResult.fromJson(e);
            }).toList();
            onPlaneOrPointTap!(hitTestResults);
          }
          break;
        case 'onLightEstimate':
          if (onLightEstimate != null) {
            final serializedData = Map<String, dynamic>.from(call.arguments);
            onLightEstimate!(LightEstimate.fromJson(serializedData));
          }
          break;
        case 'onPlanesDetected':
          if (onPlanesDetected != null) {
            final rawPlanes = call.arguments as List<dynamic>;
            final serializedPlanes =
                rawPlanes.map((p) => Map<String, dynamic>.from(p)).toList();
            final planes =
                serializedPlanes.map((e) => DetectedPlane.fromJson(e)).toList();
            onPlanesDetected!(planes);
          }
          break;
        case 'dispose':
          _channel.invokeMethod<void>("dispose");
          break;
        default:
          if (debug) {
            print('Unimplemented method ${call.method} ');
          }
      }
    } catch (e) {
      print('Error caught: ' + e.toString());
    }
    return Future.value();
  }

  /// Function to initialize the platform-specific AR view. Can be used to initially set or update session settings.
  /// [customPlaneTexturePath] refers to flutter assets from the app that is calling this function, NOT to assets within this plugin. Make sure
  /// the assets are correctly registered in the pubspec.yaml of the parent app (e.g. the ./example app in this plugin's repo)
  onInitialize({
    bool showAnimatedGuide = true,
    bool showFeaturePoints = false,
    bool showPlanes = true,
    String? customPlaneTexturePath,
    bool showWorldOrigin = false,
    bool handleTaps = true,
    bool handlePans = false, // nodes are not draggable by default
    bool handleRotation = false, // nodes can not be rotated by default
  }) {
    _channel.invokeMethod<void>('init', {
      'showAnimatedGuide': showAnimatedGuide,
      'showFeaturePoints': showFeaturePoints,
      'planeDetectionConfig': planeDetectionConfig.index,
      'showPlanes': showPlanes,
      'customPlaneTexturePath': customPlaneTexturePath,
      'showWorldOrigin': showWorldOrigin,
      'handleTaps': handleTaps,
      'handlePans': handlePans,
      'handleRotation': handleRotation,
    });
  }

  /// Displays the [errorMessage] in a snackbar of the parent widget
  onError(String errorMessage) {
    ScaffoldMessenger.of(buildContext).showSnackBar(SnackBar(
        content: Text(errorMessage),
        action: SnackBarAction(
            label: 'HIDE',
            onPressed:
                ScaffoldMessenger.of(buildContext).hideCurrentSnackBar)));
  }

  /// Dispose the AR view on the platforms to pause the scenes and disconnect the platform handlers.
  /// You should call this before removing the AR view to prevent out of memory erros
  dispose() async {
    try {
      await _channel.invokeMethod<void>("dispose");
    } catch (e) {
      print(e);
    }
  }

  /// Returns a future ImageProvider that contains a screenshot of the current AR Scene
  Future<ImageProvider> snapshot() async {
    final result = await _channel.invokeMethod<Uint8List>('snapshot');
    return MemoryImage(result!);
  }

  /// Performs a programmatic hit test at the given normalized screen coordinates (0.0 to 1.0)
  Future<List<ARHitTestResult>> performHitTest(double x, double y) async {
    try {
      final serializedHitTestResults = await _channel.invokeMethod<List<dynamic>>(
          'performHitTest', {"x": x, "y": y});
          
      if (serializedHitTestResults == null) return [];
      
      return serializedHitTestResults
          .map((e) => Map<String, dynamic>.from(e))
          .map((e) => ARHitTestResult.fromJson(e))
          .toList();
    } catch (e) {
      print('Error caught in performHitTest: ' + e.toString());
      return [];
    }
  }

  /// Performs a programmatic hit test at the center of the screen
  Future<ARHitTestResult?> getSurfaceAtCenter() async {
    try {
      final serializedHitTestResult =
          await _channel.invokeMethod<Map<dynamic, dynamic>?>('getSurfaceAtCenter');
      if (serializedHitTestResult == null) return null;
      return ARHitTestResult.fromJson(Map<String, dynamic>.from(serializedHitTestResult));
    } catch (e) {
      print('Error caught in getSurfaceAtCenter: ' + e.toString());
      return null;
    }
  }

  /// Explicitly requests the current light estimate from ARCore
  Future<LightEstimate?> getLightEstimate() async {
    try {
      final serializedLight =
          await _channel.invokeMethod<Map<dynamic, dynamic>?>('getLightEstimate');
      if (serializedLight == null) return null;
      return LightEstimate.fromJson(Map<String, dynamic>.from(serializedLight));
    } catch (e) {
      print('Error caught in getLightEstimate: ' + e.toString());
      return null;
    }
  }

  /// Explicitly requests all currently detected planes (room scanning)
  Future<List<DetectedPlane>> getDetectedPlanes() async {
    try {
      final serializedPlanes =
          await _channel.invokeMethod<List<dynamic>>('getDetectedPlanes');
      if (serializedPlanes == null) return [];
      
      return serializedPlanes
          .map((e) => Map<String, dynamic>.from(e))
          .map((e) => DetectedPlane.fromJson(e))
          .toList();
    } catch (e) {
      print('Error caught in getDetectedPlanes: ' + e.toString());
      return [];
    }
  }

  /// Starts streaming plane detections for room scanning via the onPlanesDetected callback
  Future<void> startRoomScan() async {
    await _channel.invokeMethod<void>('startRoomScan');
  }

  /// Stops streaming plane detections
  Future<void> stopRoomScan() async {
    await _channel.invokeMethod<void>('stopRoomScan');
  }
}
