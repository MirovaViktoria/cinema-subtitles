import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:flutter/material.dart';

class SubtitleView extends StatefulWidget {
  const SubtitleView({
    required this.cues,
    required this.preferredFontSize,
    this.previousCue,
    super.key,
  });

  static const minimumFontSize = 18.0;
  static const previousColor = Color(0xFFD7E7F2);
  static const transitionDuration = Duration(milliseconds: 750);
  static const _cueGap = 18.0;

  final List<SubtitleCue> cues;
  final double preferredFontSize;
  final SubtitleCue? previousCue;

  @override
  State<SubtitleView> createState() => _SubtitleViewState();
}

class _SubtitleViewState extends State<SubtitleView> {
  int? _previousSlot;
  int? _activeSlot;

  @override
  void initState() {
    super.initState();
    if (widget.previousCue != null) {
      _previousSlot = 0;
    }
    if (widget.cues.isNotEmpty) {
      _activeSlot = _previousSlot == null ? 0 : 1;
    }
  }

  @override
  void didUpdateWidget(SubtitleView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldActiveIds = oldWidget.cues.map((cue) => cue.id).toSet();
    final newActiveIds = widget.cues.map((cue) => cue.id).toSet();
    final activeContinues = oldActiveIds.intersection(newActiveIds).isNotEmpty;

    int? nextActiveSlot;
    if (widget.cues.isNotEmpty && activeContinues) {
      nextActiveSlot = _activeSlot;
    }

    int? nextPreviousSlot;
    final previousCue = widget.previousCue;
    if (previousCue != null) {
      if (oldWidget.previousCue?.id == previousCue.id) {
        nextPreviousSlot = _previousSlot;
      } else if (oldActiveIds.contains(previousCue.id)) {
        nextPreviousSlot = _activeSlot;
      }
    }

    if (widget.cues.isNotEmpty && nextActiveSlot == null) {
      nextActiveSlot = nextPreviousSlot == null ? 0 : 1 - nextPreviousSlot;
    }
    if (previousCue != null && nextPreviousSlot == null) {
      nextPreviousSlot = nextActiveSlot == null ? 0 : 1 - nextActiveSlot;
    }
    if (nextActiveSlot != null && nextActiveSlot == nextPreviousSlot) {
      if (activeContinues) {
        nextPreviousSlot = 1 - nextActiveSlot;
      } else {
        nextActiveSlot = 1 - nextPreviousSlot!;
      }
    }

    _activeSlot = nextActiveSlot;
    _previousSlot = nextPreviousSlot;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = (constraints.maxWidth - 32)
            .clamp(0.0, double.infinity)
            .toDouble();
        final cueGap = constraints.maxHeight >= SubtitleView._cueGap
            ? SubtitleView._cueGap
            : 0.0;
        final slotHeight = ((constraints.maxHeight - cueGap) / 2)
            .clamp(0.0, double.infinity)
            .toDouble();
        final fontSize = _largestFittingFontSize(
          context,
          availableWidth,
          slotHeight,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: _buildSlot(
                  index: 0,
                  alignment: Alignment.bottomCenter,
                  fontSize: fontSize,
                ),
              ),
              SizedBox(height: cueGap),
              Expanded(
                child: _buildSlot(
                  index: 1,
                  alignment: Alignment.topCenter,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlot({
    required int index,
    required Alignment alignment,
    required double fontSize,
  }) {
    final isActive = _activeSlot == index && widget.cues.isNotEmpty;
    final isPrevious = _previousSlot == index && widget.previousCue != null;
    final cues = isActive
        ? widget.cues
        : isPrevious
        ? [widget.previousCue!]
        : const <SubtitleCue>[];
    final contentKey = ValueKey(
      cues.isEmpty
          ? 'group:empty'
          : 'group:${cues.map((cue) => cue.id).join(',')}',
    );

    return _AnimatedCueSlot(
      switcherKey: ValueKey('subtitle-slot-$index'),
      alignment: alignment,
      child: _CueList(
        key: contentKey,
        cues: cues,
        fontSize: fontSize,
        isPrevious: !isActive && isPrevious,
      ),
    );
  }

  double _largestFittingFontSize(
    BuildContext context,
    double width,
    double slotHeight,
  ) {
    var candidate = widget.preferredFontSize
        .clamp(SubtitleView.minimumFontSize, 72.0)
        .toDouble();
    final previousCues = [?widget.previousCue];
    while (candidate > SubtitleView.minimumFontSize &&
        (_contentHeight(context, width, candidate, previousCues) > slotHeight ||
            _contentHeight(context, width, candidate, widget.cues) >
                slotHeight)) {
      candidate -= 2;
    }
    return candidate.clamp(SubtitleView.minimumFontSize, 72.0).toDouble();
  }

  double _contentHeight(
    BuildContext context,
    double width,
    double fontSize,
    List<SubtitleCue> measuredCues,
  ) {
    if (measuredCues.isEmpty) {
      return 0;
    }

    var height = 0.0;
    final style = TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      height: 1.22,
    );
    for (final cue in measuredCues) {
      final painter = TextPainter(
        text: TextSpan(text: cue.text, style: style),
        textAlign: TextAlign.center,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      height += painter.height;
    }
    return height + (measuredCues.length - 1) * SubtitleView._cueGap;
  }
}

class _AnimatedCueSlot extends StatelessWidget {
  const _AnimatedCueSlot({
    required this.switcherKey,
    required this.alignment,
    required this.child,
  });

  final Key switcherKey;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final switcher = AnimatedSwitcher(
      key: switcherKey,
      duration: SubtitleView.transitionDuration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: alignment,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        reverse: alignment == Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Align(alignment: alignment, child: switcher),
        ),
      ),
    );
  }
}

class _CueList extends StatelessWidget {
  const _CueList({
    required this.cues,
    required this.fontSize,
    required this.isPrevious,
    super.key,
  });

  final List<SubtitleCue> cues;
  final double fontSize;
  final bool isPrevious;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, cue) in cues.indexed) ...[
          if (index > 0) const SizedBox(height: SubtitleView._cueGap),
          AnimatedDefaultTextStyle(
            duration: SubtitleView.transitionDuration,
            curve: Curves.easeInOutCubic,
            style: TextStyle(
              color: isPrevious ? SubtitleView.previousColor : Colors.white,
              fontSize: fontSize,
              fontWeight: isPrevious ? FontWeight.w400 : FontWeight.w500,
              height: 1.22,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
            ),
            child: Text(
              cue.text,
              key: ValueKey(cue.id),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}
