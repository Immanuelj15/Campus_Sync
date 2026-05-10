import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:campus_sync/models/post_model.dart';
import 'package:campus_sync/services/auth_service.dart';
import 'package:campus_sync/services/db_service.dart';
import 'package:campus_sync/services/storage_service.dart';
import 'package:campus_sync/widgets/custom_button.dart';

class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key, this.initialPost});

  final PostModel? initialPost;

  bool get isEditing => initialPost != null;

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final DbService _dbService = DbService();
  final AuthService _authService = AuthService();

  File? _selectedImageFile;
  String _imageUrl = '';
  bool _isSubmitting = false;
  bool _isAnonymous = false;
  bool _isUploadingImage = false;
  double _uploadProgress = 0;
  String _selectedCategory = postCategories.first;
  String _selectedStudyResourceType = studyResourceTypes.first;
  String _selectedUrgency = postUrgencies.first;
  Duration _expiryDuration = const Duration(hours: 24);

  static const List<_QuickTemplate> _templates = <_QuickTemplate>[
    _QuickTemplate(
      title: 'Need a charger',
      description: 'Need a phone or laptop charger near the library for 1-2 hours.',
      location: 'Library',
      category: 'Tech',
      urgency: 'Soon',
      icon: Icons.bolt_rounded,
    ),
    _QuickTemplate(
      title: 'Need study material',
      description: 'Looking for unit notes, PDFs, or slides for an upcoming class or exam.',
      location: 'Library',
      category: 'Study',
      studyResourceType: 'Study Material',
      urgency: 'Flexible',
      icon: Icons.menu_book_rounded,
    ),
    _QuickTemplate(
      title: 'Need previous sem questions',
      description: 'Looking for previous semester question papers to practice before exams.',
      location: 'Department Block',
      category: 'Study',
      studyResourceType: 'Previous Semester Questions',
      urgency: 'Soon',
      icon: Icons.quiz_outlined,
    ),
    _QuickTemplate(
      title: 'Need semester books',
      description: 'Looking for textbooks or reference books for this semester subjects.',
      location: 'Library',
      category: 'Study',
      studyResourceType: 'Books',
      urgency: 'Flexible',
      icon: Icons.library_books_rounded,
    ),
    _QuickTemplate(
      title: 'Need a quick ride',
      description: 'Looking for a short ride to the main gate or bus stop after class.',
      location: 'Main Gate',
      category: 'Travel',
      urgency: 'Urgent',
      icon: Icons.directions_car_filled_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final initialPost = widget.initialPost;
    if (initialPost == null) {
      return;
    }
    _titleController.text = initialPost.title;
    _descriptionController.text = initialPost.description;
    _locationController.text = initialPost.location;
    _imageUrl = initialPost.imageUrl;
    _selectedCategory = initialPost.category;
    _selectedStudyResourceType = initialPost.studyResourceType.isEmpty
        ? studyResourceTypes.first
        : initialPost.studyResourceType;
    _selectedUrgency = initialPost.urgency;
    _isAnonymous = initialPost.isAnonymous;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (pickedFile == null) {
      return;
    }
    setState(() {
      _selectedImageFile = File(pickedFile.path);
    });
  }

  Future<void> _uploadSelectedImage() async {
    final file = _selectedImageFile;
    if (file == null) {
      return;
    }
    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0;
    });
    try {
      final uploadId =
          widget.initialPost?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final uploadedUrl = await StorageService.uploadImageFile(
        file: file,
        postId: uploadId,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() => _uploadProgress = progress);
        },
      );
      if (!mounted) {
        return;
      }
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed. Please try again.')),
        );
        return;
      }
      setState(() {
        _imageUrl = uploadedUrl;
        _selectedImageFile = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final currentUser = _authService.currentUser;
    if (currentUser?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in to post.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_selectedImageFile != null) {
        await _uploadSelectedImage();
      }
      final existing = widget.initialPost;
      final createdAt = existing?.timestamp ?? DateTime.now();
      final post = PostModel(
        id: existing?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        postedBy: currentUser!.email!,
        createdByUid: currentUser.uid,
        timestamp: createdAt,
        category: _selectedCategory,
        studyResourceType:
            _selectedCategory == 'Study' ? _selectedStudyResourceType : '',
        urgency: _selectedUrgency,
        location: _locationController.text.trim(),
        status: existing?.status ?? 'Open',
        expiresAt: DateTime.now().add(_expiryDuration),
        helperIds: existing?.helperIds ?? const <String>[],
        imageUrl: _imageUrl,
        isAnonymous: _isAnonymous,
        resolvedHelperUid: existing?.resolvedHelperUid ?? '',
        resolvedHelperEmail: existing?.resolvedHelperEmail ?? '',
        resolvedThankYou: existing?.resolvedThankYou ?? '',
        resolvedRating: existing?.resolvedRating,
      );

      if (widget.isEditing) {
        await _dbService.updatePost(post);
      } else {
        await _dbService.createNewPost(post);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'Request updated.' : 'Request posted.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _applyTemplate(_QuickTemplate template) {
    setState(() {
      _titleController.text = template.title;
      _descriptionController.text = template.description;
      _locationController.text = template.location;
      _selectedCategory = template.category;
      _selectedStudyResourceType = template.studyResourceType.isEmpty
          ? studyResourceTypes.first
          : template.studyResourceType;
      _selectedUrgency = template.urgency;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentEmail = _authService.currentUser?.email ?? 'student@campus.edu';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Request' : 'Create Request'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroBanner(isEditing: widget.isEditing),
                if (!widget.isEditing) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Quick start',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 126,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _templates.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _TemplateCard(
                        template: _templates[index],
                        onTap: () => _applyTemplate(_templates[index]),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Request details',
                  subtitle: 'Give helpers enough context to act quickly.',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Need charger near Block B',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) =>
                            (value?.trim().length ?? 0) < 4 ? 'Please add a clearer title.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Add what you need, when you need it, and any helpful context.',
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 70),
                            child: Icon(Icons.notes_rounded),
                          ),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) =>
                            (value?.trim().length ?? 0) < 10 ? 'Add a few more details.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'Library, canteen, hostel gate',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) =>
                            (value?.trim().isEmpty ?? true) ? 'Location helps nearby students respond.' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: postCategories
                                  .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedCategory = value;
                                    if (value != 'Study') {
                                      _selectedStudyResourceType =
                                          studyResourceTypes.first;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedUrgency,
                              decoration: const InputDecoration(
                                labelText: 'Urgency',
                                prefixIcon: Icon(Icons.local_fire_department_outlined),
                              ),
                              items: postUrgencies
                                  .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedUrgency = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_selectedCategory == 'Study') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedStudyResourceType,
                          decoration: const InputDecoration(
                            labelText: 'Study type',
                            prefixIcon: Icon(Icons.library_books_outlined),
                          ),
                          items: studyResourceTypes
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(
                                () => _selectedStudyResourceType = value,
                              );
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Duration>(
                        initialValue: _expiryDuration,
                        decoration: const InputDecoration(
                          labelText: 'Expires in',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        items: _expiryOptions
                            .map((value) => DropdownMenuItem<Duration>(value: value, child: Text(_expiryLabel(value))))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _expiryDuration = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile.adaptive(
                        value: _isAnonymous,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) => setState(() => _isAnonymous = value),
                        title: const Text('Post anonymously'),
                        subtitle: const Text('Useful for sensitive asks while keeping moderation active.'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Media attachment',
                  subtitle: 'Attach a screenshot or photo when context matters.',
                  child: Column(
                    children: [
                      _AttachmentCard(
                        localFile: _selectedImageFile,
                        imageUrl: _imageUrl,
                        isUploading: _isUploadingImage,
                        progress: _uploadProgress,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isUploadingImage ? null : () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isUploadingImage ? null : () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Camera'),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedImageFile != null) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isUploadingImage ? null : _uploadSelectedImage,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Upload attachment'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _PreviewCard(
                  title: _titleController.text.trim(),
                  description: _descriptionController.text.trim(),
                  email: currentEmail,
                  category: _selectedCategory,
                  studyResourceType: _selectedCategory == 'Study'
                      ? _selectedStudyResourceType
                      : '',
                  urgency: _selectedUrgency,
                  location: _locationController.text.trim(),
                  expiresInLabel: _expiryLabel(_expiryDuration),
                  imageUrl: _imageUrl,
                  localImage: _selectedImageFile,
                  isAnonymous: _isAnonymous,
                ),
                const SizedBox(height: 20),
                CustomButton(
                  label: widget.isEditing ? 'Save Changes' : 'Post Request',
                  icon: widget.isEditing ? Icons.save_outlined : Icons.send_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _submitPost,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0F172A), Color(0xFF2563EB), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isEditing ? Icons.edit_note_rounded : Icons.campaign_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isEditing ? 'Polish your request' : 'Ask for help clearly',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.localFile,
    required this.imageUrl,
    required this.isUploading,
    required this.progress,
  });

  final File? localFile;
  final String imageUrl;
  final bool isUploading;
  final double progress;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (localFile != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.file(localFile!, fit: BoxFit.cover),
      );
    } else if (imageUrl.trim().isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(imageUrl, fit: BoxFit.cover),
      );
    } else {
      child = const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 40));
    }

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (isUploading) Align(alignment: Alignment.bottomCenter, child: LinearProgressIndicator(value: progress)),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});

  final _QuickTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(14)),
              child: Icon(template.icon, color: const Color(0xFF0369A1)),
            ),
            const Spacer(),
            Text(template.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${template.category} • ${template.location}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.description,
    required this.email,
    required this.category,
    required this.studyResourceType,
    required this.urgency,
    required this.location,
    required this.expiresInLabel,
    required this.imageUrl,
    required this.localImage,
    required this.isAnonymous,
  });

  final String title;
  final String description;
  final String email;
  final String category;
  final String studyResourceType;
  final String urgency;
  final String location;
  final String expiresInLabel;
  final String imageUrl;
  final File? localImage;
  final bool isAnonymous;

  @override
  Widget build(BuildContext context) {
    final hasImage = localImage != null || imageUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live preview', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: localImage != null
                  ? Image.file(localImage!, height: 170, width: double.infinity, fit: BoxFit.cover)
                  : Image.network(imageUrl, height: 170, width: double.infinity, fit: BoxFit.cover),
            ),
          if (hasImage) const SizedBox(height: 14),
          Text(title.isEmpty ? 'Your request title will show here' : title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(description.isEmpty ? 'Add more detail so nearby students know how to help.' : description),
          const SizedBox(height: 12),
          Text('$category • $urgency • ${location.isEmpty ? 'Location pending' : location}'),
          const SizedBox(height: 6),
          Text(expiresInLabel),
          const SizedBox(height: 6),
          Text(isAnonymous ? 'Anonymous Student' : email),
        ],
      ),
    );
  }
}

class _QuickTemplate {
  const _QuickTemplate({
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    this.studyResourceType = '',
    required this.urgency,
    required this.icon,
  });

  final String title;
  final String description;
  final String location;
  final String category;
  final String studyResourceType;
  final String urgency;
  final IconData icon;
}

const List<Duration> _expiryOptions = <Duration>[
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(hours: 24),
  Duration(days: 3),
];

String _expiryLabel(Duration duration) {
  if (duration.inHours < 24) {
    return 'Expires in ${duration.inHours}h';
  }
  return 'Expires in ${duration.inDays}d';
}
