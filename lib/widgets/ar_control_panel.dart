import 'dart:ui';
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
class ArControlPanel extends StatefulWidget {
  final ARNode? selectedNode;
  final bool isLocked;
  final bool showPlanes;
  final bool useLiDAR;
  final bool usePhysics;
  final bool canUndo;
  final bool canRedo;
  final bool isLiDARSupported;

  final VoidCallback onToggleLock;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
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
    required this.onUndo,
    required this.onRedo,
    required this.onToggleLiDAR,
    required this.onTogglePhysics,
  });

  @override
  State<ArControlPanel> createState() => _ArControlPanelState();
}

class _ArControlPanelState extends State<ArControlPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.selectedNode == null) return const SizedBox.shrink();

    return Positioned(
      top: 140,
      right: 16,
      child: RepaintBoundary(
        child: Column(
          children: [
            // Primary Lock Button
            _buildControlButton(
              widget.isLocked ? Icons.lock : Icons.lock_open,
              color: widget.isLocked ? AppTheme.primaryBlue : Colors.white30,
              onTap: widget.onToggleLock,
              label: widget.isLocked ? "Unlock" : "Lock",
            ),
            const SizedBox(height: 12),

            // Expand/Collapse Toggle
            _buildControlButton(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.more_vert,
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              color: _isExpanded
                  ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                  : Colors.white12,
              label: _isExpanded ? "Less" : "More",
            ),

            // Advanced Options (Animated visibility)
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              _buildControlButton(
                Icons.undo,
                onTap: widget.canUndo ? widget.onUndo : null,
                color: widget.canUndo ? Colors.white30 : Colors.white12,
                label: "Undo",
              ),
              const SizedBox(height: 12),
              _buildControlButton(
                Icons.redo,
                onTap: widget.canRedo ? widget.onRedo : null,
                color: widget.canRedo ? Colors.white30 : Colors.white12,
                label: "Redo",
              ),
              const SizedBox(height: 12),
              _buildControlButton(
                widget.useLiDAR ? Icons.view_in_ar : Icons.view_in_ar_outlined,
                onTap: widget.isLiDARSupported ? widget.onToggleLiDAR : null,
                color: widget.useLiDAR
                    ? Colors.greenAccent.withValues(alpha: 0.5)
                    : Colors.black26,
                label: "LiDAR",
              ),
              const SizedBox(height: 12),
              _buildControlButton(
                widget.usePhysics ? Icons.bolt : Icons.bolt_outlined,
                onTap: widget.onTogglePhysics,
                color: widget.usePhysics
                    ? Colors.amberAccent.withValues(alpha: 0.5)
                    : Colors.black26,
                label: "Physics",
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon, {
    Color? color,
    VoidCallback? onTap,
    String? label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      color?.withValues(alpha: 0.3) ??
                      Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
