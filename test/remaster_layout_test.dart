import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/remaster_shell.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/note_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final size in [
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1366, 768),
    const Size(1440, 900),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Start fits ${size.width}x${size.height} dark=$dark text=$scale',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var added = 0;
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              MaterialApp(
                theme: buildRemasterTheme(
                  dark ? Brightness.dark : Brightness.light,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: const ValueKey('capture'),
                  child: RemasterShell(
                    name: 'Adrian',
                    syncStatus: 'Lokalnie',
                    tasks: const [],
                    notes: const [],
                    tasksContent: const Center(child: Text('Lista zadań')),
                    notesContent: const Center(child: Text('Lista notatek')),
                    onAddTask: () => added++,
                    onAddNote: () {},
                    onOpenTask: (_) {},
                    onOpenNote: (_) {},
                    onCompleteTask: (_) {},
                    onOpenFocus: (_) {},
                    onLegacy: () {},
                    themeMode: ThemeMode.system,
                    onThemeMode: (_) {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(
              find.byKey(const ValueKey('remaster-now')),
            );
            await tester.tap(find.byKey(const ValueKey('remaster-now')));
            expect(added, 1);
            expect(tester.takeException(), isNull);
            if (scale == 1 && (size.width == 390 || size.width == 1366)) {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpWidget(
                MaterialApp(
                  theme: buildRemasterTheme(
                    dark ? Brightness.dark : Brightness.light,
                  ),
                  home: RepaintBoundary(
                    key: const ValueKey('capture'),
                    child: RemasterShell(
                      name: 'Adrian',
                      syncStatus: 'Zsynchronizowano',
                      tasks: const [
                        TaskItem(
                          id: 'a',
                          title: 'Dopracować pomysł na aplikację',
                          status: 'todo',
                          category: 'Praca',
                          pinnedToday: true,
                        ),
                        TaskItem(
                          id: 'b',
                          title: 'Wyjść na dłuższy spacer',
                          status: 'todo',
                          category: 'Dom',
                        ),
                        TaskItem(
                          id: 'c',
                          title: 'Zaplanować spokojny weekend',
                          status: 'todo',
                          category: 'Osobiste',
                        ),
                      ],
                      notes: [
                        NoteItem(
                          id: 'n',
                          title: 'Pomysły, do których chcę wrócić',
                          pinned: true,
                          blocks: [
                            NoteBlock.text(
                              id: 't',
                              text: 'Mniej pośpiechu. Więcej miejsca na rzeczy, które naprawdę lubię robić.',
                            ),
                          ],
                        ),
                        NoteItem(
                          id: 'm',
                          title: 'Na najbliższe dni',
                          blocks: [
                            NoteBlock.text(
                              id: 'u',
                              text: 'Dobra książka, nowa trasa na spacer i trochę czasu bez telefonu.',
                            ),
                          ],
                        ),
                      ],
                      tasksContent: const SizedBox(),
                      notesContent: const SizedBox(),
                      onAddTask: () {},
                      onAddNote: () {},
                      onOpenTask: (_) {},
                      onOpenNote: (_) {},
                      onCompleteTask: (_) {},
                      onOpenFocus: (_) {},
                      onLegacy: () {},
                      themeMode: ThemeMode.system,
                      onThemeMode: (_) {},
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('capture')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final dir = Directory('build/remaster-previews');
                await dir.create(recursive: true);
                await File(
                  '${dir.path}/start-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          },
        );
      }
    }
  }
}
