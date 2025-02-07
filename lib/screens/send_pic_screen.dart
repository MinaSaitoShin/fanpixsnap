import 'package:flutter/material.dart';
import 'local_server_send_screen.dart';
import 'err_send_screen.dart';
import 'storage_server_send_screen.dart';

class SendPicScreen extends StatefulWidget {
  @override
  _SendPicScreenState createState() => _SendPicScreenState();
}

class _SendPicScreenState extends State<SendPicScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FanPixSnap')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocalServerSendScreen(),
                  ),
                );
              },
              child: Text(' ローカルサーバーの画像を送る '),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StorageServerSendScreen(),
                  ),
                );
              },
              child: Text('ストレージサーバーの画像を送る'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ErrSendScreen(),
                  ),
                );
              },
              child: Text(' エラー画像を送る '),
            ),
          ],
        ),
      ),
    );
  }
}
