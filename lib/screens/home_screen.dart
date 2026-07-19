import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/sms_service.dart';
import '../services/server_service.dart';
import '../models/config.dart';

enum LogType { info, request, error }

class LogEntry {
  final DateTime timestamp;
  final String method;
  final String path;
  final String clientIp;
  final String details;
  final bool success;
  final LogType type;

  LogEntry({
    required this.timestamp,
    required this.method,
    required this.path,
    required this.clientIp,
    required this.details,
    required this.success,
    required this.type,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _serverRunning = false;
  String _ipAddress = "Stopped";
  int _requests = 0;

  final ServerService _serverService = ServerService();
  final SmsService _smsService = SmsService();
  final NetworkInfo _networkInfo = NetworkInfo();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController =
      TextEditingController(text: AppConfig.defaultMessage);

  final List<LogEntry> _logs = [];

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _updateIpAddress() async {
    String? wifiIp = await _networkInfo.getWifiIP();
    setState(() {
      _ipAddress = wifiIp ?? "192.160.29.123";
    });
  }

  void _addLog(String method, String path, String clientIp, String details, bool success, LogType type) {
    setState(() {
      _logs.insert(
        0,
        LogEntry(
          timestamp: DateTime.now(),
          method: method,
          path: path,
          clientIp: clientIp,
          details: details,
          success: success,
          type: type,
        ),
      );
    });
  }

  Future<void> _startServer() async {
    try {
      await _updateIpAddress();
      await _serverService.start(
        onRequestReceived: (method, path, clientIp, details, success) {
          _addLog(method, path, clientIp, details, success, success ? LogType.request : LogType.error);
          setState(() {
            _requests++;
          });
        },
      );
      setState(() {
        _serverRunning = true;
      });
      _addLog(
        "SYS",
        "",
        "localhost",
        "Gateway active, listening on port ${AppConfig.defaultPort}",
        true,
        LogType.info,
      );
    } catch (e) {
      _addLog(
        "SYS",
        "",
        "localhost",
        "Failed to start gateway server: $e",
        false,
        LogType.error,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error starting server: $e"),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  Future<void> _stopServer() async {
    await _serverService.stop();
    setState(() {
      _serverRunning = false;
      _ipAddress = "Stopped";
    });
    _addLog(
      "SYS",
      "",
      "localhost",
      "Gateway server stopped",
      true,
      LogType.info,
    );
  }

  Future<void> _sendTestSms() async {
    final number = _phoneController.text.trim();
    final message = _messageController.text.trim();

    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a phone number"),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    _addLog(
      "TEST",
      "/send",
      "Local UI",
      "Initiating mock SMS transmission to $number...",
      true,
      LogType.info,
    );

    final result = await _smsService.sendSms(
      number: number,
      message: message,
    );

    final isError = result.contains("Platform Error") || result.contains("Unexpected Error");

    _addLog(
      "TEST",
      "/send",
      "Local UI",
      result,
      !isError,
      isError ? LogType.error : LogType.request,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result),
        backgroundColor: isError ? Colors.red.shade900 : const Color(0xFF10B981),
      ),
    );
  }

  void _copyToClipboard(String text, String successMessage) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(successMessage),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getGatewayUrl() {
    final ip = _serverRunning
        ? (_ipAddress == "Stopped" ? "192.160.29.123" : _ipAddress)
        : "192.160.29.123";
    return "http://$ip:${AppConfig.defaultPort}/send";
  }

  String _getCurlSnippet() {
    final url = _getGatewayUrl();
    return 'curl -X POST $url \\\n'
        '  -H "Content-Type: application/json" \\\n'
        '  -d \'{"number": "+1234567890", "message": "Hello from API!"}\'';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(
                Icons.alt_route_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              AppConfig.appName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusHeaderCard(),
            const SizedBox(height: 16),
            _buildMetricsGrid(),
            const SizedBox(height: 16),
            _buildCurlConsole(),
            const SizedBox(height: 16),
            _buildTestClient(),
            const SizedBox(height: 16),
            _buildActivityConsole(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeaderCard() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _serverRunning
                ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
                : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "GATEWAY STATUS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          PulsingIndicator(isActive: _serverRunning),
                          const SizedBox(width: 8),
                          Text(
                            _serverRunning ? "ONLINE" : "OFFLINE",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _serverRunning ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: _serverRunning
                          ? const Color(0xFF10B981).withOpacity(0.1)
                          : const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      _serverRunning ? "API Ready" : "Standby",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _serverRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _serverRunning ? _stopServer : _startServer,
                    icon: Icon(_serverRunning ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded),
                    label: Text(_serverRunning ? "SHUTDOWN GATEWAY" : "INITIALIZE GATEWAY"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _serverRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: "GATEWAY IP",
            value: _serverRunning ? _ipAddress : "Offline",
            subtitle: _serverRunning ? "Port ${AppConfig.defaultPort}" : "Click copy to capture",
            icon: Icons.lan_outlined,
            iconColor: const Color(0xFF3B82F6),
            action: _serverRunning
                ? IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () => _copyToClipboard(_getGatewayUrl(), "Copied Gateway URL to Clipboard"),
                    tooltip: "Copy Endpoint",
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: "TOTAL CALLS",
            value: "$_requests",
            subtitle: "Processed requests",
            icon: Icons.sync_alt_rounded,
            iconColor: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Widget? action,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 20),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurlConsole() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text(
          "Developer API Snippet (cURL)",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.code, color: Color(0xFF10B981)),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Text(
              _getCurlSnippet(),
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                color: Color(0xFF38BDF8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _copyToClipboard(_getCurlSnippet(), "Copied cURL command to Clipboard"),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text("Copy Command", style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestClient() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.send_to_mobile_rounded, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 8),
                Text(
                  "SMS Testing Console",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "Recipient Number",
                hintText: "+1234567890",
                prefixIcon: Icon(Icons.phone, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: "Message Payload",
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _sendTestSms,
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text("DISPATCH MOCK SMS"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityConsole() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal_rounded, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Live System Activity",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (_logs.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _logs.clear()),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        "CLEAR",
                        style: TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monitor_heart, color: Color(0xFF475569), size: 36),
                          SizedBox(height: 8),
                          Text(
                            "Waiting for gateway activity...",
                            style: TextStyle(color: Color(0xFF475569), fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _logs.length,
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B), height: 12),
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return _buildLogLine(log);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogLine(LogEntry log) {
    Color typeColor;
    IconData icon;

    switch (log.type) {
      case LogType.info:
        typeColor = const Color(0xFF3B82F6);
        icon = Icons.info_outline;
        break;
      case LogType.request:
        typeColor = const Color(0xFF10B981);
        icon = Icons.check_circle_outline;
        break;
      case LogType.error:
        typeColor = const Color(0xFFEF4444);
        icon = Icons.error_outline;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: typeColor, size: 14),
        const SizedBox(width: 8),
        Text(
          "[${_formatTime(log.timestamp)}]",
          style: const TextStyle(
            fontFamily: 'Courier',
            fontSize: 10,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 6),
        if (log.method.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.method,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            log.details,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 10.5,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ),
      ],
    );
  }
}

class PulsingIndicator extends StatefulWidget {
  final bool isActive;
  const PulsingIndicator({super.key, required this.isActive});

  @override
  State<PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<PulsingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 3.0, end: 12.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.5),
                blurRadius: _animation.value,
                spreadRadius: _animation.value / 2.5,
              )
            ],
          ),
        );
      },
    );
  }
}

