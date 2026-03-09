import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class Sidebar extends StatelessWidget {
  final Function(String) onTap;
  final String selectedItem;

  const Sidebar({super.key, required this.onTap, required this.selectedItem});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Drawer(
          child: Container(
            color: themeProvider.isDarkMode
                ? const Color(0xFF1F2840)
                : Colors.white,
            child: ListView(
              children: [
                DrawerHeader(
                  child: Text("Khono Admin",
                      style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black,
                          fontSize: 24)),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    listTileTheme: const ListTileThemeData(
                      selectedTileColor: Color(0xFFC10D00),
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        selected: selectedItem == "dashboard",
                        leading: Image.asset(
                          'assets/images/Home_Remote_Work_Red_Badge_White.png',
                          width: 24,
                          height: 24,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                        title: Text("Dashboard",
                            style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                        onTap: () => onTap("dashboard"),
                      ),
                      ListTile(
                        selected: selectedItem == "jobs",
                        leading: Icon(Icons.work,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black),
                        title: Text("Jobs",
                            style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                        onTap: () => onTap("jobs"),
                      ),
                      ListTile(
                        selected: selectedItem == "shortlisting",
                        leading: Image.asset(
                          'assets/images/Collaboration_Red_Badge_White.png',
                          width: 24,
                          height: 24,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                        title: Text("Shortlisting",
                            style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                        onTap: () => onTap("shortlisting"),
                      ),
                      ListTile(
                        selected: selectedItem == "interviews",
                        leading: Icon(Icons.schedule,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black),
                        title: Text("Interviews",
                            style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                        onTap: () => onTap("interviews"),
                      ),
                      ListTile(
                        selected: selectedItem == "cv_review",
                        leading: Icon(Icons.description,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black),
                        title: Text("CV Review",
                            style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                        onTap: () => onTap("cv_review"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
