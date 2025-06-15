import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class MessageWidget extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String? repliedToText;
  final VoidCallback onReply;
  final VoidCallback onShare;
  final VoidCallback onLongPress;
  final VoidCallback onTapOriginal;
  final VoidCallback onDelete;
  final AudioPlayer audioPlayer;
  final Function(String?) setCurrentlyPlaying;
  final String? currentlyPlayingId;
  final encrypt.Encrypter encrypter;
  final bool isRead;

  const MessageWidget({
    Key? key,
    required this.message,
    required this.isMe,
    this.repliedToText,
    required this.onReply,
    required this.onShare,
    required this.onLongPress,
    required this.onTapOriginal,
    required this.onDelete,
    required this.audioPlayer,
    required this.setCurrentlyPlaying,
    required this.currentlyPlayingId,
    required this.encrypter,
    required this.isRead,
  }) : super(key: key);

  @override
  _MessageWidgetState createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget> {
  double _dragOffset = 0.0;

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final messageTime = DateTime.parse(widget.message['created_at'].toString());
    final formattedTime = DateFormat('h:mm a').format(messageTime);
    final messageType = widget.message['type']?.toString() ?? 'text';

    // Define tick widget for sent messages
    Widget tickWidget = widget.isMe
        ? Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(
              widget.isRead
                  ? Icons.done_all
                  : widget.message['delivered_at'] != null
                      ? Icons.done_all
                      : Icons.done,
              size: 16,
              color: widget.isRead
                  ? Colors.blue
                  : widget.message['delivered_at'] != null
                      ? Colors.grey
                      : Colors.grey[400],
            ),
          )
        : Container();

    Widget content;
    switch (messageType) {
      case 'image':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedNetworkImage(
              imageUrl: widget.message['message'],
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
            if (!widget.isMe && widget.message['sender_username'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  widget.message['sender_username'] ?? 'Unknown',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isMe) tickWidget,
                if (widget.isMe) const SizedBox(width: 4),
                Text(formattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        );
        break;
      case 'video':
        content = VideoPlayerWidget(url: widget.message['message']);
        break;
      case 'audio':
        final isPlaying = widget.currentlyPlayingId == widget.message['id'];
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white),
                  onPressed: () async {
                    if (isPlaying) {
                      await widget.audioPlayer.pause();
                      widget.setCurrentlyPlaying(null);
                    } else {
                      if (widget.currentlyPlayingId != null)
                        await widget.audioPlayer.stop();
                      await widget.audioPlayer
                          .setUrl(widget.message['message']);
                      await widget.audioPlayer.play();
                      widget.setCurrentlyPlaying(widget.message['id']);
                    }
                  },
                ),
                Expanded(
                  child: StreamBuilder<Duration?>(
                    stream: widget.audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration =
                          widget.audioPlayer.duration ?? Duration.zero;
                      return Slider(
                          value: position.inSeconds.toDouble(),
                          max: duration.inSeconds.toDouble(),
                          onChanged: (value) => widget.audioPlayer
                              .seek(Duration(seconds: value.toInt())));
                    },
                  ),
                ),
                Text(
                    '${_formatDuration(widget.audioPlayer.position)} / ${_formatDuration(widget.audioPlayer.duration)}',
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
            if (!widget.isMe && widget.message['sender_username'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  widget.message['sender_username'] ?? 'Unknown',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isMe) tickWidget,
                if (widget.isMe) const SizedBox(width: 4),
                Text(formattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        );
        break;
      case 'document':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.description, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Document ${widget.message['message'].split('/').last.toString()}',
                      style: const TextStyle(color: Colors.white))),
            ]),
            if (!widget.isMe && widget.message['sender_username'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  widget.message['sender_username'] ?? 'Unknown',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isMe) tickWidget,
                if (widget.isMe) const SizedBox(width: 4),
                Text(formattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        );
        break;
      default:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.repliedToText != null) ...[
              GestureDetector(
                onTap: widget.onTapOriginal,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text("Replied to: ${widget.repliedToText}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            if (!widget.isMe && widget.message['sender_username'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  widget.message['sender_username'] ?? 'Unknown',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold),
                ),
              ),
            Text(
              widget.message['message'] ?? '[No message content]',
              style: TextStyle(
                  fontSize: 14,
                  color: widget.isMe ? Colors.white : Colors.black87),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isMe) tickWidget,
                if (widget.isMe) const SizedBox(width: 4),
                Text(formattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            if (widget.message['is_pinned'] == true)
              const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.push_pin, color: Colors.orange, size: 18)),
            if (widget.message['reactions']?.isNotEmpty ?? false)
              Wrap(
                children:
                    (widget.message['reactions'] as Map<String, List<String>>)
                        .entries
                        .map((entry) {
                  IconData icon;
                  switch (entry.key) {
                    case 'like':
                      icon = Icons.circle;
                      break;
                    case 'heart':
                      icon = Icons.favorite;
                      break;
                    default:
                      icon = Icons.emoji_emotions;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: Colors.white),
                        const SizedBox(width: 2),
                        Text('${entry.value.length}',
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        );
    }

    return Dismissible(
      key: Key(widget.message['id'].toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => widget.onDelete(),
      background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(Icons.delete, color: Colors.white)),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) =>
            setState(() => _dragOffset += details.delta.dx),
        onHorizontalDragEnd: (details) {
          if (_dragOffset < -50) {
            widget.onReply();
          } else if (_dragOffset > 50) {
            widget.onShare();
          }
          setState(() => _dragOffset = 0.0);
        },
        onLongPress: widget.onLongPress,
        child: Stack(
          children: [
            if (_dragOffset < 0)
              Positioned(
                  right: 0,
                  child: Container(
                      color: Colors.blue,
                      width: -_dragOffset,
                      height: 100,
                      alignment: Alignment.center,
                      child: const Text('Reply',
                          style: TextStyle(color: Colors.white)))),
            if (_dragOffset > 0)
              Positioned(
                  left: 0,
                  child: Container(
                      color: Colors.green,
                      width: _dragOffset,
                      height: 100,
                      alignment: Alignment.center,
                      child: const Text('Share',
                          style: TextStyle(color: Colors.white)))),
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Align(
                alignment:
                    widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.deepPurpleAccent
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(2, 2)),
                    ],
                  ),
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;

  const VideoPlayerWidget({Key? key, required this.url}) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                VideoPlayer(_controller),
                VideoProgressIndicator(_controller, allowScrubbing: true),
                IconButton(
                    icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white),
                    onPressed: () => setState(() => _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play())),
              ],
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }
}

