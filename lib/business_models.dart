import 'dart:convert';

enum BusinessProductStatus {
  saved,
  toAnalyze,
  readyToTest,
  testing,
  potential,
  rejected,
}

enum BusinessTestStatus { planned, active, completed }

enum BusinessTestDecision { continueTesting, changeApproach, reject }

enum BusinessPlatform { tiktok, instagram, facebook, other }

enum BusinessIdeaStatus { fresh, toCheck, done }

enum BusinessFocusState { running, paused, completed, abandoned }

String _enumName(Object value) => value.toString().split('.').last;
T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.where((value) => _enumName(value) == raw).firstOrNull ?? fallback;

class BusinessProduct {
  const BusinessProduct({
    required this.id,
    required this.name,
    required this.status,
    required this.addedAt,
    this.imageLocalPath,
    this.imageStoragePath,
    this.imageUrl,
    this.inspirationUrl,
    this.supplierUrl,
    this.purchasePriceCents,
    this.sellingPriceCents,
    this.shippingCostCents = 0,
    this.adCostCents = 0,
    this.otherCostCents = 0,
    this.category = '',
    this.problem = '',
    this.angles = const [],
    this.notes = '',
    this.criteria = const [null, null, null, null, null],
    this.updatedAt,
  });

  final String id;
  final String name;
  final BusinessProductStatus status;
  final DateTime addedAt;
  final String? imageLocalPath, imageStoragePath, imageUrl;
  final String? inspirationUrl, supplierUrl;
  final int? purchasePriceCents, sellingPriceCents;
  final int shippingCostCents, adCostCents, otherCostCents;
  final String category, problem, notes;
  final List<String> angles;
  final List<bool?> criteria;
  final DateTime? updatedAt;

  int? get estimatedMarginCents => sellingPriceCents == null
      ? null
      : sellingPriceCents! -
            (purchasePriceCents ?? 0) -
            shippingCostCents -
            adCostCents -
            otherCostCents;
  double? get estimatedMarginPercent =>
      sellingPriceCents == null || sellingPriceCents == 0
      ? null
      : estimatedMarginCents! * 100 / sellingPriceCents!;
  int get qualificationScore =>
      criteria.where((answer) => answer == true).length;
  int get checkedCriteria => criteria.where((answer) => answer != null).length;

