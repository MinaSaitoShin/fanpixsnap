import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

class NearbyTransferPage extends StatefulWidget {
  final bool isHost;
  final String? filePath; // 画像ファイルのパス（クライアントモード時に使用）

  NearbyTransferPage({required this.isHost, this.filePath});

  @override
  _NearbyTransferPageState createState() => _NearbyTransferPageState();
}

class _NearbyTransferPageState extends State<NearbyTransferPage> {
  late RTCPeerConnection peerConnection;
  RTCDataChannel? dataChannel;
  String? receivedFilePath;
  bool isWaiting = false;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    final config = {'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]};
    peerConnection = await createPeerConnection(config);

    if (widget.isHost) {
      peerConnection.onDataChannel = (channel) {
        dataChannel = channel;
        dataChannel?.onMessage = _onDataReceived;
      };
      setState(() {
        isWaiting = true; // ホストは接続待機状態
      });
    } else {
      dataChannel = await peerConnection.createDataChannel(
        'fileTransfer',
        RTCDataChannelInit(),
      );
      dataChannel?.onMessage = _onDataReceived;
      _sendFile();
    }
  }

  void _onDataReceived(RTCDataChannelMessage message) async {
    if (message.isBinary) {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/received_image.jpg');
      await file.writeAsBytes(message.binary);
      setState(() {
        receivedFilePath = file.path;
        isWaiting = false;
      });
    }
  }

  Future<void> _sendFile() async {
    if (widget.filePath != null && dataChannel != null) {
      final file = File(widget.filePath!);
      if (await file.exists()) {
        final fileBytes = await file.readAsBytes();
        dataChannel!.send(RTCDataChannelMessage.fromBinary(fileBytes));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isHost ? '画像受信待機中' : '画像送信中')),
      body: Center(
        child: widget.isHost
            ? isWaiting
            ? Text('接続を待機中...')
            : receivedFilePath != null
            ? Column(
          children: [
            Text('画像を受信しました'),
            Image.file(File(receivedFilePath!)),
          ],
        )
            : Text('接続エラー')
            : Text('画像を送信中...'),
      ),
    );
  }

  @override
  void dispose() {
    peerConnection.close();
    super.dispose();
  }
}
