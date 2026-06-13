import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:4000/api');

void main() {
  runApp(const NetMapApp());
}

class C {
  static const bg = Color(0xFF05080D);
  static const bg2 = Color(0xFF080D14);
  static const card = Color(0xFF0D1623);
  static const card2 = Color(0xFF101B2B);
  static const line = Color(0xFF243653);
  static const text = Color(0xFFF4F7FB);
  static const muted = Color(0xFF9AA7B8);
  static const accent = Color(0xFFF2B233);
  static const danger = Color(0xFFE34D64);
  static const warning = Color(0xFFF2B233);
  static const success = Color(0xFF6EE7A8);
  static const ok = Color(0xFF6EE7A8);
  static const info = Color(0xFF82A8FF);
}

class NetMapApp extends StatelessWidget {
  const NetMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AITAT NetMap',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        colorScheme: const ColorScheme.dark(primary: C.accent, secondary: C.accent, surface: C.card),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.bg2,
          hintStyle: const TextStyle(color: C.muted),
          labelStyle: const TextStyle(color: C.muted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.accent)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

String strVal(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();
int intVal(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(strVal(v)) ?? fallback;
}
List<dynamic> extractList(dynamic data, String key) {
  if (data is List) return data;
  if (data is Map && data[key] is List) return data[key] as List<dynamic>;
  return <dynamic>[];
}
Map<String, dynamic> extractMap(dynamic data, String key) {
  if (data is Map && data[key] is Map) return Map<String, dynamic>.from(data[key] as Map);
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String role;
  const UserProfile({required this.id, required this.name, required this.email, required this.role});
  bool get canWrite => role == 'admin' || role == 'engineer';
  bool get isAdmin => role == 'admin';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: strVal(json['_id'] ?? json['id']),
      name: strVal(json['name'], 'Пользователь'),
      email: strVal(json['email']),
      role: strVal(json['role'], 'viewer'),
    );
  }
}

class Device {
  final String id;
  final String name;
  final String type;
  final String room;
  final String ip;
  final String mac;
  final String status;
  final String description;
  final int load;
  final int latency;
  final int uptime;
  final List<String> connectedTo;

  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.room,
    required this.ip,
    required this.mac,
    required this.status,
    required this.description,
    required this.load,
    required this.latency,
    required this.uptime,
    required this.connectedTo,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: strVal(json['_id'] ?? json['id']),
      name: strVal(json['name'], 'Устройство'),
      type: strVal(json['type'], 'pc'),
      room: strVal(json['room'], 'Open-space'),
      ip: strVal(json['ip']),
      mac: strVal(json['mac']),
      status: strVal(json['status'], 'online'),
      description: strVal(json['description']),
      load: intVal(json['load']).clamp(0, 100),
      latency: intVal(json['latency']),
      uptime: intVal(json['uptime'], 99).clamp(0, 100),
      connectedTo: json['connectedTo'] is List ? (json['connectedTo'] as List).map((e) => e.toString()).toList() : <String>[],
    );
  }
}

class Incident {
  final String id;
  final String title;
  final String deviceName;
  final String severity;
  final String description;
  final String status;
  final List<String> notes;

  const Incident({
    required this.id,
    required this.title,
    required this.deviceName,
    required this.severity,
    required this.description,
    required this.status,
    required this.notes,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'] is List ? json['notes'] as List : <dynamic>[];
    return Incident(
      id: strVal(json['_id'] ?? json['id']),
      title: strVal(json['title'], 'Инцидент'),
      deviceName: strVal(json['deviceName']),
      severity: strVal(json['severity'], 'medium'),
      description: strVal(json['description']),
      status: strVal(json['status'], 'active'),
      notes: rawNotes.map((n) {
        if (n is Map) return strVal(n['text']);
        return n.toString();
      }).where((s) => s.trim().isNotEmpty).toList(),
    );
  }
}

class EventItem {
  final String id;
  final String message;
  final String type;
  final String deviceName;
  final String actor;

  const EventItem({required this.id, required this.message, required this.type, required this.deviceName, required this.actor});

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: strVal(json['_id'] ?? json['id']),
      message: strVal(json['message'], 'Событие'),
      type: strVal(json['type'], 'info'),
      deviceName: strVal(json['deviceName']),
      actor: strVal(json['actor'], 'Система'),
    );
  }
}

class Overview {
  final int total;
  final int online;
  final int problems;
  final int maintenance;
  final int activeIncidents;
  final int avgLoad;
  final List<Device> topLoad;

  const Overview({
    required this.total,
    required this.online,
    required this.problems,
    required this.maintenance,
    required this.activeIncidents,
    required this.avgLoad,
    required this.topLoad,
  });

