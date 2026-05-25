import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photopedia/main.dart';

void main() {
  testWidgets('PhotopediaApp memuat MainShell dengan bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotopediaApp());

    // Verifikasi bottom navigation bar muncul
    expect(find.byType(BottomAppBar), findsAny);

    // Verifikasi halaman awal adalah HomeScreen (ada teks 'Photopedia')
    expect(find.text('Photopedia'), findsWidgets);
  });

  testWidgets('Navigasi bottom nav berfungsi', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotopediaApp());

    // Tap tab Camera
    await tester.tap(find.text('Camera'));
    await tester.pump();

    // Tab Camera seharusnya terpilih
    expect(find.text('Camera'), findsWidgets);
  });
}
