import 'package:flutter/material.dart';
import '../services/ai_recommendation_service.dart';
import '../core/app_theme.dart';

/// AI Insights Overlay Widget
///
/// Displays AI-generated recommendations, budget tracking,
/// and auto-arrange functionality for the AR scene.
/// Now expanded/collapsed to be less intrusive.
class AiInsightsOverlay extends StatefulWidget {
  final List<AiInsight> activeInsights;
  final bool isAnalyzing;
  final int nodesCount;
  final VoidCallback? onAutoArrange;
  final ValueChanged<AiInsight>? onMagicArrange;
  final ValueChanged<AiInsight>? onDismissInsight;

  const AiInsightsOverlay({
    super.key,
    required this.activeInsights,
    required this.isAnalyzing,
    required this.nodesCount,
    this.onAutoArrange,
    this.onMagicArrange,
    this.onDismissInsight,
  });

  @override
  State<AiInsightsOverlay> createState() => _AiInsightsOverlayState();
}

class _AiInsightsOverlayState extends State<AiInsightsOverlay> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.activeInsights.isEmpty &&
        !widget.isAnalyzing &&
        widget.nodesCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 140,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.end, // Align to right for expanding
        children: [
          // AI Analyzing Indicator (Always visible when active)
          if (widget.isAnalyzing) _buildAnalyzingIndicator(),

          // Insights Toggle / List
          if (widget.activeInsights.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isExpanded
                          ? "Hide AI Insights"
                          : "AI Insights (${widget.activeInsights.length})",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isExpanded) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isExpanded)
              ...widget.activeInsights
                  .take(3)
                  .map((insight) => _buildInsightCard(insight)),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyzingIndicator() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 10),
            Text(
              "Analyzing...",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(AiInsight insight) {
    IconData icon = Icons.info_outline;
    Color color = Colors.blueAccent;

    // Map string types to icons and colors
    switch (insight.type.toLowerCase()) {
      case 'warning':
      case 'styleconflict':
        icon = Icons.warning_amber_rounded;
        color = Colors.orangeAccent;
        break;
      case 'budget':
      case 'suggestion':
        icon = Icons.attach_money;
        color = Colors.greenAccent;
        break;
      case 'harmony':
      case 'placement':
        icon = Icons.lightbulb_outline;
        color = AppTheme.primaryBlue;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (insight.suggestedPosition != null &&
                    widget.onMagicArrange != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GestureDetector(
                      onTap: () => widget.onMagicArrange!(insight),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_fix_high,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Magic Arrange",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (insight.suggestedAction == "FILTER_STYLE" &&
                    insight.suggestedValue != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        // We will handle this in the parent screen via MagicArrange callback
                        // or a new callback. Let's reuse onMagicArrange or extend the widget.
                        // For now, let's reuse onMagicArrange as a'Generic Action' handler if possible
                        // Or just let it be handled by the parent if we passed it.
                        widget.onMagicArrange!(insight);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Show ${insight.suggestedValue} Items",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.onDismissInsight != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 16),
              onPressed: () => widget.onDismissInsight!(insight),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
