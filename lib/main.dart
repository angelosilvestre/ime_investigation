import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: TextInputExample(),
      ),
    ),
  );
}

class TextInputExample extends StatefulWidget {
  const TextInputExample({Key? key}) : super(key: key);

  @override
  State<TextInputExample> createState() => _TextInputExampleState();
}

class _TextInputExampleState extends State<TextInputExample> implements DeltaTextInputClient {
  final emptyParagraphPlaceholder = '. ';
  final firstParagraphText = 'Abc';

  TextInputConnection? _inputConnection;
  late TextEditingValue _currentEditingValue;

  @override
  void initState() {
    super.initState();
    _currentEditingValue = _firstParagraphEditingValue;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    TextEditingValue newEditingValue = _currentEditingValue;

    for (final delta in textEditingDeltas) {
      print('IME: received delta $delta');
      if (delta.oldText != _currentEditingValue.text) {
        print('Out of sync with IME');
        print('OS text - ${delta.oldText}');
        print('OS selection - ${delta.selection}');
        print('OS composing - ${delta.composing}');

        print('App text - ${_currentEditingValue.text}');
        print('App selection - ${_currentEditingValue.selection}');
        print('App composing - ${_currentEditingValue.composing}');
      }
      if (delta is TextEditingDeltaInsertion) {
        newEditingValue = _applyInsertionDelta(newEditingValue, delta);
      } else if (delta is TextEditingDeltaDeletion) {
        newEditingValue = _applyDeletionDelta(newEditingValue, delta);
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        newEditingValue = _applyNonTextDelta(newEditingValue, delta);
      } else {
        newEditingValue = delta.apply(newEditingValue);
      }
      if (newEditingValue.text.isEmpty) {
        newEditingValue = _placeHolderEditingValue;
      }
    }

    _syncWithOS(newEditingValue);
    setState(() {
      _currentEditingValue = newEditingValue;
    });
  }

  void _syncWithOS(TextEditingValue textEditingValue) async {
    print('sending to the OS: $textEditingValue');
    _inputConnection?.setEditingState(textEditingValue);
  }

  void _run() {
    _detach();
    _attach();

    _syncWithOS(_currentEditingValue);
  }

  void _attach() {
    if (_inputConnection != null) {
      return;
    }
    _inputConnection = TextInput.attach(
      this,
      const TextInputConfiguration(
        enableDeltaModel: true,
        inputType: TextInputType.multiline,
        inputAction: TextInputAction.newline,
      ),
    );
    _inputConnection!.show();
  }

  void _detach() {
    _inputConnection?.close();
    _inputConnection = null;
  }

  /// Placehold which the editor sends to the framework to represent an empty paragraph.
  TextEditingValue get _placeHolderEditingValue => TextEditingValue(
        text: emptyParagraphPlaceholder,
        selection: const TextSelection.collapsed(offset: 2),
        composing: const TextRange(start: -1, end: -1),
      );

  /// Represents a paragraph of text.
  TextEditingValue get _firstParagraphEditingValue => TextEditingValue(
        text: firstParagraphText,
        selection: const TextSelection.collapsed(offset: 3),
        composing: const TextRange(start: -1, end: -1),
      );

  TextEditingValue _applyInsertionDelta(TextEditingValue current, TextEditingDeltaInsertion delta) {
    TextEditingValue newEditingValue = current;
    if (delta.textInserted == "\n") {
      // In SuperEditor, when we receive a new line, a new empty paragraph is created.
      // We send a placeholder to the IME, so the user is able to press backspace.
      // Upon the deletion delta, SuperEditor removes the empty paragraph and syncs
      // the previous paragraph with the IME.
      newEditingValue = _placeHolderEditingValue;

      print('User pressed newLine - creating a new paragraph.');
    } else if (delta.oldText == emptyParagraphPlaceholder) {
      // The text contains only the placeholder, so we are in an empty paragraph.
      // The inserted text should be the new text.
      newEditingValue = TextEditingValue(
        text: delta.textInserted,
        composing: const TextRange(start: 0, end: 1),
        selection: const TextSelection.collapsed(offset: 1),
      );

      print('User typed in an empty paragraph.');
    } else {
      newEditingValue = delta.apply(current);
    }

    return newEditingValue;
  }

  TextEditingValue _applyDeletionDelta(TextEditingValue current, TextEditingDeltaDeletion delta) {
    if (delta.oldText == emptyParagraphPlaceholder) {
      print('User pressed backspace in an empty paragraph.');

      // When the IME contains only the placeholder, it means that the user is pressing backspace
      // in an empty paragraph.
      // We remove the current paragraph and sync the preceding paragraph with the IME.
      return _firstParagraphEditingValue;
    }
    return delta.apply(current);
  }

  TextEditingValue _applyNonTextDelta(TextEditingValue current, TextEditingDeltaNonTextUpdate delta) {
    print("IME: Non-text change:");
    print("IME: OS-side text      - ${delta.oldText}");
    print("IME: OS-side selection - ${delta.selection}");
    print("IME: OS-side composing - ${delta.composing}");
    return current.copyWith(composing: delta.composing);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _currentEditingValue.toString(),
            textAlign: TextAlign.center,
          ),
          ElevatedButton(
            onPressed: _run,
            child: const Text('Attach to IME'),
          ),
        ],
      ),
    );
  }

  @override
  void connectionClosed() {}

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  TextEditingValue? get currentTextEditingValue => null;

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void performAction(TextInputAction action) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void showToolbar() {}

  @override
  void updateEditingValue(TextEditingValue value) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}
}
