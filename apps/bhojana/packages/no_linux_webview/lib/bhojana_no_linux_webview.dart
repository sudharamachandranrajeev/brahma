/// Bhojana's Linux "implementation" of flutter_inappwebview: it registers
/// nothing, because the app never opens a web view on Linux (see hasWebView).
class NoLinuxWebView {
  static void registerWith() {}
}
