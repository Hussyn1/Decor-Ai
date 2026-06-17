class ArConstants {
  ArConstants._();

  static const double collisionThreshold = 0.5;

  static const double wallDetectionThreshold = 0.3;

  static const double wallSnapDistance = 0.15;

  static const double minScale = 0.9;

  static const double maxScale = 2.0;

  static const int maxUndoStackSize = 20;

  static const Duration aiAnalysisDebounce = Duration(milliseconds: 500);

  static const Duration arSessionStabilizationDelay = Duration(
    milliseconds: 300,
  );

  static const Duration nodeSpawnDelay = Duration(milliseconds: 150);

  static const double planeOverlayOpacity = 0.3;

  static const double controlButtonSize = 44.0;

  static const double smallControlButtonSize = 36.0;

  static const bool showFeaturePointsDefault = false;

  static const bool showPlanesDefault = true;

  static const bool showWorldOriginDefault = false;
}
