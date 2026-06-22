import 'package:flutter/material.dart';

/// Renderer Markdown ringan untuk output AI (heading ##, bullet -, **bold**).
/// Sengaja minimal — menghindari menambah dependency baru.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.data, {super.key});
  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    final lines = data.replaceAll('\r\n', '\n').split('\n');

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (line.startsWith('### ')) {
        widgets.add(_heading(theme, line.substring(4), theme.textTheme.titleSmall));
      } else if (line.startsWith('## ')) {
        widgets.add(_heading(theme, line.substring(3), theme.textTheme.titleMedium));
      } else if (line.startsWith('# ')) {
        widgets.add(_heading(theme, line.substring(2), theme.textTheme.titleLarge));
      } else if (line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('* ')) {
        final content = line.trimLeft().substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Icon(Icons.circle,
                    size: 6, color: theme.colorScheme.primary),
              ),
              Expanded(
                child: Text.rich(
                  _inline(content, theme.textTheme.bodyMedium),
                ),
              ),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(_inline(line, theme.textTheme.bodyMedium)),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _heading(ThemeData theme, String text, TextStyle? base) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text.rich(
          _inline(text, base?.copyWith(fontWeight: FontWeight.bold)),
        ),
      );

  /// Parse **bold** inline (segmen ganjil = tebal).
  TextSpan _inline(String text, TextStyle? base) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ));
    }
    return TextSpan(style: base, children: spans);
  }
}
