import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectDatabase {
  ProjectDatabase._(this.db) : supabase = null;
  ProjectDatabase._remote(this.supabase);
  late final Database db;
  final SupabaseClient? supabase;
  bool get isSupabase => supabase != null;

  static void _requiredText(String value, String field) {
    if (value.trim().isEmpty) throw ArgumentError('$field is required.');
  }

  static void _validateDate(String value, String field) {
    final parsed = DateTime.tryParse(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != value) {
      throw ArgumentError('$field must be a valid YYYY-MM-DD date.');
    }
  }

  static Future<ProjectDatabase> open() async {
    late final String databasePath;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      databasePath = 'smart_healthcare_pm.sqlite';
    } else {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await getApplicationSupportDirectory();
      await Directory(dir.path).create(recursive: true);
      databasePath = p.join(dir.path, 'smart_healthcare_pm.db');
    }
    return _openPath(databasePath);
  }

  static Future<ProjectDatabase> openSupabase(SupabaseClient client) async =>
      ProjectDatabase._remote(client);

  @visibleForTesting
  static Future<ProjectDatabase> openInMemoryForTest() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    return _openPath(inMemoryDatabasePath);
  }

  static Future<ProjectDatabase> _openPath(String databasePath) async {
    final db = await openDatabase(
      databasePath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute(
          '''CREATE TABLE project(id INTEGER PRIMARY KEY, name TEXT NOT NULL, objective TEXT NOT NULL, start_date TEXT NOT NULL, deadline TEXT NOT NULL, budget REAL NOT NULL CHECK(budget >= 0), status TEXT NOT NULL CHECK(status IN ('Planning','On track','At risk','Rebaselined · change approved','Closed')), scope TEXT NOT NULL, stakeholders TEXT NOT NULL)''',
        );
        await db.execute(
          '''CREATE TABLE requirements(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, description TEXT NOT NULL, priority TEXT NOT NULL CHECK(priority IN ('Must have','Should have','Could have')), status TEXT NOT NULL CHECK(status IN ('Pending','Approved','Rejected')), source TEXT NOT NULL)''',
        );
        await db.execute(
          '''CREATE TABLE changes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, justification TEXT NOT NULL, cost_impact REAL NOT NULL CHECK(cost_impact >= 0), days_impact INTEGER NOT NULL CHECK(days_impact >= 0), status TEXT NOT NULL CHECK(status IN ('Pending','Approved','Rejected')))''',
        );
        await db.execute(
          '''CREATE TABLE activities(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL, name TEXT NOT NULL, owner TEXT NOT NULL, start_date TEXT NOT NULL, duration INTEGER NOT NULL CHECK(duration > 0), cost REAL NOT NULL CHECK(cost >= 0), actual_cost REAL NOT NULL CHECK(actual_cost >= 0), progress REAL NOT NULL CHECK(progress BETWEEN 0 AND 1), dependency TEXT NOT NULL, milestone INTEGER NOT NULL DEFAULT 0 CHECK(milestone IN (0,1)))''',
        );
        await db.execute(
          '''CREATE TABLE defects(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, severity TEXT NOT NULL CHECK(severity IN ('Critical','High','Medium','Low')), assignee TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('Open','In progress','Resolved')), reported TEXT NOT NULL)''',
        );
        await db.execute(
          '''CREATE TABLE risks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, likelihood INTEGER NOT NULL CHECK(likelihood BETWEEN 1 AND 5), impact INTEGER NOT NULL CHECK(impact BETWEEN 1 AND 5), response TEXT NOT NULL, owner TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('Open','Monitoring','Closed')))''',
        );
        await db.execute(
          '''CREATE TABLE checklist(id INTEGER PRIMARY KEY AUTOINCREMENT, item TEXT NOT NULL, deliverable TEXT NOT NULL, result TEXT NOT NULL CHECK(result IN ('Pass','Fail','Fail · critical defect open','In progress','Not tested','Pending')), inspector TEXT NOT NULL)''',
        );
        await db.execute(
          '''CREATE TABLE closure_records(id INTEGER PRIMARY KEY AUTOINCREMENT, recorded_at TEXT NOT NULL, summary TEXT NOT NULL, approved_by TEXT NOT NULL)''',
        );
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            '''CREATE TABLE closure_records(id INTEGER PRIMARY KEY AUTOINCREMENT, recorded_at TEXT NOT NULL, summary TEXT NOT NULL, approved_by TEXT NOT NULL)''',
          );
        }
        if (oldVersion < 3) {
          await db.update(
            'activities',
            {'duration': 21},
            where: "code='4.1' AND name='AI diagnosis + mobile delivery'",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "UPDATE activities SET duration=21 WHERE code='4.1' AND name='AI diagnosis + mobile delivery'",
          );
        }
        if (oldVersion < 5) {
          const ownerUpdates = {
            '2.1': ['Backend team', 'Backend developer 1'],
            '2.2': ['Backend team', 'Backend developer 2'],
            '2.3': ['Frontend team', 'Frontend developer 1'],
            '2.4': ['Backend + database', 'Frontend developer 2'],
            '3.1': ['QA engineer', 'Quality assurance engineer'],
          };
          for (final entry in ownerUpdates.entries) {
            await db.update(
              'activities',
              {'owner': entry.value[1]},
              where: 'code=? AND owner=?',
              whereArgs: [entry.key, entry.value[0]],
            );
          }
        }
      },
    );
    return ProjectDatabase._(db);
  }

  Future<void> close() => isSupabase ? Future.value() : db.close();

  static Future<void> _seed(DatabaseExecutor db) async {
    await db.insert('project', {
      'id': 1,
      'name': 'Smart Healthcare Project Management System',
      'objective':
          'Deliver a secure, integrated system for appointments, lab reports, doctor schedules, online consultations and billing across five hospitals.',
      'start_date': '2026-08-03',
      'deadline': '2026-11-23',
      'budget': 5000000,
      'status': 'At risk',
      'scope':
          'Five-hospital network; patient appointments, laboratory reports, doctor schedules, online consultations, billing.',
      'stakeholders':
          'Hospital management; patients; doctors; lab staff; finance teams; project team',
    });
    final requirements = [
      [
        'Patient appointment scheduling',
        'Book, reschedule and cancel appointments across five hospitals.',
        'Must have',
        'Approved',
        'Baseline',
      ],
      [
        'Patient record management',
        'Maintain authorized patient demographics and visit records.',
        'Must have',
        'Approved',
        'Baseline',
      ],
      [
        'Laboratory reports',
        'Publish and view verified lab results.',
        'Must have',
        'Approved',
        'Baseline',
      ],
      [
        'Doctor schedules',
        'Manage availability and prevent double booking.',
        'Must have',
        'Approved',
        'Baseline',
      ],
      [
        'Online consultations',
        'Support secure remote consultations.',
        'Should have',
        'Approved',
        'Baseline',
      ],
      [
        'Hospital billing',
        'Track charges, invoices and payment status.',
        'Must have',
        'Approved',
        'Baseline',
      ],
      [
        'AI preliminary diagnosis',
        'Provide clinician-reviewed preliminary decision support; never replace medical judgement.',
        'Could have',
        'Pending',
        'Change request CR-001',
      ],
      [
        'Mobile application',
        'Provide patient and clinician workflows on mobile devices.',
        'Should have',
        'Pending',
        'Change request CR-001',
      ],
    ];
    for (final r in requirements) {
      await db.insert('requirements', {
        'title': r[0],
        'description': r[1],
        'priority': r[2],
        'status': r[3],
        'source': r[4],
      });
    }
    await db.insert('changes', {
      'title': 'CR-001 · AI diagnosis + mobile app',
      'justification':
          'Hospital management requested AI preliminary diagnosis and native mobile access after baseline approval.',
      'cost_impact': 800000,
      'days_impact': 21,
      'status': 'Pending',
    });
    final acts = [
      [
        '1.1',
        'Requirements & charter',
        'Project manager',
        '2026-08-03',
        10,
        450000,
        420000,
        1.0,
        '',
        1,
      ],
      [
        '1.2',
        'Architecture & database design',
        'Database developer',
        '2026-08-13',
        12,
        520000,
        540000,
        1.0,
        '1.1',
        0,
      ],
      [
        '2.1',
        'Appointment scheduling module',
        'Backend developer 1',
        '2026-08-25',
        24,
        850000,
        920000,
        0.78,
        '1.2',
        0,
      ],
      [
        '2.2',
        'Patient records & laboratory reports',
        'Backend developer 2',
        '2026-09-18',
        25,
        950000,
        890000,
        0.68,
        '1.2',
        0,
      ],
      [
        '2.3',
        'Doctor schedules & consultations',
        'Frontend developer 1',
        '2026-09-18',
        24,
        740000,
        570000,
        0.7,
        '1.2',
        0,
      ],
      [
        '2.4',
        'Billing & finance module',
        'Frontend developer 2',
        '2026-10-12',
        18,
        600000,
        260000,
        0.34,
        '2.2',
        0,
      ],
      [
        '3.1',
        'Integration & system testing',
        'Quality assurance engineer',
        '2026-10-20',
        19,
        520000,
        0,
        0.12,
        '2.1,2.2,2.3,2.4',
        0,
      ],
      [
        '3.2',
        'Hospital pilot & handover',
        'Project manager',
        '2026-11-08',
        15,
        370000,
        0,
        0,
        '3.1',
        1,
      ],
    ];
    for (final a in acts) {
      await db.insert('activities', {
        'code': a[0],
        'name': a[1],
        'owner': a[2],
        'start_date': a[3],
        'duration': a[4],
        'cost': a[5],
        'actual_cost': a[6],
        'progress': a[7],
        'dependency': a[8],
        'milestone': a[9],
      });
    }
    for (final d in [
      [
        'Appointment double-booking under concurrent requests',
        'Critical',
        'Backend developer 1',
        'Open',
        '2026-10-18',
      ],
      [
        'Patient record mismatch after update',
        'Critical',
        'Database developer',
        'In progress',
        '2026-10-19',
      ],
      [
        'Lab report export formatting',
        'Medium',
        'Frontend developer 2',
        'Open',
        '2026-10-21',
      ],
    ]) {
      await db.insert('defects', {
        'title': d[0],
        'severity': d[1],
        'assignee': d[2],
        'status': d[3],
        'reported': d[4],
      });
    }
    for (final r in [
      [
        'Critical defects delay system test',
        '4',
        '5',
        'Daily triage; block release until both critical defects pass regression.',
        'QA engineer',
        'Open',
      ],
      [
        'Late change request exceeds baseline',
        '4',
        '4',
        'Submit CR for impact review; use contingency only after sponsor approval.',
        'Project manager',
        'Open',
      ],
      [
        'Patient data exposure',
        '2',
        '5',
        'Least privilege, encryption, audit trail and security review before pilot.',
        'Database developer',
        'Open',
      ],
    ]) {
      await db.insert('risks', {
        'title': r[0],
        'likelihood': int.parse(r[1]),
        'impact': int.parse(r[2]),
        'response': r[3],
        'owner': r[4],
        'status': r[5],
      });
    }
    for (final c in [
      [
        'Role-based access and audit logs',
        'Security design',
        'Pass',
        'QA engineer',
      ],
      [
        'Appointment conflict and concurrency tests',
        'Scheduling module',
        'Fail · critical defect open',
        'QA engineer',
      ],
      [
        'Patient record integrity and recovery',
        'Patient records',
        'In progress',
        'Database developer',
      ],
      [
        'Five-hospital billing reconciliation',
        'Billing module',
        'Not tested',
        'QA engineer',
      ],
      [
        'Pilot sign-off from hospital stakeholders',
        'Release readiness',
        'Pending',
        'Project manager',
      ],
    ]) {
      await db.insert('checklist', {
        'item': c[0],
        'deliverable': c[1],
        'result': c[2],
        'inspector': c[3],
      });
    }
  }

  Future<Map<String, Object?>> project() async {
    if (isSupabase) {
      return await supabase!.from('project').select().eq('id', 1).single();
    }
    return (await db.query('project', limit: 1)).first;
  }

  Future<List<String>> tableColumns(String table) async {
    if (!_tables.contains(table)) throw ArgumentError('Unknown table.');
    if (!isSupabase) {
      final info = await db.rawQuery('PRAGMA table_info("$table")');
      return info.map((column) => column['name'] as String).toList();
    }
    return _remoteColumns[table]!;
  }

  static const _tables = {
    'project',
    'requirements',
    'changes',
    'activities',
    'defects',
    'risks',
    'checklist',
    'closure_records',
  };
  static const _remoteColumns = <String, List<String>>{
    'project': [
      'id',
      'name',
      'objective',
      'start_date',
      'deadline',
      'budget',
      'status',
      'scope',
      'stakeholders',
    ],
    'requirements': [
      'id',
      'title',
      'description',
      'priority',
      'status',
      'source',
    ],
    'changes': [
      'id',
      'title',
      'justification',
      'cost_impact',
      'days_impact',
      'status',
    ],
    'activities': [
      'id',
      'code',
      'name',
      'owner',
      'start_date',
      'duration',
      'cost',
      'actual_cost',
      'progress',
      'dependency',
      'milestone',
    ],
    'defects': ['id', 'title', 'severity', 'assignee', 'status', 'reported'],
    'risks': [
      'id',
      'title',
      'likelihood',
      'impact',
      'response',
      'owner',
      'status',
    ],
    'checklist': ['id', 'item', 'deliverable', 'result', 'inspector'],
    'closure_records': ['id', 'recorded_at', 'summary', 'approved_by'],
  };
  Future<void> updateCharter({
    required String objective,
    required String stakeholders,
    required String scope,
    required String status,
  }) async {
    _requiredText(objective, 'Objective');
    _requiredText(stakeholders, 'Stakeholders');
    _requiredText(scope, 'Scope boundary');
    if (!['Planning', 'On track', 'At risk'].contains(status)) {
      throw ArgumentError('Choose Planning, On track, or At risk.');
    }
    final current = await project();
    if (current['status'] == 'Closed') {
      throw StateError('A closed project cannot be reopened from the charter.');
    }
    if (isSupabase) {
      await supabase!
          .from('project')
          .update({
            'objective': objective,
            'stakeholders': stakeholders,
            'scope': scope,
            'status': status,
          })
          .eq('id', 1);
      return;
    }
    await db.update('project', {
      'objective': objective,
      'stakeholders': stakeholders,
      'scope': scope,
      'status': status,
    }, where: 'id=1');
  }

  Future<void> recordClosure(String summary, String approvedBy) async {
    _requiredText(summary, 'Closeout summary');
    _requiredText(approvedBy, 'Closure approver');
    if (isSupabase) {
      await supabase!.rpc(
        'healthpm_record_closure',
        params: {
          'p_summary': summary.trim(),
          'p_approved_by': approvedBy.trim(),
        },
      );
      return;
    }
    await db.transaction((txn) async {
      final critical =
          (await txn.rawQuery(
                "SELECT COUNT(*) AS n FROM defects WHERE severity='Critical' AND status!='Resolved'",
              )).first['n']
              as int;
      final pending =
          (await txn.rawQuery(
                "SELECT COUNT(*) AS n FROM changes WHERE status='Pending'",
              )).first['n']
              as int;
      if (critical > 0 || pending > 0) {
        throw StateError(
          'Closeout is blocked while there are $critical unresolved critical defects and $pending pending change requests.',
        );
      }
      await txn.insert('closure_records', {
        'recorded_at': DateTime.now().toIso8601String().substring(0, 10),
        'summary': summary,
        'approved_by': approvedBy,
      });
      await txn.update('project', {'status': 'Closed'}, where: 'id=1');
    });
  }

  Future<List<Map<String, Object?>>> rows(
    String table, {
    String orderBy = 'id',
  }) async {
    if (!_tables.contains(table)) throw ArgumentError('Unknown table.');
    if (isSupabase) {
      final result = await supabase!.from(table).select().order(orderBy);
      return result.map((row) => Map<String, Object?>.from(row)).toList();
    }
    return db.query(table, orderBy: orderBy);
  }

  Future<void> addRequirement(
    String title,
    String description,
    String priority,
  ) async {
    _requiredText(title, 'Requirement name');
    _requiredText(description, 'Requirement description');
    if (!['Must have', 'Should have', 'Could have'].contains(priority)) {
      throw ArgumentError('Choose a valid requirement priority.');
    }
    if (isSupabase) {
      await supabase!.from('requirements').insert({
        'title': title.trim(),
        'description': description.trim(),
        'priority': priority,
        'status': 'Pending',
        'source': 'New requirement',
      });
      return;
    }
    await db.insert('requirements', {
      'title': title.trim(),
      'description': description.trim(),
      'priority': priority,
      'status': 'Pending',
      'source': 'New requirement',
    });
  }

  Future<void> updateRequirement(
    int id,
    String title,
    String description,
    String priority,
  ) async {
    _requiredText(title, 'Requirement name');
    _requiredText(description, 'Requirement description');
    if (!['Must have', 'Should have', 'Could have'].contains(priority)) {
      throw ArgumentError('Choose a valid requirement priority.');
    }
    if (isSupabase) {
      await supabase!
          .from('requirements')
          .update({
            'title': title.trim(),
            'description': description.trim(),
            'priority': priority,
          })
          .eq('id', id);
      return;
    }
    await db.update(
      'requirements',
      {
        'title': title.trim(),
        'description': description.trim(),
        'priority': priority,
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> setRequirement(int id, String status) async {
    if (!['Pending', 'Approved', 'Rejected'].contains(status)) {
      throw ArgumentError('Choose Pending, Approved, or Rejected.');
    }
    if (isSupabase) {
      await supabase!.rpc(
        'healthpm_set_requirement_status',
        params: {'p_id': id, 'p_status': status},
      );
      return;
    }
    await db.transaction((txn) async {
      final requirement = (await txn.query(
        'requirements',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      )).first;
      if (status == 'Approved') {
        final linkedRequest = RegExp(
          r'^Change request (CR-\d+)',
        ).firstMatch(requirement['source'] as String);
        if (linkedRequest != null) {
          final requests = await txn.query(
            'changes',
            where: 'title LIKE ?',
            whereArgs: ['${linkedRequest.group(1)} ·%'],
            limit: 1,
          );
          if (requests.isEmpty || requests.first['status'] != 'Approved') {
            throw StateError(
              'Approve the linked change request before adding this requirement to scope.',
            );
          }
        }
      }
      await txn.update(
        'requirements',
        {'status': status},
        where: 'id=?',
        whereArgs: [id],
      );
    });
  }

  Future<void> addChange(
    String title,
    String why,
    double cost,
    int days,
  ) async {
    _requiredText(title, 'Change title');
    _requiredText(why, 'Change justification');
    if (!cost.isFinite || cost < 0 || days < 0) {
      throw ArgumentError('Change cost and days must be non-negative values.');
    }
    if (isSupabase) {
      await supabase!.rpc(
        'healthpm_add_change',
        params: {
          'p_title': title.trim(),
          'p_justification': why.trim(),
          'p_cost': cost,
          'p_days': days,
        },
      );
      return;
    }
    final count =
        (await db.rawQuery('SELECT COUNT(*) AS n FROM changes')).first['n']
            as int;
    final code = 'CR-${(count + 1).toString().padLeft(3, '0')}';
    final cleanTitle = title.trim().replaceFirst(
      RegExp(r'^CR-\d+\s*[·:-]?\s*'),
      '',
    );
    await db.insert('changes', {
      'title': '$code · $cleanTitle',
      'justification': why.trim(),
      'cost_impact': cost,
      'days_impact': days,
      'status': 'Pending',
    });
  }

  Future<void> updateChange({
    required int id,
    required String title,
    required String justification,
    required double costImpact,
    required int daysImpact,
  }) async {
    _requiredText(title, 'Change title');
    _requiredText(justification, 'Change justification');
    if (!costImpact.isFinite || costImpact < 0 || daysImpact < 0) {
      throw ArgumentError('Change cost and days must be non-negative values.');
    }
    final existing = isSupabase
        ? (await supabase!.from('changes').select().eq('id', id).single())
        : (await db.query('changes', where: 'id=?', whereArgs: [id])).first;
    if (existing['status'] != 'Pending') {
      throw StateError('Only pending change requests can be edited.');
    }
    final currentTitle = existing['title'] as String;
    final prefix = RegExp(r'^(CR-\d+)\s*[·:-]?\s*').firstMatch(currentTitle);
    final cleanTitle = title.trim().replaceFirst(
      RegExp(r'^CR-\d+\s*[·:-]?\s*'),
      '',
    );
    final values = {
      'title': prefix == null ? cleanTitle : '${prefix.group(1)} · $cleanTitle',
      'justification': justification.trim(),
      'cost_impact': costImpact,
      'days_impact': daysImpact,
    };
    if (isSupabase) {
      await supabase!.from('changes').update(values).eq('id', id);
    } else {
      await db.update('changes', values, where: 'id=?', whereArgs: [id]);
    }
  }

  Future<void> decideChange(int id, bool approve) async {
    if (isSupabase) {
      await supabase!.rpc(
        'healthpm_decide_change',
        params: {'p_id': id, 'p_approve': approve},
      );
      return;
    }
    await db.transaction((txn) async {
      final change = (await txn.query(
        'changes',
        where: 'id=?',
        whereArgs: [id],
      )).first;
      if (change['status'] != 'Pending') return;
      await txn.update(
        'changes',
        {'status': approve ? 'Approved' : 'Rejected'},
        where: 'id=?',
        whereArgs: [id],
      );
      if (!approve) return;
      final p = (await txn.query('project', limit: 1)).first;
      final next = DateTime.parse(
        p['deadline'] as String,
      ).add(Duration(days: change['days_impact'] as int));
      await txn.update('project', {
        'budget':
            (p['budget'] as num).toDouble() +
            (change['cost_impact'] as num).toDouble(),
        'deadline': next.toIso8601String().substring(0, 10),
        'status': 'Rebaselined · change approved',
      }, where: 'id=1');
      final changeTitle = change['title'] as String;
      final isCaseStudyChange = changeTitle.startsWith('CR-001');
      if (isCaseStudyChange) {
        await txn.update(
          'requirements',
          {'status': 'Approved'},
          where: "source='Change request CR-001' AND status='Pending'",
        );
      }
      final costImpact = (change['cost_impact'] as num).toDouble();
      final daysImpact = change['days_impact'] as int;
      if (costImpact > 0 || daysImpact > 0) {
        final workPackages = await txn.query(
          'activities',
          where: "code LIKE '4.%'",
        );
        final code = '4.${workPackages.length + 1}';
        final start = DateTime(2026, 10, 25);
        await txn.insert('activities', {
          'code': code,
          'name': isCaseStudyChange
              ? 'AI diagnosis + mobile delivery'
              : changeTitle.replaceFirst(RegExp(r'^CR-\d+\s*[·:-]?\s*'), ''),
          'owner': isCaseStudyChange
              ? 'Backend developer 1 + Frontend developer 2'
              : 'Project manager',
          'start_date': start.toIso8601String().substring(0, 10),
          'duration': daysImpact > 0 ? daysImpact : 1,
          'cost': costImpact,
          'actual_cost': 0,
          'progress': 0,
          'dependency': '3.1',
          'milestone': 0,
        });
      }
    });
  }

  Future<void> updateActivity(int id, double progress, double actual) async {
    if (!progress.isFinite ||
        !actual.isFinite ||
        progress < 0 ||
        progress > 1 ||
        actual < 0) {
      throw ArgumentError(
        'Progress must be 0–100% and cost cannot be negative.',
      );
    }
    if (isSupabase) {
      await supabase!
          .from('activities')
          .update({'progress': progress, 'actual_cost': actual})
          .eq('id', id);
      return;
    }
    await db.update(
      'activities',
      {'progress': progress, 'actual_cost': actual},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> updateActivityPlan({
    required int id,
    required String name,
    required String owner,
    required String startDate,
    required int duration,
    required double cost,
    required String dependency,
    required bool milestone,
  }) async {
    if (name.trim().isEmpty || owner.trim().isEmpty) {
      throw ArgumentError('Activity name and owner are required.');
    }
    if (duration < 1 || !cost.isFinite || cost < 0) {
      throw ArgumentError(
        'Duration must be positive and cost cannot be negative.',
      );
    }
    final parsedStart = DateTime.tryParse(startDate);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(startDate) ||
        parsedStart == null ||
        parsedStart.toIso8601String().substring(0, 10) != startDate) {
      throw ArgumentError('Start date must use YYYY-MM-DD format.');
    }

    final activities = await rows('activities');
    final byCode = {
      for (final activity in activities) activity['code'] as String: activity,
    };
    Map<String, Object?>? current;
    for (final activity in activities) {
      if (activity['id'] == id) {
        current = activity;
        break;
      }
    }
    if (current == null) throw ArgumentError('Activity no longer exists.');
    final code = current['code'] as String;
    final predecessorCodes = dependency
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final unknown = predecessorCodes.where(
      (value) => !byCode.containsKey(value),
    );
    if (unknown.isNotEmpty) {
      throw ArgumentError('Unknown predecessor code: ${unknown.join(', ')}.');
    }
    if (predecessorCodes.contains(code)) {
      throw ArgumentError('An activity cannot depend on itself.');
    }
    bool reachesCurrent(String candidate, Set<String> visited) {
      if (candidate == code) return true;
      if (!visited.add(candidate)) return false;
      final parents = (byCode[candidate]?['dependency'] as String? ?? '')
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty);
      return parents.any((parent) => reachesCurrent(parent, visited));
    }

    if (predecessorCodes.any((value) => reachesCurrent(value, <String>{}))) {
      throw ArgumentError('This dependency would create a schedule cycle.');
    }
    final values = {
      'name': name.trim(),
      'owner': owner.trim(),
      'start_date': startDate,
      'duration': duration,
      'cost': cost,
      'dependency': predecessorCodes.join(', '),
      'milestone': milestone ? 1 : 0,
    };
    if (isSupabase) {
      await supabase!.from('activities').update(values).eq('id', id);
    } else {
      await db.update('activities', values, where: 'id=?', whereArgs: [id]);
    }
  }

  Future<void> addActivity({
    String? code,
    required String name,
    required String owner,
    required String startDate,
    required int duration,
    required double cost,
    String dependency = '',
    bool milestone = false,
  }) async {
    if (name.trim().isEmpty ||
        owner.trim().isEmpty ||
        duration <= 0 ||
        !cost.isFinite ||
        cost < 0) {
      throw ArgumentError(
        'Enter an activity, owner, positive duration and non-negative cost.',
      );
    }
    final parsedStart = DateTime.tryParse(startDate);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(startDate) ||
        parsedStart == null ||
        parsedStart.toIso8601String().substring(0, 10) != startDate) {
      throw ArgumentError('Start date must use YYYY-MM-DD format.');
    }
    final predecessorCodes = dependency
        .split(',')
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toSet();
    final activities = await rows('activities');
    final knownCodes = activities.map((a) => a['code'] as String).toSet();
    var nextWbsNumber = 1;
    for (final existingCode in knownCodes) {
      final match = RegExp(r'^4\.(\d+)$').firstMatch(existingCode);
      final number = int.tryParse(match?.group(1) ?? '');
      if (number != null && number >= nextWbsNumber) {
        nextWbsNumber = number + 1;
      }
    }
    final activityCode = code?.trim().isNotEmpty == true
        ? code!.trim()
        : '4.$nextWbsNumber';
    if (!RegExp(r'^\d+(\.\d+)+$').hasMatch(activityCode)) {
      throw ArgumentError(
        'WBS code must use a hierarchical format such as 2.1.',
      );
    }
    if (knownCodes.contains(activityCode)) {
      throw ArgumentError('WBS code $activityCode is already in use.');
    }
    final unknownCodes = predecessorCodes.difference(knownCodes);
    if (unknownCodes.isNotEmpty) {
      throw ArgumentError(
        'Unknown predecessor code${unknownCodes.length == 1 ? '' : 's'}: ${unknownCodes.join(', ')}.',
      );
    }
    final values = {
      'code': activityCode,
      'name': name.trim(),
      'owner': owner.trim(),
      'start_date': startDate,
      'duration': duration,
      'cost': cost,
      'actual_cost': 0,
      'progress': 0,
      'dependency': dependency.trim(),
      'milestone': milestone ? 1 : 0,
    };
    if (isSupabase) {
      await supabase!.from('activities').insert(values);
    } else {
      await db.insert('activities', values);
    }
  }

  Future<void> addDefect(
    String title,
    String severity,
    String owner, {
    String status = 'Open',
    String? reported,
  }) async {
    _requiredText(title, 'Defect description');
    _requiredText(owner, 'Defect owner');
    if (!['Critical', 'High', 'Medium', 'Low'].contains(severity)) {
      throw ArgumentError('Choose a valid defect severity.');
    }
    if (!['Open', 'In progress', 'Resolved'].contains(status)) {
      throw ArgumentError('Choose a valid defect status.');
    }
    final reportedDate =
        reported ?? DateTime.now().toIso8601String().substring(0, 10);
    _validateDate(reportedDate, 'Reported date');
    if (isSupabase) {
      await supabase!.from('defects').insert({
        'title': title.trim(),
        'severity': severity,
        'assignee': owner.trim(),
        'status': status,
        'reported': reportedDate,
      });
      return;
    }
    await db.insert('defects', {
      'title': title.trim(),
      'severity': severity,
      'assignee': owner.trim(),
      'status': status,
      'reported': reportedDate,
    });
  }

  Future<void> updateDefectDetails({
    required int id,
    required String title,
    required String severity,
    required String assignee,
    required String status,
    required String reported,
  }) async {
    _requiredText(title, 'Defect description');
    _requiredText(assignee, 'Defect owner');
    if (!['Critical', 'High', 'Medium', 'Low'].contains(severity)) {
      throw ArgumentError('Choose a valid defect severity.');
    }
    if (!['Open', 'In progress', 'Resolved'].contains(status)) {
      throw ArgumentError('Choose a valid defect status.');
    }
    _validateDate(reported, 'Reported date');
    final values = {
      'title': title.trim(),
      'severity': severity,
      'assignee': assignee.trim(),
      'status': status,
      'reported': reported,
    };
    if (isSupabase) {
      await supabase!.from('defects').update(values).eq('id', id);
    } else {
      await db.update('defects', values, where: 'id=?', whereArgs: [id]);
    }
  }

  Future<void> updateDefect(int id, String status) {
    if (!['Open', 'In progress', 'Resolved'].contains(status)) {
      throw ArgumentError('Choose Open, In progress, or Resolved.');
    }
    if (isSupabase) {
      return supabase!.from('defects').update({'status': status}).eq('id', id);
    }
    return db
        .update('defects', {'status': status}, where: 'id=?', whereArgs: [id])
        .then((_) {});
  }

  Future<void> addRisk(
    String title,
    int likelihood,
    int impact,
    String response,
    String owner, {
    String status = 'Open',
  }) async {
    _requiredText(title, 'Risk title');
    _requiredText(response, 'Risk response');
    _requiredText(owner, 'Risk owner');
    if (likelihood < 1 || likelihood > 5 || impact < 1 || impact > 5) {
      throw ArgumentError('Likelihood and impact must each be from 1 to 5.');
    }
    if (!['Open', 'Monitoring', 'Closed'].contains(status)) {
      throw ArgumentError('Choose a valid risk status.');
    }
    if (isSupabase) {
      await supabase!.from('risks').insert({
        'title': title.trim(),
        'likelihood': likelihood,
        'impact': impact,
        'response': response.trim(),
        'owner': owner.trim(),
        'status': status,
      });
      return;
    }
    await db.insert('risks', {
      'title': title.trim(),
      'likelihood': likelihood,
      'impact': impact,
      'response': response.trim(),
      'owner': owner.trim(),
      'status': status,
    });
  }

  Future<void> updateRisk({
    required int id,
    required String title,
    required int likelihood,
    required int impact,
    required String response,
    required String owner,
    required String status,
  }) async {
    _requiredText(title, 'Risk title');
    _requiredText(response, 'Risk response');
    _requiredText(owner, 'Risk owner');
    if (likelihood < 1 || likelihood > 5 || impact < 1 || impact > 5) {
      throw ArgumentError('Likelihood and impact must each be from 1 to 5.');
    }
    if (!['Open', 'Monitoring', 'Closed'].contains(status)) {
      throw ArgumentError('Choose a valid risk status.');
    }
    final values = {
      'title': title.trim(),
      'likelihood': likelihood,
      'impact': impact,
      'response': response.trim(),
      'owner': owner.trim(),
      'status': status,
    };
    if (isSupabase) {
      await supabase!.from('risks').update(values).eq('id', id);
    } else {
      await db.update('risks', values, where: 'id=?', whereArgs: [id]);
    }
  }

  Future<void> setRiskStatus(int id, String status) async {
    if (!['Open', 'Monitoring', 'Closed'].contains(status)) {
      throw ArgumentError('Choose Open, Monitoring, or Closed.');
    }
    if (isSupabase) {
      await supabase!.from('risks').update({'status': status}).eq('id', id);
    } else {
      await db.update(
        'risks',
        {'status': status},
        where: 'id=?',
        whereArgs: [id],
      );
    }
  }

  static const _checklistResults = [
    'Pass',
    'Fail',
    'Fail · critical defect open',
    'In progress',
    'Not tested',
    'Pending',
  ];

  Future<void> addChecklist({
    required String item,
    required String deliverable,
    required String result,
    required String inspector,
  }) async {
    _requiredText(item, 'Checklist item');
    _requiredText(deliverable, 'Deliverable');
    _requiredText(inspector, 'Inspector');
    if (!_checklistResults.contains(result)) {
      throw ArgumentError('Choose a valid inspection result.');
    }
    final values = {
      'item': item.trim(),
      'deliverable': deliverable.trim(),
      'result': result,
      'inspector': inspector.trim(),
    };
    if (isSupabase) {
      await supabase!.from('checklist').insert(values);
      return;
    }
    await db.insert('checklist', values);
  }

  Future<void> updateChecklistDetails({
    required int id,
    required String item,
    required String deliverable,
    required String result,
    required String inspector,
  }) async {
    _requiredText(item, 'Checklist item');
    _requiredText(deliverable, 'Deliverable');
    _requiredText(inspector, 'Inspector');
    if (!_checklistResults.contains(result)) {
      throw ArgumentError('Choose a valid inspection result.');
    }
    final values = {
      'item': item.trim(),
      'deliverable': deliverable.trim(),
      'result': result,
      'inspector': inspector.trim(),
    };
    if (isSupabase) {
      await supabase!.from('checklist').update(values).eq('id', id);
    } else {
      await db.update('checklist', values, where: 'id=?', whereArgs: [id]);
    }
  }

  Future<void> updateChecklist(int id, String result) async {
    if (!_checklistResults.contains(result)) {
      throw ArgumentError('Choose a valid inspection result.');
    }
    if (isSupabase) {
      await supabase!.from('checklist').update({'result': result}).eq('id', id);
      return;
    }
    await db.update(
      'checklist',
      {'result': result},
      where: 'id=?',
      whereArgs: [id],
    );
  }
}
