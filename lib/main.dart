import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MirroringControlApp());
}

class MirroringControlApp extends StatelessWidget {
  const MirroringControlApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirroring Control',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
      routes: {
        '/control': (context) => const MirroringControlPage(),
        '/guide': (context) => const SetupGuidePage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    MirroringControlPage(),
    SetupGuidePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MirrorX'),
        centerTitle: true,
      ),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.screen_share),
            label: 'Control',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'Setup Guide',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class MirroringControlPage extends StatefulWidget {
  const MirroringControlPage({Key? key}) : super(key: key);

  @override
  _MirroringControlPageState createState() => _MirroringControlPageState();
}

class _MirroringControlPageState extends State<MirroringControlPage> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _recordingNameController = TextEditingController();
  String _status = "Not Connected";
  bool _isLoading = false;
  bool _enableWireless = false;
  bool _enableRecording = false;
  int _retryCount = 0;

  Future<void> _connectToWindowsApp() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _updateStatus('IP address cannot be empty');
      return;
    }

    _setLoading(true);
    _retryCount = 0;

    while (_retryCount < 3) {
      final success = await _tryHttpRequest(
        () => http.post(Uri.parse('http://$ip:8080/connect?ip=$ip')),
        'Connected to Windows App',
        'Failed to connect to Windows App',
      );
      if (success) break;
      _retryCount++;
    }

    _setLoading(false);
  }

  Future<void> _startMirroring() async {
    final ip = _ipController.text.trim();
    final recordingName = _enableRecording ? _recordingNameController.text.trim() : null;
    if (ip.isEmpty) {
      _updateStatus('IP address cannot be empty');
      return;
    }

    _setLoading(true);
    _retryCount = 0;

    while (_retryCount < 3) {
      final connectSuccess = await _tryHttpRequest(
        () => http.post(Uri.parse('http://$ip:8080/connect?ip=$ip')),
        'Connected to Windows App',
        'Failed to connect to Windows App',
      );

      if (connectSuccess) {
        final startUri = Uri.parse('http://$ip:8080/start${_enableWireless ? "?wireless=true" : ""}${recordingName != null ? "&recordingName=$recordingName" : ""}');
        final startSuccess = await _tryHttpRequest(
          () => http.post(startUri),
          'Mirroring started',
          'Failed to start mirroring',
        );
        if (startSuccess) break;
      } else {
        break;
      }
      _retryCount++;
    }

    _setLoading(false);
  }

  Future<void> _stopMirroring() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _updateStatus('IP address cannot be empty');
      return;
    }

    _setLoading(true);
    _retryCount = 0;

    while (_retryCount < 3) {
      final success = await _tryHttpRequest(
        () => http.post(Uri.parse('http://$ip:8080/stop')),
        'Mirroring stopped',
        'Failed to stop mirroring',
      );
      if (success) break;
      _retryCount++;
    }

    _setLoading(false);
  }

  Future<bool> _tryHttpRequest(
    Future<http.Response> Function() request,
    String successMessage,
    String errorMessage,
  ) async {
    try {
      final response = await request();
      if (response.statusCode == 200) {
        _updateStatus(successMessage);
        return true;
      } else {
        _updateStatus('$errorMessage (Status Code: ${response.statusCode})');
        return false;
      }
    } catch (e) {
      _updateStatus('$errorMessage: $e');
      return false;
    }
  }

  void _updateStatus(String message) {
    setState(() {
      _status = message;
    });
  }

  void _setLoading(bool value) {
    setState(() {
      _isLoading = value;
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _recordingNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'Windows App IP Address',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _recordingNameController,
            decoration: const InputDecoration(
              labelText: 'Custom Recording Name (Optional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Enable Wireless:'),
              Switch(
                value: _enableWireless,
                onChanged: (value) {
                  setState(() {
                    _enableWireless = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Enable Recording:'),
              Switch(
                value: _enableRecording,
                onChanged: (value) {
                  setState(() {
                    _enableRecording = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _isLoading
              ? const CircularProgressIndicator()
              : Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _connectToWindowsApp,
                      icon: const Icon(Icons.link),
                      label: const Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _startMirroring,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Mirroring'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _stopMirroring,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Mirroring'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 20),
          Text(
            'Status: $_status',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class SetupGuidePage extends StatelessWidget {
  const SetupGuidePage({Key? key}) : super(key: key);

  Widget _buildStep(String stepNumber, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            child: Text(
              stepNumber,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> steps) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...steps,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            'Setting up Your Android Device',
            [
              _buildStep(
                '1',
                'Open Settings on your Android device.',
              ),
              _buildStep(
                '2',
                'Scroll down and tap on "About phone".',
              ),
              _buildStep(
                '3',
                'Tap "Build number" seven times to enable Developer Options.',
              ),
              _buildStep(
                '4',
                'Go back to Settings and tap on "Developer Options".',
              ),
              _buildStep(
                '5',
                'Enable "USB Debugging" within Developer Options.',
              ),
            ],
          ),
          _buildSection(
            'Setting up Your Windows PC',
            [
              _buildStep(
                '1',
                'Ensure that MirrorX Windows Application is installed on your Windows machine.',
              ),
              _buildStep(
                '2',
                'Connect your Android device to the Windows PC using a USB cable.',
              ),
              _buildStep(
                '3',
                'Run the MirrorX Windows application that hosts the Scrcpy server.',
              ),
              _buildStep(
                '4',
                'Note down the IP address of your Windows machine. You can find this by running "ipconfig" in Command Prompt.',
              ),
            ],
          ),
          _buildSection(
            'Using the Mirroring Control App',
            [
              _buildStep(
                '1',
                'Enter the Windows machine\'s IP address in the "Windows App IP Address" field.',
              ),
              _buildStep(
                '2',
                'Toggle "Enable Wireless" to enable or disable wireless mirroring.',
              ),
              _buildStep(
                '3',
                'Toggle "Enable Recording" if you want to record the mirroring session with a custom name.',
              ),
              _buildStep(
                '4',
                'Tap "Connect" to establish a connection with the Windows application.',
              ),
              _buildStep(
                '5',
                'Once connected, tap "Start Mirroring" to begin screen mirroring.',
              ),
              _buildStep(
                '6',
                'To stop mirroring, tap "Stop Mirroring".',
              ),
            ],
          ),
          _buildSection(
            'Troubleshooting',
            [
              _buildStep(
                '1',
                'If unable to connect, ensure both devices are on the same network.',
              ),
              _buildStep(
                '2',
                'Verify that firewall settings are not blocking the connection.',
              ),
              _buildStep(
                '3',
                'Restart both applications and try connecting again.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
