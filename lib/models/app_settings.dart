class AppSettings {
  bool compactHomeCards;
  bool enableSwipeActions;
  bool autoCloudSync;
  bool showWeeklyTrend;
  bool showForecastHints;
  bool onboardingCompleted;
  bool defaultSubjectReminderEnabled;
  int defaultSubjectReminderMinutes;
  double defaultGoalPercent;
  String currentSemester;
  List<String> semesters;
  bool darkMode;
  bool tutorialCompleted;
  bool interactiveGuideEnabled;
  int interactiveGuideStep;
  String themeSeedKey;
  bool useCustomColors;
  bool gradientEnabled;
  int? customPrimaryColor;
  int? customSecondaryColor;

  AppSettings({
    this.compactHomeCards = false,
    this.enableSwipeActions = true,
    this.autoCloudSync = true,
    this.showWeeklyTrend = true,
    this.showForecastHints = true,
    this.onboardingCompleted = false,
    this.defaultSubjectReminderEnabled = true,
    this.defaultSubjectReminderMinutes = 15,
    this.defaultGoalPercent = 75,
    this.currentSemester = 'Semester 1',
    this.semesters = const ['Semester 1'],
    this.darkMode = false,
    this.tutorialCompleted = false,
    this.interactiveGuideEnabled = false,
    this.interactiveGuideStep = 0,
    this.themeSeedKey = 'ocean',
    this.useCustomColors = false,
    this.gradientEnabled = true,
    this.customPrimaryColor,
    this.customSecondaryColor,
  });

  Map<String, dynamic> toMap() => {
    'compactHomeCards': compactHomeCards,
    'enableSwipeActions': enableSwipeActions,
    'autoCloudSync': autoCloudSync,
    'showWeeklyTrend': showWeeklyTrend,
    'showForecastHints': showForecastHints,
    'onboardingCompleted': onboardingCompleted,
    'defaultSubjectReminderEnabled': defaultSubjectReminderEnabled,
    'defaultSubjectReminderMinutes': defaultSubjectReminderMinutes,
    'defaultGoalPercent': defaultGoalPercent,
    'currentSemester': currentSemester,
    'semesters': semesters,
    'darkMode': darkMode,
    'tutorialCompleted': tutorialCompleted,
    'interactiveGuideEnabled': interactiveGuideEnabled,
    'interactiveGuideStep': interactiveGuideStep,
    'themeSeedKey': themeSeedKey,
    'useCustomColors': useCustomColors,
    'gradientEnabled': gradientEnabled,
    'customPrimaryColor': customPrimaryColor,
    'customSecondaryColor': customSecondaryColor,
  };

  factory AppSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return AppSettings();
    return AppSettings(
      compactHomeCards: map['compactHomeCards'] ?? false,
      enableSwipeActions: map['enableSwipeActions'] ?? true,
      autoCloudSync: map['autoCloudSync'] ?? true,
      showWeeklyTrend: map['showWeeklyTrend'] ?? true,
      showForecastHints: map['showForecastHints'] ?? true,
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      defaultSubjectReminderEnabled: map['defaultSubjectReminderEnabled'] ?? true,
      defaultSubjectReminderMinutes: map['defaultSubjectReminderMinutes'] ?? 15,
      defaultGoalPercent: (map['defaultGoalPercent'] ?? 75).toDouble(),
      currentSemester: map['currentSemester'] ?? 'Semester 1',
      semesters: (map['semesters'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Semester 1'],
      darkMode: map['darkMode'] ?? false,
      tutorialCompleted: map['tutorialCompleted'] ?? false,
      interactiveGuideEnabled: map['interactiveGuideEnabled'] ?? false,
      interactiveGuideStep: (map['interactiveGuideStep'] ?? 0) is num
          ? (map['interactiveGuideStep'] as num).toInt()
          : 0,
      themeSeedKey: (map['themeSeedKey'] ?? 'ocean').toString(),
      useCustomColors: map['useCustomColors'] ?? false,
      gradientEnabled: map['gradientEnabled'] ?? true,
      customPrimaryColor: map['customPrimaryColor'] is num
          ? (map['customPrimaryColor'] as num).toInt()
          : null,
      customSecondaryColor: map['customSecondaryColor'] is num
          ? (map['customSecondaryColor'] as num).toInt()
          : null,
    );
  }
}
