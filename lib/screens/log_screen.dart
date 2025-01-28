import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/local_server_manager.dart';

class LogScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ログ画面")),
      body: Consumer<LocalServerManager>(
        builder: (context, serverManager, child) {
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: serverManager.logs.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(serverManager.logs[index]),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => serverManager.startServer(),
                      child: Text("サーバー起動"),
                    ),
                    ElevatedButton(
                      onPressed: () => serverManager.stopServer(),
                      child: Text("サーバー停止"),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
