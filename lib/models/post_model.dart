import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> postCategories = <String>[
  'General',
  'Tech',
  'Study',
  'Travel',
  'Food',
  'Stay',
];

const List<String> studyResourceTypes = <String>[
  'Study Material',
  'Previous Semester Questions',
  'Books',
];

const List<String> postUrgencies = <String>['Flexible', 'Soon', 'Urgent'];

const List<String> postStatuses = <String>['Open', 'In Progress', 'Resolved'];

class PostModel {
  const PostModel({
    required this.id,
    required this.title,
    required this.description,
    required this.postedBy,
    required this.createdByUid,
    required this.timestamp,
    required this.category,
    required this.studyResourceType,
    required this.urgency,
    required this.location,
    required this.status,
    required this.expiresAt,
    required this.helperIds,
    required this.imageUrl,
    required this.isAnonymous,
    required this.resolvedHelperUid,
    required this.resolvedHelperEmail,
    required this.resolvedThankYou,
    required this.resolvedRating,
  });

  final String id;
  final String title;
  final String description;
  final String postedBy;
  final String createdByUid;
  final DateTime timestamp;
  final String category;
  final String studyResourceType;
  final String urgency;
  final String location;
  final String status;
  final DateTime expiresAt;
  final List<String> helperIds;
  final String imageUrl;
  final bool isAnonymous;
  final String resolvedHelperUid;
  final String resolvedHelperEmail;
  final String resolvedThankYou;
  final int? resolvedRating;

  int get helperCount => helperIds.length;
  bool get isExpired => expiresAt.isBefore(DateTime.now());
  bool get isResolved => status == 'Resolved';
  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasResolutionFeedback =>
      resolvedHelperUid.isNotEmpty ||
      resolvedThankYou.isNotEmpty ||
      resolvedRating != null;
  String get displayAuthor =>
      isAnonymous ? 'Anonymous Student' : postedBy.trim();

  factory PostModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawTimestamp = map['timestamp'];
    final rawExpiresAt = map['expiresAt'];
    final title = (map['title'] as String? ?? '').trim();
    final description = (map['description'] as String? ?? '').trim();

