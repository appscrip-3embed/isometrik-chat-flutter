import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Pill segmented control bound to a [TabController]. The thumb follows the
/// controller's animation, so it tracks swipes in the [TabBarView] too.
class IsmChatSegmentedTabs extends StatelessWidget {
  const IsmChatSegmentedTabs({
    super.key,
    required this.controller,
    required this.labels,
    this.trackColor,
    this.thumbColor,
    this.selectedStyle,
    this.unselectedStyle,
    this.height = 36,
  }) : assert(labels.length > 0, 'labels must not be empty');

  final TabController controller;
  final List<String> labels;

  /// Null → [IsmChatDesignTokens.segmentTrack].
  final Color? trackColor;

  /// Null → [IsmChatDesignTokens.segmentThumb].
  final Color? thumbColor;
  final TextStyle? selectedStyle;
  final TextStyle? unselectedStyle;
  final double height;

  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    final selected = selectedStyle ??
        tokens.footnote.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        );
    final unselected = unselectedStyle ??
        tokens.footnote.copyWith(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w500,
        );
    final animation = controller.animation ??
        AlwaysStoppedAnimation<double>(
          controller.index.toDouble(),
        );

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: trackColor ?? tokens.segmentTrack,
          borderRadius: BorderRadius.circular(10),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth =
                (constraints.maxWidth - _inset * 2) / labels.length;
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final value = animation.value;
                return Stack(
                  children: [
                    Positioned(
                      left: _inset + value * segmentWidth,
                      top: _inset,
                      bottom: _inset,
                      width: segmentWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: thumbColor ?? tokens.segmentThumb,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: tokens.isDark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(_inset),
                      child: Row(
                        children: [
                          for (var i = 0; i < labels.length; i++)
                            Expanded(
                              child: _Segment(
                                label: labels[i],
                                isSelected: (value - i).abs() < .5,
                                selectedStyle: selected,
                                unselectedStyle: unselected,
                                onTap: () => controller.animateTo(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isSelected,
    required this.selectedStyle,
    required this.unselectedStyle,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final TextStyle selectedStyle;
  final TextStyle unselectedStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: isSelected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: isSelected ? selectedStyle : unselectedStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
}
