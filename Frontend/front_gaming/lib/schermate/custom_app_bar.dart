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
  bool _isSearchActive = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 420;
    final isTablet = width > 600;
    bool _isSearching = false;

    Widget _buildSearchBar({bool autofocus = false}) {
      return Expanded(
        child: Container(
          height: 35,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: _searchController,
            autofocus: autofocus,
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
              setState(() => _isSearchActive = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(query: value),
                ),
              );
            },
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 4,
      automaticallyImplyLeading: false,
      toolbarHeight: dimensione,
      flexibleSpace: SafeArea(
        child: Container(
          height: dimensione,
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LOGO
              if (!_isSearchActive || !isSmall) ...[
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/main'),
                  child: Image.asset(
                    'images/logo2.png',
                    height: isTablet ? 200 : 48,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: isTablet ? 25 : 20),
              ],

              // SEARCH BAR
              // SEARCH BAR
              if (!isSmall)
                _buildSearchBar()
              else if (_isSearchActive) ...[
                _buildSearchBar(autofocus: true),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearchActive = false;
                      _searchController.clear();
                    });
                  },
                ),
              ] else
                const Spacer(),

              SizedBox(width: isTablet ? 25 : 20),
              // AZIONI (solo se non in modalità ricerca attiva su schermo piccolo)
              if (!_isSearchActive || !_isSearchActive) ...[
                if (isSmall)
                  IconButton(
                    icon: Icon(Icons.search, color: Colors.white),
                    tooltip: 'Cerca',
                    onPressed: () {
                      if (isSmall) {
                        setState(() => _isSearchActive = true);
                      }
                    },
                  ),
                SizedBox(width: isTablet ? 25 : 0),
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
                      fontSize: isTablet ? 18 : 0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.white24,
                ),
                SizedBox(width: isTablet ? 10 : 0),
                IconButton(
                  icon: Icon(
                    Icons.notifications_sharp,
                    size: isTablet ? 30 : 28,
                    color: Colors.white,
                  ),
                  tooltip: 'Notifiche',
                  onPressed: () {},
                ),
                SizedBox(width: isTablet ? 25 : 0),
                Tooltip(
                  message: 'Profilo',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: CircleAvatar(
                      radius: isTablet ? 24 : 20,
                      backgroundImage: AssetImage(
                        widget.selectedImageName != null
                            ? 'images/propic/${widget.selectedImageName}.png'
                            : 'images/propic/1.png',
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 25 : 20)
              ],
            ],
          ),
        ),
      ),
    );
  }
}