  factory Overview.fromJson(Map<String, dynamic> json) {
    return Overview(
      total: intVal(json['total']),
      online: intVal(json['online']),
      problems: intVal(json['problems']),
      maintenance: intVal(json['maintenance']),
      activeIncidents: intVal(json['activeIncidents']),
      avgLoad: intVal(json['avgLoad']),
      topLoad: extractList(json, 'topLoad').map((e) => Device.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class ApiClient {
  String? token;

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri uri(String path) => Uri.parse('$apiBaseUrl$path');

  Future<dynamic> _decode(http.Response res) async {
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      data = {'message': res.body};
    }
    if (res.statusCode >= 400) {
      throw Exception(data is Map ? strVal(data['message'], 'Ошибка сервера') : 'Ошибка сервера');
    }
    return data;
  }

  Future<UserProfile> login(String email, String password) async {
    final res = await http.post(uri('/auth/login'), headers: headers, body: jsonEncode({'email': email, 'password': password}));
    final data = await _decode(res);
    token = strVal(data['token']);
    return UserProfile.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<UserProfile> register(String name, String email, String password) async {
    final res = await http.post(uri('/auth/register'), headers: headers, body: jsonEncode({'name': name, 'email': email, 'password': password}));
    final data = await _decode(res);
    token = strVal(data['token']);
    return UserProfile.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<List<Device>> devices() async {
    final data = await _decode(await http.get(uri('/devices'), headers: headers));
    return extractList(data, 'devices').map((e) => Device.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Device> createDevice(Map<String, dynamic> body) async {
    final data = await _decode(await http.post(uri('/devices'), headers: headers, body: jsonEncode(body)));
    return Device.fromJson(extractMap(data, 'device'));
  }

  Future<Device> updateDevice(String id, Map<String, dynamic> body) async {
    final data = await _decode(await http.patch(uri('/devices/$id'), headers: headers, body: jsonEncode(body)));
    return Device.fromJson(extractMap(data, 'device'));
  }

  Future<void> deleteDevice(String id) async {
    await _decode(await http.delete(uri('/devices/$id'), headers: headers));
  }

  Future<Device> ping(String id) async {
    final data = await _decode(await http.post(uri('/devices/$id/ping'), headers: headers));
    return Device.fromJson(extractMap(data, 'device'));
  }

  Future<List<Incident>> incidents() async {
    final data = await _decode(await http.get(uri('/incidents'), headers: headers));
    return extractList(data, 'incidents').map((e) => Incident.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Incident> createIncident({required String deviceId, required String title, required String description}) async {
    final data = await _decode(await http.post(uri('/incidents'), headers: headers, body: jsonEncode({'deviceId': deviceId, 'title': title, 'description': description})));
    return Incident.fromJson(extractMap(data, 'incident'));
  }

  Future<Incident> commentIncident(String id, String comment) async {
    final data = await _decode(await http.patch(uri('/incidents/$id/comment'), headers: headers, body: jsonEncode({'comment': comment})));
    return Incident.fromJson(extractMap(data, 'incident'));
  }

  Future<Incident> resolveIncident(String id) async {
    final data = await _decode(await http.patch(uri('/incidents/$id/resolve'), headers: headers));
    return Incident.fromJson(extractMap(data, 'incident'));
  }

  Future<List<EventItem>> events() async {
    final data = await _decode(await http.get(uri('/events'), headers: headers));
    return extractList(data, 'events').map((e) => EventItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Overview> overview() async {
    final data = await _decode(await http.get(uri('/overview'), headers: headers));
    return Overview.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final api = ApiClient();
  UserProfile? user;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return LoginPage(api: api, onLogin: (u) => setState(() => user = u));
    }
    return HomePage(api: api, user: user!, onLogout: () => setState(() => user = null));
  }
}

class LoginPage extends StatefulWidget {
  final ApiClient api;
  final ValueChanged<UserProfile> onLogin;
  const LoginPage({super.key, required this.api, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(text: 'admin@aitat.local');
  final password = TextEditingController(text: '123456');
  final name = TextEditingController();
  bool loading = false;
  bool register = false;
  String? error;

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final u = register ? await widget.api.register(name.text.trim(), email.text.trim(), password.text.trim()) : await widget.api.login(email.text.trim(), password.text.trim());
      widget.onLogin(u);
    } catch (e) {
      setState(() => error = cleanError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [C.bg, C.bg2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(width: 54, height: 54, decoration: BoxDecoration(color: C.accent.withOpacity(.15), border: Border.all(color: C.accent), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.hub, color: C.accent)),
                        const SizedBox(width: 14),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('АЙТАТ NetMap', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), Text('Карта сетевой инфраструктуры', style: TextStyle(color: C.muted))])),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (register) TextField(controller: name, decoration: const InputDecoration(labelText: 'Имя')),
                    if (register) const SizedBox(height: 10),
                    TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 10),
                    TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль')),
                    if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: C.danger, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Подождите...' : register ? 'Создать аккаунт' : 'Войти')),
                    TextButton(onPressed: loading ? null : () => setState(() => register = !register), child: Text(register ? 'Уже есть аккаунт' : 'Создать новый аккаунт')),
                    const Divider(color: C.line),
                    const Text('Демо: admin@aitat.local / 123456\nengineer@aitat.local / 123456\nviewer@aitat.local / 123456', style: TextStyle(color: C.muted)),
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

class HomePage extends StatefulWidget {
  final ApiClient api;
  final UserProfile user;
  final VoidCallback onLogout;
  const HomePage({super.key, required this.api, required this.user, required this.onLogout});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  int refreshTick = 0;

  void refreshAll() {
    setState(() { refreshTick++; });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MapPage(api: widget.api, user: widget.user, refreshTick: refreshTick, onChanged: refreshAll),
      DevicesPage(api: widget.api, user: widget.user, refreshTick: refreshTick, onChanged: refreshAll),
      IncidentsPage(api: widget.api, user: widget.user, refreshTick: refreshTick, onChanged: refreshAll),
      EventsPage(api: widget.api, refreshTick: refreshTick),
      OverviewPage(api: widget.api, refreshTick: refreshTick),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 6),
              child: Row(
                children: [
                  const Icon(Icons.hub, color: C.text, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('АЙТАТ NetMap', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900))),
                  IconButton(tooltip: 'Обновить', onPressed: refreshAll, icon: const Icon(Icons.refresh)),
                  IconButton(tooltip: 'Выход', onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
                ],
              ),
            ),
            Expanded(child: IndexedStack(index: index, children: pages)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: C.bg2,
        indicatorColor: C.accent.withOpacity(.2),
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Карта'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Устройства'),
          NavigationDestination(icon: Icon(Icons.notifications_none), label: 'Инциденты'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Журнал'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Обзор'),
        ],
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  final ApiClient api;
  final UserProfile user;
  final int refreshTick;
  final VoidCallback onChanged;
  const MapPage({super.key, required this.api, required this.user, required this.refreshTick, required this.onChanged});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late Future<List<Device>> future;
  String filter = 'all';
  String query = '';

  @override
  void initState() {
    super.initState();
    future = widget.api.devices();
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) reloadLocal();
  }

  void reloadLocal() {
    setState(() { future = widget.api.devices(); });
  }

  void afterChange() {
    reloadLocal();
    widget.onChanged();
  }

  Future<void> addDevice() async {
    final ok = await showDeviceForm(context, widget.api, null);
    if (ok == true) afterChange();
  }

  Future<void> ping(Device d) async {
    try {
      final updated = await widget.api.ping(d.id);
      if (!mounted) return;
      final reachable = updated.status != 'offline' && updated.latency > 0;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: C.card,
          title: Text(
            reachable ? 'Ping успешен' : 'Устройство недоступно',
            style: TextStyle(
              color: reachable ? C.success : C.danger,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Устройство: ${updated.name}'),
              const SizedBox(height: 8),
              Text('Статус: ${statusLabel(updated.status)}'),
              Text('Задержка: ${updated.latency} ms'),
              Text('Нагрузка: ${updated.load}%'),
              const SizedBox(height: 8),
              Text(
                reachable
                    ? 'Устройство отвечает на запрос.'
                    : 'Устройство не отвечает на ping-запрос.',
                style: TextStyle(color: reachable ? C.success : C.danger),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
      afterChange();
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  void openDevice(Device d) {
    showDeviceSheet(context: context, api: widget.api, user: widget.user, device: d, onChanged: afterChange, onPing: () => ping(d));
  }

  List<Device> filtered(List<Device> all) {
    return all.where((d) {
      final byStatus = filter == 'all' || d.status == filter;
      final q = query.trim().toLowerCase();
      final byQuery = q.isEmpty || '${d.name} ${d.ip} ${d.room} ${d.type}'.toLowerCase().contains(q);
      return byStatus && byQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Интерактивная карта офиса',
      subtitle: 'Устройства сгруппированы по комнатам. Нажмите на устройство для действий.',
      child: FutureBuilder<List<Device>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorBox(message: cleanError(snap.error!), onRetry: reloadLocal);
          final devices = filtered(snap.data ?? []);
          final rooms = <String, List<Device>>{};
          for (final d in devices) {
            rooms.putIfAbsent(d.room, () => []).add(d);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск...'))),
                  const SizedBox(width: 10),
                  if (widget.user.canWrite) SizedBox(height: 48, child: FilledButton.icon(onPressed: addDevice, icon: const Icon(Icons.add), label: const Text(''))),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  FilterChipX(label: 'Все', selected: filter == 'all', onTap: () => setState(() => filter = 'all')),
                  FilterChipX(label: 'Онлайн', selected: filter == 'online', onTap: () => setState(() => filter = 'online')),
                  FilterChipX(label: 'Внимание', selected: filter == 'warning', onTap: () => setState(() => filter = 'warning')),
                  FilterChipX(label: 'Офлайн', selected: filter == 'offline', onTap: () => setState(() => filter = 'offline')),
                ]),
              ),
              const SizedBox(height: 12),
              if (rooms.isEmpty) const EmptyBox(text: 'Устройства не найдены'),
              for (final entry in rooms.entries) RoomBlock(room: entry.key, devices: entry.value, onTap: openDevice),
            ],
          );
        },
      ),
    );
  }
}

class RoomBlock extends StatelessWidget {
  final String room;
  final List<Device> devices;
  final ValueChanged<Device> onTap;
  const RoomBlock({super.key, required this.room, required this.devices, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(room, style: const TextStyle(fontWeight: FontWeight.w900))), BadgeBox(text: '${devices.length} узл.', color: C.muted)]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final twoCols = c.maxWidth > 300;
            final itemWidth = twoCols ? (c.maxWidth - 10) / 2 : c.maxWidth;
            return Wrap(spacing: 10, runSpacing: 10, children: [for (final d in devices) SizedBox(width: itemWidth, child: DeviceMiniCard(device: d, onTap: () => onTap(d)))]);
          }),
        ],
      ),
    );
  }
}

class DevicesPage extends StatefulWidget {
  final ApiClient api;
  final UserProfile user;
  final int refreshTick;
  final VoidCallback onChanged;
  const DevicesPage({super.key, required this.api, required this.user, required this.refreshTick, required this.onChanged});
  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late Future<List<Device>> future;
  String query = '';

  @override
  void initState() {
    super.initState();
    future = widget.api.devices();
  }

  @override
  void didUpdateWidget(covariant DevicesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) reloadLocal();
  }

  void reloadLocal() {
    setState(() { future = widget.api.devices(); });
  }

  void afterChange() {
    reloadLocal();
    widget.onChanged();
  }

  Future<void> addDevice() async {
    final ok = await showDeviceForm(context, widget.api, null);
    if (ok == true) afterChange();
  }

  Future<void> ping(Device d) async {
    try {
      final updated = await widget.api.ping(d.id);
      if (!mounted) return;
      final reachable = updated.status != 'offline' && updated.latency > 0;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: C.card,
          title: Text(
            reachable ? 'Ping успешен' : 'Устройство недоступно',
            style: TextStyle(
              color: reachable ? C.success : C.danger,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Устройство: ${updated.name}'),
              const SizedBox(height: 8),
              Text('Статус: ${statusLabel(updated.status)}'),
              Text('Задержка: ${updated.latency} ms'),
              Text('Нагрузка: ${updated.load}%'),
              const SizedBox(height: 8),
              Text(
                reachable
                    ? 'Устройство отвечает на запрос.'
                    : 'Устройство не отвечает на ping-запрос.',
                style: TextStyle(color: reachable ? C.success : C.danger),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
      afterChange();
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  void openDevice(Device d) {
    showDeviceSheet(context: context, api: widget.api, user: widget.user, device: d, onChanged: afterChange, onPing: () => ping(d));
  }

  List<Device> filtered(List<Device> list) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((d) => '${d.name} ${d.ip} ${d.room} ${d.type}'.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Устройства',
      subtitle: 'Список оборудования, нагрузка и ping.',
      child: FutureBuilder<List<Device>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorBox(message: cleanError(snap.error!), onRetry: reloadLocal);
          final list = filtered(snap.data ?? []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Row(children: [
                Expanded(child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск устройства'))),
                const SizedBox(width: 10),
                if (widget.user.canWrite) SizedBox(height: 48, child: FilledButton.icon(onPressed: addDevice, icon: const Icon(Icons.add), label: const Text(''))),
              ]),
              const SizedBox(height: 12),
              if (list.isEmpty) const EmptyBox(text: 'Устройств нет'),
              for (final d in list) DeviceListCard(device: d, onTap: () => openDevice(d), onPing: () => ping(d)),
            ],
          );
        },
      ),
    );
  }
}

class IncidentsPage extends StatefulWidget {
  final ApiClient api;
  final UserProfile user;
  final int refreshTick;
  final VoidCallback onChanged;
  const IncidentsPage({super.key, required this.api, required this.user, required this.refreshTick, required this.onChanged});
  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  late Future<List<Incident>> future;
  String filter = 'active';

  @override
  void initState() {
    super.initState();
    future = widget.api.incidents();
  }

  @override
  void didUpdateWidget(covariant IncidentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) reloadLocal();
  }

  void reloadLocal() {
    setState(() { future = widget.api.incidents(); });
  }

  void afterChange() {
    reloadLocal();
    widget.onChanged();
  }

  List<Incident> filtered(List<Incident> list) {
    if (filter == 'all') return list;
    return list.where((i) => i.status == filter).toList();
  }

  Future<void> addComment(Incident inc) async {
    final text = await askText(context, 'Причина / действие', 'Опишите причину или действие. Инцидент останется активным.');
    if (text == null || text.trim().isEmpty) return;
    try {
      await widget.api.commentIncident(inc.id, text.trim());
      if (mounted) showMsg(context, 'Комментарий сохранён. Инцидент остался активным.');
      afterChange();
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  Future<void> resolve(Incident inc) async {
    final ok = await confirm(context, 'Отметить решённым?', 'Инцидент перейдёт из активных в решённые только после этого действия.');
    if (ok != true) return;
    try {
      await widget.api.resolveIncident(inc.id);
      if (mounted) showMsg(context, 'Инцидент отмечен решённым');
      afterChange();
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Инциденты',
      subtitle: 'Комментарий не закрывает инцидент. Закрытие — только отдельной кнопкой.',
      child: FutureBuilder<List<Incident>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorBox(message: cleanError(snap.error!), onRetry: reloadLocal);
          final list = filtered(snap.data ?? []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  FilterChipX(label: 'Активные', selected: filter == 'active', onTap: () => setState(() => filter = 'active')),
                  FilterChipX(label: 'Решённые', selected: filter == 'resolved', onTap: () => setState(() => filter = 'resolved')),
                  FilterChipX(label: 'Все', selected: filter == 'all', onTap: () => setState(() => filter = 'all')),
                ]),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty) const EmptyBox(text: 'Инцидентов нет'),
              for (final inc in list)
                IncidentCard(
                  incident: inc,
                  canWrite: widget.user.canWrite,
                  onComment: () => addComment(inc),
                  onResolve: () => resolve(inc),
                ),
            ],
          );
        },
      ),
    );
  }
}

