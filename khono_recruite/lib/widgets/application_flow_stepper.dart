import 'package:flutter/material.dart';

class ApplicationFlowStepper extends StatelessWidget {
  final int currentStep;
  final List<String> labels;
  final Color activeColor;
  final Color completedColor;
  final Color inactiveColor;
  final bool showLabels;
  final double size;

  const ApplicationFlowStepper({
    super.key,
    required this.currentStep,
    this.labels = const [
      "Proceed",
      "Assessment",
      "Upload CV",
      "Results",
    ],
    this.activeColor = const Color(0xFFC10D00),
    this.completedColor = Colors.green,
    this.inactiveColor = const Color(0xFFBDBDBD),
    this.showLabels = true,
    this.size = 48,
  });

  int get _safeCurrentStep {
    if (labels.isEmpty) return 0;
    if (currentStep < 0) return 0;
    if (currentStep >= labels.length) return labels.length - 1;
    return currentStep;
  }

  Widget _buildStepIndicator(int index) {
    final isActive = _safeCurrentStep == index;
    final isCompleted = _safeCurrentStep > index;
    final Color circleColor = isActive
        ? activeColor
        : (isCompleted ? completedColor : inactiveColor);
    final Color borderColor = isActive
        ? activeColor
        : (isCompleted ? completedColor : inactiveColor);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              (index + 1).toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(
              labels[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _safeCurrentStep >= index
                    ? Colors.white
                    : Colors.grey.shade300,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(labels.length, (index) {
        return _buildStepIndicator(index);
      }),
    );
  }
}
