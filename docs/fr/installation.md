# Installation (français)

Prérequis : `bash` 3.2+, `git`, `jq`. Tous les scanners sont optionnels.

1. **Cloner le dépôt**
   ```bash
   git clone https://github.com/IbrahimCodeur/saas-blind-security.git
   cd saas-blind-security && ./scripts/validate-environment.sh
   ```
2. **Copier le framework dans votre projet**
   ```bash
   ./scripts/install.sh --dry-run /chemin/vers/mon-saas   # aperçu
   ./scripts/install.sh /chemin/vers/mon-saas
   ```
   Les scripts et configurations vont dans `.saas-blind-security/`, les workflows dans `.github/workflows/`,
   les compétences dans `.claude/skills/`. Aucun fichier existant n'est écrasé sans `--force`. Si votre projet
   possède déjà un `CLAUDE.md`, ajoutez-y la ligne `@.saas-blind-security/CLAUDE.security.md`.
3. **Configurer les variables et secrets** : `.saas-blind-security/sbs.conf` en local ; dans GitHub, le secret
   optionnel `SNYK_TOKEN` et les variables `SBS_FAIL_ON_SEVERITY`, `SBS_ZAP_TARGET`, `SBS_ZAP_ALLOWED_HOSTS`,
   `SBS_ZAP_PRODUCTION_HOSTS` (voir [configuration](../configuration.md)).
4. **Activer les workflows** : commit + push, puis
   `./.saas-blind-security/scripts/configure-github-security.sh PROPRIETAIRE/DEPOT --dry-run`
   (alertes Dependabot, secret scanning, push protection, protection de branche).
5. **Lancer le premier audit**
   ```bash
   ./.saas-blind-security/scripts/security-check.sh --check-only
   ./.saas-blind-security/scripts/security-check.sh --report
   ```
6. **Examiner le rapport** `.sbs-results/<horodatage>/report.md` — commencez par le tableau *Coverage* :
   un outil qui n'a pas tourné signifie une zone non vérifiée.
7. **Corriger** avec votre agent IA (instructions `CLAUDE.md`, compétence `security-remediation`), puis relancer
   l'audit et comparer.

Rappel : l'absence d'alerte ne prouve jamais qu'une application est sécurisée.
