import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
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
  String? _selectedEvaluationStatus;
  final TextEditingController _noteController = TextEditingController();
  final List<String> _selectedPhotoPaths = [];

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

  Future<void> _pickPhotos() async {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Sélectionner de la galerie (multiples)'),
                onTap: () async {
                  Navigator.pop(context);
                  final List<XFile> images = await picker.pickMultiImage();
                  for (final img in images) {
                    final relPath = await provider.saveXFileToDocs(img, 'activities');
                    final absPath = provider.getAbsolutePath(relPath);
                    if (absPath != null) {
                      setState(() {
                        _selectedPhotoPaths.add(absPath);
                      });
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    final relPath = await provider.saveXFileToDocs(image, 'activities');
                    final absPath = provider.getAbsolutePath(relPath);
                    if (absPath != null) {
                      setState(() {
                        _selectedPhotoPaths.add(absPath);
                      });
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos associées',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(Icons.add_a_photo, color: Colors.grey, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              ..._selectedPhotoPaths.asMap().entries.map((entry) {
                final int index = entry.key;
                final String path = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(path.replaceFirst('file://', '')),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPhotoPaths.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    // Default selection of evaluation status if null
    if (_selectedEvaluationStatus == null && provider.evaluationStatuses.isNotEmpty) {
      _selectedEvaluationStatus = provider.evaluationStatuses.first;
    }

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

                // Customizable Evaluation Status
                if (provider.evaluationStatuses.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedEvaluationStatus,
                    decoration: const InputDecoration(
                      labelText: 'Statut de l\'évaluation',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.star_border),
                    ),
                    items: provider.evaluationStatuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedEvaluationStatus = val),
                  ),
                  const SizedBox(height: 16),
                ],

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

                const SizedBox(height: 20),

                // Multi-Photo Selector Widget
                _buildPhotoSelector(),

                const SizedBox(height: 20),

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
                      ? () async {
                          // Copy all picked photos permanently to Documents
                          final List<String> savedRelativePaths = [];
                          for (final absPath in _selectedPhotoPaths) {
                            if (absPath.contains('activities/')) {
                              final filename = absPath.split('activities/').last;
                              savedRelativePaths.add('activities/$filename');
                            } else if (File(absPath.replaceFirst('file://', '')).existsSync()) {
                              final relPath = await provider.saveImageToDocs(absPath, 'activities');
                              savedRelativePaths.add(relPath);
                            }
                          }

                          final log = ActivityLog(
                            id: 'log_${DateTime.now().millisecondsSinceEpoch}',
                            childId: _selectedChildId!,
                            activityTypeId: _selectedActivityTypeId!,
                            timestamp: DateTime.now(),
                            emotion: _selectedEmotion,
                            note: _noteController.text.trim(),
                            photoPaths: savedRelativePaths,
                            evaluationStatus: _selectedEvaluationStatus,
                          );
                          provider.logActivity(log);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Activité enregistrée avec succès !')),
                            );
                            setState(() {
                              _selectedChildId = null;
                              _selectedActivityTypeId = null;
                              _noteController.clear();
                              _selectedPhotoPaths.clear();
                            });
                          }
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

  // Feedback states
  String? _scanMessage;
  bool _isErrorMessage = false;
  Timer? _messageTimer;

  // Duplicate prevention
  String? _lastScannedValue;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    _scannedChildId = widget.initialChildId;
    _scannedActivityTypeId = widget.initialActivityTypeId;
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showScanMessage(String message, {required bool isError}) {
    _messageTimer?.cancel();
    setState(() {
      _scanMessage = message;
      _isErrorMessage = isError;
    });
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _scanMessage = null;
        });
      }
    });
  }

  void _triggerErrorVibration() {
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.vibrate();
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isClosed) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      final now = DateTime.now();
      if (_lastScannedValue == rawValue &&
          _lastScanTime != null &&
          now.difference(_lastScanTime!).inSeconds < 2) {
        continue;
      }

      _lastScannedValue = rawValue;
      _lastScanTime = now;

      debugPrint('Detected QR Code: $rawValue');

      if (rawValue.startsWith('PETITPAS:CHILD:')) {
        final childId = rawValue.replaceFirst('PETITPAS:CHILD:', '');
        final childIndex = widget.children.indexWhere((c) => c.id == childId);
        if (childIndex >= 0) {
          HapticFeedback.mediumImpact();
          setState(() {
            _scannedChildId = childId;
          });
          _showScanMessage('Élève détecté : ${widget.children[childIndex].firstname}', isError: false);
          _checkAndAutoClose();
        } else {
          _triggerErrorVibration();
          _showScanMessage('Élève inconnu dans la base', isError: true);
        }
      } else if (rawValue.startsWith('PETITPAS:ACT:')) {
        final actId = rawValue.replaceFirst('PETITPAS:ACT:', '');
        final actIndex = widget.activityTypes.indexWhere((a) => a.id == actId);
        if (actIndex >= 0) {
          HapticFeedback.mediumImpact();
          setState(() {
            _scannedActivityTypeId = actId;
          });
          _showScanMessage('Atelier détecté : ${widget.activityTypes[actIndex].name}', isError: false);
          _checkAndAutoClose();
        } else {
          _triggerErrorVibration();
          _showScanMessage('Atelier inconnu dans la base', isError: true);
        }
      } else {
        _triggerErrorVibration();
        _showScanMessage('QR Code non reconnu par PetitPas', isError: true);
      }
    }
  }

  void _checkAndAutoClose() {
    if (_scannedChildId != null && _scannedActivityTypeId != null) {
      _isClosed = true;
      Future.delayed(const Duration(milliseconds: 1200), () async {
        await _controller.stop();
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
                  onPressed: () async {
                    await _controller.stop();
                    if (mounted) Navigator.pop(context);
                  },
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

          // Floating notification banner inside camera preview
          if (_scanMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isErrorMessage ? Colors.red.withOpacity(0.9) : const Color(0xFF4E9F3D).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _isErrorMessage ? Icons.error_outline : Icons.check_circle_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scanMessage!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating info panel
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
                        onPressed: () async {
                          await _controller.stop();
                          if (mounted) {
                            Navigator.pop(context, {
                              'childId': _scannedChildId,
                              'activityTypeId': _scannedActivityTypeId,
                            });
                          }
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
