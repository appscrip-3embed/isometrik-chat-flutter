import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Centered empty / idle state: icon in a soft circle, title, optional
/// subtitle and action. Scrolls when space is tight (keyboard open).
class IsmChatEmptyState extends StatelessWidget {
  const IsmChatEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.iconColor,
    this.iconBackgroundColor,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Null → [IsmChatDesignTokens.title].
  final TextStyle? titleStyle;

  /// Null → [IsmChatDesignTokens.footnote].
  final TextStyle? subtitleStyle;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: iconBackgroundColor ?? tokens.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: iconColor ?? tokens.accent),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: titleStyle ?? tokens.title,
                textAlign: TextAlign.center,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: subtitleStyle ?? tokens.footnote,
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
