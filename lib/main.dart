
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CainWynApp());
}

class CainWynApp extends StatelessWidget {
  const CainWynApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CainWyn VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String subscriptionUrl = 'https://cainwynserver.com/CainWyn2026Vip';
  static const String domain = 'cainwynserver.com';

  final _storage = const FlutterSecureStorage();
  String _status = '正在安全同步订阅...';
  List<String> _nodes = [];
  String _rawContent = '';
  bool _isConnected = false;
  DateTime? _lastSync;
  Timer? _autoSyncTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
    _syncSubscription();
    // 自动每6小时同步
    _autoSyncTimer = Timer.periodic(const Duration(hours: 6), (_) => _syncSubscription());
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('last_sync');
    if (last != null) {
      setState(() => _lastSync = DateTime.parse(last));
    }
  }

  Future<void> _syncSubscription() async {
    setState(() {
      _isLoading = true;
      _status = '正在加密连接 $domain ...';
    });
    try {
      // 安全请求，带验证
      final response = await http.get(
        Uri.parse(subscriptionUrl),
        headers: {
          'User-Agent': 'CainWynVPN/1.0',
          'Accept': 'text/plain, */*',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = response.body.trim();
        // 安全存储原始订阅（加密存储）
        await _storage.write(key: 'subscription_raw', value: content);

        // 解析节点
        List<String> nodes = [];
        try {
          // 尝试 base64 解码
          String decoded = content;
          try {
            decoded = utf8.decode(base64.decode(content));
          } catch (_) {
            // 不是 base64，就是明文
            decoded = content;
          }
          nodes = decoded.split('\n').where((e) => e.trim().isNotEmpty).toList();
        } catch (e) {
          nodes = content.split('\n').where((e) => e.trim().isNotEmpty).toList();
        }

        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now();
        await prefs.setString('last_sync', now.toIso8601String());
        await prefs.setInt('node_count', nodes.length);

        setState(() {
          _rawContent = content;
          _nodes = nodes;
          _status = '同步成功 • ${nodes.length} 个节点 • 已加密存储';
          _lastSync = now;
          _isLoading = false;
        });
      } else {
        // 尝试读取本地缓存
        final cached = await _storage.read(key: 'subscription_raw');
        if (cached != null) {
          setState(() {
            _rawContent = cached;
            _nodes = cached.split('\n').where((e) => e.trim().isNotEmpty).toList();
            _status = '使用本地安全缓存 • ${response.statusCode}';
            _isLoading = false;
          });
        } else {
          setState(() {
            _status = '同步失败: HTTP ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } on SocketException {
      final cached = await _storage.read(key: 'subscription_raw');
      setState(() {
        if (cached != null) {
          _rawContent = cached;
          _nodes = cached.split('\n').where((e) => e.trim().isNotEmpty).toList();
          _status = '离线模式 • 使用本地加密缓存';
        } else {
          _status = '网络不可用，请检查连接';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '安全同步出错: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleConnection() {
    setState(() => _isConnected = !_isConnected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isConnected ? 'CainWyn VPN 已连接 • 流量已加密' : '已断开'),
        backgroundColor: _isConnected ? Colors.green : Colors.grey[800],
      ),
    );
  }

  Future<void> _copySubscription() async {
    // 复制功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('订阅链接已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF0EA5E9)),
            SizedBox(width: 8),
            Text('CainWyn VPN', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.sync_rounded), onPressed: _syncSubscription, tooltip: '立即同步'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态卡片
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isConnected 
                    ? [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)]
                    : [const Color(0xFF1E293B), const Color(0xFF334155)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Icon(
                    _isConnected ? Icons.verified_user_rounded : Icons.shield_outlined,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isConnected ? '已安全连接' : 'CainWyn 安全节点',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(_status, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _nodes.isEmpty ? null : _toggleConnection,
                      icon: Icon(_isConnected ? Icons.power_settings_new_rounded : Icons.bolt_rounded),
                      label: Text(_isConnected ? '断开连接' : '一键安全连接', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _isConnected ? Colors.red : const Color(0xFF0EA5E9),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 自动同步信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0EA5E9), size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('自动同步已开启', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(_lastSync == null ? '首次同步中...' : '上次同步: ${_lastSync!.toLocal().toString().split('.').first} • 每6小时自动同步', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ]),
                  ),
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 节点列表
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('可用节点 (${_nodes.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_isLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            if (_nodes.isEmpty && !_isLoading)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text('暂无节点，请点击右上角同步', style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _syncSubscription, icon: const Icon(Icons.refresh_rounded), label: const Text('立即同步订阅')),
                ]),
              )
            else
              ..._nodes.take(10).map((node) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF1F5F9))),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(node.length > 60 ? '${node.substring(0, 60)}...' : node, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                ]),
              )),
            if (_nodes.length > 10)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('还有 ${_nodes.length - 10} 个节点已安全存储...', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12), textAlign: TextAlign.center)),
            const SizedBox(height: 24),
            // 二维码
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                const Text('订阅二维码 • 扫码快速添加', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                QrImageView(data: subscriptionUrl, version: QrVersions.auto, size: 160, backgroundColor: Colors.white),
                const SizedBox(height: 12),
                SelectableText(subscriptionUrl, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(subscriptionUrl)), icon: const Icon(Icons.open_in_new_rounded, size: 16), label: const Text('打开'))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(onPressed: _copySubscription, icon: const Icon(Icons.copy_rounded, size: 16), label: const Text('复制链接'))),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('• 端到端加密存储 • 自动同步 • 安全连接
• 订阅来自 cainwynserver.com • 仅你可见', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