class EventsPage extends StatefulWidget {
  final ApiClient api;
  final int refreshTick;
  const EventsPage({super.key, required this.api, required this.refreshTick});
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  late Future<List<EventItem>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.events();
  }

  @override
  void didUpdateWidget(covariant EventsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) reloadLocal();
  }

  void reloadLocal() {
    setState(() { future = widget.api.events(); });
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Журнал событий',
      subtitle: 'Ping, закрытие инцидентов и изменения записываются сюда.',
      child: FutureBuilder<List<EventItem>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorBox(message: cleanError(snap.error!), onRetry: reloadLocal);
          final events = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (events.isEmpty) const EmptyBox(text: 'Событий пока нет'),
              for (final e in events) EventCard(event: e),
            ],
          );
        },
      ),
    );
  }
}

class OverviewPage extends StatefulWidget {
  final ApiClient api;
  final int refreshTick;
  const OverviewPage({super.key, required this.api, required this.refreshTick});
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late Future<Overview> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.overview();
  }

  @override
  void didUpdateWidget(covariant OverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) reloadLocal();
  }

  void reloadLocal() {
    setState(() { future = widget.api.overview(); });
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Обзор сети',
      subtitle: 'Сводка состояния инфраструктуры и нагрузки.',
      child: FutureBuilder<Overview>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorBox(message: cleanError(snap.error!), onRetry: reloadLocal);
          final o = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              KpiWide(title: 'Всего устройств', value: '${o.total}', icon: Icons.devices, color: C.info),
              KpiWide(title: 'Онлайн', value: '${o.online}', icon: Icons.check_circle_outline, color: C.success),
              KpiWide(title: 'Проблемы', value: '${o.problems}', icon: Icons.warning_amber_rounded, color: C.warning),
              KpiWide(title: 'Активные инциденты', value: '${o.activeIncidents}', icon: Icons.notifications_none, color: C.danger),
              AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Средняя нагрузка сети', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  LoadBar(value: o.avgLoad, label: 'Средняя нагрузка'),
                  const SizedBox(height: 8),
                  Text('Значение меняется при добавлении/удалении устройств и после ping.', style: TextStyle(color: C.muted, fontSize: 12)),
                ]),
              ),
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Высокая нагрузка', style: TextStyle(fontWeight: FontWeight.w900))),
              if (o.topLoad.isEmpty) const EmptyBox(text: 'Нет данных по нагрузке'),
              for (final d in o.topLoad) LoadDeviceCard(device: d),
            ],
          );
        },
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const PageShell({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12)),
          ]),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class DeviceMiniCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  const DeviceMiniCard({super.key, required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(device.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(.55))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(typeIcon(device.type), size: 16, color: color), const SizedBox(width: 6), Expanded(child: Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))), Icon(Icons.keyboard_arrow_down, color: C.accent, size: 18)]),
          const SizedBox(height: 6),
          Text(device.ip.isEmpty ? 'IP не указан' : device.ip, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 11)),
          const SizedBox(height: 8),
          LoadBar(value: device.load, compact: true),
        ]),
      ),
    );
  }
}

class DeviceListCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onPing;
  const DeviceListCard({super.key, required this.device, required this.onTap, required this.onPing});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(typeIcon(device.type), color: statusColor(device.status)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${typeLabel(device.type)} • ${device.room}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12))])), BadgeBox(text: statusLabel(device.status), color: statusColor(device.status))]),
          const SizedBox(height: 10),
          LoadBar(value: device.load),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [BadgeBox(text: '${device.latency} ms', color: C.info), BadgeBox(text: 'uptime ${device.uptime}%', color: C.muted), OutlinedButton.icon(onPressed: onPing, icon: const Icon(Icons.network_ping, size: 16), label: const Text('Ping'))]),
        ]),
      ),
    );
  }
}

class IncidentCard extends StatelessWidget {
  final Incident incident;
  final bool canWrite;
  final VoidCallback onComment;
  final VoidCallback onResolve;
  const IncidentCard({super.key, required this.incident, required this.canWrite, required this.onComment, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final active = incident.status == 'active';
    final color = severityColor(incident.severity);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.warning_amber_rounded, color: color, size: 18), const SizedBox(width: 8), Expanded(child: Text(incident.severity.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w900))), BadgeBox(text: active ? 'АКТИВЕН' : 'РЕШЁН', color: active ? C.danger : C.success)]),
        const SizedBox(height: 10),
        Text(incident.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        if (incident.deviceName.isNotEmpty) Text('Устройство: ${incident.deviceName}', style: const TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 8),
        Text(incident.description, style: const TextStyle(color: C.muted)),
        if (incident.notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final note in incident.notes.take(2)) Text('• $note', style: const TextStyle(color: C.info, fontSize: 12)),
        ],
        if (canWrite && active) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: onComment, icon: const Icon(Icons.edit_note, size: 18), label: const Text('Добавить причину')),
            FilledButton.icon(onPressed: onResolve, icon: const Icon(Icons.check, size: 18), label: const Text('Отметить решённым')),
          ]),
        ],
      ]),
    );
  }
}

