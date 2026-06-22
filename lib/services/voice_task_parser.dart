import 'package:flutter/foundation.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/models/subclasses/label.dart';
import 'package:to_do_app/models/subclasses/section.dart';
import 'package:to_do_app/models/subclasses/group.dart';
import 'package:to_do_app/models/subclasses/recurrent_configuration.dart';

class VoiceParsedTask {
  final String title;
  final DateTime? scheduledAt;
  final DateTime? deadline;
  final TaskPriority priority;
  final TaskCategory? category;
  final List<Label> labels;
  final RecurrentConfig? recurrentConfig;
  final bool pinned;
  final String? notes;
  final String? section;
  final String? groupId;
  final String? groupName;

  const VoiceParsedTask({
    required this.title,
    this.scheduledAt,
    this.deadline,
    this.priority = TaskPriority.none,
    this.category,
    this.labels = const [],
    this.recurrentConfig,
    this.pinned = false,
    this.notes,
    this.section,
    this.groupId,
    this.groupName,
  });
}

List<VoiceParsedTask> parseVoiceCommand(
  String raw, {
  required List<TaskCategory> categories,
  required List<Label> labels,
  required List<Section> sections,
  required List<Group> groups,
  DateTime? now,
}) {
  final refDate = now ?? DateTime.now();
  // Pre-extract notes from full raw text so "and" inside notes doesn't split
  String? preNotes;
  var textForSplit = raw;
  final notePattern = RegExp(
    r'(?:note|notes|comment|description|details)[:\s]\s*(.+?)$',
    caseSensitive: false,
  );
  final noteMatch = notePattern.firstMatch(raw);
  if (noteMatch != null) {
    preNotes = noteMatch.group(1)?.trim();
    textForSplit = raw.replaceFirst(noteMatch.group(0)!, '').trim();
  }

  final parts = textForSplit
      .split(RegExp(r'\s+and\s+', caseSensitive: false))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) parts.add(textForSplit);
  debugPrint('[VoiceParser] Input: "$raw" → ${parts.length} part(s)');

  final results = parts
      .map((part) => _parseSingle(part,
          categories: categories,
          labels: labels,
          sections: sections,
          groups: groups,
          now: refDate))
      .toList();

  // Apply pre-extracted notes to the last task
  if (preNotes != null && results.isNotEmpty) {
    final last = results.length - 1;
    results[last] = VoiceParsedTask(
      title: results[last].title,
      scheduledAt: results[last].scheduledAt,
      deadline: results[last].deadline,
      priority: results[last].priority,
      category: results[last].category,
      labels: results[last].labels,
      recurrentConfig: results[last].recurrentConfig,
      pinned: results[last].pinned,
      notes: preNotes,
      section: results[last].section,
      groupId: results[last].groupId,
      groupName: results[last].groupName,
    );
    debugPrint('[VoiceParser] Notes applied to result[$last]: "$preNotes"');
  }

  for (var i = 0; i < results.length; i++) {
    final r = results[i];
    debugPrint('[VoiceParser] Final[$i]: title="${r.title}" prio=${r.priority.name} '
        'sched=${r.scheduledAt?.toIso8601String() ?? "null"} '
        'deadline=${r.deadline?.toIso8601String() ?? "null"} '
        'recur=${r.recurrentConfig?.frequency.name ?? "null"} '
        'cat=${r.category?.name ?? "null"} '
        'labels=[${r.labels.map((l) => l.name).join(",")}] '
        'pinned=${r.pinned} '
        'notes="${r.notes ?? ""}"');
  }

  return results;
}

class _ParseCtx {
  String text;
  TaskPriority? priority;
  DateTime? scheduledAt;
  DateTime? deadline;
  TaskCategory? category;
  final List<Label> labels = [];
  RecurrentConfig? recurrent;
  bool pinned = false;
  String? notes;
  String? section;
  String? groupId;
  String? groupName;

  _ParseCtx(this.text);
}

