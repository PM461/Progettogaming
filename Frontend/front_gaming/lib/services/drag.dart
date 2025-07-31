import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/services/image_services.dart'; // Per NetworkSvgWidget

class DraggableGameList extends StatefulWidget {
  final List<Map<String, dynamic>> games;
  final String title;

  const DraggableGameList({
    super.key,
    required this.games,
    required this.title,
  });

  @override
  State<DraggableGameList> createState() => _DraggableGameListState();
}

class _DraggableGameListState extends State<DraggableGameList> {
  late List<Map<String, dynamic>> _games;

  @override
  void initState() {
    super.initState();
    _games = List.from(widget.games);
  }

  @override
  void didUpdateWidget(covariant DraggableGameList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.games != oldWidget.games) {
      _games = List.from(widget.games);
    }
  }

  bool _isSvg(String url) => url.toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 200,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _games.length,
              itemBuilder: (context, index) {
                final game = _games[index];

                return DragTarget<int>(
                  onWillAccept: (fromIndex) => fromIndex != index,
                  onAccept: (fromIndex) {
                    setState(() {
                      final moved = _games.removeAt(fromIndex);
                      _games.insert(index, moved);
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    return LongPressDraggable<int>(
                      data: index,
                      feedback: Material(
                        elevation: 10,
                        borderRadius: BorderRadius.circular(12),
                        child: _buildGameCard(game, dragging: true),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _buildGameCard(game),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: candidateData.isNotEmpty
                              ? Border.all(color: Colors.amber, width: 2)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildGameCard(game),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game, {bool dragging = false}) {
    final String title = game['label'] ?? 'Gioco';
    final details = game['details'] ?? {};
    final String? imageUrl = details['logo'] ?? details['logo image'];

    Widget imageWidget;
    final random = Random();
    final randomColor = Color.fromARGB(
      255, // opacità piena
      random.nextInt(256), // rosso
      random.nextInt(256), // verde
      random.nextInt(256), // blu
    );
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (_isSvg(imageUrl)) {
        imageWidget = NetworkSvgWidget(
          url: imageUrl,
          placeholderColor: Colors.grey[300],
        );
      } else {
        imageWidget = Image.network(
          imageUrl,
          height: 100,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              width: 200,
              color: randomColor,
              child: const Icon(Icons.broken_image),
            );
          },
        );
      }
    } else {
      imageWidget = Container(
        height: 100,
        width: 100,
        color: randomColor,
        child: const Icon(Icons.image),
      );
    }

    // Wrap the card with GestureDetector to handle taps
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Gamedatascreen(game: game),
          ),
        );
      },
      child: Container(
        width: 140,
        height: 180,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: dragging ? Colors.grey[200] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: dragging
              ? [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: imageWidget,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
