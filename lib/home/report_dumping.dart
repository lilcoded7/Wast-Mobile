import 'package:flutter/material.dart';

class ReportDumpPage extends StatelessWidget {
  const ReportDumpPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF061405);
    const Color cardColor = Color(0xFF132314);
    const Color accentGreen = Color(0xFF5ED5A8);
    const Color warningRed = Color(0xFFE57373);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Report Illegal Dumping",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ALERT BANNER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: warningRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: warningRed.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: warningRed, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Help us keep communities clean. Report illegal dumping for immediate action.",
                      style: TextStyle(
                        color: warningRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _sectionLabel("Location / Address"),
            const SizedBox(height: 12),
            _buildTextField(
              hint: "Enter address or location description",
              icon: Icons.location_on_outlined,
              bgColor: cardColor,
            ),

            const SizedBox(height: 32),
            _sectionLabel("Description"),
            const SizedBox(height: 12),
            _buildTextField(
              hint: "Describe what you see — type of waste, volume, hazard level, etc.",
              maxLines: 5,
              bgColor: cardColor,
            ),

            const SizedBox(height: 32),
            _sectionLabel("Photo (optional)"),
            const SizedBox(height: 12),
            _buildPhotoUploader(cardColor, accentGreen),

            const SizedBox(height: 48),
            
            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  "Submit Report",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    IconData? icon,
    int maxLines = 1,
    required Color bgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF5ED5A8)) : null,
          contentPadding: const EdgeInsets.all(20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPhotoUploader(Color bg, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          style: BorderStyle.none, // We use custom painter for dashes if needed
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.camera_alt_outlined, color: accent, size: 32),
          const SizedBox(height: 12),
          const Text(
            "Tap to add a photo",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Clear evidence helps speed up action",
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}