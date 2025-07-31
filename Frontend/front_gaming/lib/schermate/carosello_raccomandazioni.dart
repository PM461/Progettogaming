import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/gamedetail.dart';
import 'package:front_gaming/schermate/gamedetailscreen.dart';
import 'package:front_gaming/services/image_services.dart';
 // Importa il widget SVG da te definito

class RecommendationCarousel extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> games;

  const RecommendationCarousel({
    required this.title,
    required this.games,
    Key? key,
  }) : super(key: key);

  bool _isSvg(String url) {
    return url.toLowerCase().endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    return games.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    final imageUrl =
                        game['details']['logo'] ?? game['details']['logo image'] ??'';

                    Widget imageWidget;

                    if (imageUrl.isEmpty) {
                      imageWidget = Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      );
                    } else if (_isSvg(imageUrl)) {
                      imageWidget = NetworkSvgWidget(
                        url: imageUrl,
                        placeholderColor: Colors.grey[300],
                      );
                    } else {
                      imageWidget = Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          );
                        },
                      );
                    }

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
                        width: 150,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageWidget,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              game['label'] ?? 'Senza titolo',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }
}
