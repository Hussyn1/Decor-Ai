import 'package:flutter/material.dart';
import '../services/ai_recommendation_service.dart';
import '../core/app_theme.dart';

/// AI Insights Overlay Widget
///
/// Displays AI-generated recommendations, budget tracking,
/// and auto-arrange functionality for the AR scene.
class AiInsightsOverlay extends StatelessWidget {
  final List<AiInsight> activeInsights;
  final double totalBudget;
  final bool isAnalyzing;
  final int nodesCount;
  final VoidCallback? onAutoArrange;
  final ValueChanged<AiInsight>? onMagicArrange;
  final ValueChanged<AiInsight>? onDismissInsight;

  const AiInsightsOverlay({
    super.key,
    required this.activeInsights,
    required this.totalBudget,
    required this.isAnalyzing,
    required this.nodesCount,
    this.onAutoArrange,
    this.onMagicArrange,
    this.onDismissInsight,
  });

  @override
  Widget build(BuildContext context) {
    if (activeInsights.isEmpty && !isAnalyzing && nodesCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Budget Tracking Row
          if (nodesCount > 0) _buildBudgetTracker(),

          // AI Analyzing Indicator
          if (isAnalyzing) _buildAnalyzingIndicator(),

          // AI Insights Cards
          ...activeInsights
              .take(3)
              .map((insight) => _buildInsightCard(insight)),
        ],
      ),
    );
  }

  Widget _buildBudgetTracker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet,
            color: AppTheme.primaryBlue,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Text(
            "Est. Total:",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          Text(
            "\$${totalBudget.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingIndicator() {
    return Container(
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
            "AI Scanning space...",
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
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
        children: [
          Icon(icon, color: color, size: 20),
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
                if (insight.suggestedPosition != null && onMagicArrange != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GestureDetector(
                      onTap: () => onMagicArrange!(insight),
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
              ],
            ),
          ),
          if (onDismissInsight != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 16),
              onPressed: () => onDismissInsight!(insight),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
