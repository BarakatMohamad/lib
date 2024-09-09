import 'package:dart_sip_ua_example/src/dialpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter/foundation.dart';

class RegisterWidget extends StatefulWidget {
  final SIPUAHelper? _helper;

  RegisterWidget(this._helper, {Key? key}) : super(key: key);

  @override
  State<RegisterWidget> createState() => _MyRegisterWidget();
}

class _MyRegisterWidget extends State<RegisterWidget>
    implements SipUaHelperListener {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _wsUriController = TextEditingController();
  final TextEditingController _sipUriController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _authorizationUserController =
      TextEditingController();
  final Map<String, String> _wsExtraHeaders = {
    // 'Origin': 'sip://302@sip.wasel.sa',
    // 'Host': 'sip://sip@sip.wasel.sa',
  };
  late SharedPreferences _preferences;
  late RegistrationState _registerState;

  TransportType _selectedTransport = TransportType.TCP;

  SIPUAHelper? get helper => widget._helper;
  @override
  void onNewReinvite(dynamic event) {
    // Handle the ReInvite event
    print("Received a re-INVITE event");
  }
  @override
  void initState() {
    super.initState();
    _registerState = helper!.registerState;
    helper!.addSipUaHelperListener(this);
    _loadSettings();
    if (kIsWeb) {
      _selectedTransport = TransportType.WS;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _wsUriController.dispose();
    _sipUriController.dispose();
    _displayNameController.dispose();
    _authorizationUserController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    super.deactivate();
    helper!.removeSipUaHelperListener(this);
    _saveSettings();
  }

  void _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _portController.text = '5060';
      // _wsUriController.text =
      //     _preferences.getString('ws_uri') ?? 'wss://tryit.jssip.net:10443';
      _sipUriController.text =
          _preferences.getString('sip_uri') ?? 'hello_flutter@tryit.jssip.net';
      _displayNameController.text =
          _preferences.getString('display_name') ?? 'Flutter SIP UA';
      _passwordController.text = _preferences.getString('password') ?? '';
      _authorizationUserController.text =
          _preferences.getString('auth_user') ?? '';
    });
  }

  void _saveSettings() {
    _preferences.setString('port', _portController.text);
    _preferences.setString('ws_uri', _wsUriController.text);
    _preferences.setString('sip_uri', _sipUriController.text);
    _preferences.setString('display_name', _displayNameController.text);
    _preferences.setString('password', _passwordController.text);
    _preferences.setString('auth_user', _authorizationUserController.text);
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    setState(() {
      _registerState = state;
    });
  }

  void _alert(BuildContext context, String alertFieldName) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$alertFieldName is empty'),
          content: Text('Please enter $alertFieldName!'),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleSave(BuildContext context) {
    if (_wsUriController.text == '') {
      _alert(context, "WebSocket URL");
    } else if (_sipUriController.text == '') {
      _alert(context, "SIP URI");
    }

    UaSettings settings = UaSettings();
    // settings. = ['G.711', 'G.729']; // Example codecs

    settings.tcpSocketSettings.allowBadCertificate = true;
    settings.port = _portController.text;
    settings.webSocketSettings.extraHeaders = _wsExtraHeaders;
    settings.webSocketSettings.allowBadCertificate = true;
    //settings.webSocketSettings.userAgent = 'Dart/2.8 (dart:io) for OpenSIPS.';
    settings.transportType = _selectedTransport;
    settings.uri = _sipUriController.text;
    settings.webSocketUrl = _wsUriController.text;
    settings.host = _sipUriController.text.split('@')[1];
    settings.authorizationUser = _authorizationUserController.text;
    settings.password = _passwordController.text;
    settings.displayName = _displayNameController.text;
    settings.userAgent = 'Dart SIP Client v1.0.0';
    settings.dtmfMode = DtmfMode.RFC2833;
    settings.contact_uri = 'sip:${_sipUriController.text}';
    settings.iceServers = [
      {"url": "stun:stun.l.google.com:19302"},
      {'url': 'stun:sip.wasel.sa:5060', 'username': '302', 'credential': 'test302'}

    ];


    helper!.start(settings);
  }
  Future<Widget?> _handleCall(BuildContext context,
      [bool voiceOnly = false]) async {
    final dest = "0580224645";
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await Permission.microphone.request();
      await Permission.camera.request();
    }
    if (dest == null || dest.isEmpty) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Target is empty.'),
            content: Text('Please enter a SIP URI or username!'),
            actions: <Widget>[
              TextButton(
                child: Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return null;
    }

    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': {
        'width': '1280',
        'height': '720',
        'facingMode': 'user',
      }
    };

    MediaStream mediaStream;

    if (kIsWeb && !voiceOnly) {
      mediaStream =
      await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      mediaConstraints['video'] = false;
      MediaStream userStream =
      await navigator.mediaDevices.getUserMedia(mediaConstraints);
      final audioTracks = userStream.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        mediaStream.addTrack(audioTracks.first, addToNative: true);
      }
    } else {
      if (voiceOnly) {
        mediaConstraints['video'] = !voiceOnly;
      }
      mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    }
    helper!.call(dest, mediaStream: mediaStream);
    _preferences.setString('dest', dest);
    return null;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("SIP Account"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        children: <Widget>[
          Center(
            child: Text(
              'Register Status: ${EnumHelper.getName(_registerState.state)}',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ),
          SizedBox(height: 20),
          if (_selectedTransport == TransportType.WS) ...[
            Text('WebSocket:'),
            TextFormField(
              controller: _wsUriController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              textAlign: TextAlign.center,
            ),
          ],
          if (_selectedTransport == TransportType.TCP) ...[
            Text('Port:'),
            TextFormField(
              controller: _portController,
              keyboardType: TextInputType.text,
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: 20),
          Text('SIP URI:'),
          TextFormField(
            controller: _sipUriController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          Text('Authorization User:'),
          TextFormField(
            controller: _authorizationUserController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText:
                  _authorizationUserController.text.isEmpty ? '[Empty]' : null,
            ),
          ),
          SizedBox(height: 20),
          Text('Password:'),
          TextFormField(
            controller: _passwordController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: _passwordController.text.isEmpty ? '[Empty]' : null,
            ),
          ),
          SizedBox(height: 20),
          Text('Display Name:'),
          TextFormField(
            controller: _displayNameController,
            keyboardType: TextInputType.text,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: _displayNameController.text.isEmpty ? '[Empty]' : null,
            ),
          ),
          const SizedBox(height: 20),
          if (!kIsWeb) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RadioMenuButton<TransportType>(
                    value: TransportType.TCP,
                    groupValue: _selectedTransport,
                    onChanged: ((value) => setState(() {
                          _selectedTransport = value!;
                        })),
                    child: Text("TCP")),
                RadioMenuButton<TransportType>(
                    value: TransportType.WS,
                    groupValue: _selectedTransport,
                    onChanged: ((value) => setState(() {
                          _selectedTransport = value!;
                        })),
                    child: Text("WS")),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            child: Text('Register'),
            onPressed: () => _handleSave(context),
          ),

        ],
      ),
    );
  }

  @override
  void callStateChanged(Call call, CallState state) {
    //NO OP
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // NO OP
  }

  @override
  void onNewNotify(Notify ntf) {
    // NO OP
  }
}
