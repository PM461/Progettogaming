import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:front_gaming/schermate/search_page.dart';
import 'package:front_gaming/services/notifications_center.dart';

const dimensione = 85.0;

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? selectedImageName;

  /// Se lo passi, sovrascrive il conteggio globale (mostra/occulta il pallino)
  final int? notifCount;

  /// Se lo passi, viene usato al posto del comportamento di default.
  final VoidCallback? onBellTap;

  const CustomAppBar({
    super.key,
    required this.selectedImageName,
    this.notifCount, // opzionale
    this.onBellTap,  // opzionale
  });

  @override
  Size get preferredSize => const Size.fromHeight(dimensione);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchActive = false;
  bool _showGif = false;
  Timer? _gifTimer;
  Timer? _resetTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _scheduleGif();
  }

  @override
  void dispose() {
    _gifTimer?.cancel();
    _resetTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleGif() {
    final int delaySeconds = 10 + _random.nextInt(50);
    _gifTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted) return;
      setState(() => _showGif = true);
      _resetTimer = Timer(const Duration(seconds: 8), () {
        if (!mounted) return;
        setState(() => _showGif = false);
        _scheduleGif();
      });
    });
  }

  // === Default: cosa succede quando si clicca la campanella ===
  void _openDefaultNotificationsSheet() async {
    // Aggiorna subito i contatori prima di mostrare il foglio
    await NotificationsCenter.instance.refreshNow();

    if (!mounted) return;
    final count = NotificationsCenter.instance.notifCount.value;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Notifiche',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (count == 0)
                const ListTile(
                  leading: Icon(Icons.inbox_outlined),
                  title: Text('Nessuna nuova notifica'),
                  subtitle: Text('Quando ricevi richieste d’amicizia o altre notifiche, le vedrai qui.'),
                )
              else
                Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.person_add_alt_1),
                      title: Text('Richieste d’amicizia in arrivo'),
                      subtitle: Text('Vai alla pagina per gestirle'),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          // Porta l’utente dove gestisce le richieste (profilo)
                          Navigator.pushNamed(context, '/profile');
                        },
                        icon: const Icon(Icons.manage_accounts),
                        label: const Text('Gestisci richieste'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

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
            prefixIcon: const Icon(Icons.search, color: Colors.white),
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
              MaterialPageRoute(builder: (context) => SearchPage(query: value)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBell(bool isTablet) {
    // se notifCount è fornito, usa quello
    if (widget.notifCount != null) {
      final hasDot = widget.notifCount! > 0;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_sharp),
            iconSize: isTablet ? 30 : 28,
            color: Colors.white,
            tooltip: 'Notifiche',
            onPressed: widget.onBellTap ?? _openDefaultNotificationsSheet,
          ),
          if (hasDot)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
        ],
      );
    }

    // altrimenti segue il centro notifiche globale
    return ValueListenableBuilder<int>(
      valueListenable: NotificationsCenter.instance.notifCount,
      builder: (context, count, _) {
        final hasDot = count > 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_sharp),
              iconSize: isTablet ? 30 : 28,
              color: Colors.white,
              tooltip: 'Notifiche',
              onPressed: widget.onBellTap ?? _openDefaultNotificationsSheet,
            ),
            if (hasDot)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 420;
    final isTablet = width > 600;

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 4,
      automaticallyImplyLeading: false,
      toolbarHeight: dimensione,
      flexibleSpace: SafeArea(
        child: Container(
          height: dimensione,
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // logo
              if (!_isSearchActive || !isSmall) ...[
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/main'),
                  child: SizedBox(
                    width: isTablet ? 200 : 100,
                    height: 50,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: Image.asset(
                        _showGif
                            ? 'images/logow.gif'
                            : (isTablet ? 'images/logoestesow.png' : 'images/logow.png'),
                        key: ValueKey<bool>(_showGif),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 25 : 20),
              ],

              // searchbar
              if (!isSmall)
                _buildSearchBar()
              else if (_isSearchActive) ...[
                _buildSearchBar(autofocus: true),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
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

              // actions
              if (!_isSearchActive) ...[
                if (isSmall)
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    tooltip: 'Cerca',
                    onPressed: () => setState(() => _isSearchActive = true),
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
                Container(height: 30, width: 1, color: Colors.white24),
                SizedBox(width: isTablet ? 10 : 0),

                // campanella (cliccabile ovunque)
                _buildBell(isTablet),

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
                SizedBox(width: isTablet ? 25 : 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
