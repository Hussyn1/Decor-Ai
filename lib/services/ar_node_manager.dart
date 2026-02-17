import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../models/result.dart';

/// Service for managing AR nodes and anchors with proper error handling
///
/// Encapsulates all AR node/anchor operations to separate concerns
/// and provide consistent error handling across the application.
class ArNodeManager {
  /// Add a furniture node to the AR scene
  ///
  /// Returns a Result containing the created node or an error message
  Future<Result<ARNode>> addFurnitureNode({
    required ARObjectManager objectManager,
    required ARPlaneAnchor anchor,
    required String modelUri,
    required vector.Vector3 position,
    required vector.Vector3 scale,
    required vector.Vector4 rotation,
  }) async {
    try {
      final node = ARNode(
        type: NodeType.webGLB,
        uri: modelUri,
        position: position,
        scale: scale,
        rotation: rotation,
        name: "furniture_${DateTime.now().microsecondsSinceEpoch}",
      );

      final success = await objectManager.addNode(node, planeAnchor: anchor);

      if (success == true) {
        return Result.success(node);
      } else {
        return Result.error("Failed to add node to AR scene");
      }
    } catch (e, stackTrace) {
      print("ERROR in addFurnitureNode: $e");
      print(stackTrace);
      return Result.error("Error adding node: ${e.toString()}");
    }
  }

  /// Remove a specific node from the AR scene
  Future<Result<void>> removeNode({
    required ARObjectManager objectManager,
    required ARNode node,
  }) async {
    try {
      await objectManager.removeNode(node);
      return Result.success(null);
    } catch (e) {
      print("ERROR in removeNode: $e");
      return Result.error("Error removing node: ${e.toString()}");
    }
  }

  /// Remove all nodes from the AR scene
  Future<Result<void>> removeAllNodes({
    required ARObjectManager objectManager,
    required List<ARNode> nodes,
  }) async {
    try {
      for (var node in nodes) {
        await objectManager.removeNode(node);
      }
      return Result.success(null);
    } catch (e) {
      print("ERROR in removeAllNodes: $e");
      return Result.error("Error removing nodes: ${e.toString()}");
    }
  }

  /// Add an anchor to the AR scene
  Future<Result<ARAnchor>> addAnchor({
    required ARAnchorManager anchorManager,
    required ARAnchor anchor,
  }) async {
    try {
      final success = await anchorManager.addAnchor(anchor);

      if (success == true) {
        return Result.success(anchor);
      } else {
        return Result.error("Failed to add anchor to AR scene");
      }
    } catch (e) {
      print("ERROR in addAnchor: $e");
      return Result.error("Error adding anchor: ${e.toString()}");
    }
  }

  /// Remove a specific anchor from the AR scene
  Future<Result<void>> removeAnchor({
    required ARAnchorManager anchorManager,
    required ARAnchor anchor,
  }) async {
    try {
      await anchorManager.removeAnchor(anchor);
      return Result.success(null);
    } catch (e) {
      print("ERROR in removeAnchor: $e");
      return Result.error("Error removing anchor: ${e.toString()}");
    }
  }

  /// Update the texture of a node
  Future<Result<void>> updateNodeTexture({
    required String nodeName,
    required String textureUrl,
    required Function(String, String) updateCallback,
  }) async {
    try {
      await updateCallback(nodeName, textureUrl);
      return Result.success(null);
    } catch (e) {
      print("ERROR in updateNodeTexture: $e");
      return Result.error("Error updating texture: ${e.toString()}");
    }
  }
}
