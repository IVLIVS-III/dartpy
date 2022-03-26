import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// The contents of a native zero-terminated array of UTF-32 code units.
///
/// The Utf32 type itself has no functionality, it's only intended to be used
/// through a `Pointer<Utf32>` representing the entire array. This pointer is
/// the equivalent of a char pointer (`const wchar_t*`) in C code. The
/// individual UTF-32 code units are stored in native byte order.
class Utf32 extends Opaque {}

/// Extension method for converting a`Pointer<Utf32>` to a [String].
extension Utf32Pointer on Pointer<Utf32> {
  /// The number of UTF-32 code units in this zero-terminated UTF-32 string.
  ///
  /// The UTF-32 code units of the strings are the non-zero code units up to
  /// the first zero code unit.
  int get length {
    _ensureNotNullptr('length');
    final codeUnits = cast<Uint32>();
    return _length(codeUnits);
  }

  /// Converts this UTF-32 encoded string to a Dart string.
  ///
  /// Decodes the UTF-32 code units of this zero-terminated code unit array as
  /// Unicode code points and creates a Dart string containing those code
  /// points.
  ///
  /// If [length] is provided, zero-termination is ignored and the result can
  /// contain NUL characters.
  ///
  /// If [length] is not provided, the returned string is the string up til
  /// but not including  the first NUL character.
  String toDartString({int? length}) {
    _ensureNotNullptr('toDartString');
    final codeUnits = cast<Uint32>();
    if (length == null) {
      return _toUnknownLengthString(codeUnits);
    } else {
      RangeError.checkNotNegative(length, 'length');
      return _toKnownLengthString(codeUnits, length);
    }
  }

  static String _toKnownLengthString(Pointer<Uint32> codeUnits, int length) =>
      String.fromCharCodes(codeUnits.asTypedList(length));

  static String _toUnknownLengthString(Pointer<Uint32> codeUnits) {
    final buffer = StringBuffer();
    var i = 0;
    while (true) {
      final char = codeUnits.elementAt(i).value;
      if (char == 0) {
        return buffer.toString();
      }
      buffer.writeCharCode(char);
      i++;
    }
  }

  static int _length(Pointer<Uint32> codeUnits) {
    var length = 0;
    while (codeUnits[length] != 0) {
      length++;
    }
    return length;
  }

  void _ensureNotNullptr(String operation) {
    if (this == nullptr) {
      throw UnsupportedError(
          "Operation '$operation' not allowed on a 'nullptr'.");
    }
  }
}

/// Extension method for converting a [String] to a `Pointer<Utf32>`.
extension StringUtf32Pointer on String {
  /// Creates a zero-terminated [Utf32] code-unit array from this String.
  ///
  /// If this [String] contains NUL characters, converting it back to a string
  /// using [Utf32Pointer.toDartString] will truncate the result if a length is
  /// not passed.
  ///
  /// Returns an [allocator]-allocated pointer to the result.
  Pointer<Utf32> toNativeUtf32({Allocator allocator = malloc}) {
    final units = codeUnits;
    final result = allocator<Uint32>(units.length + 1);
    final nativeString = result.asTypedList(units.length + 1);
    nativeString.setRange(0, units.length, units);
    nativeString[units.length] = 0;
    return result.cast();
  }
}
