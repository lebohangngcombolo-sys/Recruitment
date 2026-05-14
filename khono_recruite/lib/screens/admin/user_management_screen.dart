import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';
import '../../utils/api_endpoints.dart';
import '../../constants/brand_tokens.dart';
import '../../widgets/themed_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> users = [];
  List<String> roles = ["Admin", "HR", "Recruiter", "Viewer"];
  bool loading = false;
  bool hasMore = true;
  int currentPage = 1;
  int totalPages = 1;
  final int pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  final AdminService _adminService = AdminService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _fetchRolesFromBackend();
    _fetchUsersFromBackend(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!loading && hasMore) {
        _fetchUsersFromBackend();
      }
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchUsersFromBackend(refresh: true);
    });
  }

  Future<void> _fetchRolesFromBackend() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      roles = ["Admin", "HR", "Recruiter", "Viewer", "Manager"];
    });
  }

  Future<void> _fetchUsersFromBackend({bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      hasMore = true;
    }

    if (!hasMore) return;

    if (!mounted) return;
    setState(() => loading = true);

    try {
      final token = await AuthService.getAccessToken();
      if (token == null) return;

      final queryParams = {
        'page': currentPage.toString(),
        'per_page': pageSize.toString(),
        'search': _searchController.text.trim(),
      };

      final uri = Uri.parse(ApiEndpoints.getUsers)
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final dynamic rawUsers = (decoded is Map<String, dynamic>)
            ? (decoded['users'] ?? decoded['data'] ?? decoded['results'])
            : decoded;

        final List<Map<String, dynamic>> newUsers;
        if (rawUsers is List) {
          newUsers = rawUsers
              .whereType<dynamic>()
              .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
              .toList();
        } else {
          newUsers = <Map<String, dynamic>>[];
        }

        if (!mounted) return;
        setState(() {
          if (refresh) {
            users = newUsers;
          } else {
            users.addAll(newUsers);
          }

          if (decoded is Map<String, dynamic>) {
            totalPages = decoded['total_pages'] ?? 1;
          } else {
            totalPages = 1;
          }
          hasMore = currentPage < totalPages;
          currentPage++;
        });
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading users: $e")),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  void _addRoleDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    String role = "";
    showDialog(
      context: context,
      builder: (ctx) {
        return ThemedDialog(
          title: "Add New Role",
          icon: Icon(Icons.add_circle_outline, color: BrandTokens.primary),
          iconColor: BrandTokens.primary,
          content: TextField(
            decoration: InputDecoration(
              hintText: "Enter role name",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              fillColor: (themeProvider.isDarkMode
                      ? const Color(0xFF14131E)
                      : Colors.white)
                  .withValues(alpha: 0.9),
              filled: true,
              hintStyle: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
            onChanged: (val) => role = val,
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (role.isNotEmpty) {
                  setState(() => roles.add(role));
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandTokens.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                ),
              ),
              child: Text(
                "Add Role",
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addMemberDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    String name = "";
    String email = "";
    String role = roles.isNotEmpty ? roles[0] : "";
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ThemedDialog(
              title: "Add Team Member",
              subtitle: "Add a new team member to the system",
              icon: Icon(Icons.person_add_outlined, color: BrandTokens.primary),
              iconColor: BrandTokens.primary,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: GoogleFonts.inter(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        fillColor: (themeProvider.isDarkMode
                                ? const Color(0xFF14131E)
                                : Colors.white)
                            .withValues(alpha: 0.9),
                        filled: true,
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      onChanged: (val) => name = val,
                      style: GoogleFonts.inter(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Email Address",
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        fillColor: (themeProvider.isDarkMode
                                ? const Color(0xFF14131E)
                                : Colors.white)
                            .withValues(alpha: 0.9),
                        filled: true,
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      onChanged: (val) => email = val,
                      style: GoogleFonts.inter(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: role.isNotEmpty ? role : null,
                      items: roles
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r,
                                  style: GoogleFonts.inter(
                                    color: themeProvider.isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) role = val;
                      },
                      decoration: InputDecoration(
                        labelText: "Select Role",
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        fillColor: (themeProvider.isDarkMode
                                ? const Color(0xFF14131E)
                                : Colors.white)
                            .withValues(alpha: 0.9),
                        filled: true,
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      dropdownColor: (themeProvider.isDarkMode
                              ? const Color(0xFF1E1E1E)
                              : Colors.white)
                          .withValues(alpha: 0.95),
                      style: GoogleFonts.inter(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.inter(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (name.isEmpty || email.isEmpty || role.isEmpty)
                            return;
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            final token = await AuthService.getAccessToken();
                            if (token == null)
                              throw Exception("Token not found");

                            final response = await http.post(
                              Uri.parse(ApiEndpoints.adminEnroll),
                              headers: {
                                "Content-Type": "application/json",
                                "Authorization": "Bearer $token",
                              },
                              body: jsonEncode({
                                "email": email.trim(),
                                "first_name": name.split(" ").first,
                                "last_name": name.split(" ").length > 1
                                    ? name.split(" ").sublist(1).join(" ")
                                    : "",
                                "role": role.toLowerCase()
                              }),
                            );

                            if (response.statusCode == 200 ||
                                response.statusCode == 201) {
                              final data = jsonDecode(response.body);
                              setState(() {
                                users.add({
                                  "user_id": data["user_id"],
                                  "name": name,
                                  "email": email,
                                  "role": role,
                                });
                              });
                              Navigator.pop(ctx);
                            } else {
                              final data = jsonDecode(response.body);
                              setState(() {
                                errorMessage =
                                    data["error"] ?? "Failed to add member";
                              });
                            }
                          } catch (e) {
                            setState(() {
                              errorMessage = "Error: $e";
                            });
                          } finally {
                            setState(() {
                              isLoading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandTokens.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(BrandTokens.buttonRadius),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          "Add Member",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editRoleDialog(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    String role = users[index]["role"]!;
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ThemedDialog(
              title: "Edit User Role",
              subtitle: "Change the role for this team member",
              icon: Icon(Icons.edit_outlined, color: BrandTokens.primary),
              iconColor: BrandTokens.primary,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius:
                            BorderRadius.circular(BrandTokens.buttonRadius),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: GoogleFonts.inter(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    users[index]["name"] ?? "",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items: roles
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r,
                                style: GoogleFonts.inter(
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) role = val;
                    },
                    decoration: InputDecoration(
                      labelText: "Select Role",
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(BrandTokens.buttonRadius),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(BrandTokens.buttonRadius),
                        borderSide:
                            const BorderSide(color: Colors.redAccent, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      fillColor: (themeProvider.isDarkMode
                              ? const Color(0xFF14131E)
                              : Colors.white)
                          .withValues(alpha: 0.9),
                      filled: true,
                      labelStyle: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    dropdownColor: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.95),
                    style: GoogleFonts.inter(
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.inter(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            final userId =
                                users[index]["user_id"] ?? users[index]["id"];
                            if (userId == null)
                              throw Exception("User ID not found");

                            await _adminService.updateUserRole(userId, role);

                            if (!mounted) return;
                            setState(() {
                              users[index]["role"] = role;
                              isLoading = false;
                            });
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Role updated successfully"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                              errorMessage = e.toString();
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandTokens.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(BrandTokens.buttonRadius),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          "Save Changes",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleUserStatus(int index) async {
    final user = users[index];
    final userId = user["user_id"] ?? user["id"];
    final isCurrentlyActive = user["is_active"] ?? true;

    if (userId == null) return;

    try {
      if (isCurrentlyActive) {
        await _adminService.deactivateUser(userId);
      } else {
        await _adminService.activateUser(userId);
      }

      if (!mounted) return;
      setState(() {
        users[index]["is_active"] = !isCurrentlyActive;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(isCurrentlyActive ? "User deactivated" : "User activated"),
          backgroundColor: isCurrentlyActive ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteUser(int index) async {
    final user = users[index];
    final userId = user["user_id"] ?? user["id"];

    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User"),
        content: Text(
            "Are you sure you want to delete ${user["name"] ?? "this user"}? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.deleteUser(userId);

        if (!mounted) return;
        setState(() {
          users.removeAt(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting user: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ------------------ UI ------------------
  Widget buildUserCard(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = users[index];
    final role = user["role"] ?? "";

    Color getRoleColor(String role) {
      switch (role.toLowerCase()) {
        case 'admin':
          return Colors.redAccent;
        case 'hr':
          return Colors.blue;
        case 'manager':
          return Colors.green;
        case 'recruiter':
          return Colors.orange;
        default:
          return Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipOval(
                child: user["profile_image"] != null &&
                        user["profile_image"].toString().isNotEmpty
                    ? Image.network(
                        user["profile_image"],
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 48,
                            height: 48,
                            color: getRoleColor(role).withValues(alpha: 0.1),
                            child: Icon(Icons.person,
                                color: getRoleColor(role), size: 24),
                          );
                        },
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: getRoleColor(role).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person,
                            color: getRoleColor(role), size: 24),
                      ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user["name"] ?? "",
                    style: GoogleFonts.inter(
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user["email"] ?? "",
                    style: GoogleFonts.inter(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getRoleColor(role).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      role,
                      style: GoogleFonts.inter(
                        color: getRoleColor(role),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (user["is_active"] == false
                              ? Colors.red
                              : Colors.green)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (user["is_active"] == false
                                ? Colors.red
                                : Colors.green)
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      user["is_active"] == false ? "Inactive" : "Active",
                      style: GoogleFonts.inter(
                        color: user["is_active"] == false
                            ? Colors.red
                            : Colors.green,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: BrandTokens.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => _editRoleDialog(index),
                  icon: Icon(Icons.edit, color: BrandTokens.primary, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: (user["is_active"] == false
                              ? Colors.green
                              : Colors.orange)
                          .withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => _toggleUserStatus(index),
                  icon: Icon(
                    user["is_active"] == false
                        ? Icons.check_circle
                        : Icons.block,
                    color: user["is_active"] == false
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => _deleteUser(index),
                  icon: Icon(Icons.delete, color: Colors.red, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: (themeProvider.isDarkMode
                            ? const Color(0xFF2D2D2D)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // 🌆 Dynamic background implementation
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(themeProvider.backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              "User Management",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            backgroundColor: (themeProvider.isDarkMode
                    ? const Color(0xFF14131E)
                    : Colors.white)
                .withValues(alpha: 0.9),
            elevation: 0,
            iconTheme: IconThemeData(
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
            actions: [
              // Search Bar
              Container(
                width: 200,
                margin: const EdgeInsets.only(right: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: BrandTokens.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _addRoleDialog,
                  icon: const Icon(Icons.add_moderator,
                      color: BrandTokens.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: BrandTokens.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _addMemberDialog,
                  icon:
                      const Icon(Icons.person_add, color: BrandTokens.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Stats
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                        ),
                        child: Icon(
                          Icons.people_alt,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Team Members",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            "${users.length} active users",
                            style: GoogleFonts.inter(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(BrandTokens.buttonRadius),
                        ),
                        child: Text(
                          "${roles.length} roles",
                          style: GoogleFonts.inter(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Users List
                Expanded(
                  child: users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No Team Members",
                                style: GoogleFonts.inter(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Add your first team member to get started",
                                style: GoogleFonts.inter(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: users.length +
                              (loading && users.isNotEmpty ? 1 : 0),
                          itemBuilder: (ctx, index) {
                            if (index == users.length && loading) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return buildUserCard(index);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
