library phosphor_flutter;

import 'package:flutter/widgets.dart';

// PATCHED for Flutter 3.44+ (Dart 3.9): `IconData` is now a `final` class and
// can no longer be extended outside dart:ui. Upstream phosphor_flutter 2.1.0
// defined `class PhosphorIconData extends IconData`, which fails CFE
// compilation on this SDK (the legacy class-modifier exemption was removed).
//
// Fix: Phosphor icons are now plain `IconData` instances (IconData has a public
// const constructor), built directly in the generated accessor files. This keeps
// the whole public API source-compatible — `PhosphorIconData` stays a usable
// type name (now an alias for `IconData`), so app code that types parameters /
// fields as `PhosphorIconData` and passes icons to `Icon(...)` needs no change.
typedef PhosphorIconData = IconData;
