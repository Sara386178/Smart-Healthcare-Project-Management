import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database.dart';
import 'project_metrics.dart';

const ink = Color(0xFF123D43),
    teal = Color(0xFF147D78),
    bg = Color(0xFFF4F7F8),
    amber = Color(0xFFF0A43A),
    red = Color(0xFFBD4B4B),
    green = Color(0xFF26816C);
final demoAsOf = DateTime(2026, 10, 25);
final originalDeadline = DateTime(2026, 11, 23);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HealthPMBootstrap());
}

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
Future<void>? _supabaseInitialization;

Future<void> _initializeSupabase() =>
    _supabaseInitialization ??= Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );

class HealthPMBootstrap extends StatelessWidget {
  const HealthPMBootstrap({super.key});
  @override
  Widget build(BuildContext context) {
    if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
      return const MaterialApp(home: _BackendConfigurationRequired());
    }
    return FutureBuilder<void>(
      future: _initializeSupabase(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _bootstrapError(
            'Supabase could not be initialized.',
            snapshot.error!,
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return const _SupabaseSessionGate();
      },
    );
  }
}

Widget _bootstrapError(String title, Object error) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  ),
);

class _BackendConfigurationRequired extends StatelessWidget {
  const _BackendConfigurationRequired();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Supabase is not configured. Start the app with the supplied Supabase configuration file.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _SupabaseSessionGate extends StatelessWidget {
  const _SupabaseSessionGate();
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, _) {
        if (client.auth.currentUser == null) {
          return _SupabaseSignInPage(client: client);
        }
        return FutureBuilder<ProjectDatabase>(
          future: ProjectDatabase.openSupabase(client),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _bootstrapError(
                'Could not connect to the HealthPM database.',
                snapshot.error!,
              );
            }
            if (!snapshot.hasData) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            return HealthPM(db: snapshot.data!);
          },
        );
      },
    );
  }
}

class _SupabaseSignInPage extends StatefulWidget {
  const _SupabaseSignInPage({required this.client});
  final SupabaseClient client;
  @override
  State<_SupabaseSignInPage> createState() => _SupabaseSignInPageState();
}

class _SupabaseSignInPageState extends State<_SupabaseSignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      if (_signUp) {
        final result = await widget.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          emailRedirectTo: Uri.base.origin,
        );
        if (result.session == null && mounted) {
          setState(
            () => _message =
                'Check your email to confirm your account, then sign in.',
          );
        }
      } else {
        await widget.client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'HealthPM sign in',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: teal)),
    home: Scaffold(
      backgroundColor: bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'HEALTH·PM',
                      style: TextStyle(
                        color: teal,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _signUp ? 'Create your account' : 'Sign in to HealthPM',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your account controls access to the hosted project database.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Enter a valid email address.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => value == null || value.length < 8
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: red)),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, style: const TextStyle(color: green)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Please wait…'
                            : _signUp
                            ? 'Create account'
                            : 'Sign in',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _signUp = !_signUp;
                              _message = null;
                              _error = null;
                            }),
                      child: Text(
                        _signUp
                            ? 'I already have an account'
                            : 'Create a new account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HealthPM extends StatefulWidget {
  const HealthPM({super.key, required this.db});
  final ProjectDatabase db;
  @override
  State<HealthPM> createState() => _HealthPMState();
}

class _HealthPMState extends State<HealthPM> {
  int selected = 0, revision = 0;
  final titles = [
    'Overview',
    'Scope & WBS',
    'Schedule & team',
    'Cost & EVM',
    'Quality & risks',
    'Reports',
    'Database',
  ];
  final icons = [
    Icons.space_dashboard_outlined,
    Icons.account_tree_outlined,
    Icons.timeline,
    Icons.payments_outlined,
    Icons.verified_user_outlined,
    Icons.description_outlined,
    Icons.storage_outlined,
  ];
  void refresh() {
    setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'HealthPM',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        primary: ink,
        surface: bg,
      ),
      scaffoldBackgroundColor: bg,
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    ),
    home: Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: ink,
            extended: false,
            selectedIndex: selected,
            onDestinationSelected: (i) => setState(() => selected = i),
            leading: const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 30),
              child: CircleAvatar(
                backgroundColor: Color(0xFF205A60),
                child: Icon(Icons.local_hospital_outlined, color: Colors.white),
              ),
            ),
            destinations: [
              for (var i = 0; i < titles.length; i++)
                NavigationRailDestination(
                  icon: Icon(icons[i]),
                  selectedIcon: Icon(icons[i]),
                  label: Text(titles[i]),
                ),
            ],
            labelType: NavigationRailLabelType.all,
            unselectedLabelTextStyle: const TextStyle(
              color: Color(0xFFB8C9CB),
              fontSize: 11,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            unselectedIconTheme: const IconThemeData(color: Color(0xFFB8C9CB)),
            selectedIconTheme: const IconThemeData(color: Colors.white),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: titles[selected], db: widget.db),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey('$selected-$revision'),
                    child: _page(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _page() {
    final db = widget.db;
    final cb = refresh;
    return switch (selected) {
      0 => Overview(db: db, onChange: cb),
      1 => ScopePage(db: db, onChange: cb),
      2 => SchedulePage(db: db, onChange: cb),
      3 => CostPage(db: db, onChange: cb),
      4 => QualityPage(db: db, onChange: cb),
      5 => ReportsPage(db: db, onChange: cb),
      _ => DatabasePage(db: db),
    };
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.db});
  final String title;
  final ProjectDatabase db;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>>(
    future: db.project(),
    builder: (context, snapshot) {
      final projectStatus =
          snapshot.data?['status'] as String? ??
          (snapshot.hasError ? 'Project unavailable' : 'Loading project');
      final statusColor = projectStatus.contains('Rebaselined') ? teal : amber;
      return Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE5ECEE))),
        ),
        child: Row(
          children: [
            Text(
              'HEALTH\u00b7PM',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
                color: teal,
              ),
            ),
            const SizedBox(width: 14),
            const Text('/', style: TextStyle(color: Colors.black26)),
            const SizedBox(width: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const Spacer(),
            Icon(Icons.circle, size: 9, color: statusColor),
            const SizedBox(width: 8),
            Text(
              projectStatus,
              style: const TextStyle(fontSize: 13, color: ink),
            ),
            const SizedBox(width: 18),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE6F0F0),
              child: Icon(Icons.person_outline, size: 18, color: ink),
            ),
            if (db.isSupabase) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => db.supabase!.auth.signOut(),
                icon: const Icon(Icons.logout_outlined),
              ),
            ],
          ],
        ),
      );
    },
  );
}

Widget content(List<Widget> children) => SingleChildScrollView(
  padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1380),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  ),
);
Widget heading(String title, String subtitle, {Widget? action}) => Padding(
  padding: const EdgeInsets.only(bottom: 20),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF718187), fontSize: 13),
            ),
          ],
        ),
      ),
      if (action != null) action,
    ],
  ),
);
Widget sectionTitle(String title, {Widget? action}) => Padding(
  padding: const EdgeInsets.only(bottom: 12, top: 22),
  child: Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      const Spacer(),
      if (action != null) action,
    ],
  ),
);
Widget card(Widget child, {EdgeInsets padding = const EdgeInsets.all(18)}) =>
    Card(
      child: Padding(padding: padding, child: child),
    );
Widget badge(String text, {Color color = teal}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .10),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
  ),
);
Widget button(String text, VoidCallback onTap, {IconData icon = Icons.add}) =>
    FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(text),
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
String money(num x) => 'PKR ${_short(x)}';
String _short(num x) => x >= 1000000
    ? '${(x / 1000000).toStringAsFixed(1)}M'
    : x >= 1000
    ? '${(x / 1000).toStringAsFixed(0)}k'
    : x.toStringAsFixed(0);
String date(String? x) => x == null
    ? '—'
    : x.length >= 10
    ? x.substring(0, 10)
    : x;

enum HealthFormInput { text, multiline, integer, decimal, choice, date, toggle }

class HealthFormField {
  const HealthFormField({
    required this.name,
    required this.label,
    this.input = HealthFormInput.text,
    this.initial = '',
    this.required = true,
    this.choices = const [],
    this.helper,
    this.minimum,
    this.maximum,
    this.validator,
  });

  final String name;
  final String label;
  final HealthFormInput input;
  final Object? initial;
  final bool required;
  final List<String> choices;
  final String? helper;
  final num? minimum;
  final num? maximum;
  final String? Function(String?)? validator;
}

Future<Map<String, Object?>?> showHealthForm(
  BuildContext context, {
  required String title,
  required List<HealthFormField> fields,
  String saveLabel = 'Save changes',
}) => showDialog<Map<String, Object?>>(
  context: context,
  builder: (_) =>
      _HealthFormDialog(title: title, fields: fields, saveLabel: saveLabel),
);

class _HealthFormDialog extends StatefulWidget {
  const _HealthFormDialog({
    required this.title,
    required this.fields,
    required this.saveLabel,
  });

  final String title;
  final List<HealthFormField> fields;
  final String saveLabel;

  @override
  State<_HealthFormDialog> createState() => _HealthFormDialogState();
}

