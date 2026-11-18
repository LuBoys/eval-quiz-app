# 08 - Documentation technique de Quiz App

Ce guide décrit l’application et les réglages de la solution du groupe. Pour voir comment démarrer le quiz ou le mettre en ligne, consulte les guides [Docker Compose](10-demarrage-local.md) et [Architecture Azure](13-architecture-cloud.md).

## 1. Présentation

**Quiz App** propose des questionnaires sur des sujets techniques comme DevOps et Docker. Elle permet de s’inscrire, d’enregistrer ses résultats dans PostgreSQL et de les consulter dans un espace d’administration. L’envoi des résultats par email via Resend est facultatif.

Le frontend charge les questionnaires dans les fichiers `questions_*.js`. Le sujet `docker` utilise [questions_docker.js](../questions_docker.js). Une modification de ce fichier permet de montrer le parcours d’une Pull Request jusqu’au quiz en ligne.

## 2. Composants et ports

| Composant | Rôle | Port ou adresse |
| --- | --- | --- |
| Vite | Serveur de développement du frontend | `5173` quand tu lances `npm run dev` à la racine |
| Nginx | Sert les pages et transmet les requêtes au backend | `8080` dans le conteneur, `127.0.0.1:8087` par défaut sur ton ordinateur et adresse HTTPS publique sur Azure |
| Backend Node.js | API Express dans `backend/server.js` | `3007` sur le réseau interne de Docker Compose ou de Container Apps |
| PostgreSQL | Stocke les utilisateurs, les scores et les réponses | `db:5432` avec la base Docker Compose, adresse Neon dans `DATABASE_URL` sur Azure |
| Resend | Envoie les résultats par email | Service externe utilisé si une clé est configurée |