class EventCard extends StatelessWidget {
  final EventItem event;
  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final color = eventColor(event.type);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 16, backgroundColor: color.withOpacity(.18), child: Icon(Icons.circle, size: 8, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.message, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(event.deviceName.isEmpty ? 'Исполнитель: ${event.actor}' : 'Устройство: ${event.deviceName} • Исполнитель: ${event.actor}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12)),
        ])),
      ]),
    );
  }
}

class KpiWide extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const KpiWide({super.key, required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        CircleAvatar(backgroundColor: color.withOpacity(.14), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
      ]),
    );
  }
}

class LoadDeviceCard extends StatelessWidget {
  final Device device;
  const LoadDeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(typeIcon(device.type), color: statusColor(device.status)), const SizedBox(width: 8), Expanded(child: Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))), BadgeBox(text: '${device.load}%', color: device.load >= 80 ? C.danger : device.load >= 60 ? C.warning : C.info)]),
        const SizedBox(height: 6),
        Text('${typeLabel(device.type)} • ${device.room} • ${device.ip}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 8),
        LoadBar(value: device.load),
      ]),
    );
  }
}

void showDeviceSheet({required BuildContext context, required ApiClient api, required UserProfile user, required Device device, required VoidCallback onChanged, required VoidCallback onPing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: .78,
      minChildSize: .45,
      maxChildSize: .94,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(color: C.card, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(18),
          children: [
            Row(children: [Icon(typeIcon(device.type), color: statusColor(device.status), size: 34), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(device.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), Text('${typeLabel(device.type)} • ${device.room}', style: const TextStyle(color: C.muted))])), IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close))]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [BadgeBox(text: statusLabel(device.status), color: statusColor(device.status)), BadgeBox(text: 'IP ${device.ip}', color: C.muted), BadgeBox(text: '${device.latency} ms', color: C.info), BadgeBox(text: 'load ${device.load}%', color: C.accent)]),
            const SizedBox(height: 14),
            AppCard(child: Column(children: [InfoRow(label: 'MAC', value: device.mac.isEmpty ? '—' : device.mac), InfoRow(label: 'Описание', value: device.description.isEmpty ? '—' : device.description), InfoRow(label: 'Подключение', value: device.connectedTo.isEmpty ? 'автоматически' : 'назначено системой'), const SizedBox(height: 10), LoadBar(value: device.load), const SizedBox(height: 8), LoadBar(value: device.uptime, label: 'Uptime')])),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: () { Navigator.pop(ctx); onPing(); }, icon: const Icon(Icons.network_ping), label: const Text('Ping')),
              if (user.canWrite) OutlinedButton.icon(onPressed: () async { Navigator.pop(ctx); final ok = await showIncidentDialog(context, api, device); if (ok == true) onChanged(); }, icon: const Icon(Icons.add_alert), label: const Text('Инцидент')),
              if (user.canWrite) OutlinedButton.icon(onPressed: () async { Navigator.pop(ctx); final ok = await showDeviceForm(context, api, device); if (ok == true) onChanged(); }, icon: const Icon(Icons.edit), label: const Text('Редактировать')),
              if (user.isAdmin) OutlinedButton.icon(onPressed: () async { final ok = await confirm(ctx, 'Удалить устройство?', 'Действие нельзя отменить.'); if (ok == true) { Navigator.pop(ctx); await api.deleteDevice(device.id); onChanged(); } }, icon: const Icon(Icons.delete_outline, color: C.danger), label: const Text('Удалить')),
            ]),
            if (user.canWrite) ...[
              const SizedBox(height: 12),
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Сменить статус', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: [MiniButton(text: 'Онлайн', color: C.success, onTap: () async { Navigator.pop(ctx); await api.updateDevice(device.id, {'status': 'online'}); onChanged(); }), MiniButton(text: 'Внимание', color: C.warning, onTap: () async { Navigator.pop(ctx); await api.updateDevice(device.id, {'status': 'warning'}); onChanged(); }), MiniButton(text: 'Офлайн', color: C.danger, onTap: () async { Navigator.pop(ctx); await api.updateDevice(device.id, {'status': 'offline'}); onChanged(); }), MiniButton(text: 'Сервис', color: C.muted, onTap: () async { Navigator.pop(ctx); await api.updateDevice(device.id, {'status': 'maintenance'}); onChanged(); })])])),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<bool?> showDeviceForm(BuildContext context, ApiClient api, Device? device) async {
  final name = TextEditingController(text: device?.name ?? '');
  final ip = TextEditingController(text: device?.ip ?? '');
  final mac = TextEditingController(text: device?.mac ?? '');
  final description = TextEditingController(text: device?.description ?? '');
  String room = device?.room ?? 'Open-space';
  String type = device?.type ?? 'pc';
  String status = device?.status ?? 'online';
  bool saving = false;
  final rooms = ['Серверная', 'Open-space', 'Переговорная', 'Кабинет CEO', 'Зона печати', 'Рабочие места'];
  final types = ['pc', 'server', 'switch', 'router', 'printer', 'access_point'];
  final statuses = ['online', 'warning', 'offline', 'maintenance'];

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
      Future<void> save() async {
        if (name.text.trim().isEmpty) {
          showErr(ctx, 'Введите название');
          return;
        }
        setLocal(() => saving = true);
        try {
          final body = {'name': name.text.trim(), 'ip': ip.text.trim(), 'mac': mac.text.trim(), 'room': room, 'type': type, 'status': status, 'description': description.text.trim()};
          if (device == null) {
            await api.createDevice(body);
          } else {
            await api.updateDevice(device.id, body);
          }
          if (ctx.mounted) Navigator.pop(ctx, true);
        } catch (e) {
          if (ctx.mounted) showErr(ctx, e);
        }
        if (ctx.mounted) setLocal(() => saving = false);
      }

      return DraggableScrollableSheet(
        initialChildSize: .88,
        minChildSize: .55,
        maxChildSize: .95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(color: C.card, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: ListView(
            controller: ctrl,
            padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
            children: [
              Row(children: [Expanded(child: Text(device == null ? 'Добавить устройство' : 'Редактировать устройство', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20))), IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close))]),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Название')),
              const SizedBox(height: 10),
              TextField(controller: ip, decoration: const InputDecoration(labelText: 'IP')),
              const SizedBox(height: 10),
              TextField(controller: mac, decoration: const InputDecoration(labelText: 'MAC')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: room, isExpanded: true, decoration: const InputDecoration(labelText: 'Помещение'), items: rooms.map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setLocal(() => room = v ?? room)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: type, isExpanded: true, decoration: const InputDecoration(labelText: 'Тип'), items: types.map((t) => DropdownMenuItem(value: t, child: Text(typeLabel(t), overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setLocal(() => type = v ?? type)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: status, isExpanded: true, decoration: const InputDecoration(labelText: 'Статус'), items: statuses.map((st) => DropdownMenuItem(value: st, child: Text(statusLabel(st), overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setLocal(() => status = v ?? status)),
              const SizedBox(height: 10),
              TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Описание')),
              const SizedBox(height: 12),
              AppCard(child: const Text('Нагрузка и связь назначаются автоматически. ПК, принтеры и точки доступа увеличивают нагрузку связанного узла; при удалении нагрузка уменьшается.', style: TextStyle(color: C.muted))),
              const SizedBox(height: 14),
              FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Сохранение...' : 'Сохранить')),
            ],
          ),
        ),
      );
    }),
  );
}

