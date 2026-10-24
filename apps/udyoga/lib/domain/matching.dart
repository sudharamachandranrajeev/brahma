import 'profile.dart';

/// A quick, offline match of a job to the candidate, 0 to 100: target roles
/// and search terms in the title, skills in the description, and the
/// salary against the minimum. The AI's assessment replaces it when asked.
int localFit(CandidateProfile p, {required String title, required String description, int? salaryMax}) {
  final t = title.toLowerCase();
  final d = description.toLowerCase();
  final roles = {...p.targets.roles, ...p.searchTerms, if (p.currentRole.isNotEmpty) p.currentRole};

  // Title: the best share of a target role's words that appear in it.
  var titleScore = 0.0;
  for (final role in roles) {
    final words = _words(role);
    if (words.isEmpty) continue;
    final share = words.where(t.contains).length / words.length;
    if (share > titleScore) titleScore = share;
  }

  // Skills: how many of the candidate's skills the advert mentions, out of
  // a handful (adverts name few of anyone's skills).
  final skills = p.skills.where((s) => s.length > 2).toList();
  final hits = skills.where((s) => d.contains(s.toLowerCase()) || t.contains(s.toLowerCase())).length;
  final skillScore = skills.isEmpty ? 0.5 : (hits / 5).clamp(0, 1).toDouble();

  var score = 60 * titleScore + 35 * skillScore + 5;
  final min = p.targets.salaryMin;
  if (min != null && salaryMax != null && salaryMax > 0 && salaryMax < min) score -= 20;
  return score.round().clamp(0, 100);
}

const _stop = {'and', 'or', 'of', 'the', 'a', 'an', 'in', 'for', 'to', 'with', '&', '-', '/'};

List<String> _words(String s) =>
    s.toLowerCase().split(RegExp(r'[^a-z0-9+#]+')).where((w) => w.length > 1 && !_stop.contains(w)).toList();
