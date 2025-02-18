import 'package:fan_pix_snap/screens/storage_qr_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class StorageServerSendScreen extends StatefulWidget {
  @override
  _StorageServerSendScreenState createState() => _StorageServerSendScreenState();
}

class _StorageServerSendScreenState extends State<StorageServerSendScreen> {
  static final SupabaseClient supabase = Supabase.instance.client;

  // 初期値は当日
  DateTime _selectedDate = DateTime.now().toLocal();
  // ローディング状態
  bool _isLoading = false;
  // 画像リスト
  List<Map<String, dynamic>> _imageList = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // **ログインチェック**
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("ユーザーがログインしていません。");
        return;
      }

      final selectedDateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate);
      print("選択された日付: $selectedDateFormatted");

      // ユーザーIDを取得
      final userId = user.id;

      final response = await supabase.rpc(
          'get_files_by_date',
          params: {'date': selectedDateFormatted.toString()}
      );

      if (response is List) {
        print("画像取得成功: $response");

        setState(() {
          _imageList = response
              .where((image) => image['user_id'].toString() == userId)
              .map((image) {
            return {
              'user_id': image['user_id'],
              'name': image['file_name'],
              'url': image['url'],
              'createdAt': DateFormat('yyyy/MM/dd HH:mm:ss').format(
                  DateTime.parse(image['created_at'])),
            };
          }).toList();
        });
      } else {
        print("エラー: ${response.error}");
      }
    } catch (e) {
      print("エラー: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 日付変更時にデータベースから再取得
  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadImages(); // 選択日付の画像を再取得
    }
  }

  // 画像を選択して QR コードを生成
  void _generateQRCode(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StorageQRCodeScreen(imageFuture: Future.value(imageUrl)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('画像を選択して送信')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 日付選択ボタン
            ElevatedButton(
              onPressed: () => _selectDate(context),
              child: Text("日付を選択: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}"),
            ),
            SizedBox(height: 10),

            // ローディング中はインジケーターを表示
            _isLoading
                ? Expanded(child: Center(child: CircularProgressIndicator()))
                : Expanded(
              child: _imageList.isEmpty
                  ? Center(child: Text('画像が見つかりません'))
                  : ListView.builder(
                itemCount: _imageList.length,
                itemBuilder: (context, index) {
                  var image = _imageList[index];

                  return ListTile(
                    contentPadding: EdgeInsets.all(8.0),
                    leading: Image.network(
                      image['url'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(image['name']),
                    subtitle: Text("作成日時: ${image['createdAt']}"),
                    onTap: () => _generateQRCode(image['url']),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _loadImages(),
              child: Text("更新"),
            ),
          ],
        ),
      ),
    );
  }
}
