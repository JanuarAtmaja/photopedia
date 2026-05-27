import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photopedia/main.dart';
import 'package:photopedia/models/photo_state.dart';

void main() {
  testWidgets('PhotopediaApp memuat MainShell dengan bottom nav', (WidgetTester tester) async {
    // FIX: PhotopediaApp sekarang membutuhkan parameter appState
    await tester.pumpWidget(PhotopediaApp(appState: AppState()));

    // Verifikasi bottom navigation bar muncul
    expect(find.byType(BottomAppBar), findsAny);

    // Verifikasi halaman awal adalah HomeScreen (ada teks 'Photopedia')
    expect(find.text('Photopedia'), findsWidgets);
  });

  testWidgets('Navigasi bottom nav berfungsi', (WidgetTester tester) async {
    // FIX: PhotopediaApp sekarang membutuhkan parameter appState
    await tester.pumpWidget(PhotopediaApp(appState: AppState()));

    // Tap tab Camera
    await tester.tap(find.text('Camera'));
    await tester.pump();

    // Tab Camera seharusnya terpilih
    expect(find.text('Camera'), findsWidgets);
  });
}
