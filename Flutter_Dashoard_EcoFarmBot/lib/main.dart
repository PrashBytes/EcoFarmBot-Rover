import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SmartAgriRoverApp());
}

class SmartAgriRoverApp extends StatelessWidget {
  const SmartAgriRoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Agri-Rover',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.green[800],
        colorScheme: ColorScheme.dark(
          primary: Colors.green[800]!,
          secondary: Colors.greenAccent[400]!,
          surface: const Color(0xFF1E1E1E),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.green.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
      ),
      home: const RoverDashboard(),
    );
  }
}

class RoverDashboard extends StatefulWidget {
  const RoverDashboard({super.key});

  @override
  State<RoverDashboard> createState() => _RoverDashboardState();
}

class _RoverDashboardState extends State<RoverDashboard> {
  // 1. Network Configuration
  String roverUrl = "http://192.168.4.1";

  // 2. State Variables
  double? temperature;
  double? humidity;
  double? soilMoisture;
  double? obstacleDistance;

  // Diagnostics and UI State
  Timer? _telemetryTimer;
  bool _isConnected = false;
  String _lastActionStatus = "Rover Initialized";
  DateTime? _lastTelemetryTime;
  String _activeCommand = "IDLE";
  bool _isSweeping = false;

  @override
  void initState() {
    super.initState();
    _startTelemetryTimer();
    // Trigger initial fetch
    _fetchRoverData();
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  // 2. State & Data Fetching (Every 3 seconds)
  void _startTelemetryTimer() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchRoverData();
    });
  }

  Future<void> _fetchRoverData() async {
    try {
      final response = await http
          .get(Uri.parse('$roverUrl/data'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            // Parse JSON: {"temp": 24.5, "humidity": 60, "soil": 45, "distance": 15}
            temperature = (data['temp'] as num?)?.toDouble();
            humidity = (data['humidity'] as num?)?.toDouble();
            soilMoisture = (data['soil'] as num?)?.toDouble();
            obstacleDistance = (data['distance'] as num?)?.toDouble();
            _isConnected = true;
            _lastTelemetryTime = DateTime.now();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
        }
      }
    } catch (e) {
      // Handle HTTP exceptions without crashing
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  // Generic HTTP GET Sender with exception handling
  Future<void> _sendRoverCommand(String endpoint, {String? actionLabel}) async {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final targetUrl = '$roverUrl$cleanEndpoint';

    try {
      final response = await http
          .get(Uri.parse(targetUrl))
          .timeout(const Duration(milliseconds: 1500));

      if (mounted) {
        setState(() {
          _lastActionStatus = actionLabel ?? 'Sent: $cleanEndpoint (${response.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastActionStatus = 'Error ($cleanEndpoint): Offline';
        });
      }
    }
  }

  // D-Pad Drive Command Handlers
  void _onDirectionPress(String directionCode, String label) {
    setState(() {
      _activeCommand = label;
      _lastActionStatus = 'Driving: $label ($directionCode)';
    });
    _sendRoverCommand(directionCode, actionLabel: 'Moving $label');
  }

  void _onDirectionRelease() {
    setState(() {
      _activeCommand = "STOP";
      _lastActionStatus = 'Motors Stopped (/S)';
    });
    _sendRoverCommand('/S', actionLabel: 'Stopped (/S)');
  }

  void _deploySoilSensor() {
    _sendRoverCommand('/deploy_soil', actionLabel: 'Soil Sensor Deploying...');
    _showFeedbackSnackBar("Deploying Soil Sensor Probe...");
  }

  Future<void> toggleCameraSweep() async {
    try {
      final response = await http
          .get(Uri.parse('$roverUrl/toggle_cam'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _isSweeping = !_isSweeping;
            _lastActionStatus = _isSweeping
                ? 'Camera Sweep: ACTIVE'
                : 'Camera Sweep: STOPPED';
          });
          _showFeedbackSnackBar(
            _isSweeping ? "Camera sweep started" : "Camera sweep stopped",
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _lastActionStatus = 'Camera Sweep Error: HTTP ${response.statusCode}';
          });
          _showFeedbackSnackBar("Camera sweep failed (${response.statusCode})");
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _lastActionStatus = 'Camera Sweep: Request Timeout';
        });
        _showFeedbackSnackBar("Camera sweep request timed out");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastActionStatus = 'Camera Sweep Error: Offline';
        });
        _showFeedbackSnackBar("Camera sweep failed: Rover offline");
      }
    }
  }

  void _showFeedbackSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1E281E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Configuration Dialog for Rover IP
  void _showConfigDialog() {
    final roverController = TextEditingController(text: roverUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Row(
            children: [
              Icon(Icons.settings_ethernet, color: Colors.greenAccent),
              SizedBox(width: 8),
              Text('Network Config', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: roverController,
                  decoration: const InputDecoration(
                    labelText: 'ESP32 Rover URL',
                    prefixIcon: Icon(Icons.memory, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  roverUrl = roverController.text.trim();
                });
                Navigator.pop(context);
                _fetchRoverData();
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.green[800],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy, color: Colors.greenAccent),
            const SizedBox(width: 10),
            const Text('SMART AGRI-ROVER'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure Network URLs',
            onPressed: _showConfigDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Header Banner
                _buildStatusHeader(),
                const SizedBox(height: 18),

                // SECTION 1: Sensor Grid (2x2)
                _buildSectionHeader(Icons.sensors, "TELEMETRY & SENSORS"),
                const SizedBox(height: 10),
                _buildSensorGrid(),
                const SizedBox(height: 22),

                // SECTION 2: Actuators & Hardware Controls
                _buildSectionHeader(Icons.precision_manufacturing, "ACTUATORS & HARDWARE"),
                const SizedBox(height: 10),
                _buildActuatorButtons(),
                const SizedBox(height: 22),

                // SECTION 3: Rover Drive Controls (D-Pad)
                _buildSectionHeader(Icons.gamepad, "ROVER DRIVE CONTROLS"),
                const SizedBox(height: 10),
                _buildDPadSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SECTION WIDGETS ---

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A221A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isConnected ? Colors.green.withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? Colors.greenAccent : Colors.redAccent,
              boxShadow: [
                BoxShadow(
                  color: (_isConnected ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isConnected ? "ONLINE" : "OFFLINE",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _isConnected ? Colors.greenAccent : Colors.redAccent,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _lastActionStatus,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[300],
              ),
            ),
          ),
          if (_lastTelemetryTime != null)
            Text(
              "${_lastTelemetryTime!.hour.toString().padLeft(2, '0')}:${_lastTelemetryTime!.minute.toString().padLeft(2, '0')}:${_lastTelemetryTime!.second.toString().padLeft(2, '0')}",
              style: TextStyle(
                fontSize: 11,
                color: Colors.green[300],
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.greenAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // Section 2: Sensor Grid (2x2)
  Widget _buildSensorGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        _buildSensorCard(
          title: "Temperature",
          value: temperature != null ? "${temperature!.toStringAsFixed(1)}°C" : "-- °C",
          rawNumeric: temperature,
          icon: Icons.thermostat,
          accentColor: Colors.orangeAccent,
        ),
        _buildSensorCard(
          title: "Humidity",
          value: humidity != null ? "${humidity!.toStringAsFixed(0)}%" : "-- %",
          rawNumeric: humidity,
          icon: Icons.water_drop,
          accentColor: Colors.lightBlueAccent,
        ),
        _buildSensorCard(
          title: "Soil Moisture",
          value: soilMoisture != null ? "${soilMoisture!.toStringAsFixed(0)}%" : "-- %",
          rawNumeric: soilMoisture,
          icon: Icons.grass,
          accentColor: Colors.greenAccent,
        ),
        _buildSensorCard(
          title: "Obstacle Dist",
          value: obstacleDistance != null ? "${obstacleDistance!.toStringAsFixed(0)} cm" : "-- cm",
          rawNumeric: obstacleDistance,
          icon: Icons.radar,
          accentColor: (obstacleDistance != null && obstacleDistance! < 20)
              ? Colors.redAccent
              : Colors.amberAccent,
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required double? rawNumeric,
    required IconData icon,
    required Color accentColor,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rawNumeric != null ? Colors.greenAccent : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  rawNumeric != null ? "Active feed" : "No signal",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Section 2: Actuators (Soil Sensor & Camera Sweep)
  Widget _buildActuatorButtons() {
    return Row(
      children: [
        Expanded(child: _buildDeploySoilButton()),
        const SizedBox(width: 12),
        Expanded(child: _buildCameraSweepButton()),
      ],
    );
  }

  Widget _buildDeploySoilButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        elevation: 6,
        shadowColor: Colors.greenAccent.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.greenAccent, width: 1.5),
        ),
      ),
      onPressed: _deploySoilSensor,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_downward, size: 24, color: Colors.greenAccent),
          SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "DEPLOY SOIL",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSweepButton() {
    final Color bgColor = _isSweeping ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20);
    final Color accentColor = _isSweeping ? Colors.redAccent : Colors.greenAccent;
    final IconData icon = _isSweeping ? Icons.stop_circle_outlined : Icons.sync;
    final String label = _isSweeping ? "STOP SWEEP" : "SWEEP CAMERA";

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        elevation: 6,
        shadowColor: accentColor.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
      onPressed: toggleCameraSweep,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: accentColor),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section 4: Rover Drive Controls (D-Pad)
  Widget _buildDPadSection() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          children: [
            // Drive telemetry active indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _activeCommand != "STOP" && _activeCommand != "IDLE"
                      ? Colors.greenAccent
                      : Colors.white24,
                ),
              ),
              child: Text(
                "STATE: $_activeCommand",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: _activeCommand != "STOP" && _activeCommand != "IDLE"
                      ? Colors.greenAccent
                      : Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Cross-shaped 5-button layout
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Up Button (/F)
                    Positioned(
                      top: 10,
                      child: _buildDPadButton(
                        icon: Icons.arrow_upward,
                        label: "FORWARD",
                        endpoint: "/F",
                        color: Colors.green[700]!,
                      ),
                    ),
                    // Left Button (/L)
                    Positioned(
                      left: 10,
                      child: _buildDPadButton(
                        icon: Icons.arrow_back,
                        label: "LEFT",
                        endpoint: "/L",
                        color: Colors.green[700]!,
                      ),
                    ),
                    // Stop Button in the middle (/S)
                    Positioned(
                      child: _buildStopButton(),
                    ),
                    // Right Button (/R)
                    Positioned(
                      right: 10,
                      child: _buildDPadButton(
                        icon: Icons.arrow_forward,
                        label: "RIGHT",
                        endpoint: "/R",
                        color: Colors.green[700]!,
                      ),
                    ),
                    // Down Button (/B)
                    Positioned(
                      bottom: 10,
                      child: _buildDPadButton(
                        icon: Icons.arrow_downward,
                        label: "BACKWARD",
                        endpoint: "/B",
                        color: Colors.green[700]!,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Press & hold to drive • Release to instantly stop",
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // D-Pad Directional Button with GestureDetector
  // CRITICAL LOGIC: onTapDown sends movement endpoint (/F, /B, /L, /R). onTapUp & onTapCancel sends /S
  Widget _buildDPadButton({
    required IconData icon,
    required String label,
    required String endpoint,
    required Color color,
  }) {
    final bool isPressed = _activeCommand == label;

    return GestureDetector(
      onTapDown: (_) => _onDirectionPress(endpoint, label),
      onTapUp: (_) => _onDirectionRelease(),
      onTapCancel: () => _onDirectionRelease(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPressed ? Colors.greenAccent : const Color(0xFF223022),
          border: Border.all(
            color: isPressed ? Colors.white : Colors.green.shade600,
            width: isPressed ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isPressed
                  ? Colors.greenAccent.withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.5),
              blurRadius: isPressed ? 14 : 6,
              spreadRadius: isPressed ? 2 : 1,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 32,
          color: isPressed ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  // Stop Button (Middle)
  Widget _buildStopButton() {
    final bool isPressed = _activeCommand == "STOP";

    return GestureDetector(
      onTap: _onDirectionRelease,
      onTapDown: (_) {
        setState(() {
          _activeCommand = "STOP";
        });
        _sendRoverCommand('/S', actionLabel: 'EMERGENCY STOP');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPressed ? Colors.redAccent : const Color(0xFF381A1A),
          border: Border.all(
            color: isPressed ? Colors.white : Colors.redAccent.withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPressed ? Colors.redAccent : Colors.red).withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stop, color: Colors.white, size: 28),
              Text(
                "STOP",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
