import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:audio_service/audio_service.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../service/audio_service.dart';
import '../settings.dart';
import 'cached_image.dart';

/// A widget that morphs between PlayerBar and PlayerScreen as you drag vertically.
class PlayerPanel extends StatefulWidget {
  const PlayerPanel({Key? key}) : super(key: key);

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isExpanded = false;
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  StreamSubscription? _mediaItemSub;
  Color? _bgColor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 0.0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _mediaItemSub = audioHandler.mediaItem.listen((event) {
      _updateColor();
    });
    _updateColor();
  }

  Future _updateColor() async {
    if (audioHandler.mediaItem.value == null) return;
    try {
      ColorScheme palette = await ColorScheme.fromImageProvider(
        provider: CachedNetworkImageProvider(
          audioHandler.mediaItem.value?.extras?['thumb'] ??
          audioHandler.mediaItem.value?.artUri,
        ),
      );
      if (mounted) {
        setState(() {
          _bgColor = palette.primary;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _mediaItemSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final delta = -details.primaryDelta! / 300.0; // 300 px drag = full expand
    _controller.value = (_controller.value + delta).clamp(0.0, 1.0);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_controller.value > 0.5) {
      _expand();
    } else {
      _collapse();
    }
  }

  void _expand() {
    setState(() => _isExpanded = true);
    _controller.fling(velocity: 1.0);
  }

  void _collapse() {
    setState(() => _isExpanded = false);
    _controller.fling(velocity: -1.0);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 150)),
      builder: (context, snapshot) {
        final mediaItem = audioHandler.mediaItem.value;
        final playbackState = audioHandler.playbackState.value;
        if (mediaItem == null || playbackState.processingState == AudioProcessingState.idle) {
          return const SizedBox.shrink();
        }
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final t = _animation.value;
            // Interpolate sizes/positions
            final double minHeight = 64;
            final double maxHeight = MediaQuery.of(context).size.height;
            final double panelHeight = minHeight + (maxHeight - minHeight) * t;
            final double imageSize = 40 + (MediaQuery.of(context).size.width * 0.7 - 40) * t;
            final double titleFont = 12 + (24 - 12) * t;
            final double artistFont = 10 + (18 - 10) * t;
            final double controlsSize = 15 + (32 - 15) * t;
            final double borderRadius = 20 * (1 - t);
            final Color bgColor = Color.lerp(
              _bgColor?.withAlpha(180) ?? Theme.of(context).scaffoldBackgroundColor,
              Colors.black,
              t * 0.2,
            )!;
            return Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                onTap: _expand,
                child: Container(
                  height: panelHeight,
                  margin: EdgeInsets.all(8 * (1 - t)),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                    boxShadow: [
                      if (t > 0.05)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2 * t),
                          blurRadius: 16 * t,
                        ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      // Main content
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.9 + 0.1 * t,
                          child: Container(color: bgColor),
                        ),
                      ),
                      // Morphing content
                      Column(
                        mainAxisAlignment: t < 0.5 ? MainAxisAlignment.start : MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8 + (MediaQuery.of(context).padding.top + 24) * t),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(width: 8 + (MediaQuery.of(context).size.width * 0.15 - 8) * t),
                              Hero(
                                tag: 'player-art',
                                child: CachedImage(
                                  width: imageSize,
                                  height: imageSize,
                                  url: mediaItem.extras?['thumb'] ?? mediaItem.artUri?.toString(),
                                ),
                              ),
                              SizedBox(width: 12 + (32 - 12) * t),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      mediaItem.displayTitle ?? '',
                                      maxLines: t < 0.5 ? 1 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: titleFont,
                                        color: Colors.white.withOpacity(0.95),
                                      ),
                                    ),
                                    SizedBox(height: 2 + (8 - 2) * t),
                                    Text(
                                      mediaItem.displaySubtitle ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: artistFont,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (t < 0.5)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _PrevNextButton(controlsSize, prev: true, hidePrev: true),
                                    _PlayPauseButton(controlsSize),
                                    _PrevNextButton(controlsSize),
                                  ],
                                ),
                              SizedBox(width: 8),
                            ],
                          ),
                          if (t < 0.5)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                              child: LinearProgressIndicator(
                                backgroundColor: (_bgColor ?? Theme.of(context).primaryColor).withAlpha(25),
                                color: _bgColor ?? Theme.of(context).primaryColor,
                                value: _progress(),
                              ),
                            ),
                          if (t >= 0.5)
                            Expanded(
                              child: Opacity(
                                opacity: (t - 0.5) * 2,
                                child: _ExpandedPlayerContent(
                                  imageSize: imageSize,
                                  titleFont: titleFont,
                                  artistFont: artistFont,
                                  controlsSize: controlsSize,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Drag handle
                      if (t > 0.05)
                        Positioned(
                          top: 12 + MediaQuery.of(context).padding.top * t,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3 + 0.2 * t),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _progress() {
    if (audioHandler.playbackState.value.processingState == AudioProcessingState.idle) {
      return 0.0;
    }
    if (audioHandler.mediaItem.value == null) return 0.0;
    if (audioHandler.mediaItem.value?.duration?.inSeconds == 0) {
      return 0.0;
    }
    return audioHandler.playbackState.value.position.inSeconds /
        (audioHandler.mediaItem.value?.duration?.inSeconds ?? 1);
  }
}

// --- Shared Controls ---

class _PrevNextButton extends StatelessWidget {
  final double size;
  final bool prev;
  final bool hidePrev;
  const _PrevNextButton(this.size, {this.prev = false, this.hidePrev = false});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: GetIt.I<AudioPlayerHandler>().queueStateStream,
      builder: (context, snapshot) {
        final queueState = snapshot.data;
        if (!prev) {
          if (!(queueState?.hasNext ?? false)) {
            return IconButton(
              icon: Icon(
                AlchemyIcons.skip_next_fill,
                semanticLabel: 'Play next',
              ),
              iconSize: size,
              onPressed: null,
            );
          }
          return IconButton(
            icon: Icon(
              AlchemyIcons.skip_next_fill,
              semanticLabel: 'Play next',
            ),
            iconSize: size,
            onPressed: () => GetIt.I<AudioPlayerHandler>().skipToNext(),
          );
        }
        if (prev) {
          if (!(queueState?.hasPrevious ?? false)) {
            if (hidePrev) {
              return const SizedBox(height: 0, width: 0);
            }
            return IconButton(
              icon: Icon(
                AlchemyIcons.skip_back,
                semanticLabel: 'Play previous',
              ),
              iconSize: size,
              onPressed: null,
            );
          }
          return IconButton(
            icon: Icon(
              AlchemyIcons.skip_back,
              semanticLabel: 'Play previous',
            ),
            iconSize: size,
            onPressed: () => GetIt.I<AudioPlayerHandler>().skipToPrevious(),
          );
        }
        return Container();
      },
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final double size;
  const _PlayPauseButton(this.size);
  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}
class _PlayPauseButtonState extends State<_PlayPauseButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    super.initState();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: GetIt.I<AudioPlayerHandler>().playbackState,
      builder: (context, snapshot) {
        final playbackState = GetIt.I<AudioPlayerHandler>().playbackState.value;
        final playing = playbackState.playing;
        final processingState = playbackState.processingState;
        if (playing ||
            processingState == AudioProcessingState.ready ||
            processingState == AudioProcessingState.idle) {
          if (playing) {
            _controller.forward();
          } else {
            _controller.reverse();
          }
          return IconButton(
            splashRadius: widget.size,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: child.key == ValueKey('icon1')
                    ? Tween<double>(begin: 1, end: 0.75).animate(anim)
                    : Tween<double>(begin: 0.75, end: 1).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: !playing
                  ? Icon(AlchemyIcons.play_fill_small, key: const ValueKey('Play'))
                  : Icon(AlchemyIcons.pause_fill_small, key: const ValueKey('Pause')),
            ),
            iconSize: widget.size,
            onPressed: playing
                ? () => GetIt.I<AudioPlayerHandler>().pause()
                : () => GetIt.I<AudioPlayerHandler>().play(),
          );
        }
        switch (processingState) {
          case AudioProcessingState.buffering:
          case AudioProcessingState.loading:
            return SizedBox(
              width: widget.size * 0.85,
              height: widget.size * 0.85,
              child: Center(
                child: Transform.scale(
                  scale: 0.85,
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            );
          default:
            return SizedBox(width: widget.size, height: widget.size);
        }
      },
    );
  }
}