class _HealthFormDialogState extends State<_HealthFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String?> _choices;
  late final Map<String, bool> _toggles;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        if (field.input != HealthFormInput.choice &&
            field.input != HealthFormInput.toggle)
          field.name: TextEditingController(
            text: field.initial?.toString() ?? '',
          ),
    };
    _choices = {
      for (final field in widget.fields)
        if (field.input == HealthFormInput.choice)
          field.name: field.choices.contains(field.initial)
              ? field.initial as String?
              : field.choices.firstOrNull,
    };
    _toggles = {
      for (final field in widget.fields)
        if (field.input == HealthFormInput.toggle)
          field.name: field.initial == true,
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(HealthFormField field, String? raw) {
    final customError = field.validator?.call(raw);
    if (customError != null) return customError;
    final value = raw?.trim() ?? '';
    if (field.required && value.isEmpty) return '${field.label} is required.';
    if (value.isEmpty) return null;
    if (field.input == HealthFormInput.integer ||
        field.input == HealthFormInput.decimal) {
      final number = field.input == HealthFormInput.integer
          ? int.tryParse(value)
          : double.tryParse(value);
      if (number == null || (number is double && !number.isFinite)) {
        return 'Enter a valid ${field.input == HealthFormInput.integer ? 'whole number' : 'number'}.';
      }
      if (field.minimum != null && number < field.minimum!) {
        return 'Enter at least ${field.minimum}.';
      }
      if (field.maximum != null && number > field.maximum!) {
        return 'Enter no more than ${field.maximum}.';
      }
    }
    if (field.input == HealthFormInput.date) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          parsed.toIso8601String().substring(0, 10) != value) {
        return 'Choose a valid date.';
      }
    }
    return null;
  }

  Widget _buildField(HealthFormField field) {
    switch (field.input) {
      case HealthFormInput.choice:
        return DropdownButtonFormField<String>(
          initialValue: _choices[field.name],
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
          ),
          items: [
            for (final choice in field.choices)
              DropdownMenuItem(value: choice, child: Text(choice)),
          ],
          onChanged: (value) => setState(() => _choices[field.name] = value),
          validator: (value) => field.required && value == null
              ? 'Choose ${field.label.toLowerCase()}.'
              : null,
        );
      case HealthFormInput.toggle:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: field.helper == null ? null : Text(field.helper!),
          value: _toggles[field.name] ?? false,
          onChanged: (value) => setState(() => _toggles[field.name] = value),
        );
      case HealthFormInput.date:
        return TextFormField(
          controller: _controllers[field.name],
          readOnly: true,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          validator: (value) => _validate(field, value),
          onTap: () async {
            final current = DateTime.tryParse(_controllers[field.name]!.text);
            final picked = await showDatePicker(
              context: context,
              initialDate: current ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              _controllers[field.name]!.text =
                  '${picked.year.toString().padLeft(4, '0')}-'
                  '${picked.month.toString().padLeft(2, '0')}-'
                  '${picked.day.toString().padLeft(2, '0')}';
            }
          },
        );
      case HealthFormInput.text:
      case HealthFormInput.multiline:
      case HealthFormInput.integer:
      case HealthFormInput.decimal:
        return TextFormField(
          controller: _controllers[field.name],
          keyboardType:
              field.input == HealthFormInput.integer ||
                  field.input == HealthFormInput.decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          maxLines: field.input == HealthFormInput.multiline ? 4 : 1,
          minLines: field.input == HealthFormInput.multiline ? 2 : 1,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
            alignLabelWithHint: field.input == HealthFormInput.multiline,
          ),
          validator: (value) => _validate(field, value),
        );
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final result = <String, Object?>{};
    for (final field in widget.fields) {
      switch (field.input) {
        case HealthFormInput.choice:
          result[field.name] = _choices[field.name];
        case HealthFormInput.toggle:
          result[field.name] = _toggles[field.name] ?? false;
        case HealthFormInput.integer:
          result[field.name] = int.parse(_controllers[field.name]!.text.trim());
        case HealthFormInput.decimal:
          result[field.name] = double.parse(
            _controllers[field.name]!.text.trim(),
          );
        case HealthFormInput.text:
        case HealthFormInput.multiline:
        case HealthFormInput.date:
          result[field.name] = _controllers[field.name]!.text.trim();
      }
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 500,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .68,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _buildField(widget.fields[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: Text(widget.saveLabel)),
    ],
  );
}

Future<void> info(BuildContext c, String title, String msg) => showDialog<void>(
  context: c,
  builder: (x) => AlertDialog(
    title: Text(title),
    content: Text(msg),
    actions: [
      TextButton(onPressed: () => Navigator.pop(x), child: const Text('Close')),
    ],
  ),
);

Widget _loadingState() => const Center(child: CircularProgressIndicator());

