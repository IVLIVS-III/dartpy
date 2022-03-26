import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:io' as io show Platform;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:path_provider/path_provider.dart';

import 'gen.dart';

export 'gen.dart';

part 'globals.dart';

/// A variable to override the python dynamic library location on your computer
String? pyLibLocation;
final _pyLib = pyLibLocation != null
    ? ffi.DynamicLibrary.open(pyLibLocation!)
    : io.Platform.isLinux
        ? ffi.DynamicLibrary.open(_findLinux())
        : io.Platform.isMacOS
            ? ffi.DynamicLibrary.open(_findMacos())
            : io.Platform.isWindows
                ? ffi.DynamicLibrary.open(_findWindows())
                : throw UnimplementedError('${io.Platform} not supported');

String _findLinux() {
  if (File('/usr/lib/x86_64-linux-gnu/libpython3.8.so').existsSync()) {
    return '/usr/lib/x86_64-linux-gnu/libpython3.8.so';
  } else if (File('/usr/lib/x86_64-linux-gnu/libpython3.9.so').existsSync()) {
    return '/usr/lib/x86_64-linux-gnu/libpython3.9.so';
  }
  throw UnimplementedError(
      'Linux python version not found, searched for Python 3.8 and 3.9, set pyLibLocation for custom install location');
}

String _findMacos() {
  if (Directory('/usr/local/Frameworks/Python.framework/Versions/3.8')
      .existsSync()) {
    return '/usr/local/Frameworks/Python.framework/Versions/3.8/lib/libpython3.8.dylib';
  } else if (Directory('/usr/local/Frameworks/Python.framework/Versions/3.9')
      .existsSync()) {
    return '/usr/local/Frameworks/Python.framework/Versions/3.9/lib/libpython3.9.dylib';
  }
  throw UnimplementedError(
      'Macos python version not found, searched for Python 3.8 and 3.9, set pyLibLocation for custom install location');
}

String _findWindows() {
  Map env = Platform.environment;
  String username = env['USERNAME'];
  if (Directory(
          'C:\\Users\\$username\\AppData\\Local\\Programs\\Python\\Python39\\python39.dll')
      .existsSync()) {
    return 'C:\\Users\\$username\\AppData\\Local\\Programs\\Python\\Python39\\python39.dll';
  } else if (Directory(
          'C:\\Users\\$username\\AppData\\Local\\Programs\\Python\\Python38\\python38.dll')
      .existsSync()) {
    return 'C:\\Users\\$username\\AppData\\Local\\Programs\\Python\\Python38\\python38.dll';
  }
  throw UnimplementedError(
      'Window python version not found, searched for Python 3.8 and 3.9, set pyLibLocation for custom install location');
}

Future<void> initializeFromAssets() async {
  WidgetsFlutterBinding.ensureInitialized();

  late final String libName;
  if (io.Platform.isLinux) {
    libName = 'libpython3.9.so';
  } else if (io.Platform.isMacOS) {
    libName = 'libpython3.9.dylib';
  } else if (io.Platform.isWindows) {
    libName = 'python39.dll';
  } else {
    throw UnimplementedError('${io.Platform} not supported');
  }

  final supportDirectory = await getApplicationSupportDirectory();
  const pathOffset = '/dartpy/python/';
  final copiedLibFile = File(supportDirectory.path + pathOffset + libName);

  if (!copiedLibFile.existsSync()) {
    copiedLibFile.createSync(recursive: true);
    final content = await rootBundle.load('assets/python/$libName');
    await copiedLibFile.writeAsBytes(content.buffer.asUint8List());
  }

  pyLibLocation = copiedLibFile.path;
}

DartPyC? _dartpyc;

/// Dynamic library
DartPyC get dartpyc => _dartpyc ?? (_dartpyc = DartPyC(_pyLib));