Future<bool?> showIncidentDialog(BuildContext context, ApiClient api, Device device) async {
  final title = TextEditingController(text: 'Инцидент: ${device.name}');
  final description = TextEditingController(text: 'Опишите проблему и первичные признаки.');
  bool saving = false;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
      Future<void> save() async {
        setLocal(() => saving = true);
        try {
          await api.createIncident(deviceId: device.id, title: title.text.trim(), description: description.text.trim());
          if (ctx.mounted) Navigator.pop(ctx, true);
        } catch (e) {
          if (ctx.mounted) showErr(ctx, e);
        }
        if (ctx.mounted) setLocal(() => saving = false);
      }

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(color: C.card, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [const Expanded(child: Text('Создать инцидент', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20))), IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close))]),
            const SizedBox(height: 10),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Заголовок')),
            const SizedBox(height: 10),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Описание')),
            const SizedBox(height: 14),
            FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Сохранение...' : 'Создать')),
          ]),
        ),
      );
    }),
  );
}

Future<String?> askText(BuildContext context, String title, String hint) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.card,
      title: Text(title),
      content: TextField(controller: controller, minLines: 3, maxLines: 5, decoration: InputDecoration(hintText: hint)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Сохранить'))],
    ),
  );
}

Future<bool?> confirm(BuildContext context, String title, String text) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.card,
      title: Text(title),
      content: Text(text),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да'))],
    ),
  );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  const AppCard({super.key, required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
      child: child,
    );
  }
}

