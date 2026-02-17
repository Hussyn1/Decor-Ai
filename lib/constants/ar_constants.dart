/// AR Configuration Constants
///
/// Centralized location for all AR-related magic numbers and configuration values.
/// This improves maintainability and makes the codebase more readable.
class ArConstants {
  // Prevent instantiation
  ArConstants._();

  // ===== COLLISION & PHYSICS =====

  /// Minimum distance (in meters) between furniture items to prevent overlap
  static const double collisionThreshold = 0.5;

  /// Threshold for detecting vertical planes (walls)
  /// Values closer to 0 indicate vertical surfaces
  static const double wallDetectionThreshold = 0.3;

  /// Distance threshold for magnetic wall snapping
  static const double wallSnapDistance = 0.15;

  // ===== SCALING CONSTRAINTS =====

  /// Minimum scale factor for furniture models
  static const double minScale = 0.9;

  /// Maximum scale factor for furniture models
  static const double maxScale = 2.0;

  // ===== PERFORMANCE & OPTIMIZATION =====

  /// Maximum number of undo states to keep in memory
  static const int maxUndoStackSize = 20;

  /// Debounce duration for AI analysis to prevent excessive API calls
  static const Duration aiAnalysisDebounce = Duration(milliseconds: 500);

  /// Delay before loading project items to allow AR session to stabilize
  static const Duration arSessionStabilizationDelay = Duration(
    milliseconds: 300,
  );

  /// Delay between spawning individual nodes during project restoration
  static const Duration nodeSpawnDelay = Duration(milliseconds: 150);

  // ===== UI CONFIGURATION =====

  /// Opacity for plane visualization overlays
  static const double planeOverlayOpacity = 0.3;

  /// Size of circular control buttons
  static const double controlButtonSize = 44.0;

  /// Size of small circular control buttons
  static const double smallControlButtonSize = 36.0;

  // ===== AR SESSION CONFIGURATION =====

  /// Default plane detection configuration
  static const bool showFeaturePointsDefault = false;

  /// Default plane visibility
  static const bool showPlanesDefault = true;

  /// Default world origin visibility
  static const bool showWorldOriginDefault = false;
}
