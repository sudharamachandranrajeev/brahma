import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

/// One page: an RGB picture, three bytes a pixel, rows top to bottom.
typedef PdfPage = ({int width, int height, Uint8List rgb});

/// A PDF of [pages], each a full-page picture [pointsWide] points across.
/// Enough for a LinkedIn document post, which shows pages as pictures
/// anyway, without a PDF package.
Uint8List imagePdf(List<PdfPage> pages, {double pointsWide = 540}) {
  final out = BytesBuilder(copy: false);
  final offsets = <int>[];
  void put(String s) => out.add(latin1.encode(s));
  void object(String body, [List<int>? stream]) {
    offsets.add(out.length);
    put('${offsets.length} 0 obj\n$body');
    if (stream != null) {
      put('\nstream\n');
      out.add(stream);
      put('\nendstream');
    }
    put('\nendobj\n');
  }

  put('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
  // 1 is the catalog, 2 the page tree; each page then takes three objects:
  // the page, its picture and the drawing that places the picture.
  final kids = [for (var i = 0; i < pages.length; i++) '${3 + i * 3} 0 R'];
  object('<< /Type /Catalog /Pages 2 0 R >>');
  object('<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>');
  for (final (i, p) in pages.indexed) {
    final n = 3 + i * 3;
    final w = _num(pointsWide), h = _num(pointsWide * p.height / p.width);
    object(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] '
      '/Resources << /XObject << /Im0 ${n + 1} 0 R >> >> /Contents ${n + 2} 0 R >>',
    );
    final picture = ZLibCodec(level: 9).encode(p.rgb);
    object(
      '<< /Type /XObject /Subtype /Image /Width ${p.width} /Height ${p.height} /ColorSpace /DeviceRGB '
      '/BitsPerComponent 8 /Filter /FlateDecode /Length ${picture.length} >>',
      picture,
    );
    final draw = latin1.encode('q $w 0 0 $h 0 0 cm /Im0 Do Q');
    object('<< /Length ${draw.length} >>', draw);
  }
  final xref = out.length;
  put('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    put('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  put('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return out.takeBytes();
}

String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
