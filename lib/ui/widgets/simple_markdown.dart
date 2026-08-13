import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Legal metinler için hafif Markdown görünümü (# / ## / ###, **kalın**, listeler).
class SimpleMarkdownView extends StatelessWidget {
  const SimpleMarkdownView({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = _parseBlocks(data);

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) SizedBox(height: _gapBefore(blocks[i])),
            _buildBlock(context, theme, blocks[i]),
          ],
        ],
      ),
    );
  }

  double _gapBefore(_MdBlock block) {
    return switch (block) {
      _MdHeading(level: 1) => 20,
      _MdHeading() => 16,
      _MdListItem() => 6,
      _MdParagraph() => 10,
    };
  }

  Widget _buildBlock(BuildContext context, ThemeData theme, _MdBlock block) {
    return switch (block) {
      _MdHeading(:final level, :final text) => Text.rich(
        TextSpan(children: _inlineSpans(text, _headingStyle(theme, level))),
        textAlign: TextAlign.start,
      ),
      _MdParagraph(:final text) => Text.rich(
        TextSpan(
          children: _inlineSpans(
            text,
            theme.textTheme.bodyLarge?.copyWith(
                  height: 1.45,
                  color: AppColors.onSurface,
                ) ??
                const TextStyle(height: 1.45, color: AppColors.onSurface),
          ),
        ),
      ),
      _MdListItem(:final text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Text(
              '•',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.primary,
                height: 1.45,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: _inlineSpans(
                  text,
                  theme.textTheme.bodyLarge?.copyWith(
                        height: 1.45,
                        color: AppColors.onSurface,
                      ) ??
                      const TextStyle(height: 1.45, color: AppColors.onSurface),
                ),
              ),
            ),
          ),
        ],
      ),
    };
  }

  TextStyle _headingStyle(ThemeData theme, int level) {
    final base = switch (level) {
      1 => theme.textTheme.headlineSmall,
      2 => theme.textTheme.titleLarge,
      _ => theme.textTheme.titleMedium,
    };
    return (base ?? const TextStyle()).copyWith(
      color: AppColors.primaryDeep,
      fontWeight: FontWeight.w700,
      height: 1.3,
    );
  }
}

sealed class _MdBlock {}

class _MdHeading extends _MdBlock {
  _MdHeading(this.level, this.text);
  final int level;
  final String text;
}

class _MdParagraph extends _MdBlock {
  _MdParagraph(this.text);
  final String text;
}

class _MdListItem extends _MdBlock {
  _MdListItem(this.text);
  final String text;
}

List<_MdBlock> _parseBlocks(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final blocks = <_MdBlock>[];
  final paragraph = StringBuffer();

  void flushParagraph() {
    final text = paragraph.toString().trim();
    paragraph.clear();
    if (text.isNotEmpty) blocks.add(_MdParagraph(text));
  }

  for (final line in lines) {
    // Markdown soft break: iki (veya daha fazla) sonda boşluk → satır kırılımı.
    final softBreak = RegExp(r' {2,}$').hasMatch(line);
    final trimmed = line.trimRight();
    final header = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
    if (header != null) {
      flushParagraph();
      blocks.add(_MdHeading(header.group(1)!.length, header.group(2)!.trim()));
      continue;
    }

    final list = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed.trimLeft());
    if (list != null) {
      flushParagraph();
      blocks.add(_MdListItem(list.group(1)!.trim()));
      continue;
    }

    if (trimmed.trim().isEmpty) {
      flushParagraph();
      continue;
    }

    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(trimmed.trim());
    if (softBreak) {
      flushParagraph();
    }
  }
  flushParagraph();
  return blocks;
}

List<InlineSpan> _inlineSpans(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  final bold = RegExp(r'\*\*(.+?)\*\*');
  var start = 0;
  for (final match in bold.allMatches(text)) {
    if (match.start > start) {
      spans.add(
        TextSpan(text: text.substring(start, match.start), style: style),
      );
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: style.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    start = match.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: style));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: style));
  }
  return spans;
}
