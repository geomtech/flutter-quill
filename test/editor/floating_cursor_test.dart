import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuillController controller;

  setUp(() {
    controller = QuillController.basic();
  });

  tearDown(() {
    controller.dispose();
  });

  Future<QuillRawEditorState> pumpEditor(
    WidgetTester tester, {
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuillEditor.basic(
            controller: controller,
            config: QuillEditorConfig(autoFocus: true, padding: padding),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<QuillRawEditorState>(find.byType(QuillRawEditor));
  }

  group('Caret rect', () {
    testWidgets('includes the horizontal offset of the child', (tester) async {
      controller.document.insert(0, 'Hello world');
      final editorState = await pumpEditor(
        tester,
        padding: const EdgeInsets.only(left: 40),
      );
      final renderEditor = editorState.renderEditor;

      const position = TextPosition(offset: 3);
      final caretRect = renderEditor.getLocalRectForCaret(position);
      final endpoint = renderEditor
          .getEndpointsForSelection(TextSelection.fromPosition(position))
          .single;

      expect(caretRect.left, moreOrLessEquals(endpoint.point.dx));
      expect(caretRect.left, greaterThanOrEqualTo(40));
    });
  });

  group('Floating cursor', () {
    testWidgets('commits the selection once when the gesture ends', (
      tester,
    ) async {
      controller
        ..document.insert(0, 'Hello world')
        ..updateSelection(
          const TextSelection.collapsed(offset: 0),
          ChangeSource.local,
        );
      final editorState = await pumpEditor(tester);

      editorState
        ..updateFloatingCursor(
          RawFloatingCursorPoint(
            offset: Offset.zero,
            state: FloatingCursorDragState.Start,
          ),
        )
        ..updateFloatingCursor(
          RawFloatingCursorPoint(
            offset: const Offset(60, 0),
            state: FloatingCursorDragState.Update,
          ),
        );
      await tester.pump();

      // The selection is not updated while the gesture is in progress.
      expect(controller.selection, const TextSelection.collapsed(offset: 0));

      editorState.updateFloatingCursor(
        RawFloatingCursorPoint(state: FloatingCursorDragState.End),
      );
      await tester.pumpAndSettle();

      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, greaterThan(0));
    });

    testWidgets('ending the gesture without any update keeps the selection', (
      tester,
    ) async {
      controller
        ..document.insert(0, 'Hello world')
        ..updateSelection(
          const TextSelection.collapsed(offset: 5),
          ChangeSource.local,
        );
      final editorState = await pumpEditor(tester);

      editorState
        ..updateFloatingCursor(
          RawFloatingCursorPoint(
            offset: Offset.zero,
            state: FloatingCursorDragState.Start,
          ),
        )
        ..updateFloatingCursor(
          RawFloatingCursorPoint(state: FloatingCursorDragState.End),
        );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
    });

    testWidgets('ignores an update without a start', (tester) async {
      controller.document.insert(0, 'Hello world');
      final editorState = await pumpEditor(tester);

      editorState.updateFloatingCursor(
        RawFloatingCursorPoint(
          offset: const Offset(20, 0),
          state: FloatingCursorDragState.Update,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
