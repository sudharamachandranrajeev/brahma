import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'json.dart';
import 'profile.dart';
import 'schema.dart';

/// A CV: what goes on the page, in order.
class ResumeDoc {
  const ResumeDoc({
    this.name = '',
    this.headline = '',
    this.contact = const [],
    this.summary = '',
    this.skills = const [],
    this.experience = const [],
    this.education = const [],
    this.certifications = const [],
    this.sections = const [],
  });

  final String name, headline;

  /// Phone, e-mail, town, LinkedIn: one line each.
  final List<String> contact;
  final String summary;
  final List<String> skills;
  final List<Experience> experience;
  final List<Education> education;
  final List<String> certifications;

  /// Anything else (achievements, languages, volunteering).
  final List<({String heading, List<String> items})> sections;

  factory ResumeDoc.fromProfile(CandidateProfile p) => ResumeDoc(
    name: p.name,
    headline: p.headline.isNotEmpty ? p.headline : p.currentRole,
    contact: [p.phone, p.email, p.location, p.linkedin, p.website].where((s) => s.isNotEmpty).toList(),
    summary: p.summary,
    skills: p.skills,
    experience: p.experience,
    education: p.education,
    certifications: p.certifications,
    sections: [
      if (p.achievements.isNotEmpty) (heading: 'Achievements', items: p.achievements),
      if (p.languages.isNotEmpty) (heading: 'Languages', items: p.languages),
    ],
  );

  factory ResumeDoc.fromJson(Json j) => ResumeDoc(
    name: str(j['name']),
    headline: str(j['headline']),
    contact: strs(j['contact']),
    summary: str(j['summary']),
    skills: strs(j['skills']),
    experience: objs(j['experience']).map(Experience.fromJson).toList(),
    education: objs(j['education']).map(Education.fromJson).toList(),
    certifications: strs(j['certifications']),
    sections: [for (final s in objs(j['sections'])) (heading: str(s['heading']), items: strs(s['items']))],
  );

  Json toJson() => {
    'name': name,
    'headline': headline,
    'contact': contact,
    'summary': summary,
    'skills': skills,
    'experience': [for (final e in experience) e.toJson()],
    'education': [for (final e in education) e.toJson()],
    'certifications': certifications,
    'sections': [
      for (final s in sections) {'heading': s.heading, 'items': s.items},
    ],
  };

  static final schema = object({
    'name': string(),
    'headline': string('Target-role headline'),
    'contact': strings(),
    'summary': string('Personal profile, 3 to 5 sentences, written for this job'),
    'skills': strings('Most relevant first; use the advert\'s wording where it is true'),
    'experience': array(Experience.schema, description: 'Most recent first; bullets lead with results'),
    'education': array(Education.schema),
    'certifications': strings(),
    'sections': array(object({'heading': string(), 'items': strings()})),
  });

  static String _dates(Experience e) =>
      [e.start, e.current ? 'Present' : e.end].where((s) => s.isNotEmpty).join(' – ');

