import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/search_page.dart';
import 'package:material_symbols_icons/symbols.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? selectedImageName;

  const CustomAppBar({super.key, required this.selectedImageName});

  @override
  Size get preferredSize => const Size.fromHeight(60);

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
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 24),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/main'),
              child: Image.asset(
                'images/logo2.png',
                height: 170,
                width: 170,
                fit: BoxFit.contain,
              ),
            ),

            // Spazio fra logo e barra di ricerca
            const SizedBox(width: 150),

            // Barra di ricerca sempre visibile e centrata
            Expanded(
              child: SizedBox(
                width: isTablet ? 400 : double.infinity,
                height: 35,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: IconButton(
                      icon: const Icon(
                        Icons.search,
                        color: Colors.white,
                      ),
                      onPressed: () {},
                    ),
                    hintText: 'Cerca...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    fillColor: Colors.white12,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(0),
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
            const SizedBox(width: 150),
            // Spazio fra barra e icone
            SizedBox(width: isSmall ? 10 : 20),

            IconButton(
              icon: Icon(
                Icons.sports_esports_outlined,
                size: isTablet ? 50 : 34,
                color: Colors.white,
              ),
              tooltip: 'Vai alla libreria',
              onPressed: () {
                Navigator.pushNamed(context, '/library');
              },
            ),
            SizedBox(width: isSmall ? 10 : 20),
            Tooltip(
              message: 'Profilo',
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                child: CircleAvatar(
                  radius: isTablet ? 28 : (isSmall ? 20 : 25),
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
    );
  }
}
