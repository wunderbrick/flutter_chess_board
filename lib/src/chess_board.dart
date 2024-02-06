import 'dart:math';

import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' hide State;
import 'package:flutter/rendering.dart';
import 'board_arrow.dart';
import 'chess_board_controller.dart';
import 'constants.dart';

class ChessBoard extends StatefulWidget {
  /// An instance of [ChessBoardController] which holds the game and allows
  /// manipulating the board programmatically.
  final ChessBoardController controller;

  /// Size of chessboard
  final double? size;

  /// The color type of the board
  final BoardColor boardColor;

  final PlayerColor boardOrientation;

  final VoidCallback? onMove;

  final List<BoardArrow> arrows;

  const ChessBoard({
    Key? key,
    required this.controller,
    this.size,
    this.boardColor = BoardColor.brown,
    this.boardOrientation = PlayerColor.white,
    this.onMove,
    this.arrows = const [],
  }) : super(key: key);

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  late Image _boardImage;

  int? _selected;

  @override
  void initState() {
    super.initState();
    _boardImage = Image.asset(
      "images/dark_brown_board.png",
      package: 'flutter_chess_board',
      fit: BoxFit.cover,
    );
  }

  @override
  void didChangeDependencies() {
    precacheImage(_boardImage.image, context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Chess>(
      valueListenable: widget.controller,
      builder: (context, game, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8),
                  itemBuilder: (context, index) {
                    var row = index ~/ 8;
                    var column = index % 8;
                    var boardRank = widget.boardOrientation == PlayerColor.black
                        ? '${row + 1}'
                        : '${(7 - row) + 1}';
                    var boardFile = widget.boardOrientation == PlayerColor.white
                        ? '${files[column]}'
                        : '${files[7 - column]}';

                    var squareName = '$boardFile$boardRank';
                    var pieceOnSquare = game.get(squareName);

                    var piece = BoardPiece(
                      squareName: squareName,
                      game: game,
                    );

                    final bool inhabitedByPiece = game.get(squareName) != null;

                    final thePieceMoveData = PieceMoveData(
                      squareName: squareName,
                      pieceType: pieceOnSquare?.type.toUpperCase() ?? 'P',
                      pieceColor: pieceOnSquare?.color ?? Color.WHITE,
                    );

                    var draggable = inhabitedByPiece
                        ? Draggable<PieceMoveData>(
                            maxSimultaneousDrags:
                                (!widget.controller.game.enableUserMoves)
                                    ? 0
                                    : null,
                            child: piece,
                            feedback: piece,
                            childWhenDragging: SizedBox(),
                            data: thePieceMoveData,
                          )
                        : Container();

                    var dragTarget = DragTarget<PieceMoveData>(
                        builder: (context, list, _) {
                          return draggable;
                        },
                        onWillAcceptWithDetails: (pieceMoveData) {
                          return widget.controller.game.enableUserMoves;
                        },
                        onAccept: (pieceMoveData) =>
                            _makeTheMove(squareName, game, pieceMoveData));

                    var lightOrDark;

                    if (row.isEven && column.isEven) {
                      lightOrDark = SquareColor.light;
                    }

                    if (row.isEven && column.isOdd) {
                      lightOrDark = SquareColor.dark;
                    }

                    if (row.isOdd && column.isOdd) {
                      lightOrDark = SquareColor.light;
                    }

                    if (row.isOdd && column.isEven) {
                      lightOrDark = SquareColor.dark;
                    }

                    final BoardSquare boardSquare = BoardSquare(
                        lightOrDark: lightOrDark, child: dragTarget);

                    final List<String> moves = game
                            .generate_moves(
                                {'square': squareName, 'legal': true})
                            .map((m) => m.toAlgebraic)
                            .toList()
                        //.reversed
                        //.toList()
                        ;

                    print(index);
                    print(moves);

                    final Semantics? moveSemanticsTree =
                        _createPossibleMovesSemanticsTree(
                            moves,
                            Semantics(child: boardSquare),
                            game,
                            thePieceMoveData);

                    return (inhabitedByPiece)
                        // Only give semantic nodes to squares inhabited by pieces to prevent the need for endless swiping to get anywhere
                        ? GestureDetector(
                            child: Semantics(
                                label: (_selected == index)
                                    ? '${pieceOnSquare?.type.name} at $squareName selected'
                                    : '${pieceOnSquare?.type.name} at $squareName unselected',
                                child: (_selected == index)
                                    ? moveSemanticsTree
                                    : boardSquare,
                                onTap: () => setState(() {
                                      if (_selected == index) {
                                        _selected = null;

                                        SemanticsService.announce(
                                            '$index unselected',
                                            TextDirection.ltr);
                                      } else {
                                        _selected = index;

                                        SemanticsService.announce(
                                            '$index selected',
                                            TextDirection.ltr);
                                      }
                                    })))
                        : (_selected == index)
                            ? Semantics(
                                label: 'Undo move',
                                child: boardSquare,
                                onTap: () => widget.controller.undoMove())
                            : boardSquare;
                  },
                  itemCount: 64,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                ),
              ),
              if (widget.arrows.isNotEmpty)
                IgnorePointer(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CustomPaint(
                      child: Container(),
                      painter:
                          _ArrowPainter(widget.arrows, widget.boardOrientation),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Semantics? _createPossibleMovesSemanticsTree(
      List<String> moves, Semantics? acc, game, pieceMoveData) {
    _makeMove(String theMove) {
      final moveTrimmed =
          theMove.replaceAll(RegExp(r'\('), '').replaceAll(RegExp(r'\)'), '');

      _makeTheMove(moveTrimmed, game, pieceMoveData);

      SemanticsService.announce('Move made', TextDirection.rtl);
    }

    if (moves.isEmpty) {
      return acc;
    }

    if (moves.length == 1) {
      return _createPossibleMovesSemanticsTree(
          [],
          Semantics(
              label: moves.first,
              onTap: () => _makeMove(moves.first),
              child: acc),
          game,
          pieceMoveData);
    }

    return _createPossibleMovesSemanticsTree(
        moves.getRange(1, moves.length).toList(),
        Semantics(
            label: moves.first,
            onTap: () => _makeMove(moves.first),
            child: acc),
        game,
        pieceMoveData);
  }

  void _makeTheMove(toSquareName, game, PieceMoveData pieceMoveData) async {
    // A way to check if move occurred.
    Color moveColor = game.turn;

    if (pieceMoveData.pieceType == "P" &&
        ((pieceMoveData.squareName[1] == "7" &&
                toSquareName[1] == "8" &&
                pieceMoveData.pieceColor == Color.WHITE) ||
            (pieceMoveData.squareName[1] == "2" &&
                toSquareName[1] == "1" &&
                pieceMoveData.pieceColor == Color.BLACK))) {
      var val = await _promotionDialog(context);

      if (val != null) {
        widget.controller.makeMoveWithPromotion(
          from: pieceMoveData.squareName,
          to: toSquareName,
          pieceToPromoteTo: val,
        );
      } else {
        return;
      }
    } else {
      widget.controller.makeMove(
        from: pieceMoveData.squareName,
        to: toSquareName,
      );
    }
    if (game.turn != moveColor) {
      widget.onMove?.call();
    }
  }

  /// Returns the board image
  Image _getBoardImage(BoardColor color) {
    switch (color) {
      case BoardColor.brown:
        return Image.asset(
          "images/brown_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.darkBrown:
        return Image.asset(
          "images/dark_brown_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.green:
        return Image.asset(
          "images/green_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.orange:
        return Image.asset(
          "images/orange_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
    }
  }

  /// Show dialog when pawn reaches last square
  Future<String?> _promotionDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return new AlertDialog(
          title: new Text('Choose promotion'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              InkWell(
                child: WhiteQueen(),
                onTap: () {
                  Navigator.of(context).pop("q");
                },
              ),
              InkWell(
                child: WhiteRook(),
                onTap: () {
                  Navigator.of(context).pop("r");
                },
              ),
              InkWell(
                child: WhiteBishop(),
                onTap: () {
                  Navigator.of(context).pop("b");
                },
              ),
              InkWell(
                child: WhiteKnight(),
                onTap: () {
                  Navigator.of(context).pop("n");
                },
              ),
            ],
          ),
        );
      },
    ).then((value) {
      return value;
    });
  }
}

enum SquareColor { light, dark }

class BoardSquare extends StatelessWidget {
  const BoardSquare({Key? key, required this.lightOrDark, this.child})
      : super(key: key);

  final SquareColor lightOrDark;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return (lightOrDark == SquareColor.light)
        ? Container(color: Colors.yellow, child: child)
        : Container(color: Colors.brown, child: child);
  }
}

class BoardPiece extends StatelessWidget {
  const BoardPiece({
    Key? key,
    required this.squareName,
    required this.game,
  }) : super(key: key);

  final String squareName;
  final Chess game;

  @override
  Widget build(BuildContext context) {
    late Widget imageToDisplay;
    var square = game.get(squareName);

    if (game.get(squareName) == null) {
      return Container();
    }

    String piece = (square?.color == Color.WHITE ? 'W' : 'B') +
        (square?.type.toUpperCase() ?? 'P');

    switch (piece) {
      case "WP":
        imageToDisplay = WhitePawn();
        break;
      case "WR":
        imageToDisplay = WhiteRook();
        break;
      case "WN":
        imageToDisplay = WhiteKnight();
        break;
      case "WB":
        imageToDisplay = WhiteBishop();
        break;
      case "WQ":
        imageToDisplay = WhiteQueen();
        break;
      case "WK":
        imageToDisplay = WhiteKing();
        break;
      case "BP":
        imageToDisplay = BlackPawn();
        break;
      case "BR":
        imageToDisplay = BlackRook();
        break;
      case "BN":
        imageToDisplay = BlackKnight();
        break;
      case "BB":
        imageToDisplay = BlackBishop();
        break;
      case "BQ":
        imageToDisplay = BlackQueen();
        break;
      case "BK":
        imageToDisplay = BlackKing();
        break;
      default:
        imageToDisplay = WhitePawn();
    }

    return imageToDisplay;
  }
}

class PieceMoveData {
  final String squareName;
  final String pieceType;
  final Color pieceColor;

  PieceMoveData({
    required this.squareName,
    required this.pieceType,
    required this.pieceColor,
  });
}

class _ArrowPainter extends CustomPainter {
  List<BoardArrow> arrows;
  PlayerColor boardOrientation;

  _ArrowPainter(this.arrows, this.boardOrientation);

  @override
  void paint(Canvas canvas, Size size) {
    var blockSize = size.width / 8;
    var halfBlockSize = size.width / 16;

    for (var arrow in arrows) {
      var startFile = files.indexOf(arrow.from[0]);
      var startRank = int.parse(arrow.from[1]) - 1;
      var endFile = files.indexOf(arrow.to[0]);
      var endRank = int.parse(arrow.to[1]) - 1;

      int effectiveRowStart = 0;
      int effectiveColumnStart = 0;
      int effectiveRowEnd = 0;
      int effectiveColumnEnd = 0;

      if (boardOrientation == PlayerColor.black) {
        effectiveColumnStart = 7 - startFile;
        effectiveColumnEnd = 7 - endFile;
        effectiveRowStart = startRank;
        effectiveRowEnd = endRank;
      } else {
        effectiveColumnStart = startFile;
        effectiveColumnEnd = endFile;
        effectiveRowStart = 7 - startRank;
        effectiveRowEnd = 7 - endRank;
      }

      var startOffset = Offset(
          ((effectiveColumnStart + 1) * blockSize) - halfBlockSize,
          ((effectiveRowStart + 1) * blockSize) - halfBlockSize);
      var endOffset = Offset(
          ((effectiveColumnEnd + 1) * blockSize) - halfBlockSize,
          ((effectiveRowEnd + 1) * blockSize) - halfBlockSize);

      var yDist = 0.8 * (endOffset.dy - startOffset.dy);
      var xDist = 0.8 * (endOffset.dx - startOffset.dx);

      var paint = Paint()
        ..strokeWidth = halfBlockSize * 0.8
        ..color = arrow.color;

      canvas.drawLine(startOffset,
          Offset(startOffset.dx + xDist, startOffset.dy + yDist), paint);

      var slope =
          (endOffset.dy - startOffset.dy) / (endOffset.dx - startOffset.dx);

      var newLineSlope = -1 / slope;

      var points = _getNewPoints(
          Offset(startOffset.dx + xDist, startOffset.dy + yDist),
          newLineSlope,
          halfBlockSize);
      var newPoint1 = points[0];
      var newPoint2 = points[1];

      var path = Path();

      path.moveTo(endOffset.dx, endOffset.dy);
      path.lineTo(newPoint1.dx, newPoint1.dy);
      path.lineTo(newPoint2.dx, newPoint2.dy);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  List<Offset> _getNewPoints(Offset start, double slope, double length) {
    if (slope == double.infinity || slope == double.negativeInfinity) {
      return [
        Offset(start.dx, start.dy + length),
        Offset(start.dx, start.dy - length)
      ];
    }

    return [
      Offset(start.dx + (length / sqrt(1 + (slope * slope))),
          start.dy + ((length * slope) / sqrt(1 + (slope * slope)))),
      Offset(start.dx - (length / sqrt(1 + (slope * slope))),
          start.dy - ((length * slope) / sqrt(1 + (slope * slope)))),
    ];
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return arrows != oldDelegate.arrows;
  }
}
