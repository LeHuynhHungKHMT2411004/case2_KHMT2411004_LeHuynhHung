import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// =====================================================
// CAU HINH API
// =====================================================

const String apiBaseUrl = 'http://10.0.2.2:3000/api';

void main() {
  runApp(const TaskManagerApp());
}

// =====================================================
// CAC HAM DUNG CHUNG
// =====================================================

Map<String, dynamic> readJson(String body) {
  try {
    final result = jsonDecode(body);
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
  } catch (_) {}

  return {};
}

String formatDate(dynamic value) {
  if (value == null || value.toString().isEmpty) {
    return 'Chua dat han';
  }

  final date = DateTime.tryParse(value.toString());
  if (date == null) return 'Khong xac dinh';

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String statusLabel(String status) {
  switch (status) {
    case 'todo':
      return 'Chua thuc hien';
    case 'in_progress':
      return 'Dang thuc hien';
    case 'completed':
      return 'Hoan thanh';
    default:
      return 'Khong xac dinh';
  }
}

String priorityLabel(String priority) {
  switch (priority) {
    case 'low':
      return 'Thap';
    case 'medium':
      return 'Trung binh';
    case 'high':
      return 'Cao';
    default:
      return 'Trung binh';
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'todo':
      return Colors.blue;
    case 'in_progress':
      return Colors.orange;
    case 'completed':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

Color priorityColor(String priority) {
  switch (priority) {
    case 'low':
      return Colors.green;
    case 'medium':
      return Colors.orange;
    case 'high':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

// =====================================================
// APP
// =====================================================

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B5FEF)),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF25264A),
          elevation: 0,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

// =====================================================
// AUTH SCREEN: DANG NHAP / DANG KY
// =====================================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final endpoint = Uri.parse(
      '$apiBaseUrl/auth/${_isLogin ? 'login' : 'register'}',
    );

    final body = <String, String>{
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
    };

    if (!_isLogin) {
      body['name'] = _nameController.text.trim();
    }

    try {
      final response = await http
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);
      final expectedStatus = _isLogin ? 200 : 201;

      if (response.statusCode == expectedStatus) {
        final token = data['token']?.toString() ?? '';
        final user = data['user'];

        if (token.isEmpty) {
          _showMessage('Khong nhan duoc token.');
        } else {
          final userData = user is Map
              ? Map<String, dynamic>.from(user)
              : <String, dynamic>{};

          final name = userData['name']?.toString() ?? '';
          final email =
              userData['email']?.toString() ?? _emailController.text.trim();

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  HomeScreen(name: name, email: email, token: token),
            ),
          );

          return;
        }
      } else {
        _showMessage(data['message']?.toString() ?? 'Co loi xay ra.');
      }
    } catch (e) {
      debugPrint('Auth error: $e');
      _showMessage('Khong the ket noi Backend.');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8F8FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5B5FEF), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 25),
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B5FEF),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.task_alt_rounded,
                          color: Colors.white,
                          size: 45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Task Manager',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF25264A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isLogin
                          ? 'Dang nhap de quan ly cong viec'
                          : 'Tao tai khoan moi',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 35),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isLogin ? 'Dang nhap' : 'Dang ky',
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (!_isLogin) ...[
                              TextFormField(
                                controller: _nameController,
                                decoration: _inputDecoration(
                                  'Ho va ten',
                                  Icons.person_outline,
                                ),
                                validator: (value) {
                                  if (!_isLogin &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Vui long nhap ho ten';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                'Email',
                                Icons.email_outlined,
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';

                                if (email.isEmpty) {
                                  return 'Vui long nhap email';
                                }

                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                    .hasMatch(email)) {
                                  return 'Email khong hop le';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration:
                                  _inputDecoration(
                                    'Mat khau',
                                    Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui long nhap mat khau';
                                }

                                if (value.length < 6) {
                                  return 'Mat khau toi thieu 6 ky tu';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 25),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B5FEF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        _isLogin
                                            ? 'Dang nhap'
                                            : 'Tao tai khoan',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLogin
                                      ? 'Chua co tai khoan?'
                                      : 'Da co tai khoan?',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLogin = !_isLogin;
                                      _formKey.currentState?.reset();
                                    });
                                  },
                                  child: Text(
                                    _isLogin ? 'Dang ky' : 'Dang nhap',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// HOME SCREEN: DASHBOARD
// =====================================================

class HomeScreen extends StatefulWidget {
  final String name;
  final String email;
  final String token;

  const HomeScreen({
    super.key,
    required this.name,
    required this.email,
    required this.token,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _tasks = [];

  bool _isLoading = true;
  bool _isSaving = false;
  int _unreadNotificationCount = 0;

  String _filter = 'all';
  String? _loadError;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadUnreadNotificationCount();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationScreen(token: widget.token),
      ),
    );

    if (!mounted) return;
    await _loadUnreadNotificationCount();
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/notifications/unread-count'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _unreadNotificationCount =
              (data['unreadCount'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Load unread notification count error: $e');
    }
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/tasks'), headers: _headers)
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode == 200) {
        final rawTasks = data['tasks'];

        final tasks = rawTasks is List
            ? rawTasks
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];

        if (!mounted) return;

        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      } else {
        throw Exception(
          data['message']?.toString() ?? 'Khong the lay danh sach cong viec.',
        );
      }
    } catch (e) {
      debugPrint('Load tasks error: $e');

      if (!mounted) return;

      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openTaskForm({Map<String, dynamic>? task}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TaskFormDialog(task: task),
    );

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);

    final isEditing = task != null;
    final taskId = task?['_id']?.toString();

    try {
      final url = isEditing ? '$apiBaseUrl/tasks/$taskId' : '$apiBaseUrl/tasks';

      final response = isEditing
          ? await http.patch(
              Uri.parse(url),
              headers: _headers,
              body: jsonEncode(result),
            )
          : await http.post(
              Uri.parse(url),
              headers: _headers,
              body: jsonEncode(result),
            );

      final data = readJson(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage(
          isEditing
              ? 'Cap nhat cong viec thanh cong!'
              : 'Tao cong viec thanh cong!',
        );

        await _loadTasks();
      } else {
        _showMessage(data['message']?.toString() ?? 'Khong the luu cong viec.');
      }
    } catch (e) {
      debugPrint('Save task error: $e');
      _showMessage('Loi ket noi khi luu cong viec.');
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _openTaskMembers(Map<String, dynamic> task) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskMembersScreen(task: task, token: widget.token),
      ),
    );

    if (mounted) {
      await _loadTasks();
    }
  }

  Future<void> _showTaskActivities(Map<String, dynamic> task) async {
    final id = task['_id']?.toString();
    if (id == null || id.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (_) => TaskActivitiesDialog(
        taskId: id,
        taskTitle: task['title']?.toString() ?? 'Cong viec',
        token: widget.token,
      ),
    );
  }

  Future<void> _updateStatus(Map<String, dynamic> task, String status) async {
    final id = task['_id']?.toString();
    if (id == null || id.isEmpty) return;

    try {
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/tasks/$id'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );

      final data = readJson(response.body);

      if (response.statusCode == 200) {
        _showMessage('Cap nhat trang thai thanh cong!');
        await _loadTasks();
      } else {
        _showMessage(
          data['message']?.toString() ?? 'Khong the cap nhat trang thai.',
        );
      }
    } catch (e) {
      debugPrint('Update status error: $e');
      _showMessage('Loi ket noi Backend.');
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoa cong viec?'),
        content: Text('Ban co chac muon xoa "${task['title']}" khong?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xoa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = task['_id']?.toString();
    if (id == null || id.isEmpty) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/tasks/$id'),
        headers: _headers,
      );

      final data = readJson(response.body);

      if (response.statusCode == 200) {
        _showMessage('Xoa cong viec thanh cong!');
        await _loadTasks();
      } else {
        _showMessage(data['message']?.toString() ?? 'Khong the xoa cong viec.');
      }
    } catch (e) {
      debugPrint('Delete task error: $e');
      _showMessage('Loi ket noi Backend.');
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  List<Map<String, dynamic>> get _filteredTasks {
    if (_filter == 'all') return _tasks;

    return _tasks.where((task) {
      return task['status'] == _filter;
    }).toList();
  }

  int get _todoCount => _tasks.where((task) => task['status'] == 'todo').length;

  int get _progressCount =>
      _tasks.where((task) => task['status'] == 'in_progress').length;

  int get _completedCount =>
      _tasks.where((task) => task['status'] == 'completed').length;

  Widget _statCard(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = task['status']?.toString() ?? 'todo';
    final priority = task['priority']?.toString() ?? 'medium';
    final description = task['description']?.toString() ?? '';

    final accessData = task['access'];
    final access = accessData is Map
        ? Map<String, dynamic>.from(accessData)
        : <String, dynamic>{};

    final isCreator = access['isCreator'] == true;
    final canEditContent = access['canEditContent'] == true;
    final canUpdateStatus = access['canUpdateStatus'] == true;
    final canDelete = access['canDelete'] == true;

    final hasActions = canEditContent || canUpdateStatus || canDelete;

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task['title']?.toString() ?? 'Khong co ten',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF25264A),
                    ),
                  ),
                ),
                if (isCreator)
                  IconButton(
                    tooltip: 'Giao viec va chia se',
                    onPressed: () => _openTaskMembers(task),
                    icon: const Icon(
                      Icons.group_add_outlined,
                      color: Color(0xFF5B5FEF),
                    ),
                  ),
                IconButton(
                  tooltip: 'Lich su hoat dong',
                  onPressed: () => _showTaskActivities(task),
                  icon: const Icon(
                    Icons.history_outlined,
                    color: Color(0xFF5B5FEF),
                  ),
                ),
                if (hasActions)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openTaskForm(task: task);
                      } else if (value == 'delete') {
                        _deleteTask(task);
                      } else if (value == 'activities') {
                        _showTaskActivities(task);
                      } else if (value.startsWith('status:')) {
                        _updateStatus(task, value.substring(7));
                      }
                    },
                    itemBuilder: (context) => [
                      if (canEditContent)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 10),
                              Text('Chinh sua'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'activities',
                        child: Row(
                          children: [
                            Icon(Icons.history),
                            SizedBox(width: 10),
                            Text('Lich su hoat dong'),
                          ],
                        ),
                      ),
                      if (canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Xoa cong viec'),
                            ],
                          ),
                        ),
                      if (canUpdateStatus) ...[
                        if (canEditContent || canDelete)
                          const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'status:todo',
                          child: Text('Chuyen sang: Chua thuc hien'),
                        ),
                        const PopupMenuItem(
                          value: 'status:in_progress',
                          child: Text('Chuyen sang: Dang thuc hien'),
                        ),
                        const PopupMenuItem(
                          value: 'status:completed',
                          child: Text('Chuyen sang: Hoan thanh'),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(statusLabel(status), statusColor(status)),
                _tag(
                  'Uu tien: ${priorityLabel(priority)}',
                  priorityColor(priority),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 7),
                Text(
                  'Han: ${formatDate(task['dueDate'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _filter == 'all' ? Icons.task_alt : Icons.filter_alt_off,
              size: 75,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _filter == 'all'
                  ? 'Chua co cong viec nao'
                  : 'Khong co cong viec trong muc nay',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hay tao cong viec dau tien cua ban.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _openTaskForm,
              icon: const Icon(Icons.add),
              label: const Text('Them cong viec'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: Colors.red, size: 65),
            const SizedBox(height: 15),
            const Text(
              'Khong the tai danh sach cong viec',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh),
              label: const Text('Thu lai'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _filter = value);
        },
        selectedColor: const Color(0xFF5B5FEF),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
        side: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.name.isEmpty ? 'Ban' : widget.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Task Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Thong ke',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => StatisticsScreen(token: widget.token),
                ),
              );
            },
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Thong bao',
            onPressed: _openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: -7,
                    top: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadNotificationCount > 99
                            ? '99+'
                            : '$_unreadNotificationCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tai lai',
            onPressed: _isLoading ? null : _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Dang xuat',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chao, $displayName!',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF25264A),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.email,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statCard(
                      'Chua lam',
                      _todoCount,
                      Icons.pending_actions,
                      Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Dang lam',
                      _progressCount,
                      Icons.autorenew,
                      Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Hoan thanh',
                      _completedCount,
                      Icons.check_circle_outline,
                      Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _filterChip('all', 'Tat ca'),
                _filterChip('todo', 'Chua thuc hien'),
                _filterChip('in_progress', 'Dang thuc hien'),
                _filterChip('completed', 'Hoan thanh'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading && _tasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null && _tasks.isEmpty
                ? _buildErrorState()
                : _filteredTasks.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 5, 16, 100),
                      itemCount: _filteredTasks.length,
                      itemBuilder: (context, index) {
                        return _buildTaskCard(_filteredTasks[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _openTaskForm,
        backgroundColor: const Color(0xFF5B5FEF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Them cong viec'),
      ),
    );
  }
}

// =====================================================
// STATISTICS SCREEN: THONG KE CONG VIEC
// =====================================================

class StatisticsScreen extends StatefulWidget {
  final String token;

  const StatisticsScreen({super.key, required this.token});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic>? _taskStats;
  Map<String, dynamic>? _assignmentStats;
  Map<String, dynamic>? _deadlineStats;
  Map<String, dynamic>? _userData;

  bool _isLoading = true;
  String? _loadError;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  int _number(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;

    final hadData = _taskStats != null;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final responses = await Future.wait([
        http
            .get(
          Uri.parse('$apiBaseUrl/statistics/tasks'),
          headers: _headers,
        )
            .timeout(const Duration(seconds: 15)),
        http
            .get(
          Uri.parse('$apiBaseUrl/statistics/assignments'),
          headers: _headers,
        )
            .timeout(const Duration(seconds: 15)),
        http
            .get(
          Uri.parse('$apiBaseUrl/statistics/deadlines'),
          headers: _headers,
        )
            .timeout(const Duration(seconds: 15)),
        http
            .get(
          Uri.parse('$apiBaseUrl/auth/me'),
          headers: _headers,
        )
            .timeout(const Duration(seconds: 15)),
      ]);

      final taskData = readJson(responses[0].body);
      final assignmentData = readJson(responses[1].body);
      final deadlineData = readJson(responses[2].body);
      final userData = readJson(responses[3].body);

      for (var i = 0; i < responses.length; i++) {
        if (responses[i].statusCode != 200) {
          final data = readJson(responses[i].body);
          throw Exception(
            data['message']?.toString() ?? 'Khong the tai du lieu.',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _taskStats = taskData;
        _assignmentStats = assignmentData;
        _deadlineStats = deadlineData;
        _userData = userData;
        _isLoading = false;
      });

      if (hadData) {
        _showMessage('Da cap nhat thong ke thanh cong.');
      }
    } catch (e) {
      debugPrint('Load statistics error: $e');

      if (!mounted) return;

      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditProfileDialog() async {
    final userMap = _userData?['user'] is Map
        ? Map<String, dynamic>.from(_userData!['user'])
        : <String, dynamic>{};
    final currentName = userMap['name']?.toString() ?? '';
    final controller = TextEditingController(text: currentName);

    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chinh sua ho ten'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Ho va ten',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Huy'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Luu'),
          ),
        ],
      ),
    );

    if (updatedName == null || updatedName.isEmpty || updatedName == currentName) return;

    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/auth/me'),
        headers: _headers,
        body: jsonEncode({'name': updatedName}),
      );

      final data = readJson(response.body);

      if (response.statusCode == 200) {
        _showMessage('Cap nhat ho ten thanh cong!');
        await _loadStatistics();
      } else {
        _showMessage(data['message']?.toString() ?? 'Khong the cap nhat ho ten.');
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
      _showMessage('Loi ket noi khi cap nhat ho ten.');
    }
  }

  Future<void> _openChangePasswordDialog() async {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        String? errorMsg;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Doi mat khau'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMsg != null) ...[
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: currentPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mat khau hien tai',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mat khau moi (>= 8 ky tu)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Xac nhan mat khau moi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Huy'),
              ),
              FilledButton(
                onPressed: () {
                  final current = currentPassController.text;
                  final next = newPassController.text;
                  final confirm = confirmPassController.text;

                  if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                    setDialogState(() => errorMsg = 'Vui long nhap day du thong tin.');
                    return;
                  }
                  if (next.length < 8) {
                    setDialogState(() => errorMsg = 'Mat khau moi phai co it nhat 8 ky tu.');
                    return;
                  }
                  if (next != confirm) {
                    setDialogState(() => errorMsg = 'Xac nhan mat khau khong khop.');
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'currentPassword': current,
                    'newPassword': next,
                  });
                },
                child: const Text('Doi mat khau'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/auth/change-password'),
        headers: _headers,
        body: jsonEncode(result),
      );

      final data = readJson(response.body);

      if (response.statusCode == 200) {
        _showMessage('Doi mat khau thanh cong!');
      } else {
        _showMessage(data['message']?.toString() ?? 'Khong the doi mat khau.');
      }
    } catch (e) {
      debugPrint('Change password error: $e');
      _showMessage('Loi ket noi khi doi mat khau.');
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Widget _buildProfileCard() {
    final userMap = _userData?['user'] is Map
        ? Map<String, dynamic>.from(_userData!['user'])
        : <String, dynamic>{};
    final name = userMap['name']?.toString() ?? 'Nguoi dung';
    final email = userMap['email']?.toString() ?? '';

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF5B5FEF).withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B5FEF),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF25264A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openEditProfileDialog,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Doi ten'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openChangePasswordDialog,
                    icon: const Icon(Icons.lock_outline, size: 17),
                    label: const Text('Doi mat khau'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Dang xuat',
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5B5FEF)),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF25264A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
      String title,
      int value,
      IconData icon,
      Color color,
      ) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE9EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricGrid(List<Widget> cards) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.15,
      children: cards,
    );
  }

  String _formatLocalDate(dynamic value) {
    if (value == null) return 'Chua dat han';

    final date = DateTime.tryParse(value.toString())?.toLocal();

    if (date == null) return 'Khong xac dinh';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _deadlineSection(
      String title,
      dynamic rawTasks, {
        required bool isOverdue,
      }) {
    final tasks = rawTasks is List
        ? rawTasks
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
        : <Map<String, dynamic>>[];

    final color = isOverdue ? Colors.red : Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          title,
          isOverdue ? Icons.warning_amber_rounded : Icons.event_available,
        ),
        if (tasks.isEmpty)
          Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading: Icon(
                Icons.check_circle_outline,
                color: Colors.green,
              ),
              title: Text(
                isOverdue
                    ? 'Khong co cong viec qua han.'
                    : 'Khong co cong viec sap den han.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
        else
          ...tasks.map((task) {
            final primaryData = task['primaryAssigneeId'];
            final primary = primaryData is Map
                ? Map<String, dynamic>.from(primaryData)
                : <String, dynamic>{};

            final primaryName = primary['name']?.toString() ?? '';

            return Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE9EAF0)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.task_alt, color: color),
                ),
                title: Text(
                  task['title']?.toString() ?? 'Cong viec',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'Trang thai: ${statusLabel(task['status']?.toString() ?? '')}\n'
                        'Uu tien: ${priorityLabel(task['priority']?.toString() ?? '')}\n'
                        'Han: ${_formatLocalDate(task['dueDate'])}'
                        '${primaryName.isNotEmpty ? '\nPhu trach: $primaryName' : ''}',
                  ),
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: Colors.red,
              size: 65,
            ),
            const SizedBox(height: 14),
            const Text(
              'Khong the tai du lieu thong ke',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadStatistics,
              icon: const Icon(Icons.refresh),
              label: const Text('Thu lai'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final byStatus = _taskStats?['byStatus'] is Map
        ? Map<String, dynamic>.from(_taskStats!['byStatus'])
        : <String, dynamic>{};

    final taskStats = _taskStats!;
    final assignmentStats = _assignmentStats!;
    final deadlineStats = _deadlineStats!;

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          if (_loadError != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Khong the lam moi du lieu: $_loadError',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),

          _sectionTitle('Ho so ca nhan', Icons.person_outline),
          _buildProfileCard(),

          _sectionTitle('Tong quan cong viec', Icons.bar_chart),
          _metricGrid([
            _metricCard(
              'Tong cong viec',
              _number(taskStats['total']),
              Icons.task_alt,
              const Color(0xFF5B5FEF),
            ),
            _metricCard(
              'Chua thuc hien',
              _number(byStatus['todo']),
              Icons.pending_actions,
              Colors.blue,
            ),
            _metricCard(
              'Dang thuc hien',
              _number(byStatus['in_progress']),
              Icons.autorenew,
              Colors.orange,
            ),
            _metricCard(
              'Hoan thanh',
              _number(byStatus['completed']),
              Icons.check_circle_outline,
              Colors.green,
            ),
          ]),

          _sectionTitle('Thong ke giao viec', Icons.assignment_ind_outlined),
          _metricGrid([
            _metricCard(
              'Duoc giao cho toi',
              _number(assignmentStats['assignedToMe']),
              Icons.assignment_ind,
              Colors.blue,
            ),
            _metricCard(
              'Toi phu trach chinh',
              _number(assignmentStats['primaryResponsible']),
              Icons.person_pin,
              Colors.deepPurple,
            ),
            _metricCard(
              'Toi da giao',
              _number(assignmentStats['assignedByMe']),
              Icons.outbox_outlined,
              Colors.teal,
            ),
          ]),

          _sectionTitle('Theo doi thoi han', Icons.calendar_month),
          _metricGrid([
            _metricCard(
              'Sap den han (7 ngay)',
              _number(deadlineStats['dueSoonCount']),
              Icons.event_available,
              Colors.orange,
            ),
            _metricCard(
              'Cong viec qua han',
              _number(deadlineStats['overdueCount']),
              Icons.warning_amber_rounded,
              Colors.red,
            ),
          ]),

          _deadlineSection(
            'Cong viec sap den han',
            deadlineStats['dueSoon'],
            isOverdue: false,
          ),

          _deadlineSection(
            'Cong viec qua han',
            deadlineStats['overdue'],
            isOverdue: true,
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              'Keo xuong de cap nhat thong ke',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ca nhan & Thong ke',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Tai lai',
            onPressed: _isLoading ? null : _loadStatistics,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading && _taskStats == null
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _taskStats == null
          ? _buildErrorState()
          : _buildContent(),
    );
  }
}

// =====================================================
// TASK ACTIVITIES DIALOG: LICH SU HOAT DONG CONG VIEC
// =====================================================

class TaskActivitiesDialog extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String token;

  const TaskActivitiesDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.token,
  });

  @override
  State<TaskActivitiesDialog> createState() => _TaskActivitiesDialogState();
}

