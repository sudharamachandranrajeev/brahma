/// Reminders through the user's own calendar, so they ring on every device
/// without the app running: a Google Calendar link for one, an .ics file
/// for many.
library;

import 'dart:convert';

String _compact(String date) => date.replaceAll('-', '');

String _nextDay(String date) {
  final d = DateTime.utc(
    int.parse(date.substring(0, 4)),
    int.parse(date.substring(5, 7)),
    int.parse(date.substring(8, 10)),
  );
  final n = d.add(const Duration(days: 1));
  return '${n.year.toString().padLeft(4, '0')}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
}

/// An all-day event on [date] (yyyy-MM-dd) in Google Calendar.
Uri googleCalendarLink({required String title, required String date, String details = ''}) =>
    Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${_compact(date)}/${_nextDay(date)}',
      if (details.isNotEmpty) 'details': details,
    });

/// Folds a content line at 75 octets, as RFC 5545 requires.
String _line(String s) {
  final bytes = utf8.encode(s);
  if (bytes.length <= 75) return '$s\r\n';
  final b = StringBuffer();
  var start = 0, limit = 75;
  while (start < bytes.length) {
    var end = (start + limit).clamp(0, bytes.length);
    // Never split a UTF-8 sequence: back off continuation bytes.
    while (end < bytes.length && bytes[end] & 0xC0 == 0x80) {
      end--;
    }
    b
      ..write(start == 0 ? '' : ' ')
      ..write(utf8.decode(bytes.sublist(start, end)))
      ..write('\r\n');
    start = end;
    limit = 74; // after the leading space
  }
  return b.toString();
}

typedef Reminder = ({String id, String title, String date, String details});

/// An iCalendar file of all-day reminders, each with a 9 am alert.
String icsFile(List<Reminder> reminders, {required String stamp}) {
  String esc(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,').replaceAll('\n', r'\n');
  final b = StringBuffer()
    ..write('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Brahma//Udyoga//EN\r\nCALSCALE:GREGORIAN\r\n');
  for (final r in reminders) {
    b
      ..write('BEGIN:VEVENT\r\n')
      ..write('UID:${r.id}@udyoga.brahma\r\n')
      ..write('DTSTAMP:$stamp\r\n')
      ..write('DTSTART;VALUE=DATE:${_compact(r.date)}\r\n')
      ..write('DTEND;VALUE=DATE:${_nextDay(r.date)}\r\n')
      ..write(_line('SUMMARY:${esc(r.title)}'));
    if (r.details.isNotEmpty) b.write(_line('DESCRIPTION:${esc(r.details)}'));
    b
      ..write('BEGIN:VALARM\r\nACTION:DISPLAY\r\n')
      ..write(_line('DESCRIPTION:${esc(r.title)}'))
      ..write('TRIGGER:PT9H\r\nEND:VALARM\r\n');
    b.write('END:VEVENT\r\n');
  }
  b.write('END:VCALENDAR\r\n');
  return b.toString();
}
