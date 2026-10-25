import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/pdf.dart';
import 'look.dart';

typedef Slide = ({String title, String body});

/// LinkedIn's portrait document size, in pixels.
const _width = 1080, _height = 1350;

/// The carousel as a PDF to upload as a LinkedIn document post: the cover
/// in azure, the rest light, each signed with [name] and numbered.
Future<Uint8List> carouselPdf(List<Slide> slides, {String name = ''}) async => imagePdf([
  for (final (i, s) in slides.indexed) await _render(s, index: i, count: slides.length, name: name),
]);

Future<PdfPage> _render(Slide s, {required int index, required int count, required String name}) async {
  final cover = index == 0;
  final fg = cover ? Colors.white : ink;
  final muted = cover ? Colors.white70 : const Color(0xFF5B6680);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = const Size(1.0 * _width, 1.0 * _height);
  canvas.drawRect(Offset.zero & size, Paint()..color = cover ? azure : const Color(0xFFF7F9FD));
  canvas.drawCircle(
    Offset(size.width * 0.95, size.height * 0.06),
    360,
    Paint()..color = (cover ? Colors.white : azure).withValues(alpha: 0.08),
  );
  if (!cover) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(96, 120, 120, 14), const Radius.circular(7)),
      Paint()..color = azure,
    );
  }

  const left = 96.0, textWidth = _width - 2 * left;
  double paint(String text, TextStyle style, double top) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 12,
      ellipsis: '...',
    )..layout(maxWidth: textWidth);
    p.paint(canvas, Offset(left, top));
    final h = p.height;
    p.dispose();
    return h;
  }

  var top = cover ? 360.0 : 220.0;
  top += paint(
    s.title,
    TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontWeight: FontWeight.w800,
      fontSize: cover ? 104 : 80,
      height: 1.1,
      letterSpacing: -1.5,
      color: fg,
    ),
    top,
  );
  if (s.body.trim().isNotEmpty) {
    paint(
      s.body.trim(),
      TextStyle(fontFamily: 'Inter', fontSize: cover ? 48 : 46, height: 1.4, color: cover ? fg : muted),
      top + 56,
    );
  }
  final footer = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 32, color: muted);
  if (name.isNotEmpty) paint(name, footer, _height - 140);
  final number = TextPainter(
    text: TextSpan(text: cover ? 'Swipe >' : '${index + 1} / $count', style: footer),
    textDirection: TextDirection.ltr,
  )..layout();
  number.paint(canvas, Offset(_width - left - number.width, _height - 140));
  number.dispose();

  final picture = recorder.endRecording();
  final image = await picture.toImage(_width, _height);
  picture.dispose();
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  image.dispose();
  final rgb = Uint8List(_width * _height * 3);
  for (var p = 0, q = 0; p < rgba.length; p += 4, q += 3) {
    rgb[q] = rgba[p];
    rgb[q + 1] = rgba[p + 1];
    rgb[q + 2] = rgba[p + 2];
  }
  return (width: _width, height: _height, rgb: rgb);
}
