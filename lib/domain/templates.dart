/// Starter curricula: a program with its courses, their topics and the
/// skills they build. Importing one copies it; everything can then be edited.
class CourseTemplate {
  const CourseTemplate(this.title, this.kind, this.hours, this.topics);
  final String title, kind;
  final int hours;
  final List<String> topics;
}

class ProgramTemplate {
  const ProgramTemplate(this.title, this.goal, this.courses, this.skills);
  final String title, goal;
  final List<CourseTemplate> courses;
  final List<String> skills;
}

const programTemplates = [
  ProgramTemplate(
    'Software engineer',
    'Build, test and ship software with confidence.',
    [
      CourseTemplate('Programming fundamentals', 'course', 30, [
        'Variables, types and control flow',
        'Functions and scope',
        'Collections and iteration',
        'Errors and debugging',
        'Reading other people’s code',
      ]),
      CourseTemplate('Data structures and algorithms', 'course', 40, [
        'Arrays, lists and hash maps',
        'Stacks, queues and trees',
        'Sorting and searching',
        'Big-O reasoning',
        'Graph basics',
      ]),
      CourseTemplate('Version control and teamwork', 'practice', 8, [
        'Git branches and merges',
        'Pull requests and review',
        'Writing a good commit',
      ]),
      CourseTemplate('Build and ship a project', 'project', 40, [
        'Choose and scope the idea',
        'Build the first version',
        'Write tests',
        'Deploy it',
        'Write the README',
      ]),
    ],
    ['Programming', 'Algorithms', 'Git', 'Testing', 'System design'],
  ),
  ProgramTemplate(
    'Data analyst',
    'Turn raw data into decisions people trust.',
    [
      CourseTemplate('Spreadsheets and SQL', 'course', 25, [
        'Cleaning data',
        'Joins and aggregates',
        'Window functions',
        'Pivot tables',
      ]),
      CourseTemplate('Statistics for analysis', 'course', 30, [
        'Distributions and sampling',
        'Confidence intervals',
        'Hypothesis tests',
        'Regression',
      ]),
      CourseTemplate('Visualisation and storytelling', 'course', 15, [
        'Choosing the right chart',
        'Dashboards that answer one question',
        'Presenting to non-experts',
      ]),
      CourseTemplate('Portfolio analysis', 'project', 30, [
        'Find an open dataset',
        'Ask three questions of it',
        'Publish the write-up',
      ]),
    ],
    ['SQL', 'Statistics', 'Visualisation', 'Communication'],
  ),
  ProgramTemplate(
    'Cloud and DevOps',
    'Run reliable systems on the cloud.',
    [
      CourseTemplate('Linux and networking', 'course', 25, [
        'The shell and permissions',
        'Processes and services',
        'DNS, TCP and HTTP',
        'SSH and firewalls',
      ]),
      CourseTemplate('Containers', 'course', 15, ['Images and containers', 'Compose', 'Registries and tags']),
      CourseTemplate('Infrastructure as code', 'course', 20, [
        'Declarative state',
        'Modules',
        'Secrets and state storage',
      ]),
      CourseTemplate('Cloud certification', 'certification', 60, [
        'Core services',
        'Identity and security',
        'Practice exam 1',
        'Practice exam 2',
        'Sit the exam',
      ]),
    ],
    ['Linux', 'Networking', 'Containers', 'Infrastructure as code', 'Security'],
  ),
];