    return PostModel(
      id: docId,
      title: title,
      description: description,
      postedBy: (map['postedBy'] as String? ?? '').trim(),
      createdByUid: (map['createdByUid'] as String? ?? '').trim(),
      timestamp: _asDateTime(rawTimestamp) ?? DateTime.now(),
      category: _normalizeCategory(
        (map['category'] as String?)?.trim(),
        title,
        description,
      ),
      studyResourceType: _normalizeStudyResourceType(
        (map['studyResourceType'] as String?)?.trim(),
        (map['category'] as String?)?.trim(),
        title,
        description,
      ),
      urgency: _normalizeUrgency(
        (map['urgency'] as String?)?.trim(),
        title,
        description,
      ),
      location: (map['location'] as String? ?? '').trim(),
      status: _normalizeStatus((map['status'] as String?)?.trim()),
      expiresAt:
          _asDateTime(rawExpiresAt) ??
          DateTime.now().add(const Duration(hours: 24)),
      helperIds: ((map['helperIds'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      imageUrl: (map['imageUrl'] as String? ?? '').trim(),
      isAnonymous: map['isAnonymous'] as bool? ?? false,
      resolvedHelperUid: (map['resolvedHelperUid'] as String? ?? '').trim(),
      resolvedHelperEmail: (map['resolvedHelperEmail'] as String? ?? '').trim(),
      resolvedThankYou: (map['resolvedThankYou'] as String? ?? '').trim(),
      resolvedRating: (map['resolvedRating'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'postedBy': postedBy.trim(),
      'createdByUid': createdByUid.trim(),
      'timestamp': Timestamp.fromDate(timestamp),
      'category': _normalizeCategory(category, title, description),
      'studyResourceType': _normalizeStudyResourceType(
        studyResourceType,
        category,
        title,
        description,
      ),
      'urgency': _normalizeUrgency(urgency, title, description),
      'location': location.trim(),
      'status': _normalizeStatus(status),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'helperIds': helperIds,
      'imageUrl': imageUrl.trim(),
      'isAnonymous': isAnonymous,
      'resolvedHelperUid': resolvedHelperUid.trim(),
      'resolvedHelperEmail': resolvedHelperEmail.trim(),
      'resolvedThankYou': resolvedThankYou.trim(),
      'resolvedRating': resolvedRating,
    };
  }

  PostModel copyWith({
    String? id,
    String? title,
    String? description,
    String? postedBy,
    String? createdByUid,
    DateTime? timestamp,
    String? category,
    String? studyResourceType,
    String? urgency,
    String? location,
    String? status,
    DateTime? expiresAt,
    List<String>? helperIds,
    String? imageUrl,
    bool? isAnonymous,
    String? resolvedHelperUid,
    String? resolvedHelperEmail,
    String? resolvedThankYou,
    int? resolvedRating,
    bool clearResolvedRating = false,
  }) {
    return PostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      postedBy: postedBy ?? this.postedBy,
      createdByUid: createdByUid ?? this.createdByUid,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      studyResourceType: studyResourceType ?? this.studyResourceType,
      urgency: urgency ?? this.urgency,
      location: location ?? this.location,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      helperIds: helperIds ?? this.helperIds,
      imageUrl: imageUrl ?? this.imageUrl,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      resolvedHelperUid: resolvedHelperUid ?? this.resolvedHelperUid,
      resolvedHelperEmail: resolvedHelperEmail ?? this.resolvedHelperEmail,
      resolvedThankYou: resolvedThankYou ?? this.resolvedThankYou,
      resolvedRating: clearResolvedRating
          ? null
          : resolvedRating ?? this.resolvedRating,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static String _normalizeCategory(
    String? value,
    String title,
    String description,
  ) {
    if (value != null && postCategories.contains(value)) {
      return value;
    }

    final text = '$title $description'.toLowerCase();
    if (_containsAny(text, <String>[
      'charger',
      'laptop',
      'phone',
      'cable',
      'usb',
    ])) {
      return 'Tech';
    }
    if (_containsAny(text, <String>[
      'book',
      'notes',
      'assignment',
      'lab',
      'calculator',
    ])) {
      return 'Study';
    }
    if (_containsAny(text, <String>['ride', 'lift', 'bus', 'travel', 'drop'])) {
      return 'Travel';
    }
    if (_containsAny(text, <String>[
      'food',
      'water',
      'snack',
      'coffee',
      'meal',
    ])) {
      return 'Food';
    }
    if (_containsAny(text, <String>['room', 'hostel', 'flat', 'stay'])) {
      return 'Stay';
    }
    return 'General';
  }

  static String _normalizeStudyResourceType(
    String? value,
    String? category,
    String title,
    String description,
  ) {
    final normalizedCategory = _normalizeCategory(category, title, description);
    if (normalizedCategory != 'Study') {
      return '';
    }

    if (value != null && studyResourceTypes.contains(value)) {
      return value;
    }

    final text = '$title $description'.toLowerCase();
    if (_containsAny(text, <String>[
      'question paper',
      'previous year',
      'previous semester',
      'prev sem',
      'pyq',
      'semester question',
      'sem question',
    ])) {
      return 'Previous Semester Questions';
    }
    if (_containsAny(text, <String>['book', 'books', 'textbook', 'guide'])) {
      return 'Books';
    }
    if (_containsAny(text, <String>[
      'study material',
      'material',
      'notes',
      'module',
      'pdf',
      'slides',
    ])) {
      return 'Study Material';
    }
    return studyResourceTypes.first;
  }

  static String _normalizeUrgency(
    String? value,
    String title,
    String description,
  ) {
    if (value != null && postUrgencies.contains(value)) {
      return value;
    }

    final text = '$title $description'.toLowerCase();
    if (_containsAny(text, <String>[
      'urgent',
      'asap',
      'immediately',
      'now',
      'emergency',
    ])) {
      return 'Urgent';
    }
    if (_containsAny(text, <String>[
      'today',
      'soon',
      'quick',
      'before class',
    ])) {
      return 'Soon';
    }
    return 'Flexible';
  }

  static String _normalizeStatus(String? value) {
    if (value != null && postStatuses.contains(value)) {
      return value;
    }
    return 'Open';
  }

  static bool _containsAny(String text, List<String> words) {
    return words.any(text.contains);
  }
}
