import 'package:flutter/material.dart';
import 'services/notification_service.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({Key? key}) : super(key: key);

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  final NotificationService _notificationService = NotificationService();
  List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toLocal()}: $message');
    });

  }

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    _addLog('🔔 Starting notification initialization...');
    try {
      await _notificationService.initialize();
      bool permissions = await _notificationService.requestPermissions();
      _addLog('🔔 Notification permissions: $permissions');
    } catch (e) {
      _addLog('❌ Initialization failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Test Notifications Here',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Test buttons
            ElevatedButton.icon(
              onPressed: () async {
                _addLog('🔔 Testing simple notification...');
                try {
                  await _notificationService.showSimpleTestNotification();
                  _addLog('✅ Simple test notification sent!');
                } catch (e) {
                  _addLog('❌ Simple test failed: $e');
                }
              },
              icon: const Icon(Icons.notifications),
              label: const Text('Test Simple Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () async {
                _addLog('🔔 Testing chat notification...');
                try {
                  await _notificationService.showChatMessageNotification(
                    senderName: 'Test Admin',
                    message: 'This is a test chat message from admin! 📱',
                    chatId: 'test_chat',
                    senderAvatar: null,
                  );
                  _addLog('✅ Chat notification sent!');
                } catch (e) {
                  _addLog('❌ Chat test failed: $e');
                }
              },
              icon: const Icon(Icons.chat),
              label: const Text('Test Chat Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () async {
                _addLog('🔔 Testing scheduled notification...');
                try {
                  await _notificationService.scheduleTestNotification();
                  _addLog('✅ Scheduled notification sent!');
                } catch (e) {
                  _addLog('❌ Scheduled test failed: $e');
                }
              },
              icon: const Icon(Icons.schedule),
              label: const Text('Test Scheduled Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Debug Logs:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  _logs.clear();
                });
              },
              child: const Text('Clear Logs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