  BusinessProduct copyWith({
    String? name,
    BusinessProductStatus? status,
    String? imageLocalPath,
    String? imageStoragePath,
    String? imageUrl,
    String? inspirationUrl,
    String? supplierUrl,
    int? purchasePriceCents,
    int? sellingPriceCents,
    int? shippingCostCents,
    int? adCostCents,
    int? otherCostCents,
    String? category,
    String? problem,
    List<String>? angles,
    String? notes,
    List<bool?>? criteria,
    DateTime? updatedAt,
  }) => BusinessProduct(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    addedAt: addedAt,
    imageLocalPath: imageLocalPath ?? this.imageLocalPath,
    imageStoragePath: imageStoragePath ?? this.imageStoragePath,
    imageUrl: imageUrl ?? this.imageUrl,
    inspirationUrl: inspirationUrl ?? this.inspirationUrl,
    supplierUrl: supplierUrl ?? this.supplierUrl,
    purchasePriceCents: purchasePriceCents ?? this.purchasePriceCents,
    sellingPriceCents: sellingPriceCents ?? this.sellingPriceCents,
    shippingCostCents: shippingCostCents ?? this.shippingCostCents,
    adCostCents: adCostCents ?? this.adCostCents,
    otherCostCents: otherCostCents ?? this.otherCostCents,
    category: category ?? this.category,
    problem: problem ?? this.problem,
    angles: angles ?? this.angles,
    notes: notes ?? this.notes,
    criteria: criteria ?? this.criteria,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': _enumName(status),
    'addedAt': addedAt.toUtc().toIso8601String(),
    'imageLocalPath': imageLocalPath,
    'imageStoragePath': imageStoragePath,
    'imageUrl': imageUrl,
    'inspirationUrl': inspirationUrl,
    'supplierUrl': supplierUrl,
    'purchasePriceCents': purchasePriceCents,
    'sellingPriceCents': sellingPriceCents,
    'shippingCostCents': shippingCostCents,
    'adCostCents': adCostCents,
    'otherCostCents': otherCostCents,
    'category': category,
    'problem': problem,
    'angles': angles,
    'notes': notes,
    'criteria': criteria,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  factory BusinessProduct.fromJson(Map<String, dynamic> json) =>
      BusinessProduct(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        status: _enumValue(
          BusinessProductStatus.values,
          json['status'],
          BusinessProductStatus.saved,
        ),
        addedAt:
            DateTime.tryParse(json['addedAt'] as String? ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
        imageLocalPath: json['imageLocalPath'] as String?,
        imageStoragePath: json['imageStoragePath'] as String?,
        imageUrl: json['imageUrl'] as String?,
        inspirationUrl: json['inspirationUrl'] as String?,
        supplierUrl: json['supplierUrl'] as String?,
        purchasePriceCents: (json['purchasePriceCents'] as num?)?.toInt(),
        sellingPriceCents: (json['sellingPriceCents'] as num?)?.toInt(),
        shippingCostCents: (json['shippingCostCents'] as num?)?.toInt() ?? 0,
        adCostCents: (json['adCostCents'] as num?)?.toInt() ?? 0,
        otherCostCents: (json['otherCostCents'] as num?)?.toInt() ?? 0,
        category: json['category'] as String? ?? '',
        problem: json['problem'] as String? ?? '',
        angles: (json['angles'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        notes: json['notes'] as String? ?? '',
        criteria: [
          ...(json['criteria'] as List? ?? const [])
              .take(5)
              .map((value) => value as bool?),
          ...List<bool?>.filled(
            5 -
                ((json['criteria'] as List? ?? const []).length
                    .clamp(0, 5)
                    .toInt()),
            null,
          ),
        ],
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')
            ?.toUtc(),
      );
}

class BusinessVideo {
  const BusinessVideo({
    required this.id,
    required this.platform,
    this.title = '',
    this.url,
    this.publishedAt,
    this.views,
    this.retentionPercent,
    this.clicks,
  });
  final String id, title;
  final BusinessPlatform platform;
  final String? url;
  final DateTime? publishedAt;
  final int? views, clicks;
  final double? retentionPercent;
  Map<String, dynamic> toJson() => {
    'id': id,
    'platform': _enumName(platform),
    'title': title,
    'url': url,
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
    'views': views,
    'retentionPercent': retentionPercent,
    'clicks': clicks,
  };
  factory BusinessVideo.fromJson(Map<String, dynamic> json) => BusinessVideo(
    id: json['id'] as String,
    platform: _enumValue(
      BusinessPlatform.values,
      json['platform'],
      BusinessPlatform.other,
    ),
    title: json['title'] as String? ?? '',
    url: json['url'] as String?,
    publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '')
        ?.toUtc(),
    views: (json['views'] as num?)?.toInt(),
    clicks: (json['clicks'] as num?)?.toInt(),
    retentionPercent: (json['retentionPercent'] as num?)?.toDouble(),
  );
}

class BusinessTest {
  const BusinessTest({
    required this.id,
    required this.productId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.startAt,
    this.endAt,
    this.plannedCreatives = 0,
    this.angles = const [],
    this.videos = const [],
    this.orders,
    this.revenueCents,
    this.notes = '',
    this.conclusion = '',
    this.decision,
  });
  final String id, productId, name, notes, conclusion;
  final BusinessTestStatus status;
  final DateTime createdAt;
  final DateTime? startAt, endAt;
  final int plannedCreatives;
  final List<String> angles;
  final List<BusinessVideo> videos;
  final int? orders, revenueCents;
  final BusinessTestDecision? decision;
  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'name': name,
    'status': _enumName(status),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'startAt': startAt?.toUtc().toIso8601String(),
    'endAt': endAt?.toUtc().toIso8601String(),
    'plannedCreatives': plannedCreatives,
    'angles': angles,
    'videos': videos.map((v) => v.toJson()).toList(),
    'orders': orders,
    'revenueCents': revenueCents,
    'notes': notes,
    'conclusion': conclusion,
    'decision': decision == null ? null : _enumName(decision!),
  };
  factory BusinessTest.fromJson(Map<String, dynamic> json) => BusinessTest(
    id: json['id'] as String,
    productId: json['productId'] as String,
    name: json['name'] as String? ?? '',
    status: _enumValue(
      BusinessTestStatus.values,
      json['status'],
      BusinessTestStatus.planned,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    startAt: DateTime.tryParse(json['startAt'] as String? ?? '')?.toUtc(),
    endAt: DateTime.tryParse(json['endAt'] as String? ?? '')?.toUtc(),
    plannedCreatives: (json['plannedCreatives'] as num?)?.toInt() ?? 0,
    angles: (json['angles'] as List? ?? const []).whereType<String>().toList(),
    videos: (json['videos'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => BusinessVideo.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    orders: (json['orders'] as num?)?.toInt(),
    revenueCents: (json['revenueCents'] as num?)?.toInt(),
    notes: json['notes'] as String? ?? '',
    conclusion: json['conclusion'] as String? ?? '',
    decision: json['decision'] == null
        ? null
        : _enumValue(
            BusinessTestDecision.values,
            json['decision'],
            BusinessTestDecision.continueTesting,
          ),
  );
}

class BusinessWorkflowStep {
  const BusinessWorkflowStep({required this.title, required this.minutes});
  final String title;
  final int minutes;
  Map<String, dynamic> toJson() => {'title': title, 'minutes': minutes};
  factory BusinessWorkflowStep.fromJson(Map<String, dynamic> json) =>
      BusinessWorkflowStep(
        title: json['title'] as String? ?? '',
        minutes: (json['minutes'] as num?)?.toInt() ?? 1,
      );
}

class BusinessWorkflow {
  const BusinessWorkflow({
    required this.id,
    required this.name,
    required this.steps,
    this.isPreset = false,
  });
  final String id, name;
  final List<BusinessWorkflowStep> steps;
  final bool isPreset;
  int get totalMinutes => steps.fold(0, (total, step) => total + step.minutes);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'steps': steps.map((s) => s.toJson()).toList(),
    'isPreset': isPreset,
  };
  factory BusinessWorkflow.fromJson(Map<String, dynamic> json) =>
      BusinessWorkflow(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        steps: (json['steps'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) =>
                  BusinessWorkflowStep.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
        isPreset: json['isPreset'] as bool? ?? false,
      );
}

class BusinessFocusSession {
  const BusinessFocusSession({
    required this.id,
    required this.workflowId,
    required this.workflowName,
    required this.steps,
    required this.stepIndex,
    required this.state,
    required this.startedAt,
    required this.remainingSeconds,
    this.lastResumedAt,
    this.endedAt,
  });
  final String id, workflowId, workflowName;
  final List<BusinessWorkflowStep> steps;
  final int stepIndex, remainingSeconds;
  final BusinessFocusState state;
  final DateTime startedAt;
  final DateTime? lastResumedAt, endedAt;
  factory BusinessFocusSession.start({
    required String id,
    required BusinessWorkflow workflow,
    required DateTime startedAt,
  }) => BusinessFocusSession(
    id: id,
    workflowId: workflow.id,
    workflowName: workflow.name,
    steps: workflow.steps,
    stepIndex: 0,
    state: BusinessFocusState.running,
    startedAt: startedAt.toUtc(),
    remainingSeconds: (workflow.steps.firstOrNull?.minutes ?? 1) * 60,
    lastResumedAt: startedAt.toUtc(),
  );
  Duration remainingAt(DateTime now) {
    final elapsed = state == BusinessFocusState.running && lastResumedAt != null
        ? now.toUtc().difference(lastResumedAt!).inSeconds
        : 0;
    return Duration(seconds: remainingSeconds - elapsed);
  }

  BusinessFocusSession copyWith({
    int? stepIndex,
    int? remainingSeconds,
    BusinessFocusState? state,
    DateTime? lastResumedAt,
    DateTime? endedAt,
  }) => BusinessFocusSession(
    id: id,
    workflowId: workflowId,
    workflowName: workflowName,
    steps: steps,
    stepIndex: stepIndex ?? this.stepIndex,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    state: state ?? this.state,
    startedAt: startedAt,
    lastResumedAt: lastResumedAt ?? this.lastResumedAt,
    endedAt: endedAt ?? this.endedAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'workflowId': workflowId,
    'workflowName': workflowName,
    'steps': steps.map((s) => s.toJson()).toList(),
    'stepIndex': stepIndex,
    'state': _enumName(state),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'remainingSeconds': remainingSeconds,
    'lastResumedAt': lastResumedAt?.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
  };
  factory BusinessFocusSession.fromJson(Map<String, dynamic> json) =>
      BusinessFocusSession(
        id: json['id'] as String,
        workflowId: json['workflowId'] as String,
        workflowName: json['workflowName'] as String? ?? '',
        steps: (json['steps'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) =>
                  BusinessWorkflowStep.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
        stepIndex: (json['stepIndex'] as num?)?.toInt() ?? 0,
        state: _enumValue(
          BusinessFocusState.values,
          json['state'],
          BusinessFocusState.paused,
        ),
        startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
        remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 0,
        lastResumedAt: DateTime.tryParse(json['lastResumedAt'] as String? ?? '')
            ?.toUtc(),
        endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '')?.toUtc(),
      );
}

class BusinessIdea {
  const BusinessIdea({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.description = '',
    this.url,
    this.productId,
    this.taskId,
  });
  final String id, title, description;
  final BusinessIdeaStatus status;
  final DateTime createdAt;
  final String? url, productId, taskId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': _enumName(status),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'url': url,
    'productId': productId,
    'taskId': taskId,
  };
  factory BusinessIdea.fromJson(Map<String, dynamic> json) => BusinessIdea(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    status: _enumValue(
      BusinessIdeaStatus.values,
      json['status'],
      BusinessIdeaStatus.fresh,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    url: json['url'] as String?,
    productId: json['productId'] as String?,
    taskId: json['taskId'] as String?,
  );
}

class BusinessSnapshot {
  const BusinessSnapshot({
    this.products = const [],
    this.tests = const [],
    this.workflows = const [],
    this.sessions = const [],
    this.ideas = const [],
    this.pending = const [],
  });
  final List<BusinessProduct> products;
  final List<BusinessTest> tests;
  final List<BusinessWorkflow> workflows;
  final List<BusinessFocusSession> sessions;
  final List<BusinessIdea> ideas;
  final List<Map<String, dynamic>> pending;
  int get activeTests =>
      tests.where((test) => test.status == BusinessTestStatus.active).length;
  int get publishedVideos => tests.fold(
    0,
    (sum, test) =>
        sum + test.videos.where((video) => video.publishedAt != null).length,
  );
  int get completedSessions => sessions
      .where((session) => session.state == BusinessFocusState.completed)
      .length;
  String encode() => jsonEncode({
    'products': products.map((e) => e.toJson()).toList(),
    'tests': tests.map((e) => e.toJson()).toList(),
    'workflows': workflows.map((e) => e.toJson()).toList(),
    'sessions': sessions.map((e) => e.toJson()).toList(),
    'ideas': ideas.map((e) => e.toJson()).toList(),
    'pending': pending,
  });
  factory BusinessSnapshot.decode(String raw) {
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    List<T> list<T>(String key, T Function(Map<String, dynamic>) fromJson) =>
        (map[key] as List? ?? const [])
            .whereType<Map>()
            .map((e) => fromJson(Map<String, dynamic>.from(e)))
            .toList();
    return BusinessSnapshot(
      products: list('products', BusinessProduct.fromJson),
      tests: list('tests', BusinessTest.fromJson),
      workflows: list('workflows', BusinessWorkflow.fromJson),
      sessions: list('sessions', BusinessFocusSession.fromJson),
      ideas: list('ideas', BusinessIdea.fromJson),
      pending: (map['pending'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}