Widget _loadFailure(
  String section,
  Object error, {
  VoidCallback? onRetry,
}) => Center(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: card(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_outlined, color: red, size: 28),
            const SizedBox(height: 10),
            Text(
              'Could not load $section',
              style: const TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The app could not read this data from the connected database. '
              'Check the connection and project access, then retry.',
              style: TextStyle(color: Color(0xFF718187), height: 1.45),
            ),
            const SizedBox(height: 12),
            SelectableText(
              error.toString(),
              style: const TextStyle(color: red, fontSize: 12),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
);

Future<bool> _saveFormData(
  BuildContext context, {
  required String errorTitle,
  required Future<void> Function() save,
}) async {
  try {
    await save();
    return true;
  } catch (error) {
    if (context.mounted) {
      await info(context, errorTitle, error.toString());
    }
    return false;
  }
}

class Overview extends StatelessWidget {
  const Overview({super.key, required this.db, required this.onChange});
  final ProjectDatabase db;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: Future.wait([
      db.project(),
      db.rows('activities'),
      db.rows('changes'),
      db.rows('defects'),
      db.rows('requirements'),
    ]),
    builder: (c, s) {
      if (s.hasError) {
        return _loadFailure('Overview', s.error!, onRetry: onChange);
      }
      if (!s.hasData) return _loadingState();
      final p = s.data![0] as Map<String, Object?>;
      final acts = s.data![1] as List<Map<String, Object?>>;
      final changes = s.data![2] as List<Map<String, Object?>>;
      final defects = s.data![3] as List<Map<String, Object?>>;
      final reqs = s.data![4] as List<Map<String, Object?>>;
      final total = p['budget'] as num;
      final metrics = EarnedValueMetrics.calculate(acts, asOf: demoAsOf);
      final pv = metrics.plannedValue,
          ev = metrics.earnedValue,
          ac = metrics.actualCost,
          cpi = metrics.cpi,
          spi = metrics.spi;
      final done = reqs.where((r) => r['status'] == 'Approved').length;
      final pending = changes.where((x) => x['status'] == 'Pending').length;
      final pendingChanges = changes
          .where((x) => x['status'] == 'Pending')
          .toList();
      final firstPending = pendingChanges.isEmpty ? null : pendingChanges.first;
      final featuredChange =
          firstPending ?? (changes.isEmpty ? null : changes.first);
      final critical = defects
          .where(
            (d) => d['severity'] == 'Critical' && d['status'] != 'Resolved',
          )
          .length;
      final progress = ev / total;
      return content([
        heading(
          'Project command center',
          'Five-hospital delivery · baseline status as of 25 Oct 2026',
        ),
        card(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SMART HEALTHCARE PROJECT MANAGEMENT SYSTEM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: teal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${date(p['start_date'] as String?)}  →  ${date(p['deadline'] as String?)}  ·  ${p['status']}',
                      style: const TextStyle(color: Color(0xFF718187)),
                    ),
                  ],
                ),
              ),
              badge('16 WEEK BASELINE', color: ink),
              const SizedBox(width: 10),
              badge('5 HOSPITALS', color: teal),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              'Approved budget',
              money(total),
              Icons.account_balance_wallet_outlined,
              'Baseline: PKR 5.0M',
            ),
            _Metric(
              'Earned value',
              money(ev),
              Icons.task_alt,
              '${(progress * 100).toStringAsFixed(0)}% of approved budget',
            ),
            _Metric(
              'CPI / SPI',
              '${cpi.toStringAsFixed(2)} / ${spi.toStringAsFixed(2)}',
              Icons.speed,
              'Cost / schedule performance',
            ),
            _Metric(
              'Open critical defects',
              '$critical',
              Icons.warning_amber_rounded,
              'Must pass before release',
            ),
          ],
        ),
        sectionTitle('Performance at a glance'),
        card(
          Column(
            children: [
              _bar('Earned value (EV)', ev, total, teal),
              const SizedBox(height: 16),
              _bar('Actual cost (AC)', ac, total, amber),
              const SizedBox(height: 16),
              _bar('Planned value (PV)', pv, total, ink),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Cost variance ${money(ev - ac)}',
                    style: TextStyle(
                      color: ev >= ac ? green : red,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Schedule variance ${money(ev - pv)}',
                    style: TextStyle(
                      color: ev >= pv ? green : red,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        sectionTitle('Decisions & delivery alerts'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.change_circle_outlined, color: amber),
                        const SizedBox(width: 8),
                        const Text(
                          'Scope change',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const Spacer(),
                        badge('$pending PENDING', color: amber),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      featuredChange?['title'] as String? ??
                          'No change requests recorded',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (featuredChange != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Impact: +${money(featuredChange['cost_impact'] as num)} · +${featuredChange['days_impact']} days',
                        style: const TextStyle(
                          color: Color(0xFF718187),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (firstPending != null) ...[
                      const SizedBox(height: 14),
                      button('Review & approve', () async {
                        if (!await _saveFormData(
                          c,
                          errorTitle: 'Could not approve change request',
                          save: () =>
                              db.decideChange(firstPending['id'] as int, true),
                        )) {
                          return;
                        }
                        onChange();
                      }, icon: Icons.fact_check_outlined),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bug_report_outlined, color: red),
                        SizedBox(width: 8),
                        Text(
                          'Quality gate',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$critical critical defects remain open',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Appointment scheduling and patient records require regression testing.',
                      style: TextStyle(color: Color(0xFF718187), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${done}/${reqs.length} approved requirements in scope',
                      style: const TextStyle(
                        color: Color(0xFF718187),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        sectionTitle('Upcoming milestones'),
        card(
          Column(
            children: acts
                .where((a) => a['milestone'] == 1)
                .map((a) => _activityLine(a))
                .toList(),
          ),
        ),
      ]);
    },
  );
  Widget _bar(String name, double value, num budget, Color color) => Row(
    children: [
      SizedBox(
        width: 155,
        child: Text(name, style: const TextStyle(fontSize: 12, color: ink)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (value / budget).clamp(0, 1),
            minHeight: 10,
            color: color,
            backgroundColor: bg,
          ),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 68,
        child: Text(
          money(value),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.note);
  final String label, value, note;
  final IconData icon;
  @override
  Widget build(BuildContext c) => SizedBox(
    width: 245,
    child: card(
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: teal.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF718187),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF718187),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
    ),
  );
}

class ScopePage extends StatelessWidget {
  const ScopePage({super.key, required this.db, required this.onChange});
  final ProjectDatabase db;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext c) => FutureBuilder(
    future: Future.wait([
      db.project(),
      db.rows('requirements'),
      db.rows('changes'),
      db.rows('activities'),
    ]),
    builder: (c, s) {
      if (s.hasError) {
        return _loadFailure('scope and WBS', s.error!, onRetry: onChange);
      }
      if (!s.hasData) return _loadingState();
      final reqs = s.data![1] as List<Map<String, Object?>>;
      final changeFeaturesApproved =
          reqs
              .where(
                (r) =>
                    r['source'] == 'Change request CR-001' &&
                    r['status'] == 'Approved',
              )
              .length ==
          2;
      final changes = s.data![2] as List<Map<String, Object?>>;
      final acts = s.data![3] as List<Map<String, Object?>>;
      return content([
        heading(
          'Scope & WBS',
          changeFeaturesApproved
              ? 'Approved requirements define the current baseline; CR-001 is included.'
              : 'Approved requirements define the baseline. Pending requests stay outside scope.',
          action: button('Add requirement', () async {
            final values = await showHealthForm(
              c,
              title: 'Add requirement',
              fields: const [
                HealthFormField(name: 'title', label: 'Requirement name'),
                HealthFormField(
                  name: 'description',
                  label: 'Description and acceptance details',
                  input: HealthFormInput.multiline,
                ),
                HealthFormField(
                  name: 'priority',
                  label: 'Priority',
                  input: HealthFormInput.choice,
                  initial: 'Should have',
                  choices: ['Must have', 'Should have', 'Could have'],
                ),
              ],
              saveLabel: 'Add requirement',
            );
            if (values == null) return;
            if (!await _saveFormData(
              c,
              errorTitle: 'Could not save requirement',
              save: () => db.addRequirement(
                values['title'] as String,
                values['description'] as String,
                values['priority'] as String,
              ),
            )) {
              return;
            }
            onChange();
          }),
        ),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BASELINE SCOPE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1,
                  color: teal,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Appointments · patient records · laboratory reports · doctor schedules · online consultations · billing${changeFeaturesApproved ? ' · AI decision support · mobile app' : ''}',
                style: TextStyle(color: ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              Text(
                changeFeaturesApproved
                    ? 'CR-001 approved: budget and deadline have been rebaselined; see Schedule & team for delivery dates.'
                    : 'Out of baseline: AI preliminary diagnosis and mobile application until a change is approved.',
                style: TextStyle(color: Color(0xFF718187), fontSize: 12),
              ),
            ],
          ),
        ),
        sectionTitle('Requirements register'),
        card(
          Column(
            children: reqs.map((r) {
              final source = r['source'] as String;
              final linkedRequest = RegExp(
                r'^Change request (CR-\d+)',
              ).firstMatch(source);
              final canApprove =
                  linkedRequest == null ||
                  changes.any(
                    (change) =>
                        (change['title'] as String).startsWith(
                          linkedRequest.group(1)!,
                        ) &&
                        change['status'] == 'Approved',
                  );
              return _requirementLine(
                c,
                db,
                r,
                onChange,
                canApprove: canApprove,
              );
            }).toList(),
          ),
        ),
        sectionTitle('Hierarchical work breakdown structure'),
        card(
          Column(
            children: [
              for (final phase in _wbsGroups(acts).entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${phase.key} · ${_phaseName(phase.key)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: teal,
                      ),
                    ),
                  ),
                ),
                ...phase.value.map((a) => _activityLine(a, indent: true)),
              ],
            ],
          ),
        ),
        sectionTitle(
          'Change control',
          action: TextButton.icon(
            onPressed: () async {
              final values = await showHealthForm(
                c,
                title: 'Submit change request',
                fields: const [
                  HealthFormField(name: 'title', label: 'Change title'),
                  HealthFormField(
                    name: 'justification',
                    label: 'Business justification',
                    input: HealthFormInput.multiline,
                  ),
                  HealthFormField(
                    name: 'cost',
                    label: 'Additional cost (PKR)',
                    input: HealthFormInput.decimal,
                    initial: '0',
                    minimum: 0,
                  ),
                  HealthFormField(
                    name: 'days',
                    label: 'Schedule impact (days)',
                    input: HealthFormInput.integer,
                    initial: '0',
                    minimum: 0,
                  ),
                ],
                saveLabel: 'Submit for review',
              );
              if (values == null) return;
              if (!await _saveFormData(
                c,
                errorTitle: 'Could not submit change request',
                save: () => db.addChange(
                  values['title'] as String,
                  values['justification'] as String,
                  values['cost'] as double,
                  values['days'] as int,
                ),
              )) {
                return;
              }
              onChange();
            },
            icon: const Icon(Icons.add),
            label: const Text('New request'),
          ),
        ),
        ...changes.map((x) => _changeCard(c, db, x, onChange)),
      ]);
    },
  );
}

String _suggestNewActivityCode(List<Map<String, Object?>> activities) {
  var highest = 0;
  for (final activity in activities) {
    final match = RegExp(r'^4\.(\d+)$').firstMatch(activity['code'] as String);
    final number = int.tryParse(match?.group(1) ?? '');
    if (number != null && number > highest) highest = number;
  }
  return '4.${highest + 1}';
}

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key, required this.db, required this.onChange});
  final ProjectDatabase db;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext c) => FutureBuilder(
    future: Future.wait([db.project(), db.rows('activities')]),
    builder: (c, s) {
      if (s.hasError) {
        return _loadFailure('schedule', s.error!, onRetry: onChange);
      }
      if (!s.hasData) return _loadingState();
      final p = s.data![0] as Map<String, Object?>;
      final acts = s.data![1] as List<Map<String, Object?>>;
      final deadline = DateTime.parse(p['deadline'] as String);
      final projectStart = DateTime.parse(p['start_date'] as String);
      final forecast = forecastActivities(acts, asOf: demoAsOf);
      final projectedFinish = forecast.values
          .map((x) => x.finish)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final finishVariance = projectedFinish.difference(deadline).inDays;
      return content([
        heading(
          'Schedule & team',
          'Select a Gantt row to edit it; scroll the chart horizontally for later dates.',
          action: button('Add activity', () async {
            final values = await showHealthForm(
              c,
              title: 'Add work package',
              fields: [
                HealthFormField(
                  name: 'code',
                  label: 'WBS code',
                  initial: _suggestNewActivityCode(acts),
                  helper: 'Use a hierarchical code such as 2.5 or 4.1.',
                  validator: (value) {
                    final code = value?.trim() ?? '';
                    if (!RegExp(r'^\d+(\.\d+)+$').hasMatch(code)) {
                      return 'Enter a hierarchical code such as 2.5.';
                    }
                    if (acts.any((activity) => activity['code'] == code)) {
                      return 'This WBS code is already in use.';
                    }
                    return null;
                  },
                ),
                const HealthFormField(name: 'name', label: 'Work package name'),
                const HealthFormField(
                  name: 'owner',
                  label: 'Responsible team member or role',
                ),
                HealthFormField(
                  name: 'startDate',
                  label: 'Planned start date',
                  input: HealthFormInput.date,
                  initial: DateTime.now().toIso8601String().substring(0, 10),
                ),
                const HealthFormField(
                  name: 'duration',
                  label: 'Duration (days)',
                  input: HealthFormInput.integer,
                  initial: '10',
                  minimum: 1,
                ),
                const HealthFormField(
                  name: 'cost',
                  label: 'Planned cost (PKR)',
                  input: HealthFormInput.decimal,
                  initial: '0',
                  minimum: 0,
                ),
                const HealthFormField(
                  name: 'dependency',
                  label: 'Predecessor WBS codes',
                  input: HealthFormInput.multiline,
                  required: false,
                  helper: 'Optional. Separate multiple codes with commas.',
                ),
                const HealthFormField(
                  name: 'milestone',
                  label: 'Mark as a milestone',
                  input: HealthFormInput.toggle,
                ),
              ],
              saveLabel: 'Add work package',
            );
            if (values == null) return;
            try {
              await db.addActivity(
                code: values['code'] as String,
                name: values['name'] as String,
                owner: values['owner'] as String,
                startDate: values['startDate'] as String,
                duration: values['duration'] as int,
                cost: values['cost'] as double,
                dependency: values['dependency'] as String,
                milestone: values['milestone'] as bool,
              );
            } catch (e) {
              await info(
                c,
                'Invalid activity dependencies',
                e.toString().replaceFirst('Invalid argument(s): ', ''),
              );
              return;
            }
            onChange();
          }),
        ),
        Row(
          children: [
            Expanded(
              child: card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PROJECT START',
                      style: TextStyle(fontSize: 10, color: Color(0xFF718187)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      date(p['start_date'] as String?),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT DEADLINE',
                      style: TextStyle(fontSize: 10, color: Color(0xFF718187)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      date(p['deadline'] as String?),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SCHEDULE BASELINE',
                      style: TextStyle(fontSize: 10, color: Color(0xFF718187)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${originalDeadline.difference(projectStart).inDays} days · 16 weeks',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        card(
          Row(
            children: [
              Icon(
                finishVariance > 0
                    ? Icons.warning_amber_rounded
                    : Icons.event_available_outlined,
                color: finishVariance > 0 ? red : green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dependency forecast: ${date(projectedFinish.toIso8601String())}${finishVariance > 0 ? ' · ${finishVariance} days beyond current deadline' : ' · within current deadline'}',
                  style: TextStyle(
                    color: finishVariance > 0 ? red : green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        sectionTitle('Gantt schedule · planned vs forecast'),
        card(
          _GanttChart(
            activities: acts,
            forecasts: forecast,
            projectStart: projectStart,
            deadline: deadline,
            horizon: projectedFinish,
            onActivityTap: (activity) =>
                _editActivityPlan(c, db, activity, onChange),
          ),
        ),
        sectionTitle('Delivery timeline · dates & progress'),
        card(
          Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'ACTIVITY / OWNER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF718187),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'START → FINISH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF718187),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 100,
                    child: Text(
                      'PROGRESS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF718187),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              ...acts.map(
                (a) => _timeline(
                  c,
                  db,
                  a,
                  onChange,
                  forecast[a['code'] as String],
                ),
              ),
            ],
          ),
        ),
        sectionTitle('Dependencies & delay analysis'),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Finish-to-start dependencies are recalculated from predecessor forecasts. Incomplete activities consume their remaining estimated duration; successors move to the latest forecast predecessor finish.',
                style: TextStyle(color: Color(0xFF718187), height: 1.5),
              ),
              const SizedBox(height: 10),
              ...acts
                  .where((a) => a['dependency'].toString().isNotEmpty)
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${a['code']} ${a['name']}  ←  ${a['dependency']}',
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ]);
    },
  );
}

class CostPage extends StatelessWidget {
  const CostPage({super.key, required this.db, required this.onChange});
  final ProjectDatabase db;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext c) => FutureBuilder(
    future: Future.wait([db.project(), db.rows('activities')]),
    builder: (c, s) {
      if (s.hasError) {
        return _loadFailure('cost and EVM data', s.error!, onRetry: onChange);
      }
      if (!s.hasData) return _loadingState();
      final p = s.data![0] as Map<String, Object?>,
          acts = s.data![1] as List<Map<String, Object?>>;
      final metrics = EarnedValueMetrics.calculate(acts, asOf: demoAsOf);
      final pv = metrics.plannedValue,
          ev = metrics.earnedValue,
          ac = metrics.actualCost;
      final plannedBudget = acts.fold<double>(
        0,
        (v, a) => v + (a['cost'] as num).toDouble(),
      );
      final cpi = metrics.cpi, spi = metrics.spi;
      return content([
        heading(
          'Cost control & earned value',
          'Planned value, earned value and actual cost roll up from activity records.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              'Planned Value · PV',
              money(pv),
              Icons.event_note_outlined,
              'Budgeted work scheduled to date',
            ),
            _Metric(
              'Earned Value · EV',
              money(ev),
              Icons.check_circle_outline,
              'Budgeted value of completed work',
            ),
            _Metric(
              'Actual Cost · AC',
              money(ac),
              Icons.receipt_long_outlined,
              'Reported expenditure',
            ),
            _Metric(
              'CPI / SPI',
              '${cpi.toStringAsFixed(2)} / ${spi.toStringAsFixed(2)}',
              Icons.speed,
              'CPI = EV/AC · SPI = EV/PV',
            ),
          ],
        ),
        sectionTitle('Performance interpretation'),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _interpret('Cost variance', ev - ac, 'EV − AC'),
              _interpret('Schedule variance', ev - pv, 'EV − PV'),
              const Divider(height: 24),
              Text(
                cpi < .9
                    ? 'Cost warning: CPI is below 0.90. Review expenditure and forecasts.'
                    : cpi < 1
                    ? 'Cost watch: actual spending is ahead of earned value.'
                    : 'Cost is within threshold.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cpi < .9
                      ? red
                      : cpi < 1
                      ? amber
                      : green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                spi < .9
                    ? 'Schedule warning: SPI is below 0.90. Escalate critical path recovery.'
                    : spi < 1
                    ? 'Schedule watch: delivery is behind the time-phased plan.'
                    : 'Schedule is within threshold.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: spi < .9
                      ? red
                      : spi < 1
                      ? amber
                      : green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Approved budget: ${money(p['budget'] as num)} · original baseline: PKR 5,000,000',
                style: const TextStyle(color: Color(0xFF718187), fontSize: 12),
              ),
              const SizedBox(height: 7),
              Text(
                'Planned activity budget: ${money(plannedBudget)} · ${plannedBudget > (p['budget'] as num) ? 'over approved funding by ${money(plannedBudget - (p['budget'] as num))}' : 'within approved funding'}',
                style: TextStyle(
                  color: plannedBudget > (p['budget'] as num) ? red : green,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        sectionTitle('Activity-level estimates & actuals'),
        card(
          Column(
            children: [for (final a in acts) _costRow(c, db, a, onChange)],
          ),
        ),
      ]);
    },
  );
  Widget _interpret(String label, double v, String formula) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
          ),
        ),
        Text(
          '${money(v)}  ($formula)',
          style: TextStyle(
            color: v < 0 ? red : green,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class QualityPage extends StatelessWidget {
  const QualityPage({super.key, required this.db, required this.onChange});
  final ProjectDatabase db;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext c) => FutureBuilder(
    future: Future.wait([
      db.rows('defects'),
      db.rows('risks'),
      db.rows('checklist'),
    ]),
    builder: (c, s) {
      if (s.hasError) {
        return _loadFailure(
          'quality and risk records',
          s.error!,
          onRetry: onChange,
        );
      }
      if (!s.hasData) return _loadingState();
      final defects = s.data![0], risks = s.data![1], checks = s.data![2];
      return content([
        heading(
          'Quality & risk control',
          'Resolve release-blocking defects and track preventive actions.',
        ),
        sectionTitle(
          'Defect tracker',
          action: button('Log defect', () async {
            final values = await showHealthForm(
              c,
              title: 'Log defect',
              fields: [
                const HealthFormField(
                  name: 'title',
                  label: 'Defect description',
                  input: HealthFormInput.multiline,
                ),
                const HealthFormField(
                  name: 'severity',
                  label: 'Severity',
                  input: HealthFormInput.choice,
                  initial: 'High',
                  choices: ['Critical', 'High', 'Medium', 'Low'],
                ),
                const HealthFormField(
                  name: 'assignee',
                  label: 'Assigned team member or role',
                  initial: 'Quality assurance engineer',
                ),
                const HealthFormField(
                  name: 'status',
                  label: 'Status',
                  input: HealthFormInput.choice,
                  initial: 'Open',
                  choices: ['Open', 'In progress', 'Resolved'],
                ),
                HealthFormField(
                  name: 'reported',
                  label: 'Reported date',
                  input: HealthFormInput.date,
                  initial: DateTime.now().toIso8601String().substring(0, 10),
                ),
              ],
              saveLabel: 'Save defect',
            );
            if (values == null) return;
            if (!await _saveFormData(
              c,
              errorTitle: 'Could not save defect',
              save: () => db.addDefect(
                values['title'] as String,
                values['severity'] as String,
                values['assignee'] as String,
                status: values['status'] as String,
                reported: values['reported'] as String,
              ),
            )) {
              return;
            }
            onChange();
          }, icon: Icons.bug_report_outlined),
        ),
        card(
          Column(
            children: defects
                .map((d) => _defectLine(c, db, d, onChange))
                .toList(),
          ),
        ),
        sectionTitle(
          'Deliverable quality checklist',
          action: button('Add checklist item', () async {
            final values = await showHealthForm(
              c,
              title: 'Add checklist item',
              fields: const [
                HealthFormField(name: 'item', label: 'Inspection item'),
                HealthFormField(name: 'deliverable', label: 'Deliverable'),
                HealthFormField(
                  name: 'result',
                  label: 'Inspection result',
                  input: HealthFormInput.choice,
                  initial: 'Not tested',
                  choices: [
                    'Not tested',
                    'In progress',
                    'Pass',
                    'Fail',
                    'Fail · critical defect open',
                    'Pending',
                  ],
                ),
                HealthFormField(name: 'inspector', label: 'Inspector'),
              ],
              saveLabel: 'Add checklist item',
            );
            if (values == null) return;
            if (!await _saveFormData(
              c,
              errorTitle: 'Could not add checklist item',
              save: () => db.addChecklist(
                item: values['item'] as String,
                deliverable: values['deliverable'] as String,
                result: values['result'] as String,
                inspector: values['inspector'] as String,
              ),
            )) {
              return;
            }
            onChange();
          }),
        ),
        card(
          Column(
            children: checks
                .map((x) => _checkLine(c, db, x, onChange))
                .toList(),
          ),
        ),
        sectionTitle(
          'Prioritization matrix · likelihood × impact',
          action: TextButton.icon(
            onPressed: () async {
              final values = await showHealthForm(
                c,
                title: 'Add risk or issue',
                fields: const [
                  HealthFormField(
                    name: 'title',
                    label: 'Risk or issue description',
                    input: HealthFormInput.multiline,
                  ),
                  HealthFormField(
                    name: 'likelihood',
                    label: 'Likelihood (1–5)',
                    input: HealthFormInput.choice,
                    initial: '3',
                    choices: ['1', '2', '3', '4', '5'],
                  ),
                  HealthFormField(
                    name: 'impact',
                    label: 'Impact (1–5)',
                    input: HealthFormInput.choice,
                    initial: '3',
                    choices: ['1', '2', '3', '4', '5'],
                  ),
                  HealthFormField(
                    name: 'response',
                    label: 'Preventive or corrective response',
                    input: HealthFormInput.multiline,
                  ),
                  HealthFormField(
                    name: 'owner',
                    label: 'Risk owner',
                    initial: 'Project manager',
                  ),
                  HealthFormField(
                    name: 'status',
                    label: 'Status',
                    input: HealthFormInput.choice,
                    initial: 'Open',
                    choices: ['Open', 'Monitoring', 'Closed'],
                  ),
                ],
                saveLabel: 'Save risk',
              );
              if (values == null) return;
              if (!await _saveFormData(
                c,
                errorTitle: 'Could not save risk',
                save: () => db.addRisk(
                  values['title'] as String,
                  int.parse(values['likelihood'] as String),
                  int.parse(values['impact'] as String),
                  values['response'] as String,
                  values['owner'] as String,
                  status: values['status'] as String,
                ),
              )) {
                return;
              }
              onChange();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add risk'),
          ),
        ),
        card(_riskMatrix(risks)),
        sectionTitle('Risk and issue register'),
        card(
          Column(
            children: [
              const Row(
                children: [
                  Expanded(flex: 2, child: Text('RISK / ISSUE · OWNER')),
                  SizedBox(
                    width: 90,
                    child: Text('L × I', textAlign: TextAlign.center),
                  ),
                  Expanded(flex: 3, child: Text('RESPONSE')),
                  SizedBox(width: 112, child: Text('STATUS')),
                  SizedBox(width: 88, child: Text('ACTIONS')),
                ],
              ),
              const Divider(),
              ...risks.map((r) => _riskLine(c, db, r, onChange)),
            ],
          ),
        ),
        sectionTitle('PDPC · release readiness response'),
        card(
          Column(
            children: risks.map((r) {
              final score = (r['likelihood'] as int) * (r['impact'] as int);
              final level = score >= 15
                  ? 'High · score $score'
                  : score >= 8
                  ? 'Moderate · score $score'
                  : 'Low · score $score';
              return _pdpc(
                r['title'] as String,
                '${r['status']} risk · $level · Owner: ${r['owner']}',
                r['response'] as String,
                score >= 15
                    ? red
                    : score >= 8
                    ? amber
                    : green,
              );
            }).toList(),
          ),
        ),
      ]);
    },
  );
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.db, required this.onChange});
  final ProjectDatabase db;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext c) => FutureBuilder(
    future: Future.wait([
      db.project(),
      db.rows('requirements'),
      db.rows('changes'),
      db.rows('activities'),
      db.rows('defects'),
      db.rows('risks'),
      db.rows('checklist'),
      db.rows('closure_records'),
    ]),
    builder: (c, s) {
      if (s.hasError) {
        return _loadFailure('reports', s.error!, onRetry: onChange);
      }
      if (!s.hasData) return _loadingState();
      final p = s.data![0] as Map<String, Object?>,
          req = s.data![1] as List<Map<String, Object?>>,
          chg = s.data![2] as List<Map<String, Object?>>,
          acts = s.data![3] as List<Map<String, Object?>>,
          bugs = s.data![4] as List<Map<String, Object?>>,
          risks = s.data![5] as List<Map<String, Object?>>,
          checks = s.data![6] as List<Map<String, Object?>>,
          closures = s.data![7] as List<Map<String, Object?>>;
      final metrics = EarnedValueMetrics.calculate(acts, asOf: demoAsOf);
      final pv = metrics.plannedValue,
          ev = metrics.earnedValue,
          ac = metrics.actualCost;
      final pending = chg.where((x) => x['status'] == 'Pending').length;
      final plannedBudget = acts.fold<double>(
        0,
        (sum, a) => sum + (a['cost'] as num).toDouble(),
      );
      final forecast = forecastActivities(acts, asOf: demoAsOf);
      final delayed = acts.where((a) {
        final start = DateTime.parse(a['start_date'] as String);
        final plannedFinish = start.add(Duration(days: a['duration'] as int));
        return forecast[a['code']]!.finish.isAfter(plannedFinish);
      }).length;
      final projectedFinish = forecast.values
          .map((f) => f.finish)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final critical = bugs
          .where(
            (b) => b['severity'] == 'Critical' && b['status'] != 'Resolved',
          )
          .length;
      final passedChecks = checks.where((x) => x['result'] == 'Pass').length;
      final statusColor = (p['status'] as String).contains('risk')
          ? red
          : p['status'] == 'Closed'
          ? green
          : teal;
      return content([
        heading(
          'Project report',
          'Live management summary generated from the project database.',
          action: button('Edit charter', () async {
            final values = await showHealthForm(
              c,
              title: 'Edit project charter',
              fields: [
                HealthFormField(
                  name: 'objective',
                  label: 'Project objective',
                  input: HealthFormInput.multiline,
                  initial: p['objective'],
                ),
                HealthFormField(
                  name: 'stakeholders',
                  label: 'Stakeholders',
                  input: HealthFormInput.multiline,
                  initial: p['stakeholders'],
                ),
                HealthFormField(
                  name: 'scope',
                  label: 'Scope boundary',
                  input: HealthFormInput.multiline,
                  initial: p['scope'],
                ),
                HealthFormField(
                  name: 'status',
                  label: 'Project status',
                  input: HealthFormInput.choice,
                  initial: (p['status'] as String).startsWith('Rebaselined')
                      ? 'At risk'
                      : p['status'],
                  choices: const ['Planning', 'On track', 'At risk'],
                  helper:
                      'Approved changes set the rebaselined status automatically.',
                ),
              ],
              saveLabel: 'Save charter',
            );
            if (values == null) return;
            if (!await _saveFormData(
              c,
              errorTitle: 'Could not update project charter',
              save: () => db.updateCharter(
                objective: values['objective'] as String,
                stakeholders: values['stakeholders'] as String,
                scope: values['scope'] as String,
                status: values['status'] as String,
              ),
            )) {
              return;
            }
            onChange();
          }, icon: Icons.edit_outlined),
        ),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SMART HEALTHCARE DELIVERY · STATUS REPORT',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: teal,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p['name'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reporting date: ${date(demoAsOf.toIso8601String())}  ·  Window: ${date(p['start_date'] as String?)} to ${date(p['deadline'] as String?)}',
                style: const TextStyle(color: Color(0xFF718187)),
              ),
              const Divider(height: 28),
              Text(
                'Overall status: ${p['status']}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Budget ${money(p['budget'] as num)}  ·  PV ${money(pv)}  ·  EV ${money(ev)}  ·  AC ${money(ac)}',
                style: const TextStyle(color: ink),
              ),
              const SizedBox(height: 7),
              Text(
                'CPI ${(ev / (ac == 0 ? 1 : ac)).toStringAsFixed(2)}  ·  SPI ${(ev / (pv == 0 ? 1 : pv)).toStringAsFixed(2)}',
                style: const TextStyle(color: ink),
              ),
            ],
          ),
        ),
        sectionTitle('Required management indicators'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              'Pending change requests',
              '$pending',
              Icons.change_circle_outlined,
              'Awaiting sponsor decision',
            ),
            _Metric(
              'Activities behind pace',
              '$delayed',
              Icons.timelapse,
              'Forecast beyond baseline',
            ),
            _Metric(
              'Critical defects open',
              '$critical',
              Icons.bug_report_outlined,
              'Release gate',
            ),
            _Metric(
              'Approved requirements',
              '${req.where((r) => r['status'] == 'Approved').length}/${req.length}',
              Icons.checklist,
              'Unapproved excluded from scope',
            ),
          ],
        ),
        sectionTitle('Integrated plan status'),
        card(
          Column(
            children: [
              _infoLine(
                'Dependency-based finish forecast',
                date(projectedFinish.toIso8601String()),
              ),
              _infoLine(
                'Schedule variance to deadline',
                '${projectedFinish.difference(DateTime.parse(p['deadline'] as String)).inDays} days',
              ),
              _infoLine(
                'Approved activity budget',
                '${money(plannedBudget)} of ${money(p['budget'] as num)}',
              ),
              _infoLine(
                'Deliverable checks passed',
                '$passedChecks of ${checks.length}',
              ),
            ],
          ),
        ),
        sectionTitle('Risk register snapshot'),
        card(
          Column(
            children: risks.map((r) => _riskLine(c, db, r, onChange)).toList(),
          ),
        ),
        sectionTitle('Project charter & constraints'),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLine('Objective', p['objective'] as String),
              _infoLine('Stakeholders', p['stakeholders'] as String),
              _infoLine('Scope boundary', p['scope'] as String),
              _infoLine('Original approved budget', 'PKR 5,000,000'),
              _infoLine('Current approved budget', money(p['budget'] as num)),
              _infoLine(
                'Original deadline',
                '23 Nov 2026 (16 weeks from 03 Aug 2026)',
              ),
              _infoLine(
                'Current approved deadline',
                date(p['deadline'] as String?),
              ),
              _infoLine(
                'Team',
                '1 project manager · 2 backend · 2 frontend · 1 database · 1 QA',
              ),
            ],
          ),
        ),
        sectionTitle(
          'Project closure records',
          action: closures.isEmpty && p['status'] != 'Closed'
              ? button('Record closure', () async {
                  final values = await showHealthForm(
                    c,
                    title: 'Record project closure',
                    fields: const [
                      HealthFormField(
                        name: 'summary',
                        label: 'Completion summary',
                        input: HealthFormInput.multiline,
                      ),
                      HealthFormField(
                        name: 'approver',
                        label: 'Sponsor or authorized approver',
                      ),
                    ],
                    saveLabel: 'Submit closeout',
                  );
                  if (values == null) return;
                  if (!await _saveFormData(
                    c,
                    errorTitle: 'Closeout validation failed',
                    save: () => db.recordClosure(
                      values['summary'] as String,
                      values['approver'] as String,
                    ),
                  )) {
                    return;
                  }
                  onChange();
                }, icon: Icons.task_alt)
              : null,
        ),
        card(
          Column(
            children: closures.isEmpty
                ? [
                    const Text(
                      'No closure record has been approved.',
                      style: TextStyle(color: Color(0xFF718187)),
                    ),
                  ]
                : closures
                      .map(
                        (x) => _infoLine(
                          '${x['recorded_at']} · ${x['approved_by']}',
                          x['summary'] as String,
                        ),
                      )
                      .toList(),
          ),
        ),
      ]);
    },
  );
}

