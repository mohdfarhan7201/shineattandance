import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

const String kAppUrl = 'https://attendance.shineinfosolutions.in';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  runApp(const ShineAttendanceApp());
}

class ShineAttendanceApp extends StatelessWidget {
  const ShineAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shine Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4257E6)),
        useMaterial3: true,
      ),
      home: const AttendanceMainScreen(),
    );
  }
}

class AttendanceMainScreen extends StatefulWidget {
  const AttendanceMainScreen({super.key});

  @override
  State<AttendanceMainScreen> createState() => _AttendanceMainScreenState();
}

class _AttendanceMainScreenState extends State<AttendanceMainScreen> {
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  
  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;
  bool _isTracking = false;
  String? _trackingToken;

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _initPullToRefresh();
  }

  Future<void> _initPermissions() async {
    // Request camera and location permissions required for attendance check-in
    await [
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.notification,
    ].request();
  }

  void _initPullToRefresh() {
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: const Color(0xFF4257E6),
      ),
      onRefresh: () async {
        if (_webViewController != null) {
          if (defaultTargetPlatform == TargetPlatform.android) {
            _webViewController?.reload();
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            _webViewController?.loadUrl(
              urlRequest: URLRequest(url: await _webViewController?.getUrl()),
            );
          }
        }
      },
    );
  }

  // Native JavaScript Bridge for Shine Attendance
  void _setupJsBridge(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'startTracking',
      callback: (args) async {
        if (args.isNotEmpty && args[0] is String) {
          _trackingToken = args[0] as String;
          _isTracking = true;
          // Request always location if needed for background
          await Permission.locationAlways.request();
          return true;
        }
        return false;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'stopTracking',
      callback: (args) {
        _isTracking = false;
        _trackingToken = null;
        return true;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'isTracking',
      callback: (args) {
        return _isTracking;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'version',
      callback: (args) {
        return '1.0.0';
      },
    );
  }

  final String _nativeBridgeScript = '''
    window.ShineNative = {
      startTracking: function(token) {
        window.flutter_inappwebview.callHandler('startTracking', token);
      },
      stopTracking: function() {
        window.flutter_inappwebview.callHandler('stopTracking');
      },
      isTracking: function() {
        return window.flutter_inappwebview.callHandler('isTracking');
      },
      version: function() {
        return "1.0.0";
      }
    };
  ''';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_webViewController != null && await _webViewController!.canGoBack()) {
          _webViewController!.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              if (!_hasError)
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(kAppUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    geolocationEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    useShouldOverrideUrlLoading: true,
                    userAgent: 'ShineAttendanceApp/1.0.0 (Flutter; Android & iOS)',
                  ),
                  pullToRefreshController: _pullToRefreshController,
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: _nativeBridgeScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  ]),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    _setupJsBridge(controller);
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    _pullToRefreshController?.endRefreshing();
                    setState(() {
                      _isLoading = false;
                    });
                  },
                  onReceivedError: (controller, request, error) {
                    _pullToRefreshController?.endRefreshing();
                    if (request.isForMainFrame ?? false) {
                      setState(() {
                        _isLoading = false;
                        _hasError = true;
                      });
                    }
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      _pullToRefreshController?.endRefreshing();
                    }
                    setState(() {
                      _progress = progress / 100;
                    });
                  },
                  onGeolocationPermissionsShowPrompt: (controller, origin) async {
                    return GeolocationPermissionShowPromptResponse(
                      origin: origin,
                      allow: true,
                      retain: true,
                    );
                  },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                ),

              // Loading bar
              if (_isLoading && !_hasError)
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4257E6)),
                  minHeight: 3,
                ),

              // Offline / Error screen
              if (_hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 72,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Connection',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF141A2A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please check your internet connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _isLoading = true;
                            });
                            _webViewController?.loadUrl(
                              urlRequest: URLRequest(url: WebUri(kAppUrl)),
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4257E6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
