// lib/widgets/video_player_widget.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerDialog({super.key, required this.videoUrl});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      setState(() {
        _controller.play();
      });
    });

    // Esconde controles após 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _showControls = true;
    });

    if (_controller.value.isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),

                  // Controles
                  if (_showControls)
                    Container(
                      color: Colors.black38,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Botão fechar
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),

                          // Botão play/pause
                          Center(
                            child: IconButton(
                              icon: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                                size: 64,
                                color: Colors.white,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                          ),

                          // Progress bar
                          VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: Theme.of(context).primaryColor,
                              bufferedColor: Colors.grey,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
        },
      ),
    );
  }
}