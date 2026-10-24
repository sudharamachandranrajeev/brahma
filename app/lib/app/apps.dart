import 'package:anveshana/suite.dart';
import 'package:artha/suite.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:udyoga/suite.dart';
import 'package:vahana/suite.dart';
import 'package:vani/suite.dart';
import 'package:vidya/suite.dart';

/// The apps the suite hosts, in home-screen order. A new app joins with its
/// subtree in ../apps, a path dependency in pubspec.yaml and a line here.
final suiteApps = <SuiteApp>[arthaSuite, udyogaSuite, anveshanaSuite, vahanaSuite, vidyaSuite, vaniSuite];
