import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FaviconWidget extends StatelessWidget {
  final String title;

  const FaviconWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final query = title.split(' ').first.toLowerCase(); 
    if (query.isEmpty) return const CircleAvatar(child: Icon(Icons.vpn_key));

    return CircleAvatar(
      backgroundColor: Colors.transparent,
      child: CachedNetworkImage(
        imageUrl: "https://www.google.com/s2/favicons?domain=$query.com&sz=64",
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (context, url) => CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.2),
          child: Text(title[0].toUpperCase(), style: const TextStyle(color: Colors.teal)),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.2),
          child: Text(title.isNotEmpty ? title[0].toUpperCase() : "?", style: const TextStyle(color: Colors.teal)),
        ),
      ),
    );
  }
}