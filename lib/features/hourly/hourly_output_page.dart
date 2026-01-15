import 'package:flutter/material.dart';
import 'package:myapp/models/sorting_log.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HourlyOutputPage extends StatefulWidget {
  const HourlyOutputPage({super.key});

  @override
  State<HourlyOutputPage> createState() => _HourlyOutputPageState();
}

class _HourlyOutputPageState extends State<HourlyOutputPage> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _operatorControllers = [TextEditingController()];
  final _partNoController = TextEditingController();
  final _partNameController = TextEditingController();
  final _quantitySortedController = TextEditingController();
  final _quantityNgController = TextEditingController();
  final _hourController = TextEditingController(text: DateTime.now().hour.toString().padLeft(2, '0'));
  
  final FirestoreService _firestoreService = FirestoreService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (var controller in _operatorControllers) {
      controller.dispose();
    }
    _partNoController.dispose();
    _partNameController.dispose();
    _quantitySortedController.dispose();
    _quantityNgController.dispose();
    _hourController.dispose();
    super.dispose();
  }

  Future<void> _submitHourlyOutput() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final log = SortingLog(
        partNo: _partNoController.text.trim(),
        partName: _partNameController.text.trim(),
        quantitySorted: int.parse(_quantitySortedController.text),
        quantityNg: int.parse(_quantityNgController.text),
        supplier: 'N/A',
        factoryLocation: 'N/A',
        operators: _operatorControllers.map((c) => c.text.trim()).where((name) => name.isNotEmpty).toList(),
        remarks: 'Hourly output for hour ${_hourController.text}',
        ngDetails: [],
        timestamp: Timestamp.now(),
      );

      await _firestoreService.addSortingLog(log);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Hourly output submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (var controller in _operatorControllers) {
      if (_operatorControllers.indexOf(controller) == 0) {
        controller.clear();
      } else {
        controller.dispose();
      }
    }
    setState(() {
      _operatorControllers.removeRange(1, _operatorControllers.length);
    });
    _partNoController.clear();
    _partNameController.clear();
    _quantitySortedController.clear();
    _quantityNgController.clear();
    _hourController.text = DateTime.now().hour.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131131),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1C1A45),
        title: const Text('Hourly Output', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF7B61FF).withOpacity(0.2), const Color(0xFF7B61FF).withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7B61FF).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.access_time, color: Color(0xFF7B61FF), size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Log Your Hourly Output', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          SizedBox(height: 4),
                          Text('Quick entry for operator hourly production', style: TextStyle(fontSize: 13, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Operator Info Card
              _buildCard(
                title: 'OPERATOR INFO',
                icon: Icons.group,
                children: [
                  ..._operatorControllers.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Operator ${idx + 1} Name', Icons.person_outline),
                              validator: (value) => value!.isEmpty ? 'Enter name' : null,
                            ),
                          ),
                          if (_operatorControllers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  controller.dispose();
                                  _operatorControllers.removeAt(idx);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _operatorControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add Another Operator'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7B61FF),
                        side: const BorderSide(color: Color(0xFF7B61FF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hourController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Hour (00-23)', Icons.schedule),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return 'Enter hour';
                      int? hour = int.tryParse(value);
                      if (hour == null || hour < 0 || hour > 23) return 'Invalid hour (0-23)';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Part Info Card
              _buildCard(
                title: 'PART INFO',
                icon: Icons.inventory_2,
                children: [
                  TextFormField(
                    controller: _partNoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Part Number', Icons.qr_code),
                    validator: (value) => value!.isEmpty ? 'Enter part number' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _partNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Part Name', Icons.label),
                    validator: (value) => value!.isEmpty ? 'Enter part name' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Production Quantity Card
              _buildCard(
                title: 'PRODUCTION QUANTITY',
                icon: Icons.production_quantity_limits,
                children: [
                  TextFormField(
                    controller: _quantitySortedController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Quantity Sorted (OK)', Icons.check_circle),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return 'Enter quantity';
                      if (int.tryParse(value) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityNgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Quantity NG (Rejected)', Icons.cancel, helperText: 'Enter 0 if no defects'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return 'Enter quantity (0 if none)';
                      if (int.tryParse(value) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Submit Button
              Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF7B61FF), const Color(0xFF6344FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF7B61FF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitHourlyOutput,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('SUBMIT HOURLY OUTPUT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: const Color(0xFF2D3561),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF7B61FF).withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B61FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF7B61FF), size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF7B61FF), letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      helperText: helperText,
      helperStyle: const TextStyle(color: Colors.white60, fontSize: 11),
      prefixIcon: Icon(icon, color: const Color(0xFF7B61FF)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: const Color(0xFF7B61FF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
