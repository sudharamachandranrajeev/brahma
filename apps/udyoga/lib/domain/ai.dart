import 'package:brahma_core/brahma_core.dart';

import 'json.dart';

/// A failure talking to the AI, worded for the user.
class AiException implements Exception, UserFacingError {
  AiException(this.message, {this.retryable = false, this.retryAfter});
  @override
  final String message;
  final bool retryable;

  /// How long the service asked to wait before trying again, when it said.
  final Duration? retryAfter;
  @override
  String toString() => message;
}

/// Shown wherever an AI feature runs without a key.
const needsAiKey =
    'Add a free Gemini key or a Claude API key, or connect your Claude or ChatGPT subscription, in Settings to use '
    'the AI features.';

/// The services Udyoga can ask, in the order one is picked when the chosen
/// model's service has no key. The subscriptions come first: they cost the
/// user nothing more.
enum AiProvider {
  claudeCode('Claude subscription', '${ClaudeCodeModels.prefix}claude-opus-5-5', subscription: true),
  codex('ChatGPT subscription', CodexModels.standard, subscription: true),
  claude('Claude', 'claude-opus-5-5'),
  gemini('Gemini', 'gemini-3.8-flash');

  const AiProvider(this.label, this.defaultModel, {this.subscription = false});
  final String label;
  final String defaultModel;

  /// Run through a CLI the user has signed in to their plan, not a key.
  final bool subscription;

  static AiProvider of(String model) => model.startsWith(ClaudeCodeModels.prefix)
      ? claudeCode
      : model.startsWith(CodexModels.prefix)
      ? codex
      : model.startsWith('gemini')
      ? gemini
      : claude;
}

/// Models run through the user's own Claude Code are named with this prefix,
/// so they never mix with the same model on an API key.
abstract final class ClaudeCodeModels {
  static const prefix = 'claude-code:';
}

/// Models run through the user's own Codex (ChatGPT plan) are named with this
/// prefix. Which models a plan offers changes often and differs by plan, so
/// Udyoga leaves the choice to Codex: [standard] runs Codex's default model.
abstract final class CodexModels {
  static const prefix = 'codex:';
  static const standard = '${prefix}default';
}

/// Models the user can choose in Settings, best first within each service.
const aiModels = {
  '${ClaudeCodeModels.prefix}claude-opus-5-5': 'Claude Opus 5.5 on your subscription (most thorough)',
  '${ClaudeCodeModels.prefix}claude-sonnet-5-5': 'Claude Sonnet 5.5 on your subscription (faster)',
  '${ClaudeCodeModels.prefix}claude-haiku-5-5': 'Claude Haiku 5.5 on your subscription (quickest)',
  CodexModels.standard: "ChatGPT on your subscription (Codex's default model)",
  'gemini-3.8-flash': 'Gemini 3.8 Flash (free tier, thorough)',
  'gemini-3.5-flash-lite': 'Gemini 3.5 Flash-Lite (free tier, quickest)',
  'claude-opus-5-5': 'Claude Opus 5.5 (most thorough)',
  'claude-sonnet-5-5': 'Claude Sonnet 5.5 (faster, half the price)',
  'claude-haiku-5-5': 'Claude Haiku 5.5 (quickest, cheapest)',
};

/// The model to use: [chosen] when its service has a key, otherwise the
/// default of the first service that has one. Null without any key.
String? effectiveModel(String chosen, Map<AiProvider, String> keys) {
  bool has(AiProvider p) => (keys[p] ?? '').trim().isNotEmpty;
  if (aiModels.containsKey(chosen) && has(AiProvider.of(chosen))) return chosen;
  return AiProvider.values.where(has).firstOrNull?.defaultModel;
}

/// What a request used, and roughly what it cost at list prices.
class AiUsage {
  const AiUsage({this.input = 0, this.output = 0, this.searches = 0, this.dollars = 0});
  final int input, output, searches;
  final double dollars;

  AiUsage operator +(AiUsage o) => AiUsage(
    input: input + o.input,
    output: output + o.output,
    searches: searches + o.searches,
    dollars: dollars + o.dollars,
  );
}

typedef Source = ({String title, String url});

class AiResult {
  const AiResult(this.data, {this.sources = const [], this.usage = const AiUsage()});
  final Json data;

  /// Pages the answer drew on: those the model listed, then those it read.
  final List<Source> sources;
  final AiUsage usage;

  /// The answer with every source in it, for storing.
  Json get withSources => {
    ...data,
    'sources': [
      for (final s in sources) {'title': s.title, 'url': s.url},
    ],
  };
}

/// The listed sources in [data], then [read], without repeats.
List<Source> mergeSources(Json data, List<Source> read) {
  final seen = <String>{};
  return [
    for (final s in [
      for (final o in objs(data['sources'])) (title: str(o['title']), url: str(o['url'])),
      ...read,
    ])
      if (s.url.startsWith('http') && seen.add(s.url)) s,
  ];
}

/// A model service that answers in JSON: [Claude] or [Gemini].
abstract interface class Ai {
  String get model;

  /// Asks for JSON matching [schema].
  ///
  /// [content] is the user turn's content blocks in the Claude Messages
  /// format (text, a base64 PDF document). With [web], the model may search
  /// and read about [searches] web pages first. [effort] is low, medium or
  /// high. [onProgress] hears what it is doing ("Searching: ...").
  Future<AiResult> ask({
    required String system,
    required List<Json> content,
    required Json schema,
    bool web = false,
    int searches = 8,
    String effort = 'high',
    int maxTokens = 32000,
    void Function(String status)? onProgress,
  });
}
