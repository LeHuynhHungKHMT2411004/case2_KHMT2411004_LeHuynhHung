import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Dia chi Backend tren Android Emulator.
const String apiBaseUrl = 'http://10.0.2.2:3000/api';

void main() {
  runApp(const TaskManagerApp());
}

// Doc JSON an toan.
Map<String, dynamic> readJson(String body) {
  try {
    final result = jsonDecode(body);

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
  } catch (_) {}

  return {};
}

// Dinh dang ngay thang.
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
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // GET: Lay danh sach cong viec.
  Future<void> _loadTasks() async {
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

  // POST / PATCH: Them hoac sua cong viec.
  Future<void> _openTaskForm({Map<String, dynamic>? task}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TaskFormDialog(task: task),
    );

    if (result == null) return;

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

  // Mo man hinh quan ly giao viec va chia se.
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

  // PATCH: Cap nhat trang thai.
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

  // DELETE: Xoa cong viec.
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

  // Dang xuat.
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

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = task['status']?.toString() ?? 'todo';
    final priority = task['priority']?.toString() ?? 'medium';

    final description = task['description']?.toString() ?? '';

    // Lay thong tin quyen truy cap tu Backend.
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

                if (hasActions)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openTaskForm(task: task);
                      } else if (value == 'delete') {
                        _deleteTask(task);
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

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
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
          // Loi chao va thong ke.
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

          // Bo loc cong viec.
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

          // Danh sach cong viec.
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

      if (response.statusCode != 200) {
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

      final data = readJson(response.body);

      if (response.statusCode != 200) {
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

  Widget _buildSearchField({
    required TextEditingController controller,
    required bool isSearching,
    required String hint,
    required VoidCallback onSearch,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E5EF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E5EF)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Tim kiem',
          onPressed: isSearching ? null : onSearch,
          icon: isSearching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
        ),
      ],
    );
  }

  Widget _buildAssigneesTab() {
    if (_isLoadingAssignees) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Tim nguoi dung theo email',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildSearchField(
          controller: _assigneeSearchController,
          isSearching: _isSearchingAssignees,
          hint: 'Nhap email can giao viec',
          onSearch: () => _searchUsers(forAssignees: true),
        ),
        if (_assigneeSearchResults.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Ket qua tim kiem - chon + de them',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          ..._assigneeSearchResults.map((user) {
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(user['name']?.toString() ?? 'Nguoi dung'),
                subtitle: Text(user['email']?.toString() ?? ''),
                trailing: IconButton(
                  tooltip: 'Them vao danh sach giao viec',
                  onPressed: () => _addAssignee(user),
                  icon: const Icon(Icons.add_circle, color: Color(0xFF5B5FEF)),
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
                'Nguoi duoc giao',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${_assignees.length} nguoi',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Chon nut radio de dat nguoi phu trach chinh.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (_assignees.isEmpty)
          const Card(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Chua co ai duoc giao cong viec nay.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ..._assignees.map((user) {
          final userId = user['_id']?.toString() ?? '';
          final isPrimary = userId.isNotEmpty && userId == _primaryAssigneeId;

          return Card(
            color: Colors.white,
            child: ListTile(
              leading: Radio<String>(
                value: userId,
                groupValue: _primaryAssigneeId,
                onChanged: (value) {
                  setState(() => _primaryAssigneeId = value);
                },
              ),
              title: Text(user['name']?.toString() ?? 'Nguoi dung'),
              subtitle: Text(
                '${user['email'] ?? ''}${isPrimary ? ' • Phu trach chinh' : ''}',
              ),
              trailing: IconButton(
                tooltip: 'Xoa khoi danh sach',
                onPressed: () => _removeAssignee(user),
                icon: const Icon(Icons.close, color: Colors.red),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),
        FilledButton.icon(
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
              : const Icon(Icons.save_outlined),
          label: const Text('Luu danh sach giao viec'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5B5FEF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSharesTab() {
    if (_isLoadingShares) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Chia se cong viec',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _newSharePermission,
          decoration: const InputDecoration(
            labelText: 'Quyen khi chia se',
            prefixIcon: Icon(Icons.security_outlined),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          items: const [
            DropdownMenuItem(value: 'viewer', child: Text('Viewer - Chi xem')),
            DropdownMenuItem(
              value: 'editor',
              child: Text('Editor - Xem va chinh sua'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _newSharePermission = value);
            }
          },
        ),
        const SizedBox(height: 12),
        _buildSearchField(
          controller: _shareSearchController,
          isSearching: _isSearchingShares,
          hint: 'Nhap email nguoi muon chia se',
          onSearch: () => _searchUsers(forAssignees: false),
        ),
        if (_shareSearchResults.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Ket qua tim kiem',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          ..._shareSearchResults.map((user) {
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(user['name']?.toString() ?? 'Nguoi dung'),
                subtitle: Text(user['email']?.toString() ?? ''),
                trailing: TextButton.icon(
                  onPressed: () => _shareWithUser(user),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Chia se'),
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
        if (_shares.isEmpty)
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
          ),
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
                '${user['email'] ?? ''}\nQuyen: ${permission == 'editor' ? 'Editor - Chinh sua' : 'Viewer - Chi xem'}',
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
                  value: _priority,
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
                  value: _status,
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
