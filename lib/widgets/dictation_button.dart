import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Bouton micro qui dicte du texte dans [controller], en francais.
///
/// Le texte reconnu s'ajoute a la suite de ce qui est deja ecrit, en direct
/// pendant qu'on parle ; un second appui arrete. Le texte deja saisi n'est
/// jamais remplace. A placer en `suffixIcon` d'un champ.
class DictationButton extends StatefulWidget {
  const DictationButton({super.key, required this.controller, this.onChanged});

  final TextEditingController controller;

  /// Appele a chaque mise a jour du texte dicte.
  final ValueChanged<String>? onChanged;

  @override
  State<DictationButton> createState() => _DictationButtonState();
}

class _DictationButtonState extends State<DictationButton> {
  // Une seule instance pour toute l'application : la reconnaissance du
  // systeme ne supporte qu'une ecoute a la fois.
  static final SpeechToText _speech = SpeechToText();
  static bool _ready = false;
  static String? _localeId;

  bool _listening = false;
  String _base = '';

  Future<bool> _init() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        onStatus: (_) {},
        onError: (_) {},
      );
      if (_ready) {
        final locales = await _speech.locales();
        _localeId = locales
            .map((l) => l.localeId)
            .firstWhere((id) => id.toLowerCase().startsWith('fr'), orElse: () => 'fr_FR');
      }
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!await _init()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Dictée indisponible : autorisez le micro et la reconnaissance vocale dans les Réglages.'),
      ));
      return;
    }
    _base = widget.controller.text.trimRight();
    setState(() => _listening = true);
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        partialResults: true,
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(minutes: 2),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    final words = r.recognizedWords.trim();
    final text = words.isEmpty
        ? _base
        : (_base.isEmpty ? _capitalize(words) : '$_base $words');
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
    if (r.finalResult && mounted) setState(() => _listening = false);
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  void dispose() {
    if (_listening) _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _listening ? 'Arrêter la dictée' : 'Dicter',
      icon: Icon(_listening ? Icons.stop_circle : Icons.mic_none,
          color: _listening ? Colors.red : const Color(0xFF4E9F3D)),
      onPressed: _toggle,
    );
  }
}
