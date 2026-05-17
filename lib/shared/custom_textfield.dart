import 'package:flutter/material.dart';

class CustomTextFieled extends StatefulWidget {
  final IconData prefix;
 final  String hitnText;
  const CustomTextFieled({super.key, required this.prefix , required this.hitnText});

  @override
  State<CustomTextFieled> createState() => _CustomTextFieledState();
}

class _CustomTextFieledState extends State<CustomTextFieled> {
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: TextField(
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(bottom: 4),
                border: InputBorder.none,
                hintText: widget.hitnText,
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
                // hajet tji 3la right
                prefixIcon: Icon(widget.prefix, color: Colors.grey),
                
              ),
            ),
          ),
        ),
    );
  }
}
