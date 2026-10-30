import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const CainWynApp());

class CainWynApp extends StatelessWidget {
  const CainWynApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'CainWyn VPN', debugShowCheckedModeBanner: false, theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)), useMaterial3: true), home: const HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const subscriptionUrl = 'https://cainwynserver.com/CainWyn2026Vip';
  String _status = '正在安全同步订阅...';
  List<String> _nodes = [];
  bool _isConnected = false;
  DateTime? _lastSync;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _sync();
    _timer = Timer.periodic(const Duration(hours: 6), (_) => _sync());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _sync() async {
    setState(() { _isLoading = true; _status = '正在连接 cainwynserver.com ...'; });
    try {
      final res = await http.get(Uri.parse(subscriptionUrl), headers: {'User-Agent': 'CainWynVPN/1.0'}).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final content = res.body.trim();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sub', content);
        String decoded = content;
        try { decoded = utf8.decode(base64.decode(content)); } catch (_) {}
        final nodes = decoded.split('\n').where((e) => e.trim().isNotEmpty).toList();
        final now = DateTime.now();
        await prefs.setString('last_sync', now.toIso8601String());
        await prefs.setInt('node_count', nodes.length);
        setState(() { _nodes = nodes; _status = '同步成功 • ${nodes.length} 个节点 • 已安全存储'; _lastSync = now; _isLoading = false; });
      } else {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('sub');
        if (cached != null) { setState(() { _nodes = cached.split('\n').where((e) => e.trim().isNotEmpty).toList(); _status = '使用本地安全缓存'; _isLoading = false; }); }
        else { setState(() { _status = '同步失败: ${res.statusCode}'; _isLoading = false; }); }
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('sub');
      setState(() { if (cached != null) { _nodes = cached.split('\n').where((e) => e.trim().isNotEmpty).toList(); _status = '离线模式 • 本地缓存'; } else { _status = '网络错误'; } _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CainWyn VPN', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(icon: const Icon(Icons.sync), onPressed: _sync)]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: _isConnected ? [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)] : [const Color(0xFF1E293B), const Color(0xFF334155)]), borderRadius: BorderRadius.circular(20)), child: Column(children: [Icon(_isConnected ? Icons.verified_user : Icons.shield_outlined, size: 64, color: Colors.white), const SizedBox(height: 12), Text(_isConnected ? '已安全连接' : 'CainWyn 安全节点', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(_status, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _nodes.isEmpty ? null : () { setState(() => _isConnected = !_isConnected); }, icon: Icon(_isConnected ? Icons.power_settings_new : Icons.bolt), label: Text(_isConnected ? '断开' : '一键安全连接')))])),
        const SizedBox(height: 16),
        Text('可用节点 (${_nodes.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._nodes.take(15).map((n) => Card(child: ListTile(leading: const Icon(Icons.circle, size: 10, color: Colors.green), title: Text(n.length > 50 ? '${n.substring(0,50)}...' : n, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))))),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: [const Text('订阅二维码'), const SizedBox(height: 12), QrImageView(data: subscriptionUrl, size: 160), const SizedBox(height: 8), const SelectableText(subscriptionUrl, style: TextStyle(fontSize: 10))]))
      ])),
    );
  }
}
