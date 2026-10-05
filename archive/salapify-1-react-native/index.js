// Custom entry point. It starts Expo Router exactly as before, and also
// registers the Android home screen widget handler so widgets can render
// even when the app is closed. The widget code only loads on Android, so
// web preview and any future iOS build are untouched.

import 'expo-router/entry';
import { Platform } from 'react-native';

if (Platform.OS === 'android') {
  const { registerWidgetTaskHandler } = require('react-native-android-widget');
  const { widgetTaskHandler } = require('./widgets/widget-task-handler');
  registerWidgetTaskHandler(widgetTaskHandler);
}
