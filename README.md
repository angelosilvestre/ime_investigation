# IME Out of sync investigation

This repo simulates the way [SuperEditor](https://github.com/superlistapp/super_editor) interacts with the IME through the delta model, to demonstrate a crash that is ocurring.

When the user is editing an empty paragraph, `SuperEditor` sends a placeholder text to the OS. That way, the user is able to press backspace to remove the empty paragraph.

When the empty paragraph is removed, the preceding paragraph is selected. In this case, `SuperEditor` sends to the OS the text of the selected paragraph.

At some point, we are sending our new text to the OS and we are getting back a `TextEditingDeltaNonTextUpdate` with an outdated content. When we try to sync with the OS again, we get a crash from the framework.

We send our updated text to the OS:
```
I/flutter (17321): sending to the OS: TextEditingValue(text: ┤Ab├, selection: TextSelection.collapsed(offset: 2, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 0, end: 2))
```

Right after that we get back an outdated version:
```
I/flutter (17321): Out of sync with IME
I/flutter (17321): OS text - Abc
I/flutter (17321): OS selection - TextSelection.collapsed(offset: 3, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (17321): OS composing - TextRange(start: 0, end: 3)
```

When we try to sync with the OS again, we are sending the composing region we got from the `TextEditingDeltaNonTextUpdate`, which is invalid given our current content:
```
I/flutter (17321): sending to the OS: TextEditingValue(text: ┤Ab├, selection: TextSelection.collapsed(offset: 2, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 0, end: 3))
```

It seems that this engine method found in `shell\platform\android\io\flutter\embedding\android\FlutterView.java` is restarting the input and sending us the old value:
```java
// Called by the text input channel to update the text input plugin with the
// latest TextEditState from the framework.
@VisibleForTesting
void setTextInputEditingState(View view, TextInputChannel.TextEditState state) {
    if (!mRestartInputPending
        && mLastKnownFrameworkTextEditingState != null
        && mLastKnownFrameworkTextEditingState.hasComposing()) {
        // Also restart input if the framework (or the developer) decides to
        // change the composing region by itself (which is discouraged). Many IMEs
        // don't expect editors to commit composing text, so a restart is needed
        // to reset their internal states.
        mRestartInputPending = composingChanged(mLastKnownFrameworkTextEditingState, state);
        if (mRestartInputPending) {
            Log.i(TAG, "Composing region changed by the framework. Restarting the input method."); // This message is displayed in the logs
        }
    }

    mLastKnownFrameworkTextEditingState = state;
    mEditable.setEditingState(state);

    // Restart if needed. Restarting will also update the selection.
    if (mRestartInputPending) {
        mImm.restartInput(view);
        mRestartInputPending = false;
    }
}
```

## Steps to Reproduce

1. Run the app on Android
2. Tap "Attach to IME"
3. Press the new line button on the software keyboard
4. Type a
5. Press Backspace quickly 3 times

After step 5 a crash happens: 
```
E/flutter (17321): [ERROR:flutter/runtime/dart_vm_initializer.cc(41)] Unhandled Exception: 'package:flutter/src/services/text_input.dart': Failed assertion: line 986 pos 9: 'range.end >= 0 && range.end <= text.length': Range end 3 is out of text of length 2
```

Full logs:
```
I/flutter (17321): IME: received delta Instance of 'TextEditingDeltaInsertion'
I/flutter (17321): User pressed newLine - creating a new paragraph.
I/flutter (17321): sending to the OS: TextEditingValue(text: ┤. ├, selection: TextSelection.collapsed(offset: 2, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))

I/flutter (17321): IME: received delta Instance of 'TextEditingDeltaInsertion'
I/flutter (17321): User typed in an empty paragraph.
I/flutter (17321): sending to the OS: TextEditingValue(text: ┤a├, selection: TextSelection.collapsed(offset: 1, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 0, end: 1))

I/flutter (17321): IME: received delta Instance of 'TextEditingDeltaNonTextUpdate'
I/flutter (17321): IME: Non-text change:
I/flutter (17321): IME: OS-side text      - a
I/flutter (17321): IME: OS-side selection - TextSelection.collapsed(offset: 1, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (17321): IME: OS-side composing - TextRange(start: -1, end: -1)

I/flutter (17321): IME: received delta Instance of 'TextEditingDeltaNonTextUpdate'
I/flutter (17321): IME: Non-text change:
I/flutter (17321): IME: OS-side text      - a
I/flutter (17321): IME: OS-side selection - TextSelection.collapsed(offset: 1, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (17321): IME: OS-side composing - TextRange(start: 0, end: 1)

I/flutter (17321): IME: received delta Instance of 'TextEditingDeltaDeletion'
I/flutter (17321): sending to the OS: TextEditingValue(text: ┤. ├, selection: TextSelection.collapsed(offset: 2, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))

I/flutter (17321): IME: received delta Instance of 'TextEditingDeltaDeletion'
I/flutter (17321): User pressed backspace in an empty paragraph.

I/flutter (17321): sending to the OS: TextEditingValue(text: ┤Abc├, selection: TextSelection.collapsed(offset: 3, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))

I/flutter (17321): IME: received delta Instance of 'TextEditingDeltaNonTextUpdate'
I/flutter (17321): IME: Non-text change:
I/flutter (17321): IME: OS-side text      - Abc
I/flutter (17321): IME: OS-side selection - TextSelection.collapsed(offset: 3, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (17321): IME: OS-side composing - TextRange(start: -1, end: -1)

I/flutter (17321): IME: received delta Instance of 'TextEditingDeltaNonTextUpdate'
I/flutter (17321): IME: Non-text change:
I/flutter (17321): IME: OS-side text      - Abc
I/flutter (17321): IME: OS-side selection - TextSelection.collapsed(offset: 3, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (17321): IME: OS-side composing - TextRange(start: 0, end: 3)

I/flutter (17321): sending to the OS: TextEditingValue(text: ┤Abc├, selection: TextSelection.collapsed(offset: 3, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 0, end: 3))

I/TextInputPlugin(17321): Composing region changed by the framework. Restarting the input method.

I/flutter (17321): IME: received delta Instance of 'TextEditingDeltaDeletion'

I/flutter (17321): sending to the OS: TextEditingValue(text: ┤Ab├, selection: TextSelection.collapsed(offset: 2, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 0, end: 2))


I/flutter (17321): Out of sync with IME
I/flutter (17321): OS text - Abc
I/flutter (17321): OS selection - TextSelection.collapsed(offset: 3, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (17321): OS composing - TextRange(start: 0, end: 3)
I/flutter (17321): App text - Ab
I/flutter (17321): App selection - TextSelection.collapsed(offset: 2, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (17321): App composing - TextRange(start: 0, end: 2)

I/flutter (17321): IME: Non-text change:
I/flutter (17321): IME: OS-side text      - Abc
I/flutter (17321): IME: OS-side selection - TextSelection.collapsed(offset: 3, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (17321): IME: OS-side composing - TextRange(start: 0, end: 3)
I/flutter (17321): sending to the OS: TextEditingValue(text: ┤Ab├, selection: TextSelection.collapsed(offset: 2, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 0, end: 3))
E/flutter (17321): [ERROR:flutter/runtime/dart_vm_initializer.cc(41)] Unhandled Exception: 'package:flutter/src/services/text_input.dart': Failed assertion: line 986 pos 9: 'range.end >= 0 && range.end <= text.length': Range end 3 is out of text of length 2
E/flutter (17321): #0      _AssertionError._doThrowNew (dart:core-patch/errors_patch.dart:51:61)
E/flutter (17321): #1      _AssertionError._throwNew (dart:core-patch/errors_patch.dart:40:5)
E/flutter (17321): #2      TextEditingValue._textRangeIsValid
E/flutter (17321): #3      TextEditingValue.toJSON
E/flutter (17321): #4      TextInput._setEditingState
E/flutter (17321): #5      TextInputConnection.setEditingState
E/flutter (17321): #6      _TextInputExampleState._syncWithOS
E/flutter (17321): #7      _TextInputExampleState.updateEditingValueWithDeltas
E/flutter (17321): #8      TextInput._handleTextInputInvocation
E/flutter (17321): #9      TextInput._loudlyHandleTextInputInvocation
E/flutter (17321): #10     MethodChannel._handleAsMethodCall
E/flutter (17321): #11     MethodChannel.setMethodCallHandler.<anonymous closure>
E/flutter (17321): #12     _DefaultBinaryMessenger.setMessageHandler.<anonymous closure>
E/flutter (17321): #13     _invoke2 (dart:ui/hooks.dart:186:13)
E/flutter (17321): #14     _ChannelCallbackRecord.invoke (dart:ui/channel_buffers.dart:42:5)
E/flutter (17321): #15     _Channel.push (dart:ui/channel_buffers.dart:132:31)
E/flutter (17321): #16     ChannelBuffers.push (dart:ui/channel_buffers.dart:329:17)
E/flutter (17321): #17     PlatformDispatcher._dispatchPlatformMessage (dart:ui/platform_dispatcher.dart:599:22)
E/flutter (17321): #18     _dispatchPlatformMessage (dart:ui/hooks.dart:89:31)
```