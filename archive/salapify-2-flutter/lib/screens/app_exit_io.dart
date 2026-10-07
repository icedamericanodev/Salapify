// Native side of the close-app-now button: a full process exit is what lets
// the Shorebird engine boot into the downloaded patch on the next open.

import 'dart:io' show exit;

void closeApp() => exit(0);
