import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/search_page.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? selectedImageName;

  const CustomAppBar({super.key, required this.selectedImageName});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        // Breakpoints
        final bool isSmall = width < 360;
        final bool isTablet = width > 600;

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
                  child: Text(
                    'Gaming Collection',
                    style: TextStyle(
                      fontSize: isSmall ? 18 : (isTablet ? 26 : 22),
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ),
                const Spacer(),

                // 🔍 Icona di ricerca
                IconButton(
                  icon: Icon(Icons.search,
                      size: isTablet ? 34 : 28, color: Colors.white),
                  tooltip: 'Cerca',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SearchPage()),
                    );
                  },
                ),
                SizedBox(width: isSmall ? 10 : 20),

                // 📚 Libreria
                IconButton(
                  icon: Icon(Icons.library_books,
                      size: isTablet ? 34 : 28, color: Colors.white),
                  tooltip: 'Vai alla libreria',
                  onPressed: () {
                    Navigator.pushNamed(context, '/library');
                  },
                ),
                SizedBox(width: isSmall ? 10 : 20),

                // 👤 Profilo con immagine
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
                        selectedImageName != null
                            ? 'images/propic/$selectedImageName.png'
                            : 'images/propic/1.png',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
