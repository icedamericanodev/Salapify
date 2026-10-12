# R8 rules for the release build.
#
# This file exists because of ONE problem, found the first time CI ever built
# `--release` (2026-10-05). Before that the Android job built `--debug`, R8
# never ran, and the release build had therefore never once succeeded. It was
# not broken by any change: it had simply never been tried, and it would have
# failed on the very first attempt to produce a publishable APK.
#
# The failure:
#
#   ERROR: R8: Missing class
#   com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
#   (referenced from: com.google.mlkit.vision.text.TextRecognizer
#    com.google_mlkit_text_recognition.TextRecognizer.initialize(...))
#
#   Execution failed for task ':app:minifyReleaseWithR8'.
#
# WHY IT HAPPENS, read from the pinned plugin rather than remembered.
# google_mlkit_text_recognition 0.17.1 declares exactly one Android
# dependency, `com.google.mlkit:text-recognition:16.0.1`, which is the LATIN
# model. Its own initialize() switches across every script ML Kit supports, so
# it names the Chinese, Devanagari, Japanese and Korean option classes too.
# Those live in separate artifacts the plugin does not pull, so the references
# are real and the classes genuinely are not there. R8 is right to complain.
#
# WHY -dontwarn IS THE CORRECT ANSWER HERE, and not a way of silencing a real
# problem. Salapify asks for ONE script, at one place:
#
#   lib/features/log/receipt_camera.dart:118
#   TextRecognizer(script: TextRecognitionScript.latin)
#
# so the other four branches are unreachable. Suppressing the warning lets R8
# strip them. The alternative, adding the four extra ML Kit artifacts, would
# add tens of megabytes of language models to the download for code that can
# never run, in an app whose receipts are Philippine and therefore Latin.
#
# WHAT WOULD MAKE THIS WRONG. If Salapify ever recognises a non-Latin script,
# the matching artifact must be ADDED as a dependency, and the matching line
# removed from here. A -dontwarn without the artifact would then turn a build
# error into a runtime crash on somebody's phone, which is strictly worse.
# Note that such a change would crash today too, artifact or not, so this
# suppression is not what is holding that door shut.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