class BadgeBox extends StatelessWidget {
  final String text;
  final Color color;
  const BadgeBox({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(.12), border: Border.all(color: color.withOpacity(.45)), borderRadius: BorderRadius.circular(999)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class MiniButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;
  const MiniButton({super.key, required this.text, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: color.withOpacity(.12), border: Border.all(color: color.withOpacity(.45)), borderRadius: BorderRadius.circular(999)), child: Text(text, style: TextStyle(color: color, fontSize: 12))),
    );
  }
}

class FilterChipX extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const FilterChipX({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: C.accent,
        backgroundColor: C.bg2,
        labelStyle: TextStyle(color: selected ? Colors.black : C.text, fontWeight: FontWeight.w700),
        side: const BorderSide(color: C.line),
      ),
    );
  }
}

class LoadBar extends StatelessWidget {
  final int value;
  final String label;
  final bool compact;
  const LoadBar({super.key, required this.value, this.label = 'Нагрузка', this.compact = false});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!compact) Row(children: [Expanded(child: Text(label, style: const TextStyle(color: C.muted, fontSize: 12))), Text('$v%', style: const TextStyle(color: C.muted, fontSize: 12))]),
      if (!compact) const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: v / 100, minHeight: compact ? 5 : 7, color: v >= 80 ? C.danger : v >= 60 ? C.warning : C.info, backgroundColor: C.line)),
    ]);
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(label, style: const TextStyle(color: C.muted))), Expanded(child: Text(value, textAlign: TextAlign.right))]),
    );
  }
}

