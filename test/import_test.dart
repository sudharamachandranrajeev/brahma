import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udyoga/domain/advisor.dart';
import 'package:udyoga/domain/ai.dart';
import 'package:udyoga/domain/book.dart';
import 'package:udyoga/domain/json.dart';
import 'package:udyoga/domain/linkedin_export.dart';
import 'package:udyoga/domain/pipeline.dart';
import 'package:udyoga/domain/profile.dart';

import 'support.dart';

/// Records what the adviser sends and answers with [answer].
class _Recorder implements Ai {
  _Recorder(this.answer);
  final Json answer;
  late String system;
  late List<Json> content;
  late String effort;

  @override
  String get model => 'test';

  @override
  Future<AiResult> ask({
    required String system,
    required List<Json> content,
    required Json schema,
    bool web = false,
    int searches = 8,
    String effort = 'high',
    int maxTokens = 32000,
    void Function(String status)? onProgress,
  }) async {
    this.system = system;
    this.content = content;
    this.effort = effort;
    return AiResult(answer);
  }
}

/// A made-up LinkedIn export, shaped like the real archive.
Uint8List _export() {
  final files = {
    'Profile.csv':
        'First Name,Last Name,Maiden Name,Address,Birth Date,Headline,Summary,Industry,Zip Code,Geo Location\n'
        'Alex,Example,,,,"Nurse, informatics",Ward nurse.,Hospitals,,Exampletown\n',
    'Positions.csv':
        'Company Name,Title,Description,Location,Started On,Finished On\n'
        'Example Health Trust,Staff Nurse,"Led the pilot\n• Trained staff",Exampletown,Mar 2020,\n'
        'Sample Clinic Ltd,Healthcare Assistant,Night shifts,Exampletown,Jan 2017,Feb 2020\n',
    'Skills.csv': 'Name\nPatient safety\nClinical audit\n',
    'Certifications.csv':
        'Name,Url,Authority,Started On,Finished On,License Number\nBLS,,Example Council,Jan 2024,,\n',
    'Recommendations_Received.csv':
        'First Name,Last Name,Company,Job Title,Text,Creation Date,Status\n'
        'Sam,Sample,Example Health Trust,Ward Manager,"Alex is calm, ""brilliant"" under pressure.",'
        '05/14/24,VISIBLE\n',
    'Connections.csv':
        'Notes:\n"When exporting your connection data, you may notice that some of the email addresses are missing."\n'
        '\n'
        'First Name,Last Name,URL,Email Address,Company,Position,Connected On\n'
        'Jo,Recruit,https://www.linkedin.com/in/jo,,Agency Example,Senior Talent Partner,12 Mar 2024\n'
        'Kim,Peer,https://www.linkedin.com/in/kim,,Target Hospital,Informatics Lead,01 Feb 2023\n'
        'Lee,Other,https://www.linkedin.com/in/lee,,Unrelated Co,Engineer,01 Feb 2023\n',
    'Jobs/Job Applications.csv':
        'Application Date,Contact Email,Contact Phone Number,Company Name,Job Title,Job Url,Resume Name,'
        'Question And Answers\n'
        '10/20/26 9:15 AM,a@example.com,,Target Hospital,Clinical Informatics Nurse,https://example.com/j/1,,\n'
        '1/5/20 9:15 AM,a@example.com,,Old Place,Old Job,https://example.com/j/0,,\n',
    'Jobs/Saved Jobs.csv': 'Saved Date,Job Url,Job Title,Company Name\n10/01/26 8:00 AM,https://example.com/j/2,Digital Nurse,Example Health Trust\n',
  };
  final archive = Archive();
  for (final e in files.entries) {
    final bytes = utf8.encode(e.value);
    archive.addFile(ArchiveFile('Basic_LinkedInDataExport/${e.key}', bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('CSV and dates', () {
    test('quotes, doubled quotes, newlines in quotes and a preamble', () {
      final rows = readCsv('note\n\nA,B\n"x, y","say ""hi""\nthere"\r\nz,\n', header: 'a');
      expect(rows, [
        {'a': 'x, y', 'b': 'say "hi"\nthere'},
        {'a': 'z', 'b': ''},
      ]);
    });

    test('LinkedIn date forms', () {
      expect(linkedInDate('Mar 2021'), '2021-03');
      expect(linkedInDate('2019'), '2019');
      expect(linkedInDate('12 Mar 2024'), '2024-03-12');
      expect(linkedInDate('3/14/24, 10:22 AM'), '2024-03-14');
      expect(linkedInDate('2024-03-14 10:22 UTC'), '2024-03-14');
      expect(linkedInDate(''), '');
    });
  });

  group('LinkedIn export', () {
    test('a ZIP without LinkedIn data is refused', () {
      expect(() => LinkedInExport.read(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });

    test('fills gaps in the profile without changing what is there', () {
      final x = LinkedInExport.read(_export());
      final p = x.mergeInto(sampleProfile);
      expect(p.name, sampleProfile.name);
      expect(p.summary, sampleProfile.summary);
      // The same job is not added twice; the new one is, oldest last.
      expect(p.experience.map((e) => e.organisation), ['Example Health Trust', 'Sample Clinic Ltd']);
      expect(p.experience.last.start, '2017-01');
      expect(p.experience.last.end, '2020-02');
      expect(p.skills, containsAll(['Patient safety', 'EPR systems', 'Clinical audit']));
      expect(p.skills.where((s) => s == 'Patient safety'), hasLength(1));
      expect(p.certifications, ['BLS']);

      final fresh = x.mergeInto(const CandidateProfile());
      expect(fresh.name, 'Alex Example');
      expect(fresh.headline, 'Nurse, informatics');
      expect(fresh.currentRole, 'Staff Nurse');
      expect(fresh.experience.first.highlights, ['Led the pilot', 'Trained staff']);
    });

    test('import spreads across profile, growth, applications, jobs and contacts', () async {
      final book = CareerBook(await Store.open(memoryDatabase()));
      await book.saveProfile(sampleProfile);
      final r = await book.importLinkedIn(LinkedInExport.read(_export()), today: '2026-10-27');
      expect(r.jobs, 1);
      expect(r.certifications, 1);
      expect(r.wins, 1);
      // Only the recent application; the 2020 one is history.
      expect(r.applications, 1);
      expect(r.savedJobs, 1);
      // The recruiter and the person at an employer being pursued, not the rest.
      expect(r.contacts, 2);

      final apps = await book.db.select(book.db.jobApplications).get();
      expect(apps.single.stage, Stage.applied.id);
      expect(apps.single.applied, '2026-10-20');
      final contacts = await book.db.select(book.db.careerContacts).get();
      expect(contacts.map((c) => c.name), unorderedEquals(['Jo Recruit', 'Kim Peer']));
      expect(contacts.every((c) => c.followUp == null), isTrue);
      final growth = await book.db.select(book.db.careerGrowth).get();
      expect(growth.singleWhere((g) => g.kind == 'certification').status, 'done');

      // Again: nothing doubles.
      final again = await book.importLinkedIn(LinkedInExport.read(_export()), today: '2026-10-27');
      expect(
        [again.jobs, again.certifications, again.wins, again.applications, again.contacts],
        [0, 0, 0, 0, 0],
      );
    });
  });

  group('Ideas and wins', () {
    test('reach the AI with the profile, and are not saved in it', () async {
      final book = CareerBook(await Store.open(memoryDatabase()));
      await book.saveProfile(sampleProfile);
      await book.saveNote(kind: 'idea', title: 'Shadow the informatics team', added: '2026-10-01');
      await book.saveNote(kind: 'win', title: 'Cut handover time', detail: 'by 20%', added: '2026-10-02');
      final p = await book.profile();
      expect(p.notes, ['Win: Cut handover time (by 20%)', 'Idea: Shadow the informatics team']);
      expect(p.forPrompt()['ownNotes'], p.notes);
      expect(p.toJson().containsKey('ownNotes'), isFalse);
      await book.saveProfile(p);
      expect(await book.pref<Map<String, Object?>>(PrefKeys.profile, const {}), isNot(contains('notes')));
      // Notes stay out of the learning plan's titles check only by kind.
      final notes = await book.notes();
      expect(notes.map((n) => n.kind), ['win', 'idea']);
    });
  });

  group('Several CVs', () {
    test('go to the AI together as one master-profile request', () async {
      final ai = _Recorder({
        ...sampleProfile.toJson(),
        'versions': [
          {'document': 'nurse.docx', 'aimedAt': 'Staff Nurse', 'emphasis': 'Ward care'},
          {
            'document': 'informatics.pdf',
            'aimedAt': 'Clinical Informatics Nurse',
            'emphasis': 'EPR roll-out',
          },
        ],
      });
      final p = await Advisor(ai, today: '2026-10-27').readCv([
        const TextCv('CV one', name: 'nurse.docx'),
        PdfCv(Uint8List.fromList([37, 80, 68, 70]), name: 'informatics.pdf'),
      ]);
      expect(p.versions.map((v) => v.aimedAt), ['Staff Nurse', 'Clinical Informatics Nurse']);
      expect(ai.effort, 'high');
      expect(ai.system, contains('list each job once'));
      final texts = [
        for (final b in ai.content)
          if (b['type'] == 'text') str(b['text']),
      ];
      expect(texts.first, contains('<cv name="nurse.docx">'));
      expect(texts, contains('<cv name="informatics.pdf">'));
      expect(texts.last, contains('2 CVs belong to the same candidate'));
      expect(ai.content.where((b) => b['type'] == 'document'), hasLength(1));
    });

    test('one CV reads as before', () async {
      final ai = _Recorder(sampleProfile.toJson());
      await Advisor(ai, today: '2026-10-27').readCv([const TextCv('CV text')]);
      expect(ai.effort, 'medium');
      expect(ai.system, isNot(contains('list each job once')));
    });
  });
}