VoiceParsedTask _parseSingle(
  String raw, {
  required List<TaskCategory> categories,
  required List<Label> labels,
  required List<Section> sections,
  required List<Group> groups,
  required DateTime now,
}) {
  final ctx = _ParseCtx(raw.trim());
  _stripNoise(ctx);
  _extractDeadline(ctx, now);
  debugPrint('[VoiceParser.Trace] after deadline: "${ctx.text}" pinned=${ctx.pinned}');
  _extractRecurrence(ctx);
  debugPrint('[VoiceParser.Trace] after recur: "${ctx.text}" pinned=${ctx.pinned}');
  _extractDates(ctx, now);
  debugPrint('[VoiceParser.Trace] after dates: "${ctx.text}" pinned=${ctx.pinned}');
  _extractPinned(ctx);
  debugPrint('[VoiceParser.Trace] after pinned: "${ctx.text}" pinned=${ctx.pinned}');
  _extractCategory(ctx, categories);
  _extractLabels(ctx, labels);
  _extractGroup(ctx, groups);
  _extractSection(ctx, sections);
  _extractPriority(ctx);
  debugPrint('[VoiceParser.Trace] after priority: "${ctx.text}" pinned=${ctx.pinned}');
  _extractTime(ctx, now);
  _extractNotes(ctx);

  final title = ctx.text.trim();
  final result = VoiceParsedTask(
    title: title.isEmpty ? raw.trim() : _toTitleCase(title),
    scheduledAt: ctx.scheduledAt,
    deadline: ctx.deadline,
    priority: ctx.priority ?? TaskPriority.none,
    category: ctx.category,
    labels: List.unmodifiable(ctx.labels),
    recurrentConfig: ctx.recurrent,
    pinned: ctx.pinned,
    notes: ctx.notes,
    section: ctx.section,
    groupId: ctx.groupId,
    groupName: ctx.groupName,
  );
  debugPrint('[VoiceParser] raw="$raw" → title="${result.title}" '
      'prio=${result.priority.name} '
      'sched=${result.scheduledAt?.toIso8601String() ?? "null"} '
      'deadline=${result.deadline?.toIso8601String() ?? "null"} '
      'recur=${result.recurrentConfig?.frequency.name ?? "null"} '
      'cat=${result.category?.name ?? "null"} '
      'labels=[${result.labels.map((l) => l.name).join(",")}] '
      'pinned=${result.pinned} '
      'notes="${result.notes ?? ""}" '
      'section=${result.section ?? "null"} '
      'group=${result.groupId ?? result.groupName ?? "null"}');
  return result;
}

String _toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');
}

void _stripNoise(_ParseCtx ctx) {
  // Strip leading verbs + optional article
  ctx.text = ctx.text.replaceFirst(RegExp(
    r'^(?:add(?:ing)?|creat(?:e|ing)|mak(?:e|ing)|schedule|set|put|'
    r'write(?:\s+down)?|remind me(?:\s+to)?|remember(?:\s+to)?)\s+'
    r'(?:a|an|the|some|my|a\s+new)?\s*',
    caseSensitive: false,
  ), '').trim();

  // Strip standalone leading articles
  ctx.text = ctx.text.replaceFirst(RegExp(
    r'^(?:a|an|the|some|my)\s+',
    caseSensitive: false,
  ), '').trim();

  ctx.text = ctx.text.replaceFirst(RegExp(
    r'\s*(?:please|pls|for me|thanks|thank you)\s*$',
    caseSensitive: false,
  ), '').trim();
}

final _weekdayNames = {
  'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
  'friday': 5, 'saturday': 6, 'sunday': 7,
};

final _monthNames = {
  'january': 1, 'jan': 1,
  'february': 2, 'feb': 2,
  'march': 3, 'mar': 3,
  'april': 4, 'apr': 4,
  'may': 5,
  'june': 6, 'jun': 6,
  'july': 7, 'jul': 7,
  'august': 8, 'aug': 8,
  'september': 9, 'sep': 9, 'sept': 9,
  'october': 10, 'oct': 10,
  'november': 11, 'nov': 11,
  'december': 12, 'dec': 12,
};