// Expanded content (morphs in as t -> 1)
class _ExpandedPlayerContent extends StatelessWidget {
  final double imageSize;
  final double titleFont;
  final double artistFont;
  final double controlsSize;
  const _ExpandedPlayerContent({
    required this.imageSize,
    required this.titleFont,
    required this.artistFont,
    required this.controlsSize,
  });
  @override
  Widget build(BuildContext context) {
    // You can add more detailed controls here, e.g. SeekBar, Lyrics, etc.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 24),
          // Album art (big)
          Hero(
            tag: 'player-art',
            child: CachedImage(
              width: imageSize,
              height: imageSize,
              url: GetIt.I<AudioPlayerHandler>().mediaItem.value?.extras?['thumb'] ??
                  GetIt.I<AudioPlayerHandler>().mediaItem.value?.artUri?.toString(),
            ),
          ),
          SizedBox(height: 32),
          // Title
          Text(
            GetIt.I<AudioPlayerHandler>().mediaItem.value?.displayTitle ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: titleFont,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
          SizedBox(height: 8),
          // Artist
          Text(
            GetIt.I<AudioPlayerHandler>().mediaItem.value?.displaySubtitle ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: artistFont,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          SizedBox(height: 32),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PrevNextButton(controlsSize, prev: true),
              SizedBox(width: 24),
              _PlayPauseButton(controlsSize * 1.2),
              SizedBox(width: 24),
              _PrevNextButton(controlsSize),
            ],
          ),
          // Add more expanded controls here (SeekBar, Lyrics, etc.)
        ],
      ),
    );
  }
}
