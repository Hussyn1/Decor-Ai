import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import '../core/app_theme.dart';

/// AR Control Panel Widget
///
/// Displays floating control buttons for AR scene manipulation:
/// - Lock/unlock selected node
/// - Toggle plane detection
/// - Toggle LiDAR mesh
/// - Toggle physics
/// - Snap to wall
/// - Undo/redo operations
class ArControlPanel extends StatelessWidget {
  final ARNode? selectedNode;
  final bool isLocked;
  final bool showPlanes;
  final bool useLiDAR;
  final bool usePhysics;
  final bool canUndo;
  final bool canRedo;
  final bool isLiDARSupported;

  final VoidCallback onToggleLock;
  final VoidCallback onSnapToWall;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onTogglePlanes;
  final VoidCallback onToggleLiDAR;
  final VoidCallback onTogglePhysics;

  const ArControlPanel({
    super.key,
    required this.selectedNode,
    required this.isLocked,
    required this.showPlanes,
    required this.useLiDAR,
    required this.usePhysics,
    required this.canUndo,
    required this.canRedo,
    required this.isLiDARSupported,
    required this.onToggleLock,
    required this.onSnapToWall,
    required this.onUndo,
    required this.onRedo,
    required this.onTogglePlanes,
    required this.onToggleLiDAR,
    required this.onTogglePhysics,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedNode == null) return const SizedBox.shrink();

    return Positioned(
      top: 120, // Moved down to avoid AI Insights overlap
      right: 16,
      child: RepaintBoundary(
        child: Column(
          children: [
            _buildControlButton(
              isLocked ? Icons.lock : Icons.lock_open,
              color: isLocked ? AppTheme.primaryBlue : Colors.white30,
              onTap: onToggleLock,
            ),
            const SizedBox(height: 12),
            _buildControlButton(Icons.grid_on, onTap: onSnapToWall),
            const SizedBox(height: 12),
            _buildControlButton(
              Icons.undo,
              onTap: canUndo ? onUndo : null,
              color: canUndo ? Colors.white30 : Colors.white12,
            ),
            const SizedBox(height: 12),
            _buildControlButton(
              Icons.redo,
              onTap: canRedo ? onRedo : null,
              color: canRedo ? Colors.white30 : Colors.white12,
            ),
            const SizedBox(height: 12),
            _buildControlButton(
              showPlanes ? Icons.grid_on : Icons.grid_off,
              onTap: onTogglePlanes,
              color: showPlanes
                  ? AppTheme.primaryBlue.withValues(alpha: 0.5)
                  : Colors.black26,
            ),
            const SizedBox(height: 12),
            _buildControlButton(
              useLiDAR ? Icons.view_in_ar : Icons.view_in_ar_outlined,
              onTap: isLiDARSupported ? onToggleLiDAR : null,
              color: useLiDAR
                  ? Colors.greenAccent.withValues(alpha: 0.5)
                  : Colors.black26,
            ),
            const SizedBox(height: 12),
            _buildControlButton(
              usePhysics ? Icons.bolt : Icons.bolt_outlined,
              onTap: onTogglePhysics,
              color: usePhysics
                  ? Colors.amberAccent.withValues(alpha: 0.5)
                  : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color ?? Colors.white30,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
