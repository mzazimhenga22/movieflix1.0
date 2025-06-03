import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';

class MarketplaceFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const MarketplaceFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Provider.of<SettingsProvider>(context).accentColor;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: accent.withOpacity(0.2),
      child: ListTile(
        leading: Icon(icon, color: accent, size: 32),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        trailing: Icon(Icons.arrow_forward_ios, color: accent),
        onTap: onTap,
      ),
    );
  }
}
