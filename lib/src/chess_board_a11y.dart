import 'dart:math';

import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' hide State;
import 'package:flutter/rendering.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'board_arrow.dart';
import 'chess_board_controller.dart';
import 'constants.dart';

class ChessBoardA11y extends StatefulWidget {
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

  const ChessBoardA11y({
    Key? key,
    required this.controller,
    this.size,
    this.boardColor = BoardColor.brown,
    this.boardOrientation = PlayerColor.white,
    this.onMove,
    this.arrows = const [],
  }) : super(key: key);

  @override
  State<ChessBoardA11y> createState() => _ChessBoardState();
}

List<int> squares = List.generate(64, (index) => index, growable: false);

bool matchColors(PlayerColor playerColor, Color chessColor) {
  if (playerColor == PlayerColor.black && chessColor == Color.BLACK) {
    return true;
  }

  if (playerColor == PlayerColor.white && chessColor == Color.WHITE) {
    return true;
  }

  return false;
}

List<PieceMoveData> getAllPieceMoveData(
    Chess game, PlayerColor boardOrientation, List<int> squareIndices) {
  return flatten(squareIndices.map((i) {
    final PieceMoveData? pmd = getPieceMoveData(game, boardOrientation, i);

    return (pmd != null) ? [pmd] : [];
  }));
}

List<PieceMoveData> getAllPieceMoveDataForColor(
    List<PieceMoveData> allPieceMoveData, PlayerColor boardOrientation) {
  return allPieceMoveData
      .where((p) => matchColors(boardOrientation, p.pieceColor))
      .toList();
}

List<T> flatten<T>(Iterable<Iterable<T>> list) =>
    [for (var sublist in list) ...sublist];

PieceMoveData? getPieceMoveData(
    Chess game, PlayerColor boardOrientation, int index) {
  final int row = index ~/ 8;
  final int column = index % 8;
  final String boardRank =
      boardOrientation == PlayerColor.black ? '${row + 1}' : '${(7 - row) + 1}';
  final String boardFile = boardOrientation == PlayerColor.white
      ? '${files[column]}'
      : '${files[7 - column]}';

  final String squareName = '$boardFile$boardRank';
  final Piece? pieceOnSquare = game.get(squareName);

  final bool inhabitedByPiece = game.get(squareName) != null;

  return inhabitedByPiece
      ? PieceMoveData(
          squareName: squareName,
          pieceType: pieceOnSquare?.type.toUpperCase() ?? 'P',
          pieceColor: pieceOnSquare?.color ?? Color.WHITE,
        )
      : null;
}

List<String> getMovesForAGivenPieceMoveData(
    Chess game, PieceMoveData pieceMoveData) {
  return getMovesForAGivenSquare(game, pieceMoveData.squareName);
}

List<String> getMovesForAGivenSquare(Chess game, String squareName) => game
    .generate_moves({'square': squareName, 'legal': true})
    .map((m) => m.toAlgebraic)
    .toList()
    // Without reversing, the farthest move is read first because we have to build the semantics tree inside out, really
    .reversed
    .toList();

Semantics buildPieceSemanticsTree(List<PieceMoveData> pieceMoveDatas,
    void Function(PieceMoveData) onTap, Semantics acc) {
  if (pieceMoveDatas.isEmpty) {
    return acc;
  }

  if (pieceMoveDatas.length == 1) {
    return buildPieceSemanticsTree(
        [], onTap, buildPieceSemantics(pieceMoveDatas.first, onTap, acc));
  }

  return buildPieceSemanticsTree(
      pieceMoveDatas.getRange(1, pieceMoveDatas.length).toList(),
      onTap,
      buildPieceSemantics(pieceMoveDatas.first, onTap, acc));
}

Semantics buildPieceSemantics(PieceMoveData pieceMoveData,
    void Function(PieceMoveData) onTap, Semantics child) {
  //'${pieceOnSquare?.type.name} at $squareName selected'
  return Semantics(
      explicitChildNodes: true,
      label: '${pieceMoveData.pieceType} at ${pieceMoveData.squareName}',
      onTap: () => onTap(pieceMoveData),
      child: child);
}

