import 'package:go_router/go_router.dart';

import '../features/editor/presentation/file_editor_page.dart';
import '../features/glossary/presentation/glossary_page.dart';
import '../features/project/presentation/home_page.dart';
import '../features/project/presentation/project_page.dart';

/// Chemins de l'application.
abstract final class Routes {
  static const home = '/';
  static const project = '/project';

  static const glossary = '/glossary';

  /// Éditeur du fichier [id].
  static String file(int id) => '/file/$id';
}

/// Crée le routeur (go_router). Les écrans des tâches suivantes s'ajoutent ici.
GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
    GoRoute(path: Routes.project, builder: (_, _) => const ProjectPage()),
    GoRoute(path: Routes.glossary, builder: (_, _) => const GlossaryPage()),
    GoRoute(
      path: '/file/:id',
      builder: (_, state) =>
          FileEditorPage(fileId: int.parse(state.pathParameters['id']!)),
    ),
  ],
);