  /// Plain text, for pasting into application forms.
  String toText() {
    final b = StringBuffer();
    void heading(String h) => b
      ..writeln()
      ..writeln(h.toUpperCase());
    b.writeln(name);
    if (headline.isNotEmpty) b.writeln(headline);
    if (contact.isNotEmpty) b.writeln(contact.join(' | '));
    if (summary.isNotEmpty) {
      heading('Profile');
      b.writeln(summary);
    }
    if (skills.isNotEmpty) {
      heading('Key skills');
      for (final s in skills) {
        b.writeln('• $s');
      }
    }
    if (experience.isNotEmpty) {
      heading('Experience');
      for (final e in experience) {
        b.writeln([e.title, e.organisation].where((s) => s.isNotEmpty).join(', '));
        final meta = [e.location, _dates(e)].where((s) => s.isNotEmpty).join(' | ');
        if (meta.isNotEmpty) b.writeln(meta);
        for (final h in e.highlights) {
          b.writeln('• $h');
        }
        b.writeln();
      }
    }
    if (education.isNotEmpty) {
      heading('Education');
      for (final e in education) {
        b.writeln([e.qualification, e.institution, e.year, e.grade].where((s) => s.isNotEmpty).join(', '));
      }
    }
    if (certifications.isNotEmpty) {
      heading('Certifications');
      for (final c in certifications) {
        b.writeln('• $c');
      }
    }
    for (final s in sections) {
      heading(s.heading);
      for (final i in s.items) {
        b.writeln('• $i');
      }
    }
    return b.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// A Word document: one column, real headings and bullets, no tables or
  /// text boxes, which applicant tracking systems read reliably.
  Uint8List toDocx() {
    final body = StringBuffer();
    String esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);
    void para(String text, {String? style, bool bold = false, int size = 0, bool center = false}) {
      body.write('<w:p><w:pPr>');
      if (style != null) body.write('<w:pStyle w:val="$style"/>');
      if (center) body.write('<w:jc w:val="center"/>');
      body.write('</w:pPr><w:r><w:rPr>');
      if (bold) body.write('<w:b/>');
      if (size > 0) body.write('<w:sz w:val="$size"/>');
      body.write('</w:rPr><w:t xml:space="preserve">${esc(text)}</w:t></w:r></w:p>');
    }

    void bullet(String text) => para(text, style: 'ListBullet');
    para(name, bold: true, size: 36, center: true);
    if (headline.isNotEmpty) para(headline, size: 24, center: true);
    if (contact.isNotEmpty) para(contact.join('  |  '), size: 20, center: true);
    if (summary.isNotEmpty) {
      para('Profile', style: 'Heading1');
      para(summary);
    }
    if (skills.isNotEmpty) {
      para('Key skills', style: 'Heading1');
      skills.forEach(bullet);
    }
    if (experience.isNotEmpty) {
      para('Experience', style: 'Heading1');
      for (final e in experience) {
        para([e.title, e.organisation].where((s) => s.isNotEmpty).join(', '), style: 'Heading2');
        final meta = [e.location, _dates(e)].where((s) => s.isNotEmpty).join('  |  ');
        if (meta.isNotEmpty) para(meta, size: 20);
        e.highlights.forEach(bullet);
      }
    }
    if (education.isNotEmpty) {
      para('Education', style: 'Heading1');
      for (final e in education) {
        para([e.qualification, e.institution, e.year, e.grade].where((s) => s.isNotEmpty).join(', '));
      }
    }
    if (certifications.isNotEmpty) {
      para('Certifications', style: 'Heading1');
      certifications.forEach(bullet);
    }
    for (final s in sections) {
      para(s.heading, style: 'Heading1');
      s.items.forEach(bullet);
    }

    const ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document $ns><w:body>$body'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000" w:header="500" w:footer="500" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';
    const styles =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles $ns>'
        '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>'
        '<w:sz w:val="22"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="80" w:line="264" w:lineRule="auto"/></w:pPr></w:pPrDefault>'
        '</w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>'
        '<w:next w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240" w:after="80"/>'
        '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="1F3A5F"/></w:pBdr><w:outlineLvl w:val="0"/></w:pPr>'
        '<w:rPr><w:b/><w:color w:val="1F3A5F"/><w:sz w:val="26"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/>'
        '<w:next w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="160" w:after="0"/><w:outlineLvl w:val="1"/></w:pPr>'
        '<w:rPr><w:b/><w:sz w:val="23"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="ListBullet"><w:name w:val="List Bullet"/><w:basedOn w:val="Normal"/>'
        '<w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr><w:spacing w:after="40"/></w:pPr></w:style>'
        '</w:styles>';
    const numbering =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:numbering $ns><w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:start w:val="1"/>'
        '<w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/>'
        '<w:pPr><w:ind w:left="360" w:hanging="260"/></w:pPr></w:lvl></w:abstractNum>'
        '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>';
    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '<Override PartName="/word/numbering.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
        '</Types>';
    const rels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="word/document.xml"/></Relationships>';
    const docRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
        'Target="styles.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" '
        'Target="numbering.xml"/></Relationships>';

    final archive = Archive();
    for (final (path, text) in [
      ('[Content_Types].xml', contentTypes),
      ('_rels/.rels', rels),
      ('word/document.xml', document),
      ('word/styles.xml', styles),
      ('word/numbering.xml', numbering),
      ('word/_rels/document.xml.rels', docRels),
    ]) {
      archive.addFile(ArchiveFile.bytes(path, utf8.encode(text)));
    }
    return ZipEncoder().encodeBytes(archive);
  }
}

/// The tailoring answer: the CV for the job and notes on it.
final tailorSchema = object({
  'resume': ResumeDoc.schema,
  'notes': object({
    'changes': strings('What was changed for this job and why'),
    'keywordsCovered': strings(),
    'keywordsMissing': strings('Advert keywords the candidate cannot honestly claim'),
    'cautions': strings('Anything the candidate must check is accurate before sending'),
    'atsScore': integer('0 to 100: how well an applicant tracking system would match it to the advert'),
    'coverLetter': string('A cover letter or supporting statement for this job, in plain paragraphs'),
  }),
});

/// Plain text of a Word document's body, for importing a CV.
String docxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final doc = archive.findFile('word/document.xml');
  if (doc == null) throw const FormatException('Not a Word document');
  final xml = utf8.decode(doc.content, allowMalformed: true);
  return htmlToText(
    xml
        .replaceAll(RegExp(r'<w:tab/>'), '\t')
        .replaceAll(RegExp(r'<w:br[^>]*/>'), '\n')
        .replaceAll(RegExp(r'</w:p>'), '</p>'),
  );
}