class _ChessBoardState extends State<ChessBoardA11y> {
  PieceMoveData? _selectedPiece;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Chess>(
      valueListenable: widget.controller,
      builder: (context, game, _) {
        final List<PieceMoveData> allPDM =
            getAllPieceMoveData(game, widget.boardOrientation, squares);

        final List<PieceMoveData> playerPMD =
            getAllPieceMoveDataForColor(allPDM, widget.boardOrientation);

        final List<PieceMoveData> opponentPMD = getAllPieceMoveDataForColor(
            allPDM,
            (widget.boardOrientation == PlayerColor.black)
                ? PlayerColor.white
                : PlayerColor.black);

        final Semantics playerSemantics =
            // We want the inner Text widget to actually show up on the button but don't read it a second time. We want the first semantics label (the outermost one here to actually read the visual text here first before the rest of the piece tree)
            Semantics(
                label: 'Player Pieces',
                // explicitChildNodes here keeps the first piece name from being read along with "button, double tap to activate"
                explicitChildNodes: true,
                child: Semantics(
                    child: buildPieceSemanticsTree(
                        playerPMD,
                        (pmd) => setState(() {
                              if (
                                  // PlayerMoveData has no equality defined
                                  _selectedPiece?.pieceColor ==
                                          pmd.pieceColor &&
                                      _selectedPiece?.pieceType ==
                                          pmd.pieceType &&
                                      _selectedPiece?.squareName ==
                                          pmd.squareName) {
                                _selectedPiece = null;
                              } else {
                                _selectedPiece = pmd;
                              }
                            }),
                        Semantics(
                            // TODO: child widget with SizedText we can pass in
                            child: Text('Player Pieces'),
                            excludeSemantics: true))));

        final Semantics opponentSemantics =
            // We want the inner Text widget to actually show up on the button but don't read it a second time. We want the first semantics label (the outermost one here to actually read the visual text here first before the rest of the piece tree)
            Semantics(
                label: 'Opponent Pieces',
                // explicitChildNodes here keeps the first piece name from being read along with "button, double tap to activate"
                explicitChildNodes: true,
                child: Semantics(
                    child: buildPieceSemanticsTree(
                        opponentPMD,
                        (pmd) {},
                        Semantics(
                            // TODO: child widget with SizedText we can pass in
                            child: Text('Opponent Pieces'),
                            excludeSemantics: true))));

        return Row(children: [
          Expanded(
              child: ElevatedButton(
            child: playerSemantics,
            onPressed: () {},
          )),
          Expanded(
              child: ElevatedButton(
            child: opponentSemantics,
            onPressed: () {},
          ))
        ]);

        //
        //
        //

        /*
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: GridView.builder(
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
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

                final BoardSquare boardSquare =
                    BoardSquare(lightOrDark: lightOrDark, child: dragTarget);

                final Semantics? moveSemanticsTree =
                    _createPossibleMovesSemanticsTree(moves,
                        Semantics(child: boardSquare), game, thePieceMoveData);

                return (inhabitedByPiece)
                    // Only give semantic nodes to squares inhabited by pieces to prevent the need for endless swiping to get anywhere
                    ? GestureDetector(
                        excludeFromSemantics: true,
                        child: Semantics(
                            label: (_selected == index)
                                ? '${pieceOnSquare?.type.name} at $squareName selected'
                                : '${pieceOnSquare?.type.name} at $squareName unselected',
                            child: (_selected == index)
                                ? moveSemanticsTree
                                : boardSquare,
                            onTap: () => setState(() {
                                  print(index);
                                  if (_selected == index) {
                                    _selected = null;

                                    SemanticsService.announce(
                                        '$index unselected', TextDirection.ltr);
                                  } else {
                                    _selected = index;

                                    SemanticsService.announce(
                                        '$index selected', TextDirection.ltr);
                                  }
                                })))
                    : (_selected == index)
                        // No idea why I need the minus 1 above
                        // Make square piece was moved from undo with semantic focus so we don't lose a11y focus
                        // TODO: still lose it sometimes, not sure why
                        ? Semantics(
                            //key: mykey,
                            label: 'index is $index',
                            child: boardSquare,
                            onTap: () => widget.controller.undoMove())
                        : Semantics(label: 'uninhabited', child: boardSquare);
              },
              itemCount: 64,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
            ),
          ),
        )*/
        ;
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
              //onTap: () => _makeMove(moves.first),
              child: acc),
          game,
          pieceMoveData);
    }

    return _createPossibleMovesSemanticsTree(
        moves.getRange(1, moves.length).toList(),
        Semantics(
            label: moves.first,
            //onTap: () => _makeMove(moves.first),
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

// This is ridiculous, but without it, TalkBack almost always focuses on FloatingActionButton instead of the screen title. Keeping for now.
class A11yFutureWidget extends StatelessWidget {
  const A11yFutureWidget({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).accessibleNavigation) {
      return FutureBuilder(
          future: Future.delayed(const Duration(milliseconds: 100), () {
            return child;
          }),
          builder: (BuildContext context, AsyncSnapshot<Widget?> snapshot) {
            if (snapshot.hasData) {
              return child;
            } else {
              return Container();
            }
          });
    } else {
      return child;
    }
  }
}
