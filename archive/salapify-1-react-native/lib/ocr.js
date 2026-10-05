// On-device OCR. Wraps the native ML Kit text recognizer behind one function
// so the rest of the app never touches the native binding directly, and any
// failure (module missing on an old build, an unreadable photo, a native
// error) degrades to null, which the caller treats as "scan found nothing" and
// falls back to manual entry. Runs fully on the device: the photo and its text
// never leave the phone.

import TextRecognition from '@react-native-ml-kit/text-recognition';

// scanReceiptText(uri) -> Promise<string | null>. Reads the text off a receipt
// photo at the given local uri. Returns the raw text, or null when OCR is
// unavailable or fails. Never throws.
export async function scanReceiptText(uri) {
  if (!uri || typeof uri !== 'string') return null;
  try {
    const result = await TextRecognition.recognize(uri);
    const text = result && typeof result.text === 'string' ? result.text.trim() : '';
    return text || null;
  } catch (e) {
    // A missing module or a native failure must never crash the log flow.
    return null;
  }
}
