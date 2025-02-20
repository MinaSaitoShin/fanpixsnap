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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ローカルサーバー関連
              SectionHeader(title: 'ローカルサーバー関連'),
              SectionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocalServerSendScreen(),
                    ),
                  );
                },
                label: 'ローカルサーバーの画像を送る',
                icon: Icons.send,
              ),
              SizedBox(height: 20),

              // ストレージサーバー関連
              SectionHeader(title: 'ストレージサーバー関連'),
              SectionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StorageServerSendScreen(),
                    ),
                  );
                },
                label: 'ストレージサーバーの画像を送る',
                icon: Icons.cloud_upload,
              ),
              SizedBox(height: 20),

              // エラー画像関連
              SectionHeader(title: 'エラー画像関連'),
              SectionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ErrSendScreen(),
                    ),
                  );
                },
                label: 'エラー画像を送る',
                icon: Icons.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

// セクションタイトル
  Widget SectionHeader({required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

// セクションボタン（共通スタイル）
  Widget SectionButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
        textStyle: TextStyle(fontSize: 16),
      ),
    );
  }

}
