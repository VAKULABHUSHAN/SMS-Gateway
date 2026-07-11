import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/sms_service.dart';
import '../services/server_service.dart';
import '../models/config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _serverRunning = false;
  String _ipAddress = "Not Started";
  int _requests = 0;

  final ServerService _serverService = ServerService();
  final SmsService _smsService = SmsService();
  final NetworkInfo _networkInfo = NetworkInfo();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController =
  TextEditingController(text: "Hello from RelaySMS 🚀");

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _updateIpAddress() async {
    String? wifiIp = await _networkInfo.getWifiIP();
    setState(() {
      _ipAddress = wifiIp ?? "Unknown (Check Wi-Fi)";
    });
  }

  void _handleRequestReceived(int count) {
    setState(() {
      _requests += count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.sms_rounded,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 15),
            const Text(
              AppConfig.appName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            _buildStatusCard(),
            const SizedBox(height: 30),
            _buildTestSmsSection(),
            const SizedBox(height: 30),
            _buildServerControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _statusRow("Server Status", _serverRunning ? "Running" : "Stopped",
                color: _serverRunning ? Colors.green : Colors.red),
            const Divider(),
            _statusRow("IP Address", _ipAddress),
            const Divider(),
            _statusRow("Port", "${AppConfig.defaultPort}"),
            const Divider(),
            _statusRow("Requests Processed", "$_requests"),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSmsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Send Test SMS",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: "Recipient Phone Number",
            hintText: "+1234567890",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _messageController,
          decoration: const InputDecoration(
            labelText: "Message",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.message),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sendTestSms,
            icon: const Icon(Icons.send),
            label: const Text("Send SMS"),
          ),
        ),
      ],
    );
  }

  Widget _buildServerControls() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _serverRunning ? null : _startServer,
            icon: const Icon(Icons.play_arrow),
            label: const Text("Start Server"),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _serverRunning ? _stopServer : null,
            icon: const Icon(Icons.stop),
            label: const Text("Stop Server"),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ),
      ],
    );
  }

  Future<void> _startServer() async {
    try {
      await _serverService.start(onRequestReceived: _handleRequestReceived);
      await _updateIpAddress();
      setState(() {
        _serverRunning = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error starting server: $e")),
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
  }

  Future<void> _sendTestSms() async {
    final number = _phoneController.text.trim();
    final message = _messageController.text.trim();

    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a phone number")),
      );
      return;
    }

    final result = await _smsService.sendSms(
      number: number,
      message: message,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );
  }

  Widget _statusRow(String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