class _TaskActivitiesDialogState extends State<TaskActivitiesDialog> {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/tasks/${widget.taskId}/activities'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode == 200) {
        final list = data['activities'];
        if (list is List) {
          setState(() {
            _activities = list
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _activities = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'Khong the tai lich su.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Loi ket noi Backend.';
        _isLoading = false;
      });
    }
  }

  String _actionText(String action, Map<String, dynamic> details) {
    switch (action) {
      case 'task_created':
        return 'da tao cong viec';
      case 'task_updated':
        return 'da cap nhat noi dung';
      case 'status_changed':
        return 'da doi trang thai';
      case 'task_completed':
        return 'da hoan thanh cong viec';
      case 'assignees_updated':
        return 'da cap nhat nguoi duoc giao';
      case 'assignee_removed':
        return 'da xoa nguoi khoi danh sach duoc giao';
      case 'task_shared':
        return 'da chia se cong viec';
      case 'share_permission_changed':
        return 'da thay doi quyen chia se';
      case 'share_revoked':
        return 'da thu hoi quyen chia se';
      case 'task_deleted':
        return 'da xoa cong viec';
      default:
        return action;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'task_created':
        return Icons.add_circle_outline;
      case 'task_updated':
        return Icons.edit_note;
      case 'status_changed':
        return Icons.swap_horiz;
      case 'task_completed':
        return Icons.check_circle_outline;
      case 'assignees_updated':
      case 'assignee_removed':
        return Icons.assignment_ind_outlined;
      case 'task_shared':
      case 'share_permission_changed':
      case 'share_revoked':
        return Icons.share_outlined;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lich su hoat dong'),
          const SizedBox(height: 4),
          Text(
            widget.taskTitle,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _activities.isEmpty
                    ? const Center(child: Text('Chua co hoat dong nao.'))
                    : ListView.separated(
                        itemCount: _activities.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _activities[index];
                          final user = item['userId'] is Map
                              ? Map<String, dynamic>.from(item['userId'])
                              : <String, dynamic>{};

                          final userName = user['name']?.toString() ?? 'Nguoi dung';
                          final action = item['action']?.toString() ?? '';
                          final details = item['details'] is Map
                              ? Map<String, dynamic>.from(item['details'])
                              : <String, dynamic>{};
                          final createdAt = item['createdAt'];

                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF5B5FEF).withValues(alpha: 0.1),
                              child: Icon(
                                _actionIcon(action),
                                size: 18,
                                color: const Color(0xFF5B5FEF),
                              ),
                            ),
                            title: Text(
                              '$userName ${_actionText(action, details)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            subtitle: Text(
                              formatDate(createdAt),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dong'),
        ),
      ],
    );
  }
}

