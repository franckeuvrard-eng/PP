import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/activity.dart';

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
              children: [
                const Icon(Icons.qr_code_scanner, size: 48, color: Color(0xFFFF7043)),
                const SizedBox(height: 10),
                const Text(
                  'Association QR Code Express',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scannez le badge élève puis la fiche d\'atelier en classe',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
                ),

                const SizedBox(height: 20),

                // Simulated Scanner Selectors for testing
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedChildId,
                        decoration: const InputDecoration(labelText: 'Élève scanné', border: OutlineInputBorder()),
                        items: provider.children.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.firstname} ${c.lastname ?? ""}'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedChildId = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedActivityTypeId,
                        decoration: const InputDecoration(labelText: 'Atelier scanné', border: OutlineInputBorder()),
                        items: provider.activityTypes.map((a) {
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedActivityTypeId = val),
                      ),
                    ],
                  ),
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

                const SizedBox(height: 20),

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
                  label: const Text('Valider et Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E9F3D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
