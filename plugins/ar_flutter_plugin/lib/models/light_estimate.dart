class LightEstimate {
  final double pixelIntensity;
  final List<double>? colorCorrection; // RGBA
  final List<double>? mainLightDirection; // xyz
  final List<double>? mainLightIntensity; // rgb

  LightEstimate({
    required this.pixelIntensity,
    this.colorCorrection,
    this.mainLightDirection,
    this.mainLightIntensity,
  });

  static LightEstimate fromJson(Map<String, dynamic> json) {
    return LightEstimate(
      pixelIntensity: (json['pixelIntensity'] as num).toDouble(),
      colorCorrection: (json['colorCorrection'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
      mainLightDirection: (json['mainLightDirection'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
      mainLightIntensity: (json['mainLightIntensity'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
    );
  }
}