class EmptyBox extends StatelessWidget {
  final String text;
  const EmptyBox({super.key, required this.text});
  @override
  Widget build(BuildContext context) => AppCard(child: Center(child: Text(text, style: const TextStyle(color: C.muted))));
}

class ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorBox({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: AppCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: C.danger),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: C.danger)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ]),
        ),
      ),
    );
  }
}

Color statusColor(String status) {
  if (status == 'online') return C.success;
  if (status == 'warning') return C.warning;
  if (status == 'offline') return C.danger;
  return C.muted;
}

String statusLabel(String status) {
  if (status == 'online') return 'Онлайн';
  if (status == 'warning') return 'Внимание';
  if (status == 'offline') return 'Офлайн';
  return 'Обслуживание';
}

String typeLabel(String type) {
  if (type == 'pc') return 'ПК';
  if (type == 'server') return 'Сервер';
  if (type == 'switch') return 'Коммутатор';
  if (type == 'router') return 'Роутер';
  if (type == 'printer') return 'Принтер';
  return 'Точка доступа';
}

IconData typeIcon(String type) {
  if (type == 'pc') return Icons.computer;
  if (type == 'server') return Icons.dns;
  if (type == 'switch') return Icons.device_hub;
  if (type == 'router') return Icons.router;
  if (type == 'printer') return Icons.print;
  return Icons.wifi;
}

Color severityColor(String severity) {
  if (severity == 'critical') return C.danger;
  if (severity == 'high') return C.warning;
  if (severity == 'medium') return C.info;
  return C.muted;
}

Color eventColor(String type) {
  if (type == 'danger') return C.danger;
  if (type == 'warning') return C.warning;
  if (type == 'success') return C.success;
  if (type == 'system') return C.accent;
  return C.info;
}

String cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');
void showMsg(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: C.card));
void showErr(BuildContext context, Object e) => showMsg(context, cleanError(e));
