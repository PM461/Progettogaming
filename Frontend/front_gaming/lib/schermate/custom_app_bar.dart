import 'dart:html';

import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/search_page.dart';
import 'package:material_symbols_icons/symbols.dart';

const dimensione = 85.00;

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? selectedImageName;

  const CustomAppBar({super.key, required this.selectedImageName});

  @override
  Size get preferredSize => const Size.fromHeight(dimensione);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 360;
    final isTablet = width > 600;

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 4,
      automaticallyImplyLeading: false,
      toolbarHeight: dimensione, // Altezza effettiva dell’AppBar
      flexibleSpace: SafeArea(
        child: Container(
          height:
              dimensione, // Questo è FONDAMENTALE per centrare verticalmente
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LOGO
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/main'),
                child: Image.asset(
                  'images/logo2.png',
                  height: isTablet ? 200 : 48,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(width: 10),

              // SEARCH BAR
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  height: 35,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.white),
                      hintText: 'Cerca...',
                      hintStyle: const TextStyle(color: Colors.white70),
                      fillColor: Colors.white12,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (value) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchPage(query: value),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ICONA LIBRERIA
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/library'),
                icon: Icon(
                  Icons.sports_esports_outlined,
                  size: isTablet ? 40 : 28,
                  color: Colors.white,
                ),
                label: Text(
                  isTablet ? 'Collezione' : '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 18 : 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              SizedBox(width: isTablet ? 10 : 5),
              IconButton(
                icon: Icon(
                  Icons.notifications_sharp,
                  size: isTablet ? 30 : 28,
                  color: Colors.white,
                ),
                tooltip: 'Notifiche',
                onPressed: () {},
              ),

              SizedBox(width: isTablet ? 10 : 5),

              // AVATAR
              Tooltip(
                message: 'Profilo',
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  child: CircleAvatar(
                    radius: isTablet ? 24 : 22,
                    backgroundImage: AssetImage(
                      widget.selectedImageName != null
                          ? 'images/propic/${widget.selectedImageName}.png'
                          : 'images/propic/1.png',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
