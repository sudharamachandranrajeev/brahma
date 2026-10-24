import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:udyoga/db/database.dart';
import 'package:udyoga/domain/feeds.dart';
import 'package:udyoga/domain/profile.dart';

/// A fresh in-memory database (the bundled SQLite3MultipleCiphers works
/// unkeyed in memory).
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// A made-up candidate. Tests never use real people's data.
const sampleProfile = CandidateProfile(
  name: 'Alex Example',
  headline: 'Staff nurse moving into clinical informatics',
  country: 'GB',
  location: 'Exampletown',
  currentRole: 'Staff Nurse',
  currentEmployer: 'Example Health Trust',
  yearsExperience: 6,
  summary: 'Ward nurse who led the roll-out of electronic observations.',
  experience: [
    Experience(
      title: 'Staff Nurse',
      organisation: 'Example Health Trust',
      start: '2020-03',
      highlights: ['Led the e-observations pilot on a 28-bed ward', 'Trained 40 staff'],
    ),
  ],
  education: [Education(qualification: 'BSc Nursing', institution: 'Example University', year: '2019')],
  skills: ['Patient safety', 'EPR systems', 'Training'],
  targets: Targets(
    roles: ['Clinical Informatics Nurse', 'Digital Nurse Specialist'],
    countries: ['GB', 'IE'],
    workModes: ['hybrid'],
  ),
);

/// A made-up opening as a feed would give it.
Posting samplePosting({
  String source = 'reed',
  String id = '1',
  String title = 'Clinical Informatics Nurse',
  String company = 'Example Health Trust',
  String url = '',
  String description = 'Support EPR systems and patient safety training across wards.',
  String? closing,
}) => Posting(
  source: source,
  sourceId: id,
  title: title,
  company: company,
  location: 'Exampletown',
  country: 'GB',
  salaryMin: 38000,
  salaryMax: 45000,
  currency: 'GBP',
  url: url,
  description: description,
  posted: '2026-10-20',
  closing: closing,
);

/// Answers every request with an empty JSON object, so the job feeds find
/// nothing and nothing leaves the machine.
http.Client quietClient() => MockClient((_) async => http.Response('{}', 200));