Avec Docker Compose, ouvre [le quiz](http://localhost:8087) ou [l’administration](http://localhost:8087/gestion-quiz). Si tu modifies `QUIZ_PORT`, utilise le port choisi. Sur Azure, ouvre les mêmes chemins `/` et `/gestion-quiz` depuis l’adresse publique du frontend. [Configuration Nginx](../nginx/nginx.conf)

## 3. Développer hors Docker

Les Dockerfiles utilisent Node.js 24. Avec Node.js installé sur ta machine, tu peux lancer les serveurs de développement. Pour essayer le parcours complet avec le proxy Nginx et la base locale, utilise [Docker Compose](10-demarrage-local.md).

### Frontend

Depuis la racine du projet, lance Vite.

```bash
npm ci
npm run dev
```

Vite sert les pages à l’adresse `http://localhost:5173`.

### Backend

Depuis la racine, ouvre un autre terminal pour lancer Express.

```bash
cd backend
npm ci
npm run dev
```

Express écoute sur `http://localhost:3007` par défaut. Pour tester l’écriture et la lecture des résultats, donne au backend les paramètres d’une base PostgreSQL accessible et initialisée.

## 4. Variables d'environnement

| Variable | Rôle |
| --- | --- |
| `QUIZ_PORT` | Port utilisé dans le navigateur avec Docker Compose. |
| `BACKEND_URL` | Adresse que Nginx utilise pour joindre le backend. Elle vaut `http://backend:3007` par défaut dans l’image Docker. Azure utilise une adresse HTTPS interne. |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Accès et nom de la base locale. Compose transmet ces valeurs au backend via `PGUSER`, `PGPASSWORD`, `PGDATABASE` et lui indique le serveur avec `PGHOST=db`. |
| `DATABASE_URL` | URL de connexion à un PostgreSQL externe. En local, laisse-la vide pour utiliser `db`. Sur Azure, elle pointe vers Neon pour enregistrer les résultats. |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD` | Identifiant et mot de passe du panneau d’administration. |
| `JWT_SECRET` | Clé que le backend utilise pour signer et vérifier les jetons de connexion admin. |
| `RESEND_API_KEY`, `FROM_EMAIL` | Clé Resend et adresse d’expédition pour envoyer les résultats par email. |

En local, renseigne les vraies valeurs dans `.env`. En ligne, le backend reçoit ses secrets via Azure Container Apps. GitHub Actions lit les secrets du fork lors du déploiement. [Exemple de fichier local](../.env.example) · [Variables et secrets sur GitHub](11-configurer-cicd.md#renseigner-github-avant-la-fusion)

## 5. PostgreSQL et initialisation

Le fichier [database/init.sql](../database/init.sql) crée les tables `users`, `quiz_results` et `answers`.

- **En local**, le conteneur PostgreSQL lance le script au premier démarrage d’un volume vide. Le volume `quiz_data` garde les données quand tu recrées les conteneurs.
- **Sur Azure**, le backend se connecte à Neon avec une connexion chiffrée. Initialise la base Neon vide avec le même script SQL, puis vérifie que tu peux enregistrer et retrouver un score dans l’administration. [Configuration Neon](10-demarrage-local.md#utiliser-neon-depuis-docker) · [Preuve du test Neon](../preuves/J5/persistance-neon.md)

## 6. API documentée

### Routes publiques

| Méthode | Route | Fonction |
| --- | --- | --- |
| `POST` | `/api/users` | Créer un utilisateur |
| `POST` | `/api/results` | Enregistrer le résultat et envoyer un email si Resend est configuré |
| `GET` | `/health` | Vérifier que le serveur répond |

### Routes administrateur (JWT)

| Méthode | Route | Fonction |
| --- | --- | --- |
| `POST` | `/api/admin/login` | Authentification administrateur |
| `GET` | `/api/admin/results` | Liste paginée des résultats |
| `GET` | `/api/admin/results/export` | Export CSV |
| `DELETE` | `/api/admin/results/old?days=30` | Suppression de résultats anciens |
| `DELETE` | `/api/admin/results/all` | Suppression de tous les résultats |

`GET /health` répond HTTP 200 avec `{"status":"ok"}` sans interroger PostgreSQL. Pour vérifier que la base fonctionne aussi, termine un quiz et retrouve le résultat dans l’administration. [Code de l’API](../backend/server.js)

## 7. Où trouver le code et la configuration

| Fichier ou dossier | Contenu |
| --- | --- |
| `index.html`, `main.js`, `questions_*.js` | Page, logique et questions du quiz. |
| `gestion-quiz.html`, `public/admin.js` | Interface d’administration. |
| `backend/server.js`, `database/init.sql` | Routes de l’API et schéma PostgreSQL. |
| `docker-compose.yml`, `nginx/nginx.conf` | Services locaux et transfert des requêtes vers l’API. |
| `terraform/infra/`, `terraform/apps/` | Ressources Azure et configuration des deux applications. |
| `.github/workflows/github-actions.yml`, `scripts/` | Workflow GitHub Actions et scripts de scan, de déploiement et de nettoyage. |

## 8. Mission d'analyse préalable — Jalon 1

Avant d'écrire les fichiers de conteneurisation, les étudiants doivent :

1. Identifier les composants, leurs rôles et leurs dépendances.
2. Relever les ports utilisés en développement et expliquer ceux qui devront être exposés.
3. Repérer les variables de configuration, distinguer paramètres publics et secrets.
4. Identifier les routes utilisables pour les tests d'intégration et de santé.
5. Expliquer où se trouvent les questionnaires et comment les résultats sont conservés.
6. Réaliser un schéma d'architecture **locale** montrant les communications entre composants.
7. Justifier leurs choix de conteneurisation et de persistance.

**Livrable :** schéma d'architecture et courte description technique dans le dépôt du groupe.

## 9. Règle d'évaluation et de livraison

Chaque groupe travaille dans son propre fork du dépôt de référence (ou dans un projet GitLab équivalent si cette plateforme a été autorisée). Les Pull Requests ciblent `main` **dans le fork du groupe**, jamais dans le dépôt de référence du formateur.

GitHub Actions est recommandé ; GitLab CI/CD est admis. Une demande de fusion doit déclencher les vérifications et le scan Trivy ; après validation et fusion, une chaîne de déploiement publie les images dans Azure Container Registry et met à jour Azure Container Apps.

Chaque jalon donne lieu à une courte démonstration et au dépôt de preuves expurgées de secrets. Les critères d'acceptation et l'organisation des validations figurent dans `docs/03-jalons-validation.md` ; aucun barème chiffré n'est publié ici.
