import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/service/illustration_service.dart';

/// One background under the navigator, shared by home/settings/server routes.
class IllustrationBackdrop extends StatelessWidget {
  const IllustrationBackdrop({
    super.key,
    required this.service,
    required this.child,
  });
  final IllustrationService service;
  final Widget child;

  @override
  Widget build(BuildContext context) => Obx(() {
    if (!service.hasBackground) return child;
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: Opacity(
                  opacity: 1 - service.transparency.value / 100,
                  child: _IllustrationSlide(
                    path: service.currentPicture!,
                    intervalSeconds: service.intervalSeconds.value,
                    onReady: service.restartPlayback,
                    onInvalid: service.rejectPicture,
                  ),
                ),
              ),
            ),
          ),
          Theme(data: illustrationSurfaceTheme(theme), child: child),
        ],
      ),
    );
  });
}

/// Keep text/control colors intact while allowing the bottom image through.
ThemeData illustrationSurfaceTheme(ThemeData theme) {
  final colors = theme.colorScheme;
  return theme.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: colors.surface.withValues(alpha: .8),
    colorScheme: colors.copyWith(
      surfaceContainerLowest: colors.surfaceContainerLowest.withValues(
        alpha: .8,
      ),
      surfaceContainerLow: colors.surfaceContainerLow.withValues(alpha: .72),
      surfaceContainer: colors.surfaceContainer.withValues(alpha: .76),
      surfaceContainerHigh: colors.surfaceContainerHigh.withValues(alpha: .82),
      surfaceContainerHighest: colors.surfaceContainerHighest.withValues(
        alpha: .88,
      ),
    ),
    cardTheme: theme.cardTheme.copyWith(
      color: colors.surfaceContainerLow.withValues(alpha: .72),
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: theme.appBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: theme.navigationRailTheme.copyWith(
      backgroundColor: colors.surface.withValues(alpha: .75),
    ),
    navigationBarTheme: theme.navigationBarTheme.copyWith(
      backgroundColor: colors.surface.withValues(alpha: .8),
    ),
  );
}

class _IllustrationSlide extends StatefulWidget {
  const _IllustrationSlide({
    required this.path,
    required this.intervalSeconds,
    required this.onReady,
    required this.onInvalid,
  });
  final String path;
  final int intervalSeconds;
  final VoidCallback onReady;
  final ValueChanged<String> onInvalid;
  @override
  State<_IllustrationSlide> createState() => _IllustrationSlideState();
}

class _IllustrationSlideState extends State<_IllustrationSlide> {
  ImageProvider? _image;
  String? _shownPath;
  int _revision = 0;
  int _decodeWidth = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 1920);
    if (_decodeWidth != width) {
      _decodeWidth = width;
      _prepare();
    }
  }

  @override
  void didUpdateWidget(covariant _IllustrationSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _prepare();
  }

  Future<void> _prepare() async {
    final revision = ++_revision;
    final path = widget.path;
    final provider = ResizeImage.resizeIfNeeded(
      _decodeWidth,
      null,
      FileImage(File(path)),
    );
    var failed = false;
    await precacheImage(
      provider,
      context,
      onError: (_, __) {
        failed = true;
      },
    );
    if (!mounted || revision != _revision) return;
    if (failed) {
      widget.onInvalid(path);
      return;
    }
    setState(() {
      _image = provider;
      _shownPath = path;
    });
    widget.onReady();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 800),
    layoutBuilder: (current, previous) => Stack(
      fit: StackFit.expand,
      children: [...previous, if (current != null) current],
    ),
    child: _image == null
        ? const SizedBox.expand()
        : PanningIllustration(
            key: ValueKey('$_shownPath:${widget.intervalSeconds}'),
            image: _image!,
            duration: Duration(
              milliseconds: widget.intervalSeconds * 1000 - 1600,
            ),
          ),
  );
}

/// Fit the complete height, then reveal the image from its left edge to its
/// right edge. Wide art is fully traversed before the next slide fades in.
class PanningIllustration extends StatelessWidget {
  const PanningIllustration({
    super.key,
    required this.image,
    required this.duration,
  });
  final ImageProvider image;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: -1, end: 1),
    duration: duration,
    curve: Curves.linear,
    builder: (context, alignment, _) => ClipRect(
      child: Image(
        image: image,
        fit: BoxFit.fitHeight,
        alignment: Alignment(alignment, 0),
        errorBuilder: (_, __, ___) => const SizedBox.expand(),
      ),
    ),
  );
}
