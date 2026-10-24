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

/// The details an enquiry about a let carries, from Settings.
class Applicant {
  const Applicant({
    this.name = '',
    this.phone = '',
    this.email = '',
    this.household = '',
    this.work = '',
    this.moveIn = '',
  });

  final String name, phone, email;

  /// Who is moving (e.g. "two adults; no children, pets or smoking").
  final String household;

  /// Job and employer, references, guarantor.
  final String work;
  final String moveIn;

  factory Applicant.fromJson(Map<String, Object?> j) => Applicant(
    name: '${j['name'] ?? ''}',
    phone: '${j['phone'] ?? ''}',
    email: '${j['email'] ?? ''}',
    household: '${j['household'] ?? ''}',
    work: '${j['work'] ?? ''}',
    moveIn: '${j['moveIn'] ?? ''}',
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'household': household,
    'work': work,
    'moveIn': moveIn,
  };
}

/// A first enquiry about a let: is it available, what next, when to view.
String rentalEnquiry(Applicant a, {required String address, String agent = ''}) {
  final lines = <String>[
    agent.isEmpty ? 'Hello,' : 'Hello $agent,',
    '',
    "I'm interested in $address and would like to know:",
    '1. Is it still available?',
    if (a.moveIn.isNotEmpty) '2. Could a tenancy start ${a.moveIn}?' else '2. When could a tenancy start?',
    '3. What are the next steps to apply, and which documents do you need?',
    '4. The deposit and any other costs up front.',
    '5. When could I arrange a viewing?',
    if (a.household.isNotEmpty || a.work.isNotEmpty) '',
    if (a.household.isNotEmpty) 'About us: ${a.household}',
    if (a.work.isNotEmpty) a.work,
    '',
    'Thank you,',
    if (a.name.isNotEmpty) a.name,
    if (a.phone.isNotEmpty) a.phone,
  ];
  return lines.join('\n');
}
