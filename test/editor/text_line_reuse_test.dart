import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuillController controller;
  late Map<String, int> spanBuilds;

  setUp(() {
    controller = QuillController(
      document: Document.fromJson([
        {'insert': 'First line\nSecond line\n'},
        {'insert': 'Bullet one'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'Bullet two'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    spanBuilds = {};
  });

  tearDown(() {
    controller.dispose();
  });

  InlineSpan countingSpanBuilder(
    BuildContext context,
    Node node,
    int nodeOffset,
    String text,
    TextStyle? style,
    GestureRecognizer? recognizer,
  ) {
    spanBuilds[text] = (spanBuilds[text] ?? 0) + 1;
    return defaultSpanBuilder(
      context,
      node,
      nodeOffset,
      text,
      style,
      recognizer,
    );
  }

  Widget editor({
    TextSpanBuilder? textSpanBuilder,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    DefaultStyles? customStyles,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: QuillEditor.basic(
          controller: controller,
          config: QuillEditorConfig(
            textSpanBuilder: textSpanBuilder ?? countingSpanBuilder,
            padding: padding,
            customStyles: customStyles,
          ),
        ),
      ),
    );
  }

  testWidgets('selection changes reuse the built lines', (tester) async {
    await tester.pumpWidget(editor());
    // The first selection change requests focus, which rebuilds the editor.
    controller.updateSelection(
      const TextSelection.collapsed(offset: 1),
      ChangeSource.local,
    );
    await tester.pump();
    final baseline = Map.of(spanBuilds);
    expect(baseline.keys, [
      'First line',
      'Second line',
      'Bullet one',
      'Bullet two',
    ]);

    for (var offset = 1; offset < 30; offset += 3) {
      controller.updateSelection(
        TextSelection(baseOffset: 0, extentOffset: offset),
        ChangeSource.local,
      );
      await tester.pump();
    }

    expect(spanBuilds, baseline);
  });

  testWidgets('document edits rebuild only the edited lines', (tester) async {
    await tester.pumpWidget(editor());

    controller.replaceText(
      0,
      0,
      'New ',
      const TextSelection.collapsed(offset: 4),
    );
    await tester.pump();

    expect(spanBuilds['New First line'], 1);
    expect(spanBuilds['Second line'], 1);
    expect(spanBuilds['Bullet one'], 1);
    expect(find.text('New First line', findRichText: true), findsOneWidget);

    controller.replaceText(
      37,
      0,
      '!',
      const TextSelection.collapsed(offset: 38),
    );
    await tester.pump();

    expect(spanBuilds['Bullet one!'], 1);
    expect(spanBuilds['New First line'], 1);
    expect(spanBuilds['Bullet two'], 1);
    expect(find.text('Bullet one!', findRichText: true), findsOneWidget);
  });

  testWidgets('line structure changes rebuild the affected lines', (
    tester,
  ) async {
    await tester.pumpWidget(editor());
    // The first selection change requests focus, which rebuilds the editor.
    controller.updateSelection(
      const TextSelection.collapsed(offset: 12),
      ChangeSource.local,
    );
    await tester.pump();
    final baseline = Map.of(spanBuilds);

    controller.formatSelection(Attribute.h1);
    await tester.pump();
    expect(spanBuilds['Second line'], baseline['Second line']! + 1);
    expect(spanBuilds['First line'], baseline['First line']);

    // Splitting a line creates a new line and changes the edited one.
    controller.replaceText(
      5,
      0,
      '\n',
      const TextSelection.collapsed(offset: 6),
    );
    await tester.pump();
    expect(spanBuilds['First'], 1);
    expect(spanBuilds[' line'], 1);
    expect(spanBuilds['Bullet two'], baseline['Bullet two']);

    // Undo merges the lines back.
    controller.undo();
    await tester.pump();
    expect(find.text('First line', findRichText: true), findsOneWidget);
    expect(spanBuilds['Bullet two'], baseline['Bullet two']);

    // A new item inside the list keeps the other items.
    final bulletOneEnd =
        controller.document.toPlainText().indexOf('Bullet one') + 10;
    controller.replaceText(
      bulletOneEnd,
      0,
      '\n',
      TextSelection.collapsed(offset: bulletOneEnd + 1),
    );
    await tester.pump();
    expect(spanBuilds['Bullet two'], baseline['Bullet two']);
    expect(spanBuilds['First line'], baseline['First line']! + 1);
  });

  testWidgets('formatting rebuilds the lines', (tester) async {
    await tester.pumpWidget(editor());

    controller
      ..updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      )
      ..formatSelection(Attribute.bold);
    await tester.pump();

    expect(spanBuilds['First'], 1);
    expect(spanBuilds[' line'], 1);
    expect(spanBuilds['Bullet two'], 1);
  });

  testWidgets('a new editor config rebuilds the lines', (tester) async {
    await tester.pumpWidget(editor());

    InlineSpan otherSpanBuilder(
      BuildContext context,
      Node node,
      int nodeOffset,
      String text,
      TextStyle? style,
      GestureRecognizer? recognizer,
    ) =>
        countingSpanBuilder(context, node, nodeOffset, text, style, recognizer);

    await tester.pumpWidget(editor(textSpanBuilder: otherSpanBuilder));

    expect(spanBuilds.values, everyElement(2));
  });

  testWidgets('rebuilding the editor with the same line inputs reuses lines', (
    tester,
  ) async {
    const styles = DefaultStyles();
    await tester.pumpWidget(editor(customStyles: styles));
    final baseline = Map.of(spanBuilds);

    for (var bottom = 10.0; bottom <= 50; bottom += 10) {
      await tester.pumpWidget(
        editor(
          customStyles: styles,
          padding: EdgeInsets.only(bottom: bottom),
        ),
      );
    }

    expect(spanBuilds, baseline);
  });

  testWidgets('new custom styles rebuild the lines', (tester) async {
    await tester.pumpWidget(editor(customStyles: const DefaultStyles()));

    await tester.pumpWidget(
      editor(
        customStyles: const DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            TextStyle(fontSize: 20),
            HorizontalSpacing.zero,
            VerticalSpacing.zero,
            VerticalSpacing.zero,
            null,
          ),
        ),
      ),
    );

    expect(spanBuilds.values, everyElement(2));
  });

  testWidgets('switching read-only mode rebuilds the lines', (tester) async {
    await tester.pumpWidget(editor());

    controller.readOnly = true;
    await tester.pumpWidget(editor());

    expect(spanBuilds.values, everyElement(2));
  });
}
