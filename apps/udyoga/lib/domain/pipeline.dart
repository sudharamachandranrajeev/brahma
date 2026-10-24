import 'package:brahma_core/brahma_core.dart';

/// Where an application stands. Open stages come first, in order.
enum Stage {
  preparing('Preparing', open: true, chaseAfter: null),
  applied('Applied', open: true, chaseAfter: 10),
  screening('Screening', open: true, chaseAfter: 7),
  interview('Interview', open: true, chaseAfter: 5),
  offer('Offer', open: true, chaseAfter: 3),
  accepted('Accepted', open: false),
  rejected('Rejected', open: false),
  withdrawn('Withdrawn', open: false),
  noReply('No reply', open: false);

  const Stage(this.label, {required this.open, this.chaseAfter});
  final String label;
  final bool open;

  /// Days after reaching this stage to chase it up, when nothing is heard.
  final int? chaseAfter;

  String get id => name;

  static Stage of(String id) => values.firstWhere((s) => s.name == id, orElse: () => preparing);

  static List<Stage> get openStages => values.where((s) => s.open).toList();
}

/// When to chase an application that just reached [stage] on [date], or
/// null for stages that end it.
String? followUpFor(Stage stage, String date) => switch (stage.chaseAfter) {
  final days? => addDays(date, days),
  null => null,
};

/// An application with no reply this many days after applying is marked as
/// no reply (the user can still move it on).
const ghostedAfterDays = 42;

/// What happens on an application, with the stage it implies.
const eventKinds = {
  'applied': ('Applied', Stage.applied),
  'followup': ('Chased up', null),
  'reply': ('Heard back', Stage.screening),
  'interview': ('Interview', Stage.interview),
  'offer': ('Offer', Stage.offer),
  'accepted': ('Accepted', Stage.accepted),
  'rejected': ('Rejected', Stage.rejected),
  'withdrawn': ('Withdrew', Stage.withdrawn),
  'note': ('Note', null),
};

const leadKinds = {
  'recruiter': 'Recruiter',
  'hiring_manager': 'Hiring manager',
  'referral': 'Referral',
  'peer': 'Peer in the field',
  'mentor': 'Mentor',
  'other': 'Other',
};

const leadStatuses = {
  'new': 'Not contacted',
  'contacted': 'Contacted',
  'replied': 'Replied',
  'cold': 'Gone cold',
};

const growthKinds = {
  'certification': 'Certification',
  'course': 'Course',
  'degree': 'Degree or diploma',
  'skill': 'Skill',
  'experience': 'Experience',
  'goal': 'Career goal',
};

const growthStatuses = {
  'suggested': 'Suggested',
  'planned': 'Planned',
  'doing': 'In progress',
  'done': 'Done',
  'dropped': 'Dropped',
};

const jobStatuses = {'new': 'New', 'saved': 'Saved', 'dismissed': 'Dismissed', 'applied': 'Applied'};
