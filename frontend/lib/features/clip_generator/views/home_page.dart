// lib/features/clip_generator/views/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/clip_provider.dart';
import 'loading_view.dart';
import 'result_view.dart';
import '../models/job_response.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClipProvider>(context);

    // Dynamic state rendering
    switch (provider.state) {
      case UIState.loading:
        return const Scaffold(body: LoadingView());
      case UIState.result:
        return const Scaffold(body: ResultView());
      default:
        return Scaffold(
          body: Stack(
            children: [
              // Efek Background Gradasi Elegan
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F0F12), Color(0xFF1F1A3A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Card(
                          color: Theme.of(context).cardColor.withOpacity(0.85),
                      elevation: 32,
                      shadowColor: Colors.black.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width > 600 ? 40 : 20,
                          vertical: 48,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header Logo & Glow Effect
                              const HeaderWidget(),
                              const SizedBox(height: 48),
                              
                              // Input URL
                              TextFormField(
                                controller: _urlController,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  hintText: 'Masukkan link YouTube (e.g., https://...)',
                                  prefixIcon: Icon(Icons.link, color: Colors.grey),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Tautan URL tidak boleh kosong';
                                  }
                                  if (!value.contains('youtube.com') &&
                                      !value.contains('youtu.be')) {
                                    return 'Harap masukkan tautan YouTube yang valid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              
                              // Pilihan Layout
                              const Text('Pilih Tipe Video:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12.0,
                                runSpacing: 8.0,
                                alignment: WrapAlignment.center,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Solo (Vlog)'),
                                    selected: provider.selectedLayout == 'solo',
                                    onSelected: (selected) {
                                      if (selected) provider.setLayout('solo');
                                    },
                                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    side: BorderSide(
                                      color: provider.selectedLayout == 'solo' 
                                          ? Theme.of(context).primaryColor 
                                          : Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Presentasi'),
                                    selected: provider.selectedLayout == 'presentation',
                                    onSelected: (selected) {
                                      if (selected) provider.setLayout('presentation');
                                    },
                                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    side: BorderSide(
                                      color: provider.selectedLayout == 'presentation' 
                                          ? Theme.of(context).primaryColor 
                                          : Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Podcast'),
                                    selected: provider.selectedLayout == 'podcast',
                                    onSelected: (selected) {
                                      if (selected) provider.setLayout('podcast');
                                    },
                                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    side: BorderSide(
                                      color: provider.selectedLayout == 'podcast' 
                                          ? Theme.of(context).primaryColor 
                                          : Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // Error Banner
                              if (provider.state == UIState.error) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          provider.errorMessage ?? 'Terjadi kesalahan sistem.',
                                          style: const TextStyle(color: Colors.redAccent),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).primaryColor.withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: provider.state == UIState.submitting
                                        ? null
                                        : () {
                                            if (_formKey.currentState!.validate()) {
                                              provider.submitYoutubeUrl(
                                                _urlController.text.trim(),
                                              );
                                            }
                                          },
                                    child: provider.state == UIState.submitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Gunting Video Menjadi Vertical Clip ⚡',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                        ),
                        if (provider.savedJobIds.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          ActiveJobsCard(provider: provider),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
          child: Icon(
            Icons.movie_filter_rounded,
            size: 56,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Local AI Clipper',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Ekstrak momen terbaik YouTube menjadi video 9:16 menggunakan kecerdasan buatan lokal.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class ActiveJobsCard extends StatelessWidget {
  final ClipProvider provider;
  const ActiveJobsCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Card(
        color: Theme.of(context).cardColor.withOpacity(0.85),
        elevation: 16,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Riwayat Pekerjaan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...provider.savedJobIds.map((id) {
                final status = provider.jobStatuses[id];
                return _buildJobTile(context, id, status);
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobTile(BuildContext context, String id, JobResponse? job) {
    IconData icon;
    Color color;
    String statusText;

    if (job == null) {
      icon = Icons.hourglass_empty;
      color = Colors.grey;
      statusText = 'Loading...';
    } else {
      switch (job.status) {
        case ClipStatus.completed:
          icon = Icons.check_circle;
          color = Colors.green;
          statusText = 'Selesai';
          break;
        case ClipStatus.failed:
          icon = Icons.error;
          color = Colors.red;
          statusText = 'Gagal';
          break;
        default:
          icon = Icons.sync;
          color = Colors.blue;
          statusText = 'Memproses';
      }
    }

    return Card(
      color: Colors.white.withOpacity(0.05),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          'Job ID: ${id.substring(0, 8)}...',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(color: color),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (job?.status == ClipStatus.completed && job?.videoPath != null)
              IconButton(
                icon: const Icon(Icons.download, color: Colors.blueAccent),
                tooltip: 'Download',
                onPressed: () async {
                  final url = Uri.parse(provider.getFullUrl(job!.videoPath!));
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              tooltip: 'Hapus Riwayat',
              onPressed: () => provider.removeJob(id),
            ),
          ],
        ),
        onTap: () {
          provider.resumeJob(id);
        },
      ),
    );
  }
}
