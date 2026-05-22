import 'package:flutter/material.dart';
import '../models/leave_model.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_text_form_field.dart';
import '../widgets/modern_date_range_picker.dart';
import '../controllers/leave_controller.dart';

class LeaveFormPage extends StatefulWidget {
  final LeaveModel? leave;

  const LeaveFormPage({super.key, this.leave});

  @override
  _LeaveFormPageState createState() => _LeaveFormPageState();
}

class _LeaveFormPageState extends State<LeaveFormPage> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedReason;
  late TextEditingController _notesController;
  DateTime? _fromDate;
  DateTime? _untilDate;
  bool _isLoading = false;
  late LeaveController _leaveController;

  final List<Map<String, dynamic>> _reasonList = [
    {'id': 1, 'text': 'menikah'},
    {'id': 2, 'text': 'sakit'},
    {'id': 3, 'text': 'pulang kampung'},
    {'id': 4, 'text': 'libur'},
    {'id': 5, 'text': 'Keluarga meninggal'},
  ];

  @override
  void initState() {
    super.initState();
    _leaveController = LeaveController(context);
    _selectedReason = widget.leave?.reason;
    _notesController = TextEditingController(text: widget.leave?.notes ?? '');
    _fromDate = widget.leave?.fromDate;
    _untilDate = widget.leave?.untilDate;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_leaveController.validateDates(_fromDate, _untilDate)) return;
    if (!_leaveController.validateReason(_selectedReason)) return;

    setState(() => _isLoading = true);

    try {
      if (widget.leave != null) {
        await _leaveController.updateLeave(
          leaveId: widget.leave!.id,
          reason: _selectedReason.toString(),
          fromDate: _fromDate!,
          untilDate: _untilDate!,
          notes: _notesController.text,
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Berhasil mengupdate cuti')),
            );
            Navigator.pop(context, true);
          },
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          },
        );
      } else {
        await _leaveController.submitLeave(
          selectedReason: _selectedReason!,
          fromDate: _fromDate!,
          untilDate: _untilDate!,
          notes: _notesController.text,
          onSuccess: () {
            Navigator.pop(context, true);
          },
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          },
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? dateRangeError;
    if (_fromDate != null &&
        _untilDate != null &&
        _untilDate!.isBefore(_fromDate!)) {
      dateRangeError = 'Tanggal selesai harus setelah tanggal mulai';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.leave == null ? 'Tambah Cuti' : 'Edit Cuti'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ModernDropdown<Map<String, dynamic>>(
                        value: _selectedReason != null
                            ? _reasonList.firstWhere(
                                (item) => item['id'] == _selectedReason)
                            : null,
                        hint: 'Pilih Jenis Cuti',
                        items: _reasonList,
                        getLabel: (item) => item['text'],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedReason = value['id']);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      ModernDateRangePicker(
                        startDate: _fromDate,
                        endDate: _untilDate,
                        onDateRangeSelected: (start, end) {
                          setState(() {
                            _fromDate = start;
                            _untilDate = end;
                          });
                        },
                        minDate: DateTime.now(),
                        maxDate: DateTime.now().add(const Duration(days: 365)),
                        errorText: dateRangeError,
                      ),
                      const SizedBox(height: 16),
                      ModernTextFormField(
                        labelText: 'Catatan',
                        controller: _notesController,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        validator: (value) {
                          if (value != null && value.length > 500) {
                            return 'Catatan tidak boleh lebih dari 500 karakter';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 8,
                top: 8,
              ),
              margin: const EdgeInsets.only(top: 8),
              child: ModernButton(
                text: widget.leave == null ? 'Simpan' : 'Update',
                onPressed: _isLoading ? null : _submitForm,
                isLoading: _isLoading,
                icon: Icons.save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
