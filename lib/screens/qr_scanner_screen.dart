import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/app_provider.dart';
import '../models/activity.dart';
import '../models/child.dart';
import '../models/activity_type.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  String? _selectedChildId;
  String? _selectedActivityTypeId;
  String _selectedEmotion = '😊 Joyeux';
  final TextEditingController _noteController = TextEditingController();

  Future<void> _startQrScanner(BuildContext context, AppStateProvider provider) async {
    final result = await Navigator.push<Map<String, String?>>(
      context,
      MaterialPageRoute(
        builder: (context) => QrCameraScannerOverlay(
          children: provider.children,
          activityTypes: provider.activityTypes,
          initialChildId: _selectedChildId,
          initialActivityTypeId: _selectedActivityTypeId,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (result['childId'] != null) {
          _selectedChildId = result['childId'];
        }
        if (result['activityTypeId'] != null) {
          _selectedActivityTypeId = result['activityTypeId'];
        }
      });

      if (_selectedChildId != null && _selectedActivityTypeId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Élève et Atelier associés avec succès !'),
            backgroundColor: Color(0xFF4E9F3D),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.qr_code_scanner, size: 48, color: Color(0xFFFF7043)),
                const SizedBox(height: 10),
                const Text(
                  'Association QR Code Express',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scannez le badge élève puis la fiche d\'atelier en classe',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
                ),

                const SizedBox(height: 24),

                // Open Camera Button
                ElevatedButton.icon(
                  onPressed: () => _startQrScanner(context, provider),
                  icon: const Icon(Icons.photo_camera, size: 22),
                  label: const Text('Ouvrir l\'appareil photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7043),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('OU SÉLECTION MANUELLE', style: TextStyle(fontSize: 10, color: Color(0xFFA0AEC0), fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 20),

                // Manual selectors
                DropdownButtonFormField<String>(
                  value: _selectedChildId,
                  decoration: const InputDecoration(
                    labelText: 'Élève sélectionné',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: provider.children.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.firstname} ${c.lastname ?? ""}'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedChildId = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedActivityTypeId,
                  decoration: const InputDecoration(
                    labelText: 'Atelier sélectionné',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: provider.activityTypes.map((a) {
                    return DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedActivityTypeId = val),
                ),

                const SizedBox(height: 20),

                // Emotion Selector
                const Text(
                  'Humeur / État d\'esprit',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedEmotion,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.mood),
                  ),
                  items: const [
                    DropdownMenuItem(value: '😊 Joyeux', child: Text('😊 Joyeux')),
                    DropdownMenuItem(value: '🎯 Concentré', child: Text('🎯 Concentré')),
                    DropdownMenuItem(value: '😴 Fatigué', child: Text('😴 Fatigué')),
                    DropdownMenuItem(value: '😢 Triste', child: Text('😢 Triste')),
                    DropdownMenuItem(value: '😡 En colère', child: Text('😡 En colère')),
                  ],
                  onChanged: (val) => setState(() => _selectedEmotion = val ?? '😊 Joyeux'),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Observation / Note pédagogique',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.comment),
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: (_selectedChildId != null && _selectedActivityTypeId != null)
                      ? () {
                          final log = ActivityLog(
                            id: 'log_${DateTime.now().millisecondsSinceEpoch}',
                            childId: _selectedChildId!,
                            activityTypeId: _selectedActivityTypeId!,
                            timestamp: DateTime.now(),
                            emotion: _selectedEmotion,
                            note: _noteController.text.trim(),
                          );
                          provider.logActivity(log);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Activité enregistrée avec succès !')),
                          );
                          setState(() {
                            _selectedChildId = null;
                            _selectedActivityTypeId = null;
                            _noteController.clear();
                          });
                        }
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Valider et Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E9F3D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Fullscreen Camera Scanner Overlay
class QrCameraScannerOverlay extends StatefulWidget {
  final List<Child> children;
  final List<ActivityType> activityTypes;
  final String? initialChildId;
  final String? initialActivityTypeId;

  const QrCameraScannerOverlay({
    super.key,
    required this.children,
    required this.activityTypes,
    this.initialChildId,
    this.initialActivityTypeId,
  });

  @override
  State<QrCameraScannerOverlay> createState() => _QrCameraScannerOverlayState();
}

class _QrCameraScannerOverlayState extends State<QrCameraScannerOverlay> {
  String? _scannedChildId;
  String? _scannedActivityTypeId;
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    _scannedChildId = widget.initialChildId;
    _scannedActivityTypeId = widget.initialActivityTypeId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isClosed) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      debugPrint('Detected QR Code: $rawValue');

      if (rawValue.startsWith('PETITPAS:CHILD:')) {
        final childId = rawValue.replaceFirst('PETITPAS:CHILD:', '');
        final childExists = widget.children.any((c) => c.id == childId);
        if (childExists && _scannedChildId != childId) {
          setState(() {
            _scannedChildId = childId;
          });
          _checkAndAutoClose();
        }
      } else if (rawValue.startsWith('PETITPAS:ACT:')) {
        final actId = rawValue.replaceFirst('PETITPAS:ACT:', '');
        final actExists = widget.activityTypes.any((a) => a.id == actId);
        if (actExists && _scannedActivityTypeId != actId) {
          setState(() {
            _scannedActivityTypeId = actId;
          });
          _checkAndAutoClose();
        }
      }
    }
  }

  void _checkAndAutoClose() {
    if (_scannedChildId != null && _scannedActivityTypeId != null) {
      _isClosed = true;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.pop(context, {
            'childId': _scannedChildId,
            'activityTypeId': _scannedActivityTypeId,
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Child? scannedChild;
    if (_scannedChildId != null) {
      scannedChild = widget.children.firstWhere((c) => c.id == _scannedChildId);
    }

    ActivityType? scannedActivity;
    if (_scannedActivityTypeId != null) {
      scannedActivity = widget.activityTypes.firstWhere((a) => a.id == _scannedActivityTypeId);
    }

    final double cutOutSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Custom Cutout Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlayPainter(
                borderColor: const Color(0xFFFF7043),
                borderWidth: 4,
                borderRadius: 24,
                cutOutSize: cutOutSize,
              ),
            ),
          ),

          // Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Scanner Express',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: ValueListenableBuilder(
                    valueListenable: _controller.torchState,
                    builder: (context, state, child) {
                      switch (state as TorchState) {
                        case TorchState.off:
                          return const Icon(Icons.flash_off, color: Colors.white, size: 24);
                        case TorchState.on:
                          return const Icon(Icons.flash_on, color: Color(0xFFFFD54F), size: 24);
                      }
                    },
                  ),
                  onPressed: () => _controller.toggleTorch(),
                ),
              ],
            ),
          ),

          // Footer info panel
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            scannedChild != null ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: scannedChild != null ? const Color(0xFF4E9F3D) : Colors.white54,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              scannedChild != null
                                  ? 'Élève : ${scannedChild.firstname} ${scannedChild.lastname ?? ""}'
                                  : 'Scannez le badge de l\'élève...',
                              style: TextStyle(
                                color: scannedChild != null ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: scannedChild != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            scannedActivity != null ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: scannedActivity != null ? const Color(0xFF4E9F3D) : Colors.white54,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              scannedActivity != null
                                  ? 'Atelier : ${scannedActivity.name}'
                                  : 'Scannez le QR Code de l\'atelier...',
                              style: TextStyle(
                                color: scannedActivity != null ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: scannedActivity != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(context, {
                            'childId': _scannedChildId,
                            'activityTypeId': _scannedActivityTypeId,
                          });
                        },
                        child: const Text('Valider la sélection', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the transparent camera cutout and borders
class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double cutOutSize;

  ScannerOverlayPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutOutSize,
      height: cutOutSize,
    );

    // Draw background with a hole in the middle
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Draw border around the cutout
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
