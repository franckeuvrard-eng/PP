import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../providers/app_provider.dart';

/// Pastille tapable qui lit une note vocale existante. Purement en lecture :
/// pour enregistrer ou supprimer une note vocale, voir [VoiceNoteField].
class VoiceNotePlayButton extends StatefulWidget {
  final AppStateProvider provider;
  final String audioPath;

  const VoiceNotePlayButton({super.key, required this.provider, required this.audioPath});

  @override
  State<VoiceNotePlayButton> createState() => _VoiceNotePlayButtonState();
}

class _VoiceNotePlayButtonState extends State<VoiceNotePlayButton> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final absolutePath = widget.provider.getAbsolutePath(widget.audioPath);
        if (absolutePath == null) return;
        if (_isPlaying) {
          await _player.pause();
        } else {
          await _player.play(DeviceFileSource(absolutePath));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF4E9F3D).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 14, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 4),
            const Text('Note vocale', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
          ],
        ),
      ),
    );
  }
}