final _timeWords = <RegExp, ({int hour, int minute})>{
  RegExp(r'\bmorning\b'): (hour: 8, minute: 0),
  RegExp(r'\bbreakfast\b'): (hour: 8, minute: 0),
  RegExp(r'\blunch\b|\bnoon\b|\bmidday\b'): (hour: 12, minute: 0),
  RegExp(r'\bafternoon\b'): (hour: 14, minute: 0),
  RegExp(r'\bevening\b'): (hour: 18, minute: 0),
  RegExp(r'\bdinner\b'): (hour: 19, minute: 0),
  RegExp(r'\bnight\b'): (hour: 21, minute: 0),
  RegExp(r'\bbedtime\b'): (hour: 22, minute: 0),
  RegExp(r'\bmidnight\b'): (hour: 0, minute: 0),
  RegExp(r'\bend of day\b|\beod\b'): (hour: 23, minute: 59),
  RegExp(r'\bclose of business\b|\bcob\b|\bend of business\b|\beob\b'): (hour: 17, minute: 0),
  RegExp(r'\bsunrise\b|\bdawn\b|\bdaybreak\b'): (hour: 6, minute: 0),
  RegExp(r'\bsunset\b|\bdusk\b'): (hour: 18, minute: 0),
};

void _extractRecurrence(_ParseCtx ctx) {
  final patterns = <(RegExp, RecurrentConfig Function(Match))>[
    (RegExp(r'\bevery\s+other\s+day\b', caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.daily, interval: 2)),
    (RegExp(r'\bevery\s+other\s+week\b', caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.weekly, interval: 2)),
    (RegExp(r'\bevery\s+other\s+month\b', caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.monthly, interval: 2)),
    (RegExp(r'\bbiw(?:eekly)?\b', caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.weekly, interval: 2)),
    (RegExp(r'\bevery\s+(\d+)\s+days?\b', caseSensitive: false),
        (m) => RecurrentConfig(frequency: RecurrentFrequency.daily, interval: int.parse(m.group(1)!))),
    (RegExp(r'\bevery\s+(\d+)\s+weeks?\b', caseSensitive: false),
        (m) => RecurrentConfig(frequency: RecurrentFrequency.weekly, interval: int.parse(m.group(1)!))),
    (RegExp(r'\bevery\s+(\d+)\s+months?\b', caseSensitive: false),
        (m) => RecurrentConfig(frequency: RecurrentFrequency.monthly, interval: int.parse(m.group(1)!))),
    (RegExp(r'\bevery\s+day\b', caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.daily)),
    (RegExp(r'\bdaily\b', caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.daily)),
    (RegExp(r'\bweekly\b', caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.weekly)),
    (RegExp(r'\bmonthly\b', caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.monthly)),
    (RegExp(r'\bye?arly\b', caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.monthly, interval: 12)),
    (RegExp(r'\bon\s+weekdays?\b|\bweekdays?\b|\bevery\s+weekday\b|\bmon(?:day)?\s+to\s+fri(?:day)?\b|\bmon through fri\b|\bmonday through friday\b',
        caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.weekly, weekdays: [1, 2, 3, 4, 5])),
    (RegExp(r'\bon\s+weekends?\b|\bweekends?\b|\bevery\s+weekend\b|\bsat(?:urday)?\s+and\s+sun(?:day)?\b',
        caseSensitive: false),
        (_) => RecurrentConfig(frequency: RecurrentFrequency.weekly, weekdays: [6, 7])),
    (RegExp(r'\bevery\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+and\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday))?\b',
        caseSensitive: false),
        (m) {
      final weekdays = <int>[];
      for (int i = 1; i <= m.groupCount; i++) {
        final name = m.group(i);
        if (name != null && _weekdayNames.containsKey(name.toLowerCase())) {
          weekdays.add(_weekdayNames[name.toLowerCase()]!);
        }
      }
      return RecurrentConfig(frequency: RecurrentFrequency.weekly, weekdays: weekdays);
    }),
    (RegExp(r'\b(repeat|recurring?|repeating)\s+(daily|weekly|monthly)\b', caseSensitive: false), (m) {
      final freq = m.group(2)!.toLowerCase();
      return RecurrentConfig(
        frequency: freq == 'daily'
            ? RecurrentFrequency.daily
            : freq == 'weekly'
                ? RecurrentFrequency.weekly
                : RecurrentFrequency.monthly,
      );
    }),
  ];

  for (final (pattern, factory) in patterns) {
    final match = pattern.firstMatch(ctx.text);
    if (match != null) {
      ctx.recurrent = factory(match);
      ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
      return;
    }
  }

  // Standalone weekday = weekly on that day (only if no other date/time in text)
  if (ctx.recurrent == null) {
    final hasDate = RegExp(
      r'\b(today|tomorrow|next|this)\b',
      caseSensitive: false,
    ).hasMatch(ctx.text);
    final hasTime = RegExp(
      r'(?:at|@)\s*\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b',
      caseSensitive: false,
    ).hasMatch(ctx.text);
    if (!hasDate && !hasTime) {
      for (final entry in _weekdayNames.entries) {
        final pattern = RegExp(r'\b' + entry.key + r'(?:s)?\b', caseSensitive: false);
        final match = pattern.firstMatch(ctx.text);
        if (match != null) {
          ctx.recurrent = RecurrentConfig(frequency: RecurrentFrequency.weekly, weekdays: [entry.value]);
          ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
          return;
        }
      }
    }
  }
}

