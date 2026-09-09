import 'package:flutter/material.dart';

class JobCard extends StatelessWidget {
  final String name, skill;
  final double rating;
  const JobCard({
    super.key,
    required this.name,
    required this.skill,
    required this.rating,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text(name),
        subtitle: Text(skill),
        trailing: Text('$rating ⭐'),
      ),
    );
  }
}
