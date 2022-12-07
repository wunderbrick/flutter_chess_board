import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ChessBoardController controller = ChessBoardController();
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Chess Demo'),
          ),
          body: Column(children: [
            Expanded(child: Center(child: HomePage(controller: controller))),
            Expanded(child: OtherGameElements(controller: controller))
          ]),
        ));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.controller}) : super(key: key);

  final ChessBoardController controller;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ChessBoard(
        controller: widget.controller,
        boardColor: BoardColor.brown,
        boardOrientation: PlayerColor.white,
      ),
    );
  }
}

class OtherGameElements extends StatelessWidget {
  const OtherGameElements({Key? key, required this.controller})
      : super(key: key);

  final ChessBoardController controller;

  @override
  build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
            onPressed: () => controller.toggleMoveEnabled(),
            child: const Text('Toggle move')),
        Expanded(
          child: ValueListenableBuilder<Chess>(
            valueListenable: controller,
            builder: (context, game, _) {
              return Text(
                controller.getSan().fold(
                      '',
                      (previousValue, element) =>
                          previousValue + '\n' + (element ?? ''),
                    ),
              );
            },
          ),
        ),
      ],
    );
  }
}