void _extractDeadline(_ParseCtx ctx, DateTime now) {
  // Match the entire "by [datetime]" expression — date/time content stops
  // before known keywords or at end of string.
  final deadlineRegex = RegExp(
    r'(?:by\s+|due\s+|before\s+|deadline\s+|finish by\s+|done by\s+|'
    r'complete by\s+|needed by\s+|need by\s+|must be done by\s+)'
    r'(.+?)(?=\s+(?:tag|label|for|in|and|note|section|group|priority|p[1-3]|urgent|high|medium|low|pin|pinned|star|starred|sticky)\b|$)',
    caseSensitive: false,
  );
  final match = deadlineRegex.firstMatch(ctx.text);
  if (match == null) return;

  final dateText = match.group(1)!.trim();
  final (parsedDate, _) = _parseDateTime(dateText, now, forDeadline: true);
  if (parsedDate != null) {
    ctx.deadline = parsedDate;
    ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
  }
}

(DateTime?, String) _parseDateTime(String text, DateTime now, {bool forDeadline = false}) {
  var working = text;
  DateTime? date;
  DateTime? time;

  // Date patterns
  final datePatterns = <(RegExp, DateTime Function(Match, DateTime))>[
    (RegExp(r'\btoday\b', caseSensitive: false), (_, n) => n),
    (RegExp(r'\btonight\b', caseSensitive: false), (_, n) => DateTime(n.year, n.month, n.day)),
    (RegExp(r'\btomorrow\b', caseSensitive: false), (_, n) => n.add(const Duration(days: 1))),
    (RegExp(r'\bday after tomorrow\b|\bovermorrow\b', caseSensitive: false),
        (_, n) => n.add(const Duration(days: 2))),
    (RegExp(r'\bnext week\b', caseSensitive: false), (_, n) => n.add(const Duration(days: 7))),
    (RegExp(r'\bthis week\b', caseSensitive: false), (_, n) => n),
    (RegExp(r'\bnext month\b', caseSensitive: false), (_, n) => DateTime(n.year, n.month + 1, n.day)),
    (RegExp(r'\bthis month\b', caseSensitive: false), (_, n) => n),
    (RegExp(r'\bin\s+a\s+day\b', caseSensitive: false), (_, n) => n.add(const Duration(days: 1))),
    (RegExp(r'\bin\s+a\s+week\b', caseSensitive: false), (_, n) => n.add(const Duration(days: 7))),
    (RegExp(r'\bin\s+a\s+month\b', caseSensitive: false), (_, n) => DateTime(n.year, n.month + 1, n.day)),
    (RegExp(r'\bin\s+(\d+)\s+days?\b', caseSensitive: false),
        (m, n) => n.add(Duration(days: int.parse(m.group(1)!)))),
    (RegExp(r'\bin\s+(\d+)\s+weeks?\b', caseSensitive: false),
        (m, n) => n.add(Duration(days: 7 * int.parse(m.group(1)!)))),
    (RegExp(r'\bin\s+(\d+)\s+months?\b', caseSensitive: false),
        (m, n) => DateTime(n.year, n.month + int.parse(m.group(1)!), n.day)),
    (RegExp(r'\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false), (m, n) {
      final target = _weekdayNames[m.group(1)!.toLowerCase()]!;
      int diff = target - n.weekday;
      if (diff <= 0) diff += 7;
      return DateTime(n.year, n.month, n.day).add(Duration(days: diff + 7));
    }),
    (RegExp(r'\bthis\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false), (m, n) {
      final target = _weekdayNames[m.group(1)!.toLowerCase()]!;
      int diff = target - n.weekday;
      if (diff < 0) diff += 7;
      return DateTime(n.year, n.month, n.day).add(Duration(days: diff));
    }),
    (RegExp(r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false), (m, n) {
      final target = _weekdayNames[m.group(1)!.toLowerCase()]!;
      int diff = target - n.weekday;
      if (diff <= 0) diff += 7;
      return DateTime(n.year, n.month, n.day).add(Duration(days: diff));
    }),
  ];

  for (final (pattern, factory) in datePatterns) {
    final match = pattern.firstMatch(working);
    if (match != null) {
      date = factory(match, now);
      working = working.replaceFirst(match.group(0)!, '').trim();
      break;
    }
  }

  // Month-day pattern
  if (date == null) {
    final monthDayPattern = RegExp(
      r'(?:on\s+)?(' +
          _monthNames.keys.join('|') +
          r')\s+(\d{1,2})(?:st|nd|rd|th)?',
      caseSensitive: false,
    );
    final match = monthDayPattern.firstMatch(working);
    if (match != null) {
      final month = _monthNames[match.group(1)!.toLowerCase()]!;
      final day = int.parse(match.group(2)!);
      date = DateTime(now.year, month, day);
      if (date.isBefore(DateTime(now.year, now.month, now.day))) {
        date = DateTime(now.year + 1, month, day);
      }
      working = working.replaceFirst(match.group(0)!, '').trim();
    }
  }

  date ??= now;

  // Check for "tonight" time
  if (RegExp(r'\btonight\b', caseSensitive: false).hasMatch(working)) {
    time = DateTime(date.year, date.month, date.day, 21, 0);
    working = working.replaceFirst(RegExp(r'\btonight\b', caseSensitive: false), '').trim();
  }

  // Time patterns (HH:MM am/pm, H am/pm)
  DateTime? matchedTime;
  String? matchedTimeStr;

  // Compact pattern: "930am", "230pm" (3-4 digits + optional am/pm)
  final compactTimePattern = RegExp(
    r'(?:at\s+|@\s+)?(\d{1,2})(\d{2})\s*(am|pm)?\b',
    caseSensitive: false,
  );
  final compactMatch = compactTimePattern.firstMatch(working);
  if (compactMatch != null &&
      (forDeadline ||
          RegExp(r'\b(?:at|@|by|due|before)\b', caseSensitive: false)
              .hasMatch(compactMatch.group(0)!))) {
    int hour = int.parse(compactMatch.group(1)!);
    final minute = int.parse(compactMatch.group(2)!);
    final ampm = compactMatch.group(3);
    if (ampm != null) {
      final isPm = ampm.toLowerCase() == 'pm';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
    }
    matchedTime = DateTime(date.year, date.month, date.day, hour, minute);
    matchedTimeStr = compactMatch.group(0)!;
  }

  // Standard pattern: "9:30am", "9 am", "9am"
  final timePattern = RegExp(
    r'(?:at\s+|@\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
    caseSensitive: false,
  );
  final timeMatch = timePattern.firstMatch(working);
  if (timeMatch != null && matchedTimeStr == null &&
      (forDeadline ||
          RegExp(r'\b(?:at|@|by|due|before)\b', caseSensitive: false)
              .hasMatch(timeMatch.group(0)!))) {
    int hour = int.parse(timeMatch.group(1)!);
    final minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
    final ampm = timeMatch.group(3);
    if (ampm != null) {
      final isPm = ampm.toLowerCase() == 'pm';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
    }
    matchedTime = DateTime(date.year, date.month, date.day, hour, minute);
    matchedTimeStr = timeMatch.group(0)!;
  }

  if (matchedTime != null) {
    time = matchedTime;
    working = working.replaceFirst(matchedTimeStr!, '').trim();
  }

  // Named time words
  if (time == null) {
    for (final entry in _timeWords.entries) {
      final prefixPattern = forDeadline
          ? RegExp(r'(?:by |before |due )' + entry.key.pattern, caseSensitive: false)
          : RegExp(r'(?:at |this |in the )' + entry.key.pattern, caseSensitive: false);
      final match = prefixPattern.firstMatch(working);
      if (match != null) {
        time = DateTime(date.year, date.month, date.day, entry.value.hour, entry.value.minute);
        working = working.replaceFirst(match.group(0)!, '').trim();
        break;
      }
    }
  }

  if (time == null) {
    // Check if the next word after date is a time word
    for (final entry in _timeWords.entries) {
      final match = entry.key.firstMatch(working);
      if (match != null && match.start == 0) {
        time = DateTime(date.year, date.month, date.day, entry.value.hour, entry.value.minute);
        working = working.replaceFirst(match.group(0)!, '').trim();
        break;
      }
    }
  }

  if (time != null) {
    date = time;
  } else if (forDeadline) {
    date = DateTime(date.year, date.month, date.day, 23, 59);
  }

  return (date, working);
}

