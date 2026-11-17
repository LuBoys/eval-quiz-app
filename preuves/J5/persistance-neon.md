# J5 · Un score conservé dans PostgreSQL sur Neon

Test effectué le 17 novembre 2026 sur l’URL publique du quiz déployé sur Azure.

1. Le [schéma PostgreSQL du projet](../../database/init.sql) a été appliqué à une base Neon vide. Le guide de démarrage explique [l’initialisation et le premier test](../../docs/10-demarrage-local.md#utiliser-neon-depuis-docker).
2. Le backend reçoit `DATABASE_URL` depuis le secret Azure `database-url`. La configuration PostgreSQL utilise `sslmode=verify-full` pour vérifier le serveur et `channel_binding=require` pour lier l’authentification à TLS.
3. `GET /health` a répondu `200`. Le test a chargé le JavaScript des questions Docker depuis l’URL Azure.
4. `POST /api/users` a créé une inscription fictive avec une adresse sous `example.test` et a répondu `201`.
5. `POST /api/results` a répondu `201` après avoir enregistré vingt réponses, dont une question expirée, et un score de **19/20**.
6. Le test a ouvert une session admin via `POST /api/admin/login`. Deux lectures séparées sur `GET /api/admin/results` ont retrouvé le même résultat. Le jeton et la chaîne PostgreSQL restent dans leurs magasins de secrets.

Le test utilise les routes appelées par le navigateur. [Guide des routes et de la configuration](../../docs/08-documentation-technique.md)