class _DatabaseTableSnapshot {
  const _DatabaseTableSnapshot(this.columns, this.rows);

  final List<String> columns;
  final List<Map<String, Object?>> rows;
}

class DatabasePage extends StatefulWidget {
  const DatabasePage({super.key, required this.db});
  final ProjectDatabase db;

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  static const tables = [
    'project',
    'requirements',
    'changes',
    'activities',
    'defects',
    'risks',
    'checklist',
    'closure_records',
  ];

  String selectedTable = 'project';
  late Future<_DatabaseTableSnapshot> tableSnapshot;

  @override
  void initState() {
    super.initState();
    tableSnapshot = _loadTable(selectedTable);
  }

  Future<_DatabaseTableSnapshot> _loadTable(String table) async {
    final columns = await widget.db.tableColumns(table);
    final rows = await widget.db.rows(table);
    return _DatabaseTableSnapshot(columns, rows);
  }

  @override
  Widget build(BuildContext context) => content([
    heading(
      widget.db.isSupabase ? 'Live Supabase database' : 'Live SQLite database',
      widget.db.isSupabase
          ? 'Read-only rows from the hosted PostgreSQL database used by this app.'
          : 'Read-only table view from the local database used by this app.',
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final table in tables)
          ChoiceChip(
            label: Text(table),
            selected: selectedTable == table,
            onSelected: (selected) {
              if (!selected) return;
              setState(() {
                selectedTable = table;
                tableSnapshot = _loadTable(table);
              });
            },
          ),
      ],
    ),
    const SizedBox(height: 16),
    FutureBuilder<_DatabaseTableSnapshot>(
      future: tableSnapshot,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return card(Text('Could not read database table: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selectedTable.toUpperCase()}  ·  ${data.rows.length} record${data.rows.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (data.rows.isEmpty)
                const Text('This table currently has no records.')
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFE6F0F0),
                    ),
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 74,
                    columnSpacing: 12,
                    columns: [
                      for (final column in data.columns)
                        DataColumn(
                          label: Text(
                            column,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                    rows: [
                      for (final row in data.rows)
                        DataRow(
                          cells: [
                            for (final column in data.columns)
                              DataCell(
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    '${row[column] ?? 'NULL'}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  ]);
}

double _fraction(Map<String, Object?> a) {
  final n = (a['progress'] as num).toDouble();
  return n.clamp(0, 1);
}

Map<int, List<Map<String, Object?>>> _wbsGroups(
  List<Map<String, Object?>> activities,
) {
  final groups = <int, List<Map<String, Object?>>>{};
  for (final activity in activities) {
    final phase = int.tryParse((activity['code'] as String).split('.').first);
    if (phase != null) groups.putIfAbsent(phase, () => []).add(activity);
  }
  final keys = groups.keys.toList()..sort();
  return {for (final key in keys) key: groups[key]!};
}

String _phaseName(int phase) => switch (phase) {
  1 => 'Initiation & architecture',
  2 => 'Core healthcare modules',
  3 => 'Integration, testing & handover',
  4 => 'Approved change work',
  _ => 'Additional work packages',
};

class _GanttChart extends StatefulWidget {
  const _GanttChart({
    required this.activities,
    required this.forecasts,
    required this.projectStart,
    required this.deadline,
    required this.horizon,
    required this.onActivityTap,
  });

  final List<Map<String, Object?>> activities;
  final Map<String, ActivityForecast> forecasts;
  final DateTime projectStart;
  final DateTime deadline;
  final DateTime horizon;
  final ValueChanged<Map<String, Object?>> onActivityTap;

  @override
  State<_GanttChart> createState() => _GanttChartState();
}

class _GanttChartState extends State<_GanttChart> {
  final ScrollController _horizontalController = ScrollController();

  List<Map<String, Object?>> get activities => widget.activities;
  Map<String, ActivityForecast> get forecasts => widget.forecasts;
  DateTime get projectStart => widget.projectStart;
  DateTime get deadline => widget.deadline;
  DateTime get horizon => widget.horizon;
  ValueChanged<Map<String, Object?>> get onActivityTap => widget.onActivityTap;

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 900;
      final labelWidth = compact ? 190.0 : 300.0;
      final gap = compact ? 12.0 : 18.0;
      final minimumWidth = compact ? 900.0 : 1120.0;
      final contentWidth = constraints.maxWidth < minimumWidth
          ? minimumWidth
          : constraints.maxWidth;
      final chartWidth = contentWidth - labelWidth - gap;
      DateTime dateOnlyUtc(DateTime value) =>
          DateTime.utc(value.year, value.month, value.day);
      final chartActivities = [...activities]
        ..sort((a, b) {
          final aStart = DateTime.parse(a['start_date'] as String);
          final bStart = DateTime.parse(b['start_date'] as String);
          final byStart = aStart.compareTo(bStart);
          if (byStart != 0) return byStart;
          return (a['code'] as String).compareTo(b['code'] as String);
        });
      var axisStart = dateOnlyUtc(projectStart);
      final chartDeadline = dateOnlyUtc(deadline);
      var latestFinish = dateOnlyUtc(horizon).isAfter(chartDeadline)
          ? dateOnlyUtc(horizon)
          : chartDeadline;
      for (final activity in chartActivities) {
        final plannedStart = dateOnlyUtc(
          DateTime.parse(activity['start_date'] as String),
        );
        final plannedFinish = plannedStart.add(
          Duration(days: activity['duration'] as int),
        );
        if (plannedStart.isBefore(axisStart)) axisStart = plannedStart;
        if (plannedFinish.isAfter(latestFinish)) latestFinish = plannedFinish;
        final forecast = forecasts[activity['code']];
        if (forecast != null) {
          if (forecast.start.isBefore(axisStart)) axisStart = forecast.start;
          if (forecast.finish.isAfter(latestFinish)) {
            latestFinish = forecast.finish;
          }
        }
      }
      // Keep the final bar and its rounded border inside the chart, with a
      // visible right margin after the last forecast/deadline date.
      final paddedFinish = latestFinish.add(const Duration(days: 14));
      final end = DateTime(paddedFinish.year, paddedFinish.month + 1);
      final spanDays = end.difference(axisStart).inDays.clamp(1, 100000);
      double x(DateTime date) =>
          (date.difference(axisStart).inDays / spanDays * chartWidth)
              .clamp(0.0, chartWidth)
              .toDouble();

      final ticks = <DateTime>[axisStart];
      var month = DateTime.utc(axisStart.year, axisStart.month + 1);
      while (!month.isAfter(end)) {
        ticks.add(month);
        month = DateTime(month.year, month.month + 1);
      }
      final monthNames = const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: const Text(
                        'WORK PACKAGE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF718187),
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: chartWidth,
                      height: 30,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final tick in ticks)
                            Positioned(
                              left: (x(tick) - 12).clamp(0.0, chartWidth - 30),
                              top: 2,
                              child: Text(
                                '${monthNames[tick.month - 1]} ${tick.day == 1 ? '' : tick.day}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF718187),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 10),
                ...chartActivities.map((activity) {
                  final startDate = dateOnlyUtc(
                    DateTime.parse(activity['start_date'] as String),
                  );
                  final plannedFinish = startDate.add(
                    Duration(days: activity['duration'] as int),
                  );
                  final progress = _fraction(activity);
                  return Tooltip(
                    message:
                        'Open ${activity['code']} · ${activity['name']} schedule details',
                    child: InkWell(
                      onTap: () => onActivityTap(activity),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: labelWidth,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 52,
                                    child: Text(
                                      activity['code'] as String,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: teal,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      activity['name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: gap),
                            SizedBox(
                              width: chartWidth,
                              height: 26,
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  _ganttBar(
                                    left: x(startDate),
                                    right: x(plannedFinish),
                                    top: 8,
                                    height: 10,
                                    color: teal.withValues(alpha: .20),
                                  ),
                                  if (progress > 0)
                                    _ganttBar(
                                      left: x(startDate),
                                      right: x(
                                        startDate.add(
                                          Duration(
                                            days:
                                                ((activity['duration'] as int) *
                                                        progress)
                                                    .round(),
                                          ),
                                        ),
                                      ),
                                      top: 8,
                                      height: 10,
                                      color: teal,
                                    ),
                                  if (forecasts[activity['code']]
                                      case final forecast?)
                                    if (forecast.finish.isAfter(plannedFinish))
                                      _ganttBar(
                                        left: x(plannedFinish),
                                        right: x(forecast.finish),
                                        top: 8,
                                        height: 10,
                                        color: red.withValues(alpha: .38),
                                      ),
                                  if (activity['milestone'] == 1)
                                    Positioned(
                                      left: (x(plannedFinish) - 6).clamp(
                                        0.0,
                                        chartWidth - 12,
                                      ),
                                      top: 6,
                                      child: const Icon(
                                        Icons.diamond,
                                        size: 13,
                                        color: amber,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _ganttLegend('Planned', teal.withValues(alpha: .25)),
                    _ganttLegend('Completed progress', teal),
                    _ganttLegend('Forecast delay', red.withValues(alpha: .38)),
                    const Text(
                      '◆ milestone',
                      style: TextStyle(fontSize: 10, color: ink),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _ganttBar({
  required double left,
  required double right,
  required double top,
  required double height,
  required Color color,
}) {
  final safeLeft = left.toDouble();
  final safeWidth = right - safeLeft;
  if (safeWidth <= 0.75) return const SizedBox.shrink();
  return Positioned(
    left: safeLeft,
    top: top,
    width: safeWidth,
    height: height,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    ),
  );
}

Widget _ganttLegend(String label, Color color) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(
      width: 12,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 10, color: ink)),
  ],
);

Widget _riskMatrix(List<Map<String, Object?>> risks) {
  final counts = List.generate(5, (_) => List.filled(5, 0));
  for (final risk in risks) {
    final l = risk['likelihood'] as int;
    final i = risk['impact'] as int;
    counts[l - 1][i - 1]++;
  }
  Color cellColor(int likelihood, int impact) {
    final score = likelihood * impact;
    return score >= 15
        ? const Color(0xFFF3D7D6)
        : score >= 8
        ? const Color(0xFFFFE9C7)
        : const Color(0xFFDCEFE9);
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'LIKELIHOOD',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF718187),
        ),
      ),
      const SizedBox(height: 8),
      for (var likelihood = 5; likelihood >= 1; likelihood--)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  '$likelihood · ${['Rare', 'Unlikely', 'Possible', 'Likely', 'Almost certain'][likelihood - 1]}',
                  style: const TextStyle(fontSize: 9, color: ink),
                ),
              ),
              for (var impact = 1; impact <= 5; impact++)
                Expanded(
                  child: Container(
                    height: 29,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: cellColor(likelihood, impact),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      counts[likelihood - 1][impact - 1] == 0
                          ? '·'
                          : '${counts[likelihood - 1][impact - 1]}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      Row(
        children: [
          const SizedBox(width: 62),
          for (var impact = 1; impact <= 5; impact++)
            Expanded(
              child: Center(
                child: Text(
                  '$impact',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF718187)),
                ),
              ),
            ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(left: 62, top: 4),
        child: Text(
          'IMPACT  ·  1 Minor → 5 Severe',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF718187),
          ),
        ),
      ),
      const SizedBox(height: 9),
      Wrap(
        spacing: 12,
        children: [
          _ganttLegend('Low · 1–7', const Color(0xFFDCEFE9)),
          _ganttLegend('Moderate · 8–14', const Color(0xFFFFE9C7)),
          _ganttLegend('High · 15–25', const Color(0xFFF3D7D6)),
        ],
      ),
    ],
  );
}

Widget _activityLine(Map<String, Object?> a, {bool indent = false}) => Padding(
  padding: EdgeInsets.only(left: indent ? 18 : 0, top: 9, bottom: 9),
  child: Row(
    children: [
      SizedBox(
        width: 48,
        child: Text(
          a['code'] as String,
          style: const TextStyle(
            color: teal,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${a['name']}',
              style: const TextStyle(color: ink, fontWeight: FontWeight.w600),
            ),
            Text(
              '${a['owner']}  ·  ${a['duration']} days  ·  ${money(a['cost'] as num)}',
              style: const TextStyle(color: Color(0xFF718187), fontSize: 11),
            ),
          ],
        ),
      ),
      if ((a['milestone'] as int) == 1) badge('MILESTONE', color: amber),
      if (_fraction(a) >= 1)
        const Icon(Icons.check_circle, size: 17, color: green),
    ],
  ),
);
Widget _requirementLine(
  BuildContext c,
  ProjectDatabase db,
  Map<String, Object?> r,
  VoidCallback done, {
  bool canApprove = true,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 9),
  child: Row(
    children: [
      Icon(
        r['status'] == 'Approved'
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        size: 19,
        color: r['status'] == 'Approved' ? green : amber,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r['title'] as String,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            Text(
              '${r['description']} · ${r['source']}',
              style: const TextStyle(color: Color(0xFF718187), fontSize: 11),
            ),
          ],
        ),
      ),
      badge(r['priority'] as String, color: ink),
      IconButton(
        tooltip: 'Edit requirement',
        onPressed: () async {
          final values = await showHealthForm(
            c,
            title: 'Edit requirement',
            fields: [
              HealthFormField(
                name: 'title',
                label: 'Requirement name',
                initial: r['title'],
              ),
              HealthFormField(
                name: 'description',
                label: 'Description and acceptance details',
                input: HealthFormInput.multiline,
                initial: r['description'],
              ),
              HealthFormField(
                name: 'priority',
                label: 'Priority',
                input: HealthFormInput.choice,
                initial: r['priority'],
                choices: const ['Must have', 'Should have', 'Could have'],
              ),
            ],
          );
          if (values == null) return;
          if (!await _saveFormData(
            c,
            errorTitle: 'Could not update requirement',
            save: () => db.updateRequirement(
              r['id'] as int,
              values['title'] as String,
              values['description'] as String,
              values['priority'] as String,
            ),
          )) {
            return;
          }
          done();
        },
        icon: const Icon(Icons.edit_outlined, size: 17),
      ),
      if (r['status'] == 'Pending') ...[
        if (canApprove)
          TextButton(
            onPressed: () async {
              if (!await _saveFormData(
                c,
                errorTitle: 'Could not approve requirement',
                save: () => db.setRequirement(r['id'] as int, 'Approved'),
              )) {
                return;
              }
              done();
            },
            child: const Text('Approve'),
          )
        else
          badge('PENDING CHANGE', color: amber),
        PopupMenuButton<String>(
          tooltip: 'Reject requirement',
          onSelected: (status) async {
            if (!await _saveFormData(
              c,
              errorTitle: 'Could not reject requirement',
              save: () => db.setRequirement(r['id'] as int, status),
            )) {
              return;
            }
            done();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'Rejected', child: Text('Reject')),
          ],
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.more_vert, size: 19),
          ),
        ),
      ] else
        badge(
          r['status'] == 'Approved' ? 'IN SCOPE' : 'REJECTED',
          color: r['status'] == 'Approved' ? green : red,
        ),
    ],
  ),
);
Widget _changeCard(
  BuildContext c,
  ProjectDatabase db,
  Map<String, Object?> x,
  VoidCallback done,
) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: card(
    Row(
      children: [
        const Icon(Icons.change_circle_outlined, color: amber, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                x['title'] as String,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
              Text(
                '${x['justification']}\nImpact: +${money(x['cost_impact'] as num)} · +${x['days_impact']} days',
                style: const TextStyle(
                  color: Color(0xFF718187),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        badge(
          x['status'] as String,
          color: x['status'] == 'Pending'
              ? amber
              : x['status'] == 'Approved'
              ? green
              : red,
        ),
        if (x['status'] == 'Pending') ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Edit pending change',
            onPressed: () async {
              final values = await showHealthForm(
                c,
                title: 'Edit change request',
                fields: [
                  HealthFormField(
                    name: 'title',
                    label: 'Change title',
                    initial: (x['title'] as String).replaceFirst(
                      RegExp(r'^CR-\d+\s*[·:-]?\s*'),
                      '',
                    ),
                  ),
                  HealthFormField(
                    name: 'justification',
                    label: 'Business justification',
                    input: HealthFormInput.multiline,
                    initial: x['justification'],
                  ),
                  HealthFormField(
                    name: 'cost',
                    label: 'Additional cost (PKR)',
                    input: HealthFormInput.decimal,
                    initial: '${x['cost_impact']}',
                    minimum: 0,
                  ),
                  HealthFormField(
                    name: 'days',
                    label: 'Schedule impact (days)',
                    input: HealthFormInput.integer,
                    initial: '${x['days_impact']}',
                    minimum: 0,
                  ),
                ],
              );
              if (values == null) return;
              if (!await _saveFormData(
                c,
                errorTitle: 'Could not update change request',
                save: () => db.updateChange(
                  id: x['id'] as int,
                  title: values['title'] as String,
                  justification: values['justification'] as String,
                  costImpact: values['cost'] as double,
                  daysImpact: values['days'] as int,
                ),
              )) {
                return;
              }
              done();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Reject',
            onPressed: () async {
              if (!await _saveFormData(
                c,
                errorTitle: 'Could not reject change request',
                save: () => db.decideChange(x['id'] as int, false),
              )) {
                return;
              }
              done();
            },
            icon: const Icon(Icons.close, color: red),
          ),
          IconButton(
            tooltip: 'Approve and rebaseline',
            onPressed: () async {
              if (!await _saveFormData(
                c,
                errorTitle: 'Could not approve change request',
                save: () => db.decideChange(x['id'] as int, true),
              )) {
                return;
              }
              done();
            },
            icon: const Icon(Icons.check_circle_outline, color: green),
          ),
        ],
      ],
    ),
  ),
);
Widget _timeline(
  BuildContext c,
  ProjectDatabase db,
  Map<String, Object?> a,
  VoidCallback done,
  ActivityForecast? forecast,
) {
  final start = DateTime.parse(a['start_date'] as String),
      end = start.add(Duration(days: a['duration'] as int));
  final pct = _fraction(a);
  final startSlip = forecast?.start.difference(start).inDays ?? 0;
  final finishSlip = forecast?.finish.difference(end).inDays ?? 0;
  final late = finishSlip > 0 && pct < 1;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  a['code'] as String,
                  style: const TextStyle(
                    color: teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    Text(
                      '${a['owner']} · depends on ${a['dependency'].toString().isEmpty ? 'none' : a['dependency']}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF718187),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date(start.toIso8601String())} → ${date(end.toIso8601String())}',
                style: const TextStyle(fontSize: 11, color: ink),
              ),
              if (late || startSlip > 0)
                Text(
                  'FORECAST +${finishSlip}d${startSlip > 0 ? ' · START +${startSlip}d' : ''}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 100,
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: pct,
                  color: late ? red : teal,
                  backgroundColor: bg,
                  minHeight: 7,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${(pct * 100).round()}%',
                style: const TextStyle(fontSize: 10, color: ink),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _editActivityPlan(
  BuildContext context,
  ProjectDatabase db,
  Map<String, Object?> activity,
  VoidCallback onChange,
) async {
  final id = activity['id'] as int;
  final values = await showHealthForm(
    context,
    title: 'Edit work package ${activity['code']}',
    fields: [
      HealthFormField(
        name: 'name',
        label: 'Work package name',
        initial: activity['name'],
      ),
      HealthFormField(
        name: 'owner',
        label: 'Responsible team member or role',
        initial: activity['owner'],
      ),
      HealthFormField(
        name: 'startDate',
        label: 'Planned start date',
        input: HealthFormInput.date,
        initial: activity['start_date'],
      ),
      HealthFormField(
        name: 'duration',
        label: 'Duration (days)',
        input: HealthFormInput.integer,
        initial: '${activity['duration']}',
        minimum: 1,
      ),
      HealthFormField(
        name: 'cost',
        label: 'Planned cost (PKR)',
        input: HealthFormInput.decimal,
        initial: '${activity['cost']}',
        minimum: 0,
      ),
      HealthFormField(
        name: 'dependency',
        label: 'Predecessor WBS codes',
        input: HealthFormInput.multiline,
        initial: activity['dependency'],
        required: false,
        helper: 'Separate multiple codes with commas.',
      ),
      HealthFormField(
        name: 'milestone',
        label: 'Mark as a milestone',
        input: HealthFormInput.toggle,
        initial: activity['milestone'] == 1,
      ),
    ],
  );
  if (values == null) return;
  try {
    await db.updateActivityPlan(
      id: id,
      name: values['name'] as String,
      owner: values['owner'] as String,
      startDate: values['startDate'] as String,
      duration: values['duration'] as int,
      cost: values['cost'] as double,
      dependency: values['dependency'] as String,
      milestone: values['milestone'] as bool,
    );
    onChange();
  } catch (error) {
    await info(
      context,
      'Could not update activity',
      error.toString().replaceFirst('Invalid argument(s): ', ''),
    );
  }
}

Widget _costRow(
  BuildContext c,
  ProjectDatabase db,
  Map<String, Object?> a,
  VoidCallback done,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: Row(
    children: [
      Expanded(
        flex: 4,
        child: Text(
          '${a['code']}  ${a['name']}',
          style: const TextStyle(
            color: ink,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      Expanded(
        child: Text(
          money(a['cost'] as num),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      Expanded(
        child: Text(
          money(a['actual_cost'] as num),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      SizedBox(
        width: 130,
        child: TextButton.icon(
          onPressed: () async {
            final values = await showHealthForm(
              c,
              title: 'Update activity actuals',
              fields: [
                HealthFormField(
                  name: 'progress',
                  label: 'Progress (%)',
                  input: HealthFormInput.decimal,
                  initial: '${(_fraction(a) * 100).round()}',
                  minimum: 0,
                  maximum: 100,
                  helper: 'Enter completed work from 0 to 100 percent.',
                ),
                HealthFormField(
                  name: 'actualCost',
                  label: 'Actual cost to date (PKR)',
                  input: HealthFormInput.decimal,
                  initial: '${a['actual_cost']}',
                  minimum: 0,
                ),
              ],
              saveLabel: 'Save actuals',
            );
            if (values == null) return;
            if (!await _saveFormData(
              c,
              errorTitle: 'Could not update activity actuals',
              save: () => db.updateActivity(
                a['id'] as int,
                (values['progress'] as double) / 100,
                values['actualCost'] as double,
              ),
            )) {
              return;
            }
            done();
          },
          icon: const Icon(Icons.edit_outlined, size: 15),
          label: const Text('Update'),
        ),
      ),
    ],
  ),
);
Widget _defectLine(
  BuildContext c,
  ProjectDatabase db,
  Map<String, Object?> d,
  VoidCallback done,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      Icon(
        Icons.bug_report_outlined,
        color: d['severity'] == 'Critical' ? red : amber,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d['title'] as String,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w600),
            ),
            Text(
              '${d['severity']} · ${d['assignee']} · reported ${d['reported']}',
              style: const TextStyle(color: Color(0xFF718187), fontSize: 11),
            ),
          ],
        ),
      ),
      PopupMenuButton<String>(
        tooltip: 'Change defect status',
        initialValue: d['status'] as String,
        onSelected: (status) async {
          if (!await _saveFormData(
            c,
            errorTitle: 'Could not change defect status',
            save: () => db.updateDefect(d['id'] as int, status),
          )) {
            return;
          }
          done();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'Open', child: Text('Open')),
          PopupMenuItem(value: 'In progress', child: Text('In progress')),
          PopupMenuItem(value: 'Resolved', child: Text('Resolved')),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge(
              d['status'] as String,
              color: d['status'] == 'Resolved' ? green : amber,
            ),
            const Icon(Icons.arrow_drop_down, size: 19),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: () async {
          final values = await showHealthForm(
            c,
            title: 'Edit defect',
            fields: [
              HealthFormField(
                name: 'title',
                label: 'Defect description',
                input: HealthFormInput.multiline,
                initial: d['title'],
              ),
              HealthFormField(
                name: 'severity',
                label: 'Severity',
                input: HealthFormInput.choice,
                initial: d['severity'],
                choices: const ['Critical', 'High', 'Medium', 'Low'],
              ),
              HealthFormField(
                name: 'assignee',
                label: 'Assigned team member or role',
                initial: d['assignee'],
              ),
              HealthFormField(
                name: 'status',
                label: 'Status',
                input: HealthFormInput.choice,
                initial: d['status'],
                choices: const ['Open', 'In progress', 'Resolved'],
              ),
              HealthFormField(
                name: 'reported',
                label: 'Reported date',
                input: HealthFormInput.date,
                initial: d['reported'],
              ),
            ],
          );
          if (values == null) return;
          if (!await _saveFormData(
            c,
            errorTitle: 'Could not update defect',
            save: () => db.updateDefectDetails(
              id: d['id'] as int,
              title: values['title'] as String,
              severity: values['severity'] as String,
              assignee: values['assignee'] as String,
              status: values['status'] as String,
              reported: values['reported'] as String,
            ),
          )) {
            return;
          }
          done();
        },
        icon: const Icon(Icons.edit_outlined, size: 17),
        label: const Text('Manage'),
      ),
    ],
  ),
);
Widget _checkLine(
  BuildContext c,
  ProjectDatabase db,
  Map<String, Object?> x,
  VoidCallback done,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              x['item'] as String,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w600),
            ),
            Text(
              '${x['deliverable']} · ${x['inspector']}',
              style: const TextStyle(color: Color(0xFF718187), fontSize: 11),
            ),
          ],
        ),
      ),
      PopupMenuButton<String>(
        tooltip: 'Change inspection result',
        initialValue: x['result'] as String,
        onSelected: (result) async {
          if (!await _saveFormData(
            c,
            errorTitle: 'Could not change inspection result',
            save: () => db.updateChecklist(x['id'] as int, result),
          )) {
            return;
          }
          done();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'Not tested', child: Text('Not tested')),
          PopupMenuItem(value: 'In progress', child: Text('In progress')),
          PopupMenuItem(value: 'Pass', child: Text('Pass')),
          PopupMenuItem(value: 'Fail', child: Text('Fail')),
          PopupMenuItem(
            value: 'Fail · critical defect open',
            child: Text('Fail · critical defect open'),
          ),
          PopupMenuItem(value: 'Pending', child: Text('Pending')),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge(
              x['result'] as String,
              color: x['result'] == 'Pass' ? green : amber,
            ),
            const Icon(Icons.arrow_drop_down, size: 19),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: () async {
          final values = await showHealthForm(
            c,
            title: 'Edit checklist item',
            fields: [
              HealthFormField(
                name: 'item',
                label: 'Inspection item',
                initial: x['item'],
              ),
              HealthFormField(
                name: 'deliverable',
                label: 'Deliverable',
                initial: x['deliverable'],
              ),
              HealthFormField(
                name: 'result',
                label: 'Inspection result',
                input: HealthFormInput.choice,
                initial: x['result'],
                choices: const [
                  'Not tested',
                  'In progress',
                  'Pass',
                  'Fail',
                  'Fail · critical defect open',
                  'Pending',
                ],
              ),
              HealthFormField(
                name: 'inspector',
                label: 'Inspector',
                initial: x['inspector'],
              ),
            ],
          );
          if (values == null) return;
          if (!await _saveFormData(
            c,
            errorTitle: 'Could not update checklist item',
            save: () => db.updateChecklistDetails(
              id: x['id'] as int,
              item: values['item'] as String,
              deliverable: values['deliverable'] as String,
              result: values['result'] as String,
              inspector: values['inspector'] as String,
            ),
          )) {
            return;
          }
          done();
        },
        icon: const Icon(Icons.edit_outlined, size: 17),
        label: const Text('Manage'),
      ),
    ],
  ),
);
Widget _riskLine(
  BuildContext c,
  ProjectDatabase db,
  Map<String, Object?> r,
  VoidCallback done,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 9),
  child: Row(
    children: [
      Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r['title'] as String,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            Text(
              r['owner'] as String,
              style: const TextStyle(color: Color(0xFF718187), fontSize: 10),
            ),
          ],
        ),
      ),
      SizedBox(
        width: 85,
        child: Center(
          child: badge(
            '${r['likelihood']} × ${r['impact']}',
            color: (r['likelihood'] as int) * (r['impact'] as int) >= 15
                ? red
                : (r['likelihood'] as int) * (r['impact'] as int) >= 8
                ? amber
                : green,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          r['response'] as String,
          style: const TextStyle(
            color: Color(0xFF718187),
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ),
      PopupMenuButton<String>(
        tooltip: 'Change risk status',
        initialValue: r['status'] as String,
        onSelected: (status) async {
          if (!await _saveFormData(
            c,
            errorTitle: 'Could not change risk status',
            save: () => db.setRiskStatus(r['id'] as int, status),
          )) {
            return;
          }
          done();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'Open', child: Text('Open')),
          PopupMenuItem(value: 'Monitoring', child: Text('Monitoring')),
          PopupMenuItem(value: 'Closed', child: Text('Closed')),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge(
              r['status'] as String,
              color: r['status'] == 'Closed' ? green : amber,
            ),
            const Icon(Icons.arrow_drop_down, size: 19),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: () async {
          final values = await showHealthForm(
            c,
            title: 'Edit risk or issue',
            fields: [
              HealthFormField(
                name: 'title',
                label: 'Risk or issue description',
                input: HealthFormInput.multiline,
                initial: r['title'],
              ),
              HealthFormField(
                name: 'likelihood',
                label: 'Likelihood (1–5)',
                input: HealthFormInput.choice,
                initial: '${r['likelihood']}',
                choices: const ['1', '2', '3', '4', '5'],
              ),
              HealthFormField(
                name: 'impact',
                label: 'Impact (1–5)',
                input: HealthFormInput.choice,
                initial: '${r['impact']}',
                choices: const ['1', '2', '3', '4', '5'],
              ),
              HealthFormField(
                name: 'response',
                label: 'Preventive or corrective response',
                input: HealthFormInput.multiline,
                initial: r['response'],
              ),
              HealthFormField(
                name: 'owner',
                label: 'Risk owner',
                initial: r['owner'],
              ),
              HealthFormField(
                name: 'status',
                label: 'Status',
                input: HealthFormInput.choice,
                initial: r['status'],
                choices: const ['Open', 'Monitoring', 'Closed'],
              ),
            ],
          );
          if (values == null) return;
          if (!await _saveFormData(
            c,
            errorTitle: 'Could not update risk',
            save: () => db.updateRisk(
              id: r['id'] as int,
              title: values['title'] as String,
              likelihood: int.parse(values['likelihood'] as String),
              impact: int.parse(values['impact'] as String),
              response: values['response'] as String,
              owner: values['owner'] as String,
              status: values['status'] as String,
            ),
          )) {
            return;
          }
          done();
        },
        icon: const Icon(Icons.edit_outlined, size: 17),
        label: const Text('Manage'),
      ),
    ],
  ),
);
Widget _pdpc(String issue, String risk, String actions, Color color) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 9,
        height: 9,
        margin: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            Text(
              risk,
              style: const TextStyle(color: Color(0xFF718187), fontSize: 11),
            ),
          ],
        ),
      ),
      const Icon(Icons.arrow_forward, size: 17, color: Color(0xFF718187)),
      const SizedBox(width: 8),
      Expanded(
        flex: 3,
        child: Text(
          actions,
          style: const TextStyle(color: ink, fontSize: 11, height: 1.45),
        ),
      ),
    ],
  ),
);
Widget _infoLine(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 160,
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF718187), fontSize: 12),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            color: ink,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    ],
  ),
);
