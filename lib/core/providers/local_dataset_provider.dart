import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_dataset_service.dart';

/// Singleton-scoped provider. The service itself is a singleton
/// ([LocalDatasetService.instance]); this provider exists so widgets/tests
/// can override it and so we have a single import site for the dependency.
final localDatasetProvider = Provider<LocalDatasetService>((ref) {
  return LocalDatasetService.instance;
});
