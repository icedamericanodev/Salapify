// Babel config for Expo SDK 54. Before this file existed, Metro applied
// babel-preset-expo by default; we now spell it out because Reanimated needs
// a companion plugin.
//
// react-native-worklets/plugin MUST be the LAST plugin. It compiles the
// "worklet" functions that Reanimated and Skia run on the UI thread. In
// Reanimated 4 this plugin moved out of the reanimated package into
// react-native-worklets, so it is required for any animated Skia or
// Reanimated code to work at all. A missing or misordered entry here is the
// classic cause of a white screen on launch, so it stays alone and last.
module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: ['react-native-worklets/plugin'],
  };
};
