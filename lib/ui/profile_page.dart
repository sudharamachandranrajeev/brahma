import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/advisor.dart';
import '../domain/countries.dart';
import '../domain/profile.dart';
import '../domain/resume.dart';
import 'common.dart';
import 'resume_page.dart';

const _workModes = {'onsite': 'On site', 'hybrid': 'Hybrid', 'remote': 'Remote'};

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAi = ref.watch(advisorProvider).value != null;
    final cvs = ref.watch(resumesProvider).value ?? const <Resume>[];
    return PageScaffold(
      title: 'Profile',
      banner: 'page.profile',
      children: [
        AsyncView(
          ref.watch(profileProvider),
          builder: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Your CV',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      p.isEmpty
                          ? 'Start here. Import your CV (PDF or Word) or paste it, and Claude fills in your profile. '
                                'Nothing is added that your CV does not say.'
                          : 'Import an updated CV at any time; your targets are kept.',
                    ),
                    if (!hasAi)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: NeedsKey(what: 'Reading a CV'),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: hasAi ? () => _importFile(context, ref, p) : null,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Import PDF or Word'),
                        ),
                        OutlinedButton.icon(
                          onPressed: hasAi ? () => _paste(context, ref, p) : null,
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Paste text'),
                        ),
                        if (!p.isEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _baseCv(context, ref, p),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('CV from profile'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'About you',
                trailing: TextButton(onPressed: () => _editAbout(context, ref, p), child: const Text('Edit')),
                child: SelectableText(
                  p.name.isEmpty && p.currentRole.isEmpty
                      ? 'Not filled in yet.'
                      : [
                          p.name,
                          p.headline,
                          [p.currentRole, p.currentEmployer].where((s) => s.isNotEmpty).join(' at '),
                          [
                            p.location,
                            if (p.country.isNotEmpty) Country.nameOf(p.country),
                          ].where((s) => s.isNotEmpty).join(', '),
                          if (p.yearsExperience != null && p.yearsExperience! > 0)
                            '${p.yearsExperience!.toStringAsFixed(p.yearsExperience! % 1 == 0 ? 0 : 1)} years\' experience',
                          [p.email, p.phone].where((s) => s.isNotEmpty).join(' · '),
                          p.linkedin,
                          if (p.summary.isNotEmpty) '\n${p.summary}',
                        ].where((s) => s.isNotEmpty).join('\n'),
                ),
              ),
              SectionCard(
                title: 'What you are looking for',
                trailing: TextButton(
                  onPressed: () => _editTargets(context, ref, p),
                  child: const Text('Edit'),
                ),
                child: Text(
                  [
                    'Roles: ${p.targets.roles.join(', ').ifEmpty('not set')}',
                    'Search terms: ${p.searchTerms.join(', ').ifEmpty('not set')}',
                    'Countries: ${p.searchCountries.map(Country.nameOf).join(', ').ifEmpty('not set')}',
                    if (p.targets.locations.isNotEmpty) 'Places: ${p.targets.locations.join(', ')}',
                    if (p.targets.workModes.isNotEmpty)
                      'Work: ${p.targets.workModes.map((m) => _workModes[m] ?? m).join(', ')}',
                    if (p.targets.salaryMin != null)
                      'Minimum pay: ${p.targets.salaryCurrency} ${p.targets.salaryMin} a year'.trim(),
                    if (p.targets.notes.isNotEmpty) p.targets.notes,
                  ].join('\n'),
                ),
              ),
              SectionCard(
                title: 'Experience',
                trailing: TextButton(
                  onPressed: () => _editJob(context, ref, p, null),
                  child: const Text('Add'),
                ),
                child: p.experience.isEmpty
                    ? const Text('None yet.')
                    : Column(
                        children: [
                          for (final (i, e) in p.experience.indexed)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text([e.title, e.organisation].where((s) => s.isNotEmpty).join(', ')),
                              subtitle: Text(
                                [
                                  [
                                    e.start,
                                    e.current ? 'present' : e.end,
                                  ].where((s) => s.isNotEmpty).join(' – '),
                                  ...e.highlights.take(3).map((h) => '• $h'),
                                  if (e.highlights.length > 3) '…',
                                ].where((s) => s.isNotEmpty).join('\n'),
                              ),
                              onTap: () => _editJob(context, ref, p, i),
                            ),
                        ],
                      ),
              ),
              SectionCard(
                title: 'Education',
                trailing: TextButton(
                  onPressed: () => _editEducation(context, ref, p, null),
                  child: const Text('Add'),
                ),
                child: p.education.isEmpty
                    ? const Text('None yet.')
                    : Column(
                        children: [
                          for (final (i, e) in p.education.indexed)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.qualification),
                              subtitle: Text(
                                [e.institution, e.year, e.grade].where((s) => s.isNotEmpty).join(' · '),
                              ),
                              onTap: () => _editEducation(context, ref, p, i),
                            ),
                        ],
                      ),
              ),
              SectionCard(
                title: 'Skills and certifications',
                trailing: TextButton(
                  onPressed: () => _editSkills(context, ref, p),
                  child: const Text('Edit'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (p.skills.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final s in p.skills) Chip(label: Text(s))],
                      ),
                    if (p.certifications.isNotEmpty) ...[
                      const Subhead('Certifications'),
                      Bullets(p.certifications, icon: Icons.verified_outlined),
                    ],
                    if (p.achievements.isNotEmpty) ...[
                      const Subhead('Achievements'),
                      Bullets(p.achievements),
                    ],
                    if (p.languages.isNotEmpty) ...[const Subhead('Languages'), Text(p.languages.join(', '))],
                    if (p.skills.isEmpty && p.certifications.isEmpty) const Text('None yet.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (cvs.isNotEmpty)
          SectionCard(
            title: 'Your CVs',
            child: Column(
              children: [
                for (final r in cvs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(r.jobId == null ? Icons.description : Icons.description_outlined),
                    title: Text(r.name),
                    subtitle: Text(niceDate(r.created)),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResumePage(r.id))),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _importFile(BuildContext context, WidgetRef ref, CandidateProfile current) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Your CV',
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'docx', 'txt'],
      );
    } catch (e) {
      if (context.mounted) showError(context, e);
      return;
    }
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    final ext = (file.extension ?? '').toLowerCase();
    final CvSource source;
    var text = '';
    try {
      if (ext == 'pdf') {
        if (bytes.length > 25 * 1024 * 1024) throw const FormatException('The PDF is over 25 MB.');
        source = PdfCv(bytes);
      } else {
        text = ext == 'docx' ? docxText(bytes) : utf8.decode(bytes, allowMalformed: true);
        if (text.trim().isEmpty) throw const FormatException('No text found in the file.');
        source = TextCv(text);
      }
    } catch (e) {
      if (context.mounted) showError(context, e is FormatException ? e.message : 'Could not read that file.');
      return;
    }
    if (context.mounted) await _read(context, ref, current, source, text);
  }

  Future<void> _paste(BuildContext context, WidgetRef ref, CandidateProfile current) async {
    final text = TextEditingController();
    final ok = await showFormDialog(
      context,
      title: 'Paste your CV',
      action: 'Read it',
      width: 640,
      fields: (_) => [Field(text, 'CV text', lines: 12, autofocus: true)],
      onSave: () async => text.text.trim().length < 200 ? 'Paste the whole CV.' : null,
    );
    if (ok && context.mounted) await _read(context, ref, current, TextCv(text.text.trim()), text.text.trim());
  }

  Future<void> _read(
    BuildContext context,
    WidgetRef ref,
    CandidateProfile current,
    CvSource cv,
    String text,
  ) async {
    final read = await runAi(
      context,
      title: 'Reading your CV',
      task: (_) async => (await requireAdvisor(ref)).readCv(cv),
    );
    if (read == null || !context.mounted) return;
    if (!current.isEmpty &&
        !await confirm(
          context,
          title: 'Replace your profile?',
          message:
              'Claude read ${read.experience.length} jobs and ${read.skills.length} skills. Your details are '
              'replaced with the CV\'s; what you are looking for is kept.',
          action: 'Replace',
        )) {
      return;
    }
    final keep = current.targets;
    final merged = read.copyWith(
      cvText: text,
      targets: current.isEmpty
          ? read.targets
          : keep.copyWith(
              roles: keep.roles.isEmpty ? read.targets.roles : null,
              keywords: keep.keywords.isEmpty ? read.targets.keywords : null,
              countries: keep.countries.isEmpty ? read.targets.countries : null,
              locations: keep.locations.isEmpty ? read.targets.locations : null,
            ),
    );
    await ref.mutate((s) => s.book.saveProfile(merged));
    if (context.mounted) {
      showMessage(context, 'Profile filled in. Check it, then run the assessment on the Career page.');
    }
  }

  Future<void> _baseCv(BuildContext context, WidgetRef ref, CandidateProfile p) async {
    final id = await ref.mutate(
      (s) => s.book.saveResume(name: 'CV from profile', doc: ResumeDoc.fromProfile(p), today: today()),
    );
    if (context.mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResumePage(id)));
  }

  Future<void> _editAbout(BuildContext context, WidgetRef ref, CandidateProfile p) {
    final name = TextEditingController(text: p.name);
    final headline = TextEditingController(text: p.headline);
    final role = TextEditingController(text: p.currentRole);
    final employer = TextEditingController(text: p.currentEmployer);
    final years = TextEditingController(text: p.yearsExperience?.toString() ?? '');
    final location = TextEditingController(text: p.location);
    final email = TextEditingController(text: p.email);
    final phone = TextEditingController(text: p.phone);
    final linkedin = TextEditingController(text: p.linkedin);
    final website = TextEditingController(text: p.website);
    final summary = TextEditingController(text: p.summary);
    var country = p.country;
    return showFormDialog(
      context,
      title: 'About you',
      width: 600,
      fields: (setState) => [
        Field(name, 'Name'),
        Field(headline, 'Headline', hint: 'Healthcare assistant specialising in elderly care'),
        Field(role, 'Current role'),
        Field(employer, 'Current employer'),
        Field(years, 'Years of experience', number: true),
        Field(location, 'Town or city'),
        Choice<String>(
          label: 'Country you live in',
          value: country,
          options: {'': 'Not set', for (final c in countries) c.code: c.name},
          onChanged: (v) => setState(() => country = v),
        ),
        Field(email, 'E-mail'),
        Field(phone, 'Phone'),
        Field(linkedin, 'LinkedIn'),
        Field(website, 'Website'),
        Field(summary, 'Personal statement', lines: 5),
      ],
      onSave: () async {
        await ref.mutate(
          (s) => s.book.saveProfile(
            CandidateProfile.fromJson({
              ...p.toJson(),
              'name': name.text.trim(),
              'headline': headline.text.trim(),
              'currentRole': role.text.trim(),
              'currentEmployer': employer.text.trim(),
              'yearsExperience': numberIn(years),
              'location': location.text.trim(),
              'country': country,
              'email': email.text.trim(),
              'phone': phone.text.trim(),
              'linkedin': linkedin.text.trim(),
              'website': website.text.trim(),
              'summary': summary.text.trim(),
            }),
          ),
        );
        return null;
      },
    );
  }

  Future<void> _editTargets(BuildContext context, WidgetRef ref, CandidateProfile p) {
    final t = p.targets;
    final roles = TextEditingController(text: t.roles.join('\n'));
    final keywords = TextEditingController(text: t.keywords.join('\n'));
    final locations = TextEditingController(text: t.locations.join(', '));
    final salary = TextEditingController(text: t.salaryMin?.toString() ?? '');
    final currency = TextEditingController(text: t.salaryCurrency);
    final notes = TextEditingController(text: t.notes);
    final picked = [
      ...t.countries.isEmpty && p.country.isNotEmpty ? [p.country] : t.countries,
    ];
    final modes = {...t.workModes};
    return showFormDialog(
      context,
      title: 'What you are looking for',
      width: 600,
      fields: (setState) => [
        Field(roles, 'Target roles', lines: 3, helper: 'One per line'),
        Field(
          keywords,
          'Job search terms',
          lines: 3,
          helper: 'One per line, short, as you would type into a job site. Empty: the roles are used.',
        ),
        const Subhead('Countries'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in countries)
              FilterChip(
                label: Text(c.name),
                selected: picked.contains(c.code),
                onSelected: (v) => setState(() => v ? picked.add(c.code) : picked.remove(c.code)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Field(
          locations,
          'Towns or regions',
          helper: 'In your home country; comma-separated. Empty: anywhere.',
        ),
        const Subhead('Work'),
        Wrap(
          spacing: 6,
          children: [
            for (final m in _workModes.entries)
              FilterChip(
                label: Text(m.value),
                selected: modes.contains(m.key),
                onSelected: (v) => setState(() => v ? modes.add(m.key) : modes.remove(m.key)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Field(salary, 'Minimum yearly pay', number: true),
        Field(currency, 'Currency', hint: 'GBP'),
        Field(
          notes,
          'Anything else',
          lines: 3,
          hint: 'Right to work, notice period, hours, relocation, driving licence',
        ),
      ],
      onSave: () async {
        await ref.mutate(
          (s) => s.book.saveProfile(
            p.copyWith(
              targets: Targets(
                roles: linesIn(roles),
                keywords: linesIn(keywords),
                countries: picked,
                locations: linesIn(locations),
                workModes: [
                  for (final m in _workModes.keys)
                    if (modes.contains(m)) m,
                ],
                salaryMin: intIn(salary),
                salaryCurrency: currency.text.trim().toUpperCase(),
                notes: notes.text.trim(),
              ),
            ),
          ),
        );
        return null;
      },
    );
  }

  Future<void> _editJob(BuildContext context, WidgetRef ref, CandidateProfile p, int? index) {
    final e = index == null ? const Experience() : p.experience[index];
    final title = TextEditingController(text: e.title);
    final org = TextEditingController(text: e.organisation);
    final location = TextEditingController(text: e.location);
    final start = TextEditingController(text: e.start);
    final end = TextEditingController(text: e.end);
    final highlights = TextEditingController(text: e.highlights.join('\n'));
    List<Experience> without() => [...p.experience]..removeAt(index!);
    return showFormDialog(
      context,
      title: index == null ? 'Add a job' : 'Job',
      width: 600,
      fields: (_) => [
        Field(title, 'Job title'),
        Field(org, 'Organisation'),
        Field(location, 'Location'),
        Field(start, 'Started', hint: '2023-04'),
        Field(end, 'Ended', hint: 'Empty while current'),
        Field(
          highlights,
          'What you did and achieved',
          lines: 6,
          helper: 'One per line. Lead with actions and results.',
        ),
        if (index != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () async {
                await ref.mutate((s) => s.book.saveProfile(p.copyWith(experience: without())));
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop(false);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ),
      ],
      onSave: () async {
        if (title.text.trim().isEmpty) return 'Enter the job title.';
        final job = Experience(
          title: title.text.trim(),
          organisation: org.text.trim(),
          location: location.text.trim(),
          start: start.text.trim(),
          end: end.text.trim(),
          highlights: highlights.text
              .split('\n')
              .map((s) => s.replaceFirst(RegExp(r'^[•\-*]\s*'), '').trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        );
        final list = index == null ? [job, ...p.experience] : ([...p.experience]..[index] = job);
        await ref.mutate((s) => s.book.saveProfile(p.copyWith(experience: list)));
        return null;
      },
    );
  }

  Future<void> _editEducation(BuildContext context, WidgetRef ref, CandidateProfile p, int? index) {
    final e = index == null ? const Education() : p.education[index];
    final qualification = TextEditingController(text: e.qualification);
    final institution = TextEditingController(text: e.institution);
    final year = TextEditingController(text: e.year);
    final grade = TextEditingController(text: e.grade);
    return showFormDialog(
      context,
      title: index == null ? 'Add a qualification' : 'Qualification',
      fields: (_) => [
        Field(qualification, 'Qualification'),
        Field(institution, 'Institution'),
        Field(year, 'Year'),
        Field(grade, 'Grade'),
        if (index != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () async {
                await ref.mutate(
                  (s) => s.book.saveProfile(p.copyWith(education: [...p.education]..removeAt(index))),
                );
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop(false);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ),
      ],
      onSave: () async {
        if (qualification.text.trim().isEmpty) return 'Enter the qualification.';
        final ed = Education(
          qualification: qualification.text.trim(),
          institution: institution.text.trim(),
          year: year.text.trim(),
          grade: grade.text.trim(),
        );
        final list = index == null ? [...p.education, ed] : ([...p.education]..[index] = ed);
        await ref.mutate((s) => s.book.saveProfile(p.copyWith(education: list)));
        return null;
      },
    );
  }

  Future<void> _editSkills(BuildContext context, WidgetRef ref, CandidateProfile p) {
    final skills = TextEditingController(text: p.skills.join('\n'));
    final certs = TextEditingController(text: p.certifications.join('\n'));
    final achievements = TextEditingController(text: p.achievements.join('\n'));
    final languages = TextEditingController(text: p.languages.join(', '));
    return showFormDialog(
      context,
      title: 'Skills and certifications',
      width: 600,
      fields: (_) => [
        Field(skills, 'Skills', lines: 5, helper: 'One per line'),
        Field(certs, 'Certifications and licences', lines: 3, helper: 'One per line'),
        Field(achievements, 'Achievements', lines: 3, helper: 'One per line'),
        Field(languages, 'Languages', helper: 'Comma-separated'),
      ],
      onSave: () async {
        await ref.mutate(
          (s) => s.book.saveProfile(
            p.copyWith(
              skills: linesIn(skills),
              certifications: linesIn(certs),
              achievements: linesIn(achievements),
              languages: linesIn(languages),
            ),
          ),
        );
        return null;
      },
    );
  }
}
