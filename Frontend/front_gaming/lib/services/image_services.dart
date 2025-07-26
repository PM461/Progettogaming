import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

class NetworkSvgWidget extends StatefulWidget {
  final String url;
  final Color? placeholderColor;

  const NetworkSvgWidget({
    required this.url,
    this.placeholderColor,
    super.key,
  });

  @override
  State<NetworkSvgWidget> createState() => _NetworkSvgWidgetState();
}

class _NetworkSvgWidgetState extends State<NetworkSvgWidget> {
  late Future<String> _svgFuture;

  @override
  void initState() {
    super.initState();
    _svgFuture = _fetchSvg();
  }

  Future<String> _fetchSvg() async {
    Uri uri = Uri.parse(widget.url);
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; FlutterApp)',
    });

    if (response.statusCode != 200) {
      throw Exception('Errore SVG: ${response.statusCode}');
    }

    // NON rimuovo width/height, ma RIMUOVO solo se strettamente necessario
    // Mantieni il viewBox originale (se c'è)
    return response.body;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: FutureBuilder<String>(
        future: _svgFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Container(
              width: 50,
              height: 50,
              color: widget.placeholderColor ?? Colors.transparent,
            );
          }

          if (snapshot.hasError) {
            return Icon(
              Icons.broken_image,
              size: 50,
              color: widget.placeholderColor ?? Colors.grey,
            );
          }

          return Center(
            child: SvgPicture.string(
              snapshot.data!,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              allowDrawingOutsideViewBox: true,
            ),
          );
        },
      ),
    );
  }
}
