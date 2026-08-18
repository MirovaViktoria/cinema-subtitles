import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:flutter/material.dart';

class SubtitleView extends StatelessWidget {
  const SubtitleView({
    required this.cues,
    required this.preferredFontSize,
    super.key,
  });

  static const minimumFontSize = 18.0;

  final List<SubtitleCue> cues;
  final double preferredFontSize;

  @override
  Widget build(BuildContext context) {
    if (cues.isEmpty) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = (constraints.maxWidth - 32)
            .clamp(0.0, double.infinity)
            .toDouble();
        final fontSize = _largestFittingFontSize(
          context,
          availableWidth,
          constraints.maxHeight,
        );
        final content = _CueList(cues: cues, fontSize: fontSize);

        if (_contentHeight(context, availableWidth, fontSize) <=
            constraints.maxHeight) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: content,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: content,
        );
      },
    );
  }

  double _largestFittingFontSize(
    BuildContext context,
    double width,
    double height,
  ) {
    var candidate = preferredFontSize.clamp(minimumFontSize, 72.0).toDouble();
    while (candidate > minimumFontSize &&
        _contentHeight(context, width, candidate) > height) {
      candidate -= 2;
    }
    return candidate.clamp(minimumFontSize, 72.0).toDouble();
  }

  double _contentHeight(BuildContext context, double width, double fontSize) {
    var height = 0.0;
    final style = TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      height: 1.22,
    );
    for (final cue in cues) {
      final painter = TextPainter(
        text: TextSpan(text: cue.text, style: style),
        textAlign: TextAlign.center,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      height += painter.height;
    }
    return height + (cues.length - 1) * 18;
  }
}

class _CueList extends StatelessWidget {
  const _CueList({required this.cues, required this.fontSize});

  final List<SubtitleCue> cues;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, cue) in cues.indexed) ...[
          if (index > 0) const SizedBox(height: 18),
          Text(
            cue.text,
            key: ValueKey(cue.id),
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.22,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