void _extractDates(_ParseCtx ctx, DateTime now) {
  final (parsedDate, rest) = _parseDateTime(ctx.text, now, forDeadline: false);
  if (parsedDate != null && rest != ctx.text) {
    ctx.scheduledAt = parsedDate;
    ctx.text = rest;
    // Check if next word is a time word (e.g., "tomorrow morning")
    for (final entry in _timeWords.entries) {
      final match = entry.key.firstMatch(ctx.text);
      if (match != null && match.start == 0) {
        ctx.scheduledAt = DateTime(
          ctx.scheduledAt!.year,
          ctx.scheduledAt!.month,
          ctx.scheduledAt!.day,
          entry.value.hour,
          entry.value.minute,
        );
        ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
        break;
      }
    }
  }
}

DateTime? _tryParseTime(String text, DateTime now) {
  // Compact pattern: "930am", "230pm" (no colon) — requires am/pm
  final compactPattern = RegExp(
    r'(?:at\s+|@\s+)?(\d{1,2})(\d{2})\s*(am|pm)\b',
    caseSensitive: false,
  );
  final compactMatch = compactPattern.firstMatch(text);
  if (compactMatch != null) {
    int hour = int.parse(compactMatch.group(1)!);
    final minute = int.parse(compactMatch.group(2)!);
    final ampm = compactMatch.group(3)!;
    final isPm = ampm.toLowerCase() == 'pm';
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    if (minute >= 0 && minute <= 59 && hour >= 0 && hour <= 23) {
      return DateTime(now.year, now.month, now.day, hour, minute);
    }
  }

  // Standard pattern: "at 3pm", "at 3:30", "3:30pm", "9 am"
  // Requires at least one of: colon, am/pm, or "at"/"@" prefix
  final timePattern = RegExp(
    r'(?:at\s+|@\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
    caseSensitive: false,
  );
  final match = timePattern.firstMatch(text);
  if (match != null) {
    final hasColon = match.group(2) != null;
    final ampm = match.group(3);
    final prefix = match.group(0)!;
    final hasPrefix = prefix.toLowerCase().startsWith('at') || prefix.startsWith('@');
    if (ampm == null && !hasColon && !hasPrefix) return null;

    int hour = int.parse(match.group(1)!);
    final minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
    if (hour > 23 || minute > 59) return null;
    if (ampm != null) {
      final isPm = ampm.toLowerCase() == 'pm';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
    }
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
  return null;
}

void _extractTime(_ParseCtx ctx, DateTime now) {
  if (ctx.scheduledAt != null) {
    // Parse time on the already-set date
    final (parsedTime, rest) = _parseDateTime(ctx.text, ctx.scheduledAt!, forDeadline: false);
    if (parsedTime != null && rest != ctx.text) {
      ctx.scheduledAt = parsedTime;
      ctx.text = rest;
    }
    return;
  }

  final parsedTime = _tryParseTime(ctx.text, now);
  if (parsedTime != null) {
    // Find the matched string to remove by re-scanning
    final compactPattern = RegExp(
      r'(?:at\s+|@\s+)?(\d{1,2})(\d{2})\s*(am|pm)\b',
      caseSensitive: false,
    );
    var matchedStr = compactPattern.firstMatch(ctx.text)?.group(0);
    if (matchedStr == null) {
      final standardPattern = RegExp(
        r'(?:at\s+|@\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
        caseSensitive: false,
      );
      matchedStr = standardPattern.firstMatch(ctx.text)?.group(0);
    }
    ctx.scheduledAt = parsedTime;
    if (matchedStr != null) {
      ctx.text = ctx.text.replaceFirst(matchedStr, '').trim();
    }
  }
}

void _extractPinned(_ParseCtx ctx) {
  final patterns = [
    RegExp(r'\b(?:pin it|pin this|pinned|star it|star this|starred|star|sticky|stick it)\b',
        caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(ctx.text);
    if (match != null) {
      ctx.pinned = true;
      ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
      return;
    }
  }
}

void _extractCategory(_ParseCtx ctx, List<TaskCategory> categories) {
  if (categories.isEmpty) return;

  // Sort by name length descending to match longest first
  final sorted = List<TaskCategory>.from(categories)
    ..sort((a, b) => b.name.length.compareTo(a.name.length));

  // Patterns: "for [name]", "in [name]", "under [name]", "category [name]"
  for (final cat in sorted) {
    final escapedName = RegExp.escape(cat.name);
    for (final prefix in ['for ', 'in ', 'under ', 'category ', 'put in ']) {
      final pattern = RegExp(
        r'\b' + RegExp.escape(prefix) + escapedName + r'\b',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(ctx.text);
      if (match != null) {
        ctx.category = cat;
        ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
        // ponytail: category match stops at first hit
        return;
      }
    }
  }

  // Fallback: fuzzy match by prefix (e.g. "personal" matches "Personal Development")
  for (final cat in sorted) {
    final lowerName = cat.name.toLowerCase();
    final prefixPattern = RegExp(r'\b(for|in|under)\s+(\w+)', caseSensitive: false);
    final match = prefixPattern.firstMatch(ctx.text);
    if (match != null) {
      final word = match.group(2)!.toLowerCase();
      if (lowerName.startsWith(word) || lowerName.contains(word) || word.startsWith(lowerName)) {
        ctx.category = cat;
        ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
        return;
      }
    }
  }
}

void _extractLabels(_ParseCtx ctx, List<Label> allLabels) {
  if (allLabels.isEmpty) return;

  final sorted = List<Label>.from(allLabels)
    ..sort((a, b) => b.name.length.compareTo(a.name.length));

  // Strip the prefix word ("tag", "label") but leave the label name in text
  // so subsequent parsers (priority, etc.) can also process it.
  for (final label in sorted) {
    final escapedName = RegExp.escape(label.name);
    for (final prefix in ['tag ', 'label ', 'with tag ', 'with label ']) {
      final pattern = RegExp(
        r'\b' + RegExp.escape(prefix) + escapedName + r'\b',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(ctx.text);
      if (match != null) {
        ctx.labels.add(label);
        // Strip only the prefix part, keep the label name
        final prefixMatch = RegExp(
          RegExp.escape(prefix),
          caseSensitive: false,
        ).firstMatch(match.group(0)!);
        if (prefixMatch != null) {
          ctx.text = ctx.text.replaceFirst(prefixMatch.group(0)!, '').trim();
        }
        break;
      }
    }
  }
}

void _extractGroup(_ParseCtx ctx, List<Group> allGroups) {
  if (allGroups.isEmpty) return;

  final sorted = List<Group>.from(allGroups)
    ..sort((a, b) => b.name.length.compareTo(a.name.length));

  for (final group in sorted) {
    final escapedName = RegExp.escape(group.name);
    for (final prefix in ['group ', 'in group ', 'in the ', 'add to group ']) {
      // "in the [name] group" — handle specially
      final patterns = [
        RegExp(r'\b' + RegExp.escape(prefix) + escapedName + r'\b', caseSensitive: false),
        if (prefix == 'in the ')
          RegExp(r'\bin the\s+' + escapedName + r'\s+group\b', caseSensitive: false),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(ctx.text);
        if (match != null) {
          ctx.groupId = group.id;
          ctx.groupName = group.name;
          ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
          return;
        }
      }
    }

    // Plain "[name] group" suffix
    final suffixPattern = RegExp(escapedName + r'\s+group\b', caseSensitive: false);
    final match = suffixPattern.firstMatch(ctx.text);
    if (match != null) {
      ctx.groupId = group.id;
      ctx.groupName = group.name;
      ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
      return;
    }
  }
}

void _extractSection(_ParseCtx ctx, List<Section> allSections) {
  if (allSections.isEmpty) return;

  final sorted = List<Section>.from(allSections)
    ..sort((a, b) => b.name.length.compareTo(a.name.length));

  for (final sec in sorted) {
    final escapedName = RegExp.escape(sec.name);
    for (final prefix in ['section ', 'in section ', 'under section ']) {
      final pattern = RegExp(
        r'\b' + RegExp.escape(prefix) + escapedName + r'\b',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(ctx.text);
      if (match != null) {
        ctx.section = sec.name;
        ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
        return;
      }
    }
  }
}

void _extractPriority(_ParseCtx ctx) {
  // Negated/longer patterns first to avoid partial matches
  final patterns = <(RegExp, TaskPriority?)>[
    (RegExp(r'\bnot urgent\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\bnot important\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\bno rush\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\bno hurry\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\btop priority\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\bdo it now\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\bright away\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\bas soon as possible\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\bhigh(?: priority)?\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\bmedium(?: priority)?\b', caseSensitive: false), TaskPriority.medium),
    (RegExp(r'\bnormal(?: priority)?\b', caseSensitive: false), TaskPriority.medium),
    (RegExp(r'\blow(?: priority)?\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\bpriority 1\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\bpriority 2\b', caseSensitive: false), TaskPriority.medium),
    (RegExp(r'\bpriority 3\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\bp[1-3]\b', caseSensitive: false), null),
    (RegExp(r'\bwhen you get a chance\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\bwhen you can\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\btake your time\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\burgent\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\basap\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\bcritical\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\bimportant\b', caseSensitive: false), TaskPriority.high),
    (RegExp(r'\bminor\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\btrivial\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\bwhenever\b', caseSensitive: false), TaskPriority.low),
    (RegExp(r'\banytime\b', caseSensitive: false), TaskPriority.low),
  ];

  int _priValue(TaskPriority p) => p.index;
  var bestPriority = ctx.priority;
  var bestValue = bestPriority != null ? _priValue(bestPriority) : 0;

  for (final (pattern, pri) in patterns) {
    final match = pattern.firstMatch(ctx.text);
    if (match != null) {
      final matchedText = match.group(0)!;
      final matchedPri = pri ?? (matchedText.length == 2 && matchedText.startsWith('p')
          ? switch (int.parse(matchedText[1])) {
              1 => TaskPriority.high,
              2 => TaskPriority.medium,
              _ => TaskPriority.low,
            }
          : null);

      if (matchedPri != null) {
        final val = _priValue(matchedPri);
        if (val > bestValue) {
          bestPriority = matchedPri;
          bestValue = val;
        }
      }

      // Remove the matched text, including any orphaned "tag "/"label " prefix
      final withPrefix = RegExp(
        r'\b(tag|label)\s+' + RegExp.escape(matchedText) + r'\b',
        caseSensitive: false,
      );
      final prefixMatch = withPrefix.firstMatch(ctx.text);
      if (prefixMatch != null) {
        ctx.text = ctx.text.replaceFirst(prefixMatch.group(0)!, '').trim();
      } else {
        ctx.text = ctx.text.replaceFirst(
          RegExp(RegExp.escape(matchedText), caseSensitive: false),
          '',
        ).trim();
      }
    }
  }

  if (bestPriority != null) {
    ctx.priority = bestPriority;
  }
}

void _extractNotes(_ParseCtx ctx) {
  final patterns = [
    RegExp(r'(?:note|notes|comment|description|details)[:\s]\s*(.+?)$', caseSensitive: false),
    RegExp(r'\bwith\s+note[:\s]\s*(.+?)$', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(ctx.text);
    if (match != null) {
      ctx.notes = match.group(1)?.trim();
      ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
      return;
    }
  }

  // "note that [text]" 
  final noteThat = RegExp(r'\bnote\s+that\s+(.+?)$', caseSensitive: false);
  final match = noteThat.firstMatch(ctx.text);
  if (match != null) {
    ctx.notes = match.group(1)?.trim();
    ctx.text = ctx.text.replaceFirst(match.group(0)!, '').trim();
  }
}
