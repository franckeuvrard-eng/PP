import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petitpas/data/release_notes.dart';

void main() {
  test('les nouveautes commencent par la version de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(kReleaseNotes.first.version, version,
        reason: 'ajoutez une entree dans lib/data/release_notes.dart pour cette version');
  });

  test('chaque version a des nouveautes, sans doublon', () {
    expect(kReleaseNotes.map((n) => n.version).toSet().length, kReleaseNotes.length);
    for (final n in kReleaseNotes) {
      expect(n.items, isNotEmpty);
    }
  });
}
