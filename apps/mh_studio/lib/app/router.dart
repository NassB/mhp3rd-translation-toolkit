import 'package:go_router/go_router.dart';

import '../features/project/presentation/home_page.dart';
import '../features/project/presentation/project_page.dart';

/// Chemins de l'application.
abstract final class Routes {
  static const home = '/';
  static const project = '/project';
}

/// Crée le routeur (go_router). Les écrans des tâches suivantes s'ajoutent ici.
GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
    GoRoute(path: Routes.project, builder: (_, _) => const ProjectPage()),
  ],
);