// =====================================================
// NOTIFICATION SCREEN: MAN HINH THONG BAO
// =====================================================

class NotificationScreen extends StatefulWidget {
  final String token;

  const NotificationScreen({super.key, required this.token});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];

  bool _isLoading = true;
  bool _isMarkingAllRead = false;
  String? _loadError;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/notifications'), headers: _headers)
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ?? 'Khong the tai thong bao.',
        );
      }

      final rawNotifications = data['notifications'];

      final notifications = rawNotifications is List
          ? rawNotifications
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load notifications error: $e');

      if (!mounted) return;

      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    if (notification['isRead'] == true) return;

    final id = notification['_id']?.toString();
    if (id == null || id.isEmpty) return;

    try {
      final response = await http
          .patch(
            Uri.parse('$apiBaseUrl/notifications/$id/read'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ?? 'Khong the danh dau da doc.',
        );
      }

      if (!mounted) return;

      setState(() {
        final index = _notifications.indexWhere(
          (item) => item['_id']?.toString() == id,
        );

        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });
    } catch (e) {
      debugPrint('Mark notification as read error: $e');
      _showMessage('Khong the danh dau thong bao da doc.');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAllRead) return;

    setState(() => _isMarkingAllRead = true);

    try {
      final response = await http
          .patch(
            Uri.parse('$apiBaseUrl/notifications/read-all'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ?? 'Khong the danh dau tat ca da doc.',
        );
      }

      if (!mounted) return;

      setState(() {
        for (final notification in _notifications) {
          notification['isRead'] = true;
        }

        _isMarkingAllRead = false;
      });

      _showMessage('Da danh dau tat ca thong bao la da doc.');
    } catch (e) {
      debugPrint('Mark all notifications as read error: $e');

      if (!mounted) return;

      setState(() => _isMarkingAllRead = false);
      _showMessage('Khong the danh dau tat ca thong bao da doc.');
    }
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind_outlined;
      case 'task_shared':
        return Icons.share_outlined;
      case 'task_completed':
        return Icons.check_circle_outline;
      case 'task_due_reminder':
        return Icons.alarm_outlined;
      case 'task_updated':
        return Icons.edit_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    await _markAsRead(notification);

    if (!mounted) return;

    final taskData = notification['task'];
    final task = taskData is Map
        ? Map<String, dynamic>.from(taskData)
        : <String, dynamic>{};

    final actorData = notification['actor'];
    final actor = actorData is Map
        ? Map<String, dynamic>.from(actorData)
        : <String, dynamic>{};

    final taskTitle = task['title']?.toString() ?? '';
    final actorName = actor['name']?.toString() ?? '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          notification['title']?.toString() ?? 'Thong bao',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification['message']?.toString() ?? '',
                style: const TextStyle(height: 1.5),
              ),
              if (actorName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Nguoi thuc hien: $actorName'),
              ],
              if (taskTitle.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'Cong viec lien quan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(taskTitle, style: const TextStyle(fontSize: 16)),
                if (task['status'] != null) ...[
                  const SizedBox(height: 6),
                  Text('Trang thai: ${statusLabel(task['status'].toString())}'),
                ],
                if (task['dueDate'] != null) ...[
                  const SizedBox(height: 6),
                  Text('Han: ${formatDate(task['dueDate'])}'),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Dong'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 75, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Ban chua co thong bao nao',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: Colors.red, size: 60),
            const SizedBox(height: 12),
            const Text('Khong the tai thong bao'),
            const SizedBox(height: 12),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Thu lai'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((notification) => notification['isRead'] != true)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thong bao',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _isMarkingAllRead ? null : _markAllAsRead,
              child: _isMarkingAllRead
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Doc tat ca'),
            ),
          IconButton(
            tooltip: 'Tai lai',
            onPressed: _isLoading ? null : _loadNotifications,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _notifications.isEmpty
          ? _buildErrorState()
          : _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final notification = _notifications[index];

                  final type = notification['type']?.toString() ?? '';
                  final isRead = notification['isRead'] == true;
                  final message = notification['message']?.toString() ?? '';
                  final createdAt = notification['createdAt'];

                  return Card(
                    color: isRead ? Colors.white : const Color(0xFFF0F0FF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE9EAF0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF5B5FEF)
                            .withValues(alpha: 0.12),
                        child: Icon(
                          _notificationIcon(type),
                          color: const Color(0xFF5B5FEF),
                        ),
                      ),
                      title: Text(
                        notification['title']?.toString() ?? 'Thong bao',
                        style: TextStyle(
                          fontWeight: isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '$message\n${formatDate(createdAt)}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      isThreeLine: true,
                      trailing: isRead
                          ? null
                          : const Icon(
                              Icons.circle,
                              color: Color(0xFF5B5FEF),
                              size: 10,
                            ),
                      onTap: () => _openNotification(notification),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// =====================================================
// TASK MEMBERS: GIAO VIEC / CHIA SE CONG VIEC
// =====================================================

class TaskMembersScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final String token;

  const TaskMembersScreen({super.key, required this.task, required this.token});

  @override
  State<TaskMembersScreen> createState() => _TaskMembersScreenState();
}

class _TaskMembersScreenState extends State<TaskMembersScreen> {
  final _assigneeSearchController = TextEditingController();
  final _shareSearchController = TextEditingController();

  List<Map<String, dynamic>> _assignees = [];
  List<Map<String, dynamic>> _assigneeSearchResults = [];
  List<Map<String, dynamic>> _shares = [];
  List<Map<String, dynamic>> _shareSearchResults = [];

  String? _primaryAssigneeId;
  String _newSharePermission = 'viewer';

  bool _isLoadingAssignees = true;
  bool _isLoadingShares = true;
  bool _isSearchingAssignees = false;
  bool _isSearchingShares = false;
  bool _isSavingAssignees = false;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  String get _taskId => widget.task['_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadAssignees();
    _loadShares();
  }

  @override
  void dispose() {
    _assigneeSearchController.dispose();
    _shareSearchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> _readUserList(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // GET /tasks/:taskId/assignees
  Future<void> _loadAssignees() async {
    setState(() => _isLoadingAssignees = true);

    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/tasks/$_taskId/assignees'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ?? 'Khong the tai danh sach giao viec.',
        );
      }

      final primary = data['primaryAssignee'];
      final primaryUser = primary is Map
          ? Map<String, dynamic>.from(primary)
          : null;

      if (!mounted) return;

      setState(() {
        _assignees = _readUserList(data['assignees']);
        _primaryAssigneeId = primaryUser?['_id']?.toString();
        _isLoadingAssignees = false;
      });
    } catch (e) {
      debugPrint('Load assignees error: $e');

      if (!mounted) return;

      setState(() => _isLoadingAssignees = false);
      _showMessage('Khong the tai danh sach nguoi duoc giao.');
    }
  }

  // GET /tasks/:taskId/shares
  Future<void> _loadShares() async {
    setState(() => _isLoadingShares = true);

    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/tasks/$_taskId/shares'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ?? 'Khong the tai danh sach chia se.',
        );
      }

      if (!mounted) return;

      setState(() {
        _shares = _readUserList(data['shares']);
        _isLoadingShares = false;
      });
    } catch (e) {
      debugPrint('Load shares error: $e');

      if (!mounted) return;

      setState(() => _isLoadingShares = false);
      _showMessage('Khong the tai danh sach chia se.');
    }
  }

  // GET /users/search?q=email
  Future<void> _searchUsers({required bool forAssignees}) async {
    final controller = forAssignees
        ? _assigneeSearchController
        : _shareSearchController;

    final query = controller.text.trim();

    if (query.length < 2) {
      _showMessage('Nhap it nhat 2 ky tu email de tim kiem.');
      return;
    }

    setState(() {
      if (forAssignees) {
        _isSearchingAssignees = true;
        _assigneeSearchResults = [];
      } else {
        _isSearchingShares = true;
        _shareSearchResults = [];
      }
    });

    try {
      final uri = Uri.parse(
        '$apiBaseUrl/users/search?q=${Uri.encodeQueryComponent(query)}',
      );

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ?? 'Tim kiem nguoi dung that bai.',
        );
      }

      final users = _readUserList(data['users']);

      if (!mounted) return;

      setState(() {
        if (forAssignees) {
          _assigneeSearchResults = users;
          _isSearchingAssignees = false;
        } else {
          _shareSearchResults = users;
          _isSearchingShares = false;
        }
      });

      if (users.isEmpty) {
        _showMessage('Khong tim thay tai khoan phu hop.');
      }
    } catch (e) {
      debugPrint('Search users error: $e');

      if (!mounted) return;

      setState(() {
        if (forAssignees) {
          _isSearchingAssignees = false;
        } else {
          _isSearchingShares = false;
        }
      });

      _showMessage('Khong the tim kiem nguoi dung.');
    }
  }

  void _addAssignee(Map<String, dynamic> user) {
    final userId = user['_id']?.toString();
    if (userId == null || userId.isEmpty) return;

    final alreadyAdded = _assignees.any(
      (item) => item['_id']?.toString() == userId,
    );

    if (alreadyAdded) {
      _showMessage('Nguoi nay da nam trong danh sach giao viec.');
      return;
    }

    if (_assignees.length >= 50) {
      _showMessage('Moi cong viec chi duoc giao toi da 50 nguoi.');
      return;
    }

    setState(() {
      _assignees.add(user);
      _primaryAssigneeId ??= userId;
      _assigneeSearchResults = [];
      _assigneeSearchController.clear();
    });
  }

  void _removeAssignee(Map<String, dynamic> user) {
    final userId = user['_id']?.toString();
    if (userId == null) return;

    setState(() {
      _assignees.removeWhere((item) => item['_id']?.toString() == userId);

      if (_primaryAssigneeId == userId) {
        _primaryAssigneeId = null;
      }
    });
  }

  // PUT /tasks/:taskId/assignees
  Future<void> _saveAssignees() async {
    setState(() => _isSavingAssignees = true);

    try {
      final response = await http
          .put(
            Uri.parse('$apiBaseUrl/tasks/$_taskId/assignees'),
            headers: _headers,
            body: jsonEncode({
              'userIds': _assignees
                  .map((user) => user['_id'].toString())
                  .toList(),
              'primaryAssigneeId': _primaryAssigneeId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ?? 'Khong the luu danh sach giao viec.',
        );
      }

      final primary = data['primaryAssignee'];
      final primaryUser = primary is Map
          ? Map<String, dynamic>.from(primary)
          : null;

      if (!mounted) return;

      setState(() {
        _assignees = _readUserList(data['assignees']);
        _primaryAssigneeId = primaryUser?['_id']?.toString();
        _isSavingAssignees = false;
      });

      _showMessage('Da cap nhat danh sach giao viec.');
    } catch (e) {
      debugPrint('Save assignees error: $e');

      if (!mounted) return;

      setState(() => _isSavingAssignees = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // POST /tasks/:taskId/shares
  Future<void> _shareWithUser(Map<String, dynamic> user) async {
    final userId = user['_id']?.toString();
    if (userId == null || userId.isEmpty) return;

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/tasks/$_taskId/shares'),
            headers: _headers,
            body: jsonEncode({
              'userId': userId,
              'permission': _newSharePermission,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          data['message']?.toString() ?? 'Khong the chia se cong viec.',
        );
      }

      if (!mounted) return;

      setState(() {
        _shareSearchResults = [];
        _shareSearchController.clear();
      });

      _showMessage('Chia se cong viec thanh cong.');
      await _loadShares();
    } catch (e) {
      debugPrint('Share task error: $e');
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // PATCH /tasks/:taskId/shares/:shareId
  Future<void> _updateSharePermission(
    Map<String, dynamic> share,
    String permission,
  ) async {
    final shareId = share['_id']?.toString();
    if (shareId == null || shareId.isEmpty) return;

    try {
      final response = await http
          .patch(
            Uri.parse('$apiBaseUrl/tasks/$_taskId/shares/$shareId'),
            headers: _headers,
            body: jsonEncode({'permission': permission}),
          )
          .timeout(const Duration(seconds: 15));

      final data = readJson(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ?? 'Khong the cap nhat quyen chia se.',
        );
      }

      _showMessage('Da cap nhat quyen chia se.');
      await _loadShares();
    } catch (e) {
      debugPrint('Update share permission error: $e');
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // DELETE /tasks/:taskId/shares/:shareId
  Future<void> _deleteShare(Map<String, dynamic> share) async {
    final shareId = share['_id']?.toString();
    if (shareId == null || shareId.isEmpty) return;

    final userData = share['userId'];
    final user = userData is Map
        ? Map<String, dynamic>.from(userData)
        : <String, dynamic>{};

    final userName = user['name']?.toString() ?? 'nguoi dung nay';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thu hoi quyen chia se?'),
        content: Text('Ban co chac muon thu hoi quyen cua $userName khong?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Thu hoi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http
          .delete(
            Uri.parse('$apiBaseUrl/tasks/$_taskId/shares/$shareId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 204) {
        final data = readJson(response.body);
        throw Exception(
          data['message']?.toString() ?? 'Khong the thu hoi quyen chia se.',
        );
      }

      _showMessage('Da thu hoi quyen chia se.');
      await _loadShares();
    } catch (e) {
      debugPrint('Delete share error: $e');
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // GIAO DIEN TAB GIAO VIEC
  Widget _buildAssigneesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Tim nguoi de giao viec',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _assigneeSearchController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Nhap email nguoi dung',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _searchUsers(forAssignees: true);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isSearchingAssignees
                  ? null
                  : () => _searchUsers(forAssignees: true),
              icon: _isSearchingAssignees
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
            ),
          ],
        ),
        if (_assigneeSearchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Ket qua tim kiem',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ..._assigneeSearchResults.map((user) {
            final id = user['_id']?.toString() ?? '';
            final alreadyAdded = _assignees.any(
              (item) => item['_id']?.toString() == id,
            );

            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(user['name']?.toString() ?? 'Nguoi dung'),
                subtitle: Text(user['email']?.toString() ?? ''),
                trailing: IconButton(
                  tooltip: alreadyAdded ? 'Da them' : 'Them',
                  onPressed: alreadyAdded ? null : () => _addAssignee(user),
                  icon: Icon(
                    alreadyAdded ? Icons.check : Icons.add_circle,
                    color: alreadyAdded ? Colors.green : null,
                  ),
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Danh sach nguoi duoc giao',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${_assignees.length} nguoi',
              style: const TextStyle(color: Colors.grey),
            ),
            IconButton(
              tooltip: 'Tai lai',
              onPressed: _loadAssignees,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_isLoadingAssignees)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_assignees.isEmpty)
          const Card(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Chua giao cong viec cho ai.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._assignees.map((user) {
            final id = user['_id']?.toString() ?? '';
            final isPrimary = id == _primaryAssigneeId;

            return Card(
              color: Colors.white,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPrimary
                      ? const Color(0xFF5B5FEF)
                      : Colors.grey.shade200,
                  child: Icon(
                    Icons.person_outline,
                    color: isPrimary ? Colors.white : Colors.black54,
                  ),
                ),
                title: Text(user['name']?.toString() ?? 'Nguoi dung'),
                subtitle: Text(
                  '${user['email'] ?? ''}'
                  '${isPrimary ? '\nNguoi phu trach chinh' : ''}',
                ),
                isThreeLine: isPrimary,
                trailing: IconButton(
                  tooltip: 'Xoa khoi danh sach',
                  onPressed: () => _removeAssignee(user),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _primaryAssigneeId = id;
                  });
                },
              ),
            );
          }),
        if (_assignees.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Cham vao mot nguoi de chon nguoi phu trach chinh.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _isSavingAssignees ? null : _saveAssignees,
            icon: _isSavingAssignees
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: const Text('Luu danh sach giao viec'),
          ),
        ),
      ],
    );
  }

  // GIAO DIEN TAB CHIA SE
  Widget _buildSharesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Tim nguoi de chia se cong viec',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _shareSearchController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Nhap email nguoi dung',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            _searchUsers(forAssignees: false);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Quyen truy cap:'),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                value: _newSharePermission,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'viewer',
                    child: Text('Viewer - Chi xem'),
                  ),
                  DropdownMenuItem(
                    value: 'editor',
                    child: Text('Editor - Chinh sua'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _newSharePermission = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isSearchingShares
                  ? null
                  : () => _searchUsers(forAssignees: false),
              icon: _isSearchingShares
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
            ),
          ],
        ),
        if (_shareSearchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Ket qua tim kiem',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ..._shareSearchResults.map((user) {
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(user['name']?.toString() ?? 'Nguoi dung'),
                subtitle: Text(user['email']?.toString() ?? ''),
                trailing: IconButton(
                  tooltip: 'Chia se',
                  onPressed: () => _shareWithUser(user),
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Color(0xFF5B5FEF),
                  ),
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Danh sach da chia se',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${_shares.length} nguoi',
              style: const TextStyle(color: Colors.grey),
            ),
            IconButton(
              tooltip: 'Tai lai',
              onPressed: _loadShares,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_isLoadingShares)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_shares.isEmpty)
          const Card(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Cong viec nay chua duoc chia se cho ai.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._shares.map((share) {
            final userData = share['userId'];
            final user = userData is Map
                ? Map<String, dynamic>.from(userData)
                : <String, dynamic>{};

            final permission = share['permission']?.toString() == 'editor'
                ? 'editor'
                : 'viewer';

            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(user['name']?.toString() ?? 'Nguoi dung'),
                subtitle: Text(
                  '${user['email'] ?? ''}\n'
                  'Quyen: ${permission == 'editor' ? 'Editor - Chinh sua' : 'Viewer - Chi xem'}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  tooltip: 'Quan ly quyen',
                  onSelected: (value) {
                    if (value == 'viewer' || value == 'editor') {
                      _updateSharePermission(share, value);
                    } else if (value == 'remove') {
                      _deleteShare(share);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'viewer',
                      child: Text('Doi thanh Viewer'),
                    ),
                    const PopupMenuItem(
                      value: 'editor',
                      child: Text('Doi thanh Editor'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        'Thu hoi quyen chia se',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskTitle = widget.task['title']?.toString() ?? 'Cong viec';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Quan ly thanh vien',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.assignment_ind_outlined), text: 'Giao viec'),
              Tab(icon: Icon(Icons.share_outlined), text: 'Chia se'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                taskTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF25264A),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [_buildAssigneesTab(), _buildSharesTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// TASK FORM: THEM / CHINH SUA CONG VIEC
// =====================================================

class TaskFormDialog extends StatefulWidget {
  final Map<String, dynamic>? task;

  const TaskFormDialog({super.key, this.task});

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late String _status;
  late String _priority;

  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(
      text: task?['title']?.toString() ?? '',
    );

    _descriptionController = TextEditingController(
      text: task?['description']?.toString() ?? '',
    );

    _status = task?['status']?.toString() ?? 'todo';
    _priority = task?['priority']?.toString() ?? 'medium';

    final rawDate = task?['dueDate'];

    if (rawDate != null) {
      _dueDate = DateTime.tryParse(rawDate.toString());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chon han hoan thanh',
    );

    if (picked != null) {
      setState(() {
        _dueDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(context, <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'status': _status,
      'priority': _priority,
      'dueDate': _dueDate?.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return AlertDialog(
      title: Text(
        isEditing ? 'Chinh sua cong viec' : 'Them cong viec',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Ten cong viec',
                    prefixIcon: Icon(Icons.task_alt),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui long nhap ten cong viec';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: 'Mo ta',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Muc do uu tien',
                    prefixIcon: Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Thap')),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Trung binh'),
                    ),
                    DropdownMenuItem(value: 'high', child: Text('Cao')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _priority = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Trang thai',
                    prefixIcon: Icon(Icons.sync),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'todo',
                      child: Text('Chua thuc hien'),
                    ),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('Dang thuc hien'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Hoan thanh'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dueDate == null
                            ? 'Chua dat han'
                            : formatDate(_dueDate!.toIso8601String()),
                      ),
                    ),
                    TextButton(
                      onPressed: _chooseDate,
                      child: const Text('Chon ngay'),
                    ),
                    if (_dueDate != null)
                      IconButton(
                        tooltip: 'Xoa han',
                        onPressed: () {
                          setState(() => _dueDate = null);
                        },
                        icon: const Icon(Icons.close, color: Colors.red),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huy'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: Text(isEditing ? 'Cap nhat' : 'Tao cong viec'),
        ),
      ],
    );
  }
}
