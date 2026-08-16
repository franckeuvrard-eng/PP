import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../providers/app_provider.dart';

/// Enregistrement, lecture et suppression d'une note vocale unique.
///
/// [audioPath] est le chemin relatif deja enregistre (ou `null`). Chaque
/// changement (nouvel enregistrement ou suppression) est signale via
/// [onChanged], a charge de l'appelant de le reporter sur son modele —
/// le widget ne connait pas [ActivityLog].
class VoiceNoteField extends StatefulWidget {
  final AppStateProvider provider;
  final String? audioPath;
  final ValueChanged<String?> onChanged;

  const VoiceNoteField({
    super.key,
    required this.provider,
    required this.audioPath,
    required this.onChanged,
  });

  @override
  State<VoiceNoteField> createState() => _VoiceNoteFieldState();
}

class _VoiceNoteFieldState extends State<VoiceNoteField> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _pendingRelativePath;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autorisation micro refusée : activez-la dans Réglages iOS.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final relativePath = await widget.provider.prepareAudioPath();
    final absolutePath = widget.provider.getAbsolutePath(relativePath)!;
    await _recorder.start(const RecordConfig(), path: absolutePath);
    _pendingRelativePath = relativePath;
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() => _isRecording = false);
    if (_pendingRelativePath != null) {
      widget.onChanged(_pendingRelativePath);
      _pendingRelativePath = null;
    }
  }

  Future<void> _togglePlayback() async {
    final absolutePath = widget.provider.getAbsolutePath(widget.audioPath);
    if (absolutePath == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(absolutePath));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
            const SizedBox(width: 8),
            const Expanded(child: Text('Enregistrement en cours…', style: TextStyle(fontSize: 13))),
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              tooltip: 'Arrêter',
              onPressed: _stopRecording,
            ),
          ],
        ),
      );
    }

    if (widget.audioPath != null && widget.audioPath!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4E9F3D).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: const Color(0xFF4E9F3D)),
              onPressed: _togglePlayback,
            ),
            const Expanded(child: Text('Note vocale', style: TextStyle(fontSize: 13))),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Supprimer la note vocale',
              onPressed: () async {
                await _player.stop();
                widget.onChanged(null);
              },
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _startRecording,
      icon: const Icon(Icons.mic, size: 18),
      label: const Text('Ajouter une note vocale'),
    );
  }
}
