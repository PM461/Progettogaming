import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? selectedImageName;

  const CustomAppBar({super.key, required this.selectedImageName});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 4,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/main');
              },
              child: const Text(
                'Gaming Collection',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),

            // 🔍 Icona di ricerca con Tooltip
            IconButton(
              icon: const Icon(Icons.search, size: 30, color: Colors.white),
              tooltip: 'Cerca',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchPage()),
                );
              },
            ),
            const SizedBox(width: 20),

            // 📚 Libreria con Tooltip
            IconButton(
              icon: const Icon(Icons.library_books,
                  size: 30, color: Colors.white),
              tooltip: 'Vai alla libreria',
              onPressed: () {
                Navigator.pushNamed(context, '/library');
              },
            ),
            const SizedBox(width: 20),

            // 👤 Profilo con Tooltip e InkWell
            Tooltip(
              message: 'Profilo',
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                child: CircleAvatar(
                  radius: 25,
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
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
