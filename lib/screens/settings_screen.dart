import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_settings.dart';
import 'tutorial_screen.dart';
import '../services/firestore_service.dart';
import '../services/android_power_settings_service.dart';
import '../services/settings_service.dart';
import '../widgets/interactive_card.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final Future<bool> Function(String oldName, String newName)? onRenameSemester;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    this.onRenameSemester,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  final _semesterController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _powerSettingsService = AndroidPowerSettingsService();
  final _firestoreService = FirestoreService();
  bool _profileLoading = true;

  Color _currentPrimary() {
    final v = _settings.customPrimaryColor;
    if (v != null) return Color(v);
    return AppTheme.resolveSeed(_settings.themeSeedKey);
  }

  Color _currentSecondary() {
    final v = _settings.customSecondaryColor;
    if (v != null) return Color(v);
    return AppTheme.seedColors['emerald']!;
  }

  Future<Color?> _pickColor(Color initial, String title) async {
    HSVColor hsv = HSVColor.fromColor(initial);
    return showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 44,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: hsv.toColor(),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Slider(
                value: hsv.hue,
                min: 0,
                max: 360,
                onChanged: (v) => setDialogState(() => hsv = hsv.withHue(v)),
              ),
              Slider(
                value: hsv.saturation,
                min: 0,
                max: 1,
                onChanged: (v) =>
                    setDialogState(() => hsv = hsv.withSaturation(v)),
              ),
              Slider(
                value: hsv.value,
                min: 0.2,
                max: 1,
                onChanged: (v) => setDialogState(() => hsv = hsv.withValue(v)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, hsv.toColor()),
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _settings = AppSettings.fromMap(widget.settings.toMap());
    _loadProfile();
  }

  @override
  void dispose() {
    _semesterController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _profileLoading = false);
      return;
    }
    final profile = await _firestoreService.loadUserProfile(user.uid);
    final profileData = (profile?['profile'] as Map?)?.cast<String, dynamic>();
    _nameController.text =
        (profileData?['fullName'] ?? user.displayName ?? '').toString();
    _phoneController.text =
        (profileData?['phone'] ?? user.phoneNumber ?? '').toString();
    _bioController.text = (profileData?['bio'] ?? '').toString();
    if (mounted) setState(() => _profileLoading = false);
  }

  Future<void> _saveProfile() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final fullName = _nameController.text.trim();
    if (fullName.isNotEmpty && fullName != user.displayName) {
      await user.updateDisplayName(fullName);
    }
    final ok = await _firestoreService.saveUserProfile(
      user.uid,
      fullName: fullName,
      phone: _phoneController.text.trim(),
      bio: _bioController.text.trim(),
    );
    await _firestoreService.upsertUserMetadata(user);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'Profile updated' : 'Profile save failed')),
    );
  }

  Future<void> _update(void Function() edit) async {
    setState(edit);
    await SettingsService().save(_settings);
    if (!mounted) return;
    widget.onChanged(_settings);
  }

  bool _validSemesterName(String value) {
    final name = value.trim();
    if (name.isEmpty) return false;
    if (name.contains('/')) return false;
    return true;
  }

  Future<void> _renameCurrentSemester() async {
    final oldName = _settings.currentSemester;
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename semester'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Semester name',
            hintText: 'e.g. Semester 2',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null) return;
    if (!_validSemesterName(newName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid semester name')),
      );
      return;
    }
    if (newName == oldName) return;
    if (_settings.semesters.contains(newName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semester name already exists')),
      );
      return;
    }

    bool moved = true;
    if (widget.onRenameSemester != null) {
      moved = await widget.onRenameSemester!(oldName, newName);
    }
    if (!moved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rename failed. Target semester already has data.'),
        ),
      );
      return;
    }

    await _update(() {
      final list = [..._settings.semesters];
      final i = list.indexOf(oldName);
      if (i >= 0) {
        list[i] = newName;
      }
      _settings.semesters = list;
      _settings.currentSemester = newName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 24 + bottomInset),
            children: [
          InteractiveCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_profileLoading)
                    const LinearProgressIndicator(minHeight: 2)
                  else ...[
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bioController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Bio'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save profile'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          InteractiveCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              SwitchListTile(
                title: const Text('Dark mode'),
                subtitle: const Text('Switch between light and dark themes'),
                value: _settings.darkMode,
                onChanged: (v) => _update(() => _settings.darkMode = v),
              ),
              SwitchListTile(
                title: const Text('Custom colors'),
                subtitle: const Text('Choose your own primary/gradient colors'),
                value: _settings.useCustomColors,
                onChanged: (v) => _update(() => _settings.useCustomColors = v),
              ),
              if (_settings.useCustomColors)
                ListTile(
                  title: const Text('Primary color'),
                  leading: CircleAvatar(backgroundColor: _currentPrimary()),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await _pickColor(
                        _currentPrimary(),
                        'Pick primary color',
                      );
                      if (picked == null) return;
                      _update(
                        () => _settings.customPrimaryColor = picked.toARGB32(),
                      );
                    },
                    child: const Text('Pick'),
                  ),
                ),
              if (_settings.useCustomColors)
                ListTile(
                  title: const Text('Gradient secondary color'),
                  leading: CircleAvatar(backgroundColor: _currentSecondary()),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await _pickColor(
                        _currentSecondary(),
                        'Pick gradient color',
                      );
                      if (picked == null) return;
                      _update(
                        () => _settings.customSecondaryColor = picked.toARGB32(),
                      );
                    },
                    child: const Text('Pick'),
                  ),
                ),
              if (_settings.useCustomColors)
                SwitchListTile(
                  title: const Text('Enable gradient'),
                  subtitle: const Text('Use primary -> secondary gradients'),
                  value: _settings.gradientEnabled,
                  onChanged: (v) => _update(() => _settings.gradientEnabled = v),
                ),
              ListTile(
                title: const Text('Background & battery setup'),
                subtitle: const Text(
                  'Open Android background activity and battery optimization settings',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _powerSettingsService.showSetupDialog(context),
              ),
              ListTile(
                title: const Text('View app tutorial'),
                subtitle: const Text('Open product walkthrough anytime'),
                trailing: const Icon(Icons.school_outlined),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TutorialScreen(
                        onDone: () => Navigator.pop(context),
                        onStartInteractive: () async {
                          final navigator = Navigator.of(context);
                          await _update(
                            () {
                              _settings.interactiveGuideEnabled = true;
                              _settings.interactiveGuideStep = 0;
                            },
                          );
                          if (!context.mounted) return;
                          navigator.pop();
                          navigator.pop();
                        },
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('Start interactive guide'),
                subtitle: const Text('Guided steps directly inside home screen'),
                trailing: const Icon(Icons.assistant_navigation),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await _update(() {
                    _settings.interactiveGuideEnabled = true;
                    _settings.interactiveGuideStep = 0;
                  });
                  if (!context.mounted) return;
                  navigator.pop();
                },
              ),
            ]),
          ),
          InteractiveCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              SwitchListTile(
                title: const Text('Enable swipe actions'),
                value: _settings.enableSwipeActions,
                onChanged: (v) => _update(() => _settings.enableSwipeActions = v),
              ),
              SwitchListTile(
                title: const Text('Auto cloud sync'),
                value: _settings.autoCloudSync,
                onChanged: (v) => _update(() => _settings.autoCloudSync = v),
              ),
            ]),
          ),
          InteractiveCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              SwitchListTile(
                title: const Text('Default reminders for new subjects'),
                value: _settings.defaultSubjectReminderEnabled,
                onChanged: (v) =>
                    _update(() => _settings.defaultSubjectReminderEnabled = v),
              ),
              ListTile(
                title: const Text('Default reminder minutes'),
                subtitle: Text('${_settings.defaultSubjectReminderMinutes} min'),
                trailing: DropdownButton<int>(
                  value: _settings.defaultSubjectReminderMinutes,
                  items: const [5, 10, 15, 30, 60]
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    _update(() => _settings.defaultSubjectReminderMinutes = v);
                  },
                ),
              ),
              ListTile(
                title: const Text('Default attendance goal'),
                subtitle: Text('${_settings.defaultGoalPercent.toStringAsFixed(0)}%'),
                trailing: DropdownButton<double>(
                  value: _settings.defaultGoalPercent,
                  items: const [75.0, 80.0, 85.0, 90.0]
                      .map((e) => DropdownMenuItem(value: e, child: Text('${e.toInt()}%')))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    _update(() => _settings.defaultGoalPercent = v);
                  },
                ),
              ),
            ]),
          ),
          InteractiveCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              ListTile(
                title: const Text('Active semester'),
                subtitle: Text(_settings.currentSemester),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Rename semester',
                      onPressed: _renameCurrentSemester,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    DropdownButton<String>(
                      value: _settings.currentSemester,
                      items: _settings.semesters
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        _update(() => _settings.currentSemester = v);
                      },
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Add semester profile'),
                subtitle: TextField(
                  controller: _semesterController,
                  decoration: const InputDecoration(hintText: 'e.g. Semester 2'),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    final name = _semesterController.text.trim();
                    if (!_validSemesterName(name)) return;
                    if (_settings.semesters.contains(name)) return;
                    _update(() {
                      _settings.semesters = [..._settings.semesters, name];
                      _settings.currentSemester = name;
                    });
                    _semesterController.clear();
                  },
                ),
              ),
            ]),
          ),
          InteractiveCard(
            child: ListTile(
              title: const Text('Sign out'),
              leading: const Icon(Icons.logout),
              onTap: () async {
                final navigator = Navigator.of(context);
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                navigator.pop();
              },
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
