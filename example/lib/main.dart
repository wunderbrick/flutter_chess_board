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
            Expanded(
                child: Center(child: ChessBoardView(controller: controller))),
            Expanded(child: OtherGameElements(controller: controller))
          ]),
        ));
  }
}

class ChessBoardView extends StatefulWidget {
  const ChessBoardView({Key? key, required this.controller}) : super(key: key);

  final ChessBoardController controller;

  @override
  _ChessBoardViewState createState() => _ChessBoardViewState();
}

class _ChessBoardViewState extends State<ChessBoardView> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ChessBoard(
        controller: widget.controller,
        boardColor: BoardColor.darkBrown,
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
