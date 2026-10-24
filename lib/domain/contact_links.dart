/// Links that hand a call, message or e-mail to the phone's own apps. The
/// business number comes later (Twilio, behind a setting); today the
/// device's dialer, SMS app, WhatsApp and mail app do the work.
library;

/// Digits and a leading +, as dialers and wa.me want them.
String dialable(String phone) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// International form for WhatsApp: UK numbers starting 0 become 44...
String international(String phone, {String country = '44'}) {
  final d = dialable(phone);
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith('0')) return '$country${d.substring(1)}';
  return d;
}

Uri callUri(String phone) => Uri(scheme: 'tel', path: dialable(phone));

Uri smsUri(String phone, {String body = ''}) =>
    Uri.parse('sms:${dialable(phone)}${body.isEmpty ? '' : '?body=${Uri.encodeComponent(body)}'}');

Uri whatsAppUri(String phone, {String text = ''}) =>
    Uri.https('wa.me', '/${international(phone)}', text.isEmpty ? null : {'text': text});

Uri mailUri(String email, {String subject = '', String body = ''}) => Uri(
  scheme: 'mailto',
  path: email,
  // Uri's own query encoding writes spaces as +, which mail apps show.
  query: [
    if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
    if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
  ].join('&'),
);
