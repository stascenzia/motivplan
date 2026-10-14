# Plan de développement — MotivPlan v1

## Contexte

MotivPlan remplace un système de plannings quotidiens tenus à la main dans l'app Notes d'iPhone. Le cahier des charges (`docs/cahier-des-charges.md`) fixe le fond : capture en un geste, aucune culpabilisation, hors-ligne intégral, manipulation au doigt. Le repo est vide (README + cahier des charges). Ce plan découpe la v1 en lots livrables, fige les décisions prises en discussion le 2026-10-08 et précise les règles métier que le cahier laissait ouvertes. Le premier geste de la session d'implémentation est de déposer ce plan dans `docs/plan-dev.md`, puis d'attaquer le lot 0.

Environnement : Mac + Xcode pour la partie iOS ; Windows pour le backend et pour le moteur de timeline pur (testable avec le toolchain Swift Windows, sans SwiftData). Versions courantes au 2026-10-08 : iOS 27 et Xcode 27 (sortis le 14 septembre 2026, macOS 26.6+ et Mac Apple silicon requis). Cible minimum iOS 17.0 conservée.

## Décisions tranchées (ne pas rouvrir pendant l'implémentation)

| Sujet | Décision |
|---|---|
| Stack | Natif pur : SwiftUI, SwiftData, App Intents, WidgetKit, App Group partagé. Backend FastAPI / SQLAlchemy 2 / Alembic / Pydantic v2 / PostgreSQL, Docker. |
| Nom | **MotivPlan**. Bundle ID `fr.ascenzia.motivplan` (à ajuster si domaine perso), App Group `group.fr.ascenzia.motivplan`, scheme d'URL `motivplan://`. |
| Siri | App Intent en deux temps : « Dis Siri, ajoute une tâche dans MotivPlan » → Siri demande « Quelle tâche ? » → dictée. Une phrase App Shortcut ne peut porter qu'un paramètre AppEnum / AppEntity, jamais un texte libre (vérifié : WWDC22 10170, forums Apple 779109). Pas de pont via Rappels. Le fonctionnement **hors-ligne** des App Shortcuts tiers n'est documenté nulle part par Apple : il est validé par un spike matériel en lot 0 avant tout investissement UI. |
| Widget | WidgetKit n'autorise aucun champ texte (seuls `Button` / `Toggle` sont interactifs, et ils sont inactifs sur écran verrouillé). Le widget (accueil + verrouillage) est un `Link` / `widgetURL("motivplan://capture")` qui ouvre l'app sur le champ de capture, clavier levé. C'est le pattern recommandé par Apple pour « ouvrir l'app ». |
| Ancres | Séquence unique du jour avec les ancres dedans : une ancre occupe une place dans l'ordre (triée par heure, non réordonnable par drag). Une flottante placée après une ancre démarre à la fin de l'ancre, trou autorisé avant. Une flottante qui déborderait sur une ancre est poussée entière après l'ancre, jamais découpée. |
| Report | À la première ouverture après minuit : les flottantes non faites de tous les jours passés (pas seulement la veille) passent à aujourd'hui, `postponeCount` +1 une seule fois, ordre relatif préservé. Les **ancrées** non faites retournent en boîte de réception, désancrées, avec `dueDate` = ancien jour planifié, ce qui les fait apparaître « en retard » via la règle §3.4 existante. Pastille sobre (ambre doux ou gris), pas de rouge, conformément au principe 2 du cahier. |
| Séquençage | iOS d'abord, utilisable hors-ligne au plus tôt ; backend et synchro en fin de v1. |
| Hébergement | VPS perso (Hetzner CX23 ou équivalent, ~6 € HT/mois), Docker Compose : api + postgres + Caddy (TLS). |
| Vue semaine | Logique implémentée en v1 (déplacer une tâche vers un autre jour, charge par jour). Forme visuelle à trancher au design ; une UI provisoire en 7 colonnes de puces sert de support. |

## Architecture et structure du repo

Monorepo :

```
motivplan/
  docs/
    cahier-des-charges.md
    plan-dev.md                  # ce plan
    decisions.md                 # ADR courts, une entrée par décision ci-dessus
  ios/
    project.yml                  # XcodeGen : le .xcodeproj est généré, jamais édité à la main
    MotivPlan/                   # cible app (SwiftUI) : App/, Features/{Day,Week,Inbox,Drawer,Capture,Settings}
    MotivPlanWidget/             # extension WidgetKit : CaptureWidget (familles system* + accessory*)
    Packages/
      TimelineEngine/            # SwiftPM pur Foundation, zéro import Apple : layout du jour, report. Testable sous Windows.
      MotivPlanCore/             # SwiftPM, dépend de TimelineEngine. Cibles : CoreModels, CoreIntents, SyncClient
  backend/
    app/                         # FastAPI
    alembic/
    tests/
    pyproject.toml               # uv
    Dockerfile
    docker-compose.yml           # api + postgres + caddy
```

Principes d'architecture :

- La base SwiftData locale fait autorité. L'UI ne parle jamais au réseau.
- `TimelineEngine` ne manipule que des entiers et des structures légères (`TimelineItem { id, orderIndex, durationMin, anchorStartMin? }`) ; `anchorTime` et l'heure de départ du jour sont des **minutes depuis minuit**, les dates-jour (`scheduledDate`, `dueDate`) des clés `yyyy-MM-dd`. Pas de `Date` dans le moteur : ni fuseau, ni changement d'heure.
- Un seul processus écrit dans le store en v1 : l'app (l'intent Siri s'exécute dans le processus app lancé en arrière-plan, le widget ne fait qu'ouvrir l'app). Cette propriété évite le problème des `ModelContainer` multiples non observables entre processus ; elle est documentée dans `decisions.md` et ne doit pas être cassée sans passer par SwiftData History (iOS 18+).
- `ModelConfiguration` toujours explicite : `groupContainer: .identifier("group.fr.ascenzia.motivplan")`, `cloudKitDatabase: .none`. Jamais `.automatic`, jamais « sans App Group pour l'instant » (le store se déplace quand l'entitlement arrive).
- Modèles `@Model nonisolated class` (recommandation DTS 788262 pour Swift 6.2 avec isolation `MainActor` par défaut). Le modèle de tâche s'appelle `TaskItem` (jamais `Task`, collision avec Swift Concurrency). `@Attribute(.unique) var id: UUID` généré client ; `persistentModelID` ne sort jamais du store.
- Schéma SwiftData versionné dès le premier commit (`SchemaV1: VersionedSchema` + `SchemaMigrationPlan` vide).
- `Session` existe dans le schéma iOS et dans le backend dès la v1 (coût nul), sans aucune UI avant la v2.
- Une seule porte d'écriture, `TaskStore` dans `CoreModels` : pose `updatedAt`, `source`, `needsSync = true` ; les vues n'appellent jamais `context.insert` / `delete`. Suppression = tombstone `deletedAt` ; tous les `FetchDescriptor` nommés du package filtrent `deletedAt == nil`.
- `orderIndex` à trous (pas de 1024, renormalisation quand l'écart tombe sous 2) : un réordonnancement = une écriture, comme le demande le cahier §3.1.
- Les intents vivent dans `CoreIntents` via `AppIntentsPackage` (iOS 17+), l'app déclare `includedPackages`. Le `ModelContainer` est enregistré dans `AppDependencyManager` dans `App.init()` (seule chose garantie quand Siri lance l'app en arrière-plan).

## Règles métier précisées

### Calcul des heures de début (TimelineEngine)

Entrée : items du jour triés par `orderIndex`, heure de départ du jour (réglage, défaut 09:00). Le moteur commence par remettre les ancres dans l'ordre croissant de `anchorStart` sans toucher aux positions relatives des flottantes.

```
layoutDay(dayStart, items):
  seq     = items triés par orderIndex, ancres réordonnées par anchorStart
  anchors = ancres de seq, intervalles [anchorStart, anchorStart + duration)
  cursor  = dayStart
  pour chaque item de seq :
    si item ancré :
      start = item.anchorStart                       # R1 : une ancre ne bouge jamais
      overlapsAnchor = une autre ancre l'intersecte  # signal discret, pas une erreur
      cursor = max(cursor, start + duration)         # R2 : après une ancre on repart de sa fin, trou autorisé
    sinon :
      start = cursor ; pushedPastAnchor = nil
      tant qu'il existe une ancre A avec A.start < start + duration et A.end > start :
        start = A.end ; pushedPastAnchor = A.id      # R3 : poussée entière, re-vérifiée en boucle
      cursor = start + duration
    émettre Placement(id, start, end, gapBefore, pushedPastAnchor, overlapsAnchor)
  normalizedSequence = placements triés par (start, position dans seq)
  retourner (placements, normalizedSequence, totalPushedMinutes)
```

Règles côté `TaskStore` :

- `slotAnchor` à la création ou au changement d'heure d'une ancre : calculer le layout sans elle, l'insérer avant le premier item dont `start ≥ anchorStart`, lui donner un `orderIndex` à trou. L'invariant « ancres triées par heure » en découle.
- `normalizeIfNeeded` : si `normalizedSequence` diffère de la séquence stockée, réécrire l'`orderIndex` des seuls items poussés (juste après l'ancre, ordre relatif conservé). Séquence stockée = séquence affichée, le prochain drag reste non ambigu. Le moteur est idempotent sur une séquence normalisée.
- Les tâches faites gardent leur place et leur durée : cocher ne décale rien (§4.4).
- `anchorTime` se règle par boutons ±15 min et ±1 h depuis l'heure ronde suivante, pas de sélecteur d'heure (principe 4).
- L'indicateur discret de débordement (§3.2) s'appuie sur `totalPushedMinutes`, `overlapsAnchor` et l'heure de fin du dernier item ; seuil réglable, forme laissée au design.

Invariants testés en propriétés : I1 `start(ancre) == anchorStart` ; I2 aucune flottante n'intersecte une ancre ; I3 l'ordre relatif des flottantes est conservé dans `normalizedSequence` ; I4 chaque flottante démarre ≥ `dayStart` et ≥ fin de l'item précédent ; I5 idempotence de la normalisation.

### Durées par défaut

Au drop depuis le tiroir : durée déjà présente sur la tâche si elle en a une (cas d'une ancrée revenue en inbox), sinon durée de la catégorie, sinon 30 min. Réglages modifiables, valeurs initiales à calibrer : sans catégorie 30, quotidienne 15, courte 15, moyenne 45, longue 90, pro 60. Minimum 5 min (refusé par le store), pas de 15 min sur les boutons ±.

### Report automatique (fonction pure, testée)

Déclenché sur `scenePhase == .active` quand `lastRolloverDayKey` (`UserDefaults(suiteName: appGroup)`) ≠ aujourd'hui. Une seule transaction, silencieuse, idempotente. Tâches ciblées : `status == scheduled`, non faites, `scheduledDate < aujourd'hui`.

- Flottantes : `scheduledDate = aujourd'hui`, `postponeCount += 1`, ajoutées **à la suite** des tâches déjà posées sur aujourd'hui, dans l'ordre `(scheduledDate, orderIndex)` d'origine. Choix réversible : les tâches planifiées délibérément pour aujourd'hui gardent la priorité, les restes n'accaparent pas la matinée.
- Ancrées : `status = inbox`, `scheduledDate = nil`, `orderIndex = nil`, `isAnchored = false`, `anchorTime = nil`, `dueDate = ancien scheduledDate` si `dueDate` était vide. La durée est conservée comme suggestion au prochain drop.
- Les tâches faites restent sur leur jour. Les récurrences (v2) ne sont jamais reportées.

### Capture

- In-app : champ permanent en haut du tiroir et de la boîte de réception. Retour clavier = création (`status inbox`, `source manual`), retour haptique léger, champ vidé, tâche visible immédiatement.
- Deep link `motivplan://capture` → `.onOpenURL` → `@FocusState` sur le champ ; `source widget`. Sur iOS 17 le focus au premier rendu peut demander un `task` différé, à vérifier sur appareil.
- `AddTaskIntent` : `@Parameter(title:, requestValueDialog:) var title: String`, pas d'`openAppWhenRun` (défaut `false`), `supportedModes = [.background]` sous `#available(iOS 26)`, `authenticationPolicy` par défaut (s'exécute verrouillé), `.result(dialog:)` court « Ajouté : … », `source siri`, puis `WidgetCenter.shared.reloadTimelines(ofKind:)`. `AppShortcutsProvider` avec au moins deux phrases non paramétrées contenant `\(.applicationName)` (« Ajoute une tâche dans MotivPlan », « Nouvelle tâche MotivPlan »). Gérer proprement l'échec « avant le premier déverrouillage après redémarrage » (store inaccessible) par une erreur parlée. Piège connu (forum 729773) : Siri filtre certains mots de la dictée (« dernier », « rappelle », …), à tester avec des titres français variés. L'intent est aussi disponible dans Raccourcis et sur le bouton Action, gratuitement.

### Synchronisation (dernier lot)

Pas de file d'opérations : un drapeau `needsSync` par enregistrement suffit et reste idempotent. Le client envoie tous les enregistrements marqués, le serveur applique « dernière écriture gagnante » sur `updated_at` (horloge client) et renvoie tout ce qui a changé côté serveur depuis `since`, filtré sur une colonne serveur `server_updated_at` (jamais sur l'horloge client, à cause des dérives). Le client stocke `server_time` de la réponse comme prochain `since`, applique les enregistrements distants avec la même règle LWW, et retire `needsSync` des enregistrements dont `updatedAt` n'a pas bougé pendant l'envoi. Déclencheurs : passage en premier plan, 2 s après une mutation locale (debounce), `BGAppRefreshTask` périodique. Jeton statique dans le Keychain, saisi dans les réglages.

## Lotissement v1

Chaque lot se termine par un commit (Conventional Commits), une app installable et un critère vérifiable. Tailles indicatives : S < 1 jour, M 1 à 3 jours, L 3 à 5 jours.

### Lot 0 — Fondations et spike Siri (M)

- Déposer ce plan dans `docs/plan-dev.md` et créer `docs/decisions.md`.
- `ios/project.yml` XcodeGen : cibles app + widget, deux packages locaux, App Group sur les deux cibles dès le premier commit, scheme d'URL, iOS 17.0 minimum, Xcode 27 / Swift 6.2 avec isolation `MainActor` par défaut sur la cible app ; les packages restent `nonisolated` par défaut.
- Packages avec un test « sanity » chacun ; `swift test` doit passer dans `TimelineEngine` sous Windows et sous macOS.
- `backend/` : `pyproject.toml` (uv), FastAPI `GET /health`, Dockerfile, compose minimal, pytest vert. Rien de plus.
- `.gitignore` (Xcode, DerivedData, Python), `README.md` avec les commandes de build.
- **Spike Siri hors-ligne** sur appareil : un `AddTaskIntent` minimal qui écrit dans `UserDefaults` de l'App Group, testé verrouillé et en mode avion (compréhension de la phrase, puis dictée du titre en français). Résultat consigné dans `decisions.md`. Si Siri hors-ligne échoue, le critère 1 est reformulé (« fonctionne verrouillé ; hors-ligne via widget, Raccourcis et bouton Action ») et le reste du plan ne change pas.
- Prérequis à vérifier : compte Apple Developer payant (sinon profils de 7 jours et capacités limitées), Mac Apple silicon sous macOS 26.6+ pour Xcode 27.

### Lot 1 — Moteur de timeline (M, faisable sous Windows)

- `TimelineEngine` : structures, `layoutDay`, `slotAnchor`, `normalizeIfNeeded`, `defaultDuration(for:)`, `rollover(tasks:today:)`, indices à trous.
- Tests unitaires, `dayStart` 09:00 :
  - T1 cascade : A 30, B 60, C 15 → 09:00 / 09:30 / 10:30 ; B passe à 90 → C 11:00, A inchangée.
  - T2 poussée entière : [A 90, M 10:00–11:00, B 30] → A 11:00–12:30 poussée par M, M intacte, B 12:30, séquence normalisée [M, A, B].
  - T3 trou autorisé : [M 14:00–15:00, A 30] → A 15:00 ; [A 30, M 14:00–15:00, B 30] → A 09:00, M 14:00 (`gapBefore` 270), B 15:00.
  - T4 double enjambement et ancre avant le début du jour : [M0 07:00–08:00, A 120, M1 09:30–10:00, M2 10:15–10:45] → A 10:45–12:45.
  - T5 ancres chevauchantes stockées dans le désordre : [M2 10:30–11:30, M1 10:00–11:00, A 30] → ordre rétabli [M1, M2], `overlapsAnchor` sur les deux, A 11:30.
  - Jour vide ; tests de propriétés I1–I5.
  - Report : multi-jours, ancrée ratée → inbox avec `dueDate`, [X, Y] non faits hier + [Z] déjà posé → [Z, X, Y] avec `postponeCount` +1, tâche faite intouchée, idempotence sur double appel.

### Lot 2 — Données et boîte de réception (M)

- `CoreModels` : `TaskItem`, `Session`, enums, `SchemaV1`, factory de `ModelContainer` App Group, `TaskStore` (création, mise à jour, tombstone, requêtes inbox / jour / semaine), tests avec `isStoredInMemoryOnly: true`.
- Écran Boîte de réception : champ de capture permanent, liste, gestes rapides (menu contextuel ou balayage) pour catégorie, importance, échéance via puces (aujourd'hui, demain, cette semaine, choisir), « planifier aujourd'hui / demain » en un tap, et « Planifier le… » (sélecteur de date) pour poser une tâche sur un jour lointain, ajoutée en fin de séquence de ce jour.
- Écran Détail tâche : notes, catégorie, importance, échéance, `postponeCount` visible ici seulement, suppression.

### Lot 3 — Vue Jour (L, cœur de l'app)

- Timeline en bulles avec heures calculées par `TimelineEngine`, hauteur proportionnelle à la durée, navigation jour par jour (swipe + bouton « aujourd'hui »).
- Tiroir en bas : groupé par catégorie, tri échéance puis importance, échéances passées signalées sobrement, champ de capture en tête. Implémenté comme **overlay maison à paliers dans la même hiérarchie** (ZStack), pas `.sheet` : une sheet désactive la vue derrière elle et rien ne garantit qu'une session de drag la traverse.
- Drag & drop **cross-conteneur** (tiroir → timeline, puis semaine) avec `draggable` / `dropDestination` et un `Transferable` DTO `Codable` en `contentType: .json` (bug Xcode 26 avec `UTType` custom). Durée par défaut et `orderIndex` à la position de dépôt. Repli garanti : tap long sur une tâche du tiroir → « Ajouter au jour » en fin de séquence.
- **Réordonnancement dans la timeline** : moteur de geste maison (long press → lift → offset → index par géométrie → auto-scroll par timer + `ScrollViewReader`), car le réordonnancement natif avec placeholder n'existe hors `List` qu'à partir d'iOS 27 (`reorderable()`), à ajouter plus tard sous `#available(iOS 27)`. Donne aussi l'haptique et la poussée visuelle. Solution intermédiaire si besoin : `onDrag` / `onDrop` + `DropDelegate`.
- Redimensionnement par boutons ±15 min ; poignée = `DragGesture` sur la poignée modifiant `durationMin` par pas de 5, en objectif secondaire (attention au conflit avec le scroll : long press pour déplacer, tap pour scroller).
- Cochage : animation < 600 ms, retour haptique, tâche barrée mais toujours affichée.
- Ancres : bascule dans le détail, heure par ±15 / ±1 h, bulle non réordonnable, indicateur discret de débordement.
- Réglages : heure de départ du jour, durées par catégorie.

### Lot 4 — Capture externe : Siri et widgets (M)

- `AddTaskIntent` définitif dans `CoreIntents` (écriture via `TaskStore`), `AppShortcutsProvider`, phrases FR localisées, `AppIntentsPackage` branché dans l'app.
- `CaptureWidget` : familles `systemSmall` et `accessoryCircular` / `accessoryInline`, uniquement `Link` / `widgetURL`, aucun `Button(intent:)` ; gestion du deep link et du focus dans l'app.
- Critère d'acceptation 1 vérifié sur appareil : écran verrouillé, mode avion, Siri → tâche en boîte de réception, `source == siri`.

### Lot 5 — Report automatique (S)

- Branchement de `rollover` sur `scenePhase == .active`, `lastRolloverDayKey`, transaction unique.
- Critère 4 vérifié : changer la date du téléphone, rouvrir, aucune notification ni écran, tâches reportées, ancrées ratées en inbox avec pastille sobre.

### Lot 5b — Sections et seconde mémoire (M, ajouté le 2026-10-14, ADR-014)

- Moteur : `Durations` sans catégories (durée de la tâche, sinon suggestion de la section, sinon 30 min).
- `CoreModels` : `TaskSection` (règles planifiable, mémoire, répétition), sections fournies au premier lancement, `TaskItem` avec `sectionId`, `tag`, `review`, `reviewNote` (catégorie et importance retirées). `TaskStore` : gestion des sections, terminer avec avis, quotidiennes posées au report, permanentes jamais consommées.
- Boîte de réception : capture, « À trier », puis une ligne par section ; écran de section avec « À faire » et « Mémoire » ; éditeur de section. Tiroir limité aux sections planifiables. Détail : section, étiquette, avis.
- Backend : table `sections`, nouvelles colonnes, sections dans `/sync`, tests.

### Lot 6 — Vue Semaine (M)

- `moveTask(to day:)` dans `TaskStore` (changement de jour, ajout en fin de séquence, ancre conservée avec son heure et re-slotée).
- UI provisoire 7 colonnes de puces, drag entre colonnes (`draggable` / `dropDestination`), tap sur un jour → vue Jour. Forme définitive au design.

### Lot 7 — Backend et déploiement (M)

- Modèles SQLAlchemy `tasks`, `sessions` avec `server_updated_at` indexé ; migration Alembic initiale.
- `POST /sync` (LWW, cursor serveur), routes de débogage `/tasks`, `/sessions`, `/days/{date}`, `/progress` (ce dernier renvoie vide en v1).
- Auth : bearer statique lu dans l'environnement, comparaison en temps constant.
- Tests pytest sur `/sync` : upsert, conflit LWW dans les deux sens, tombstone, cursor.
- Compose complet (api + postgres + caddy), déploiement sur le VPS, sauvegarde `pg_dump` quotidienne par cron.

### Lot 8 — Client de synchro iOS (M)

- `needsSync`, `SyncClient` (URLSession, DTO Codable alignés sur les schémas Pydantic), déclencheurs, réglages URL + jeton (Keychain).
- Critère 5 vérifié : mutations en mode avion sur deux appareils ou appareil + routes de débogage, puis reconnexion sans perte.

### Lot 9 — Finitions v1 (S)

- Passage sur les principes directeurs écran par écran (aucun rouge, aucun compteur d'échec visible hors détail).
- Accessibilité de base (Dynamic Type, VoiceOver sur les bulles), performance du drag avec 30 tâches.
- Distribution TestFlight ou installation directe.

## Risques techniques et parades (faits vérifiés le 2026-10-08)

- **Siri hors-ligne non garanti** : la liste Apple des requêtes hors-ligne ne cite pas les App Shortcuts tiers. Parade : spike en lot 0, dégradation documentée (widget, Raccourcis, bouton Action restent 100 % hors-ligne).
- **Drag & drop natif** : pas de réordonnancement fin hors `List` avant iOS 27, pas d'auto-scroll fourni, `dropDestination` cassé dans une sous-vue de `List` sur iOS 17, `UTType` custom non déclenché sous Xcode 26. Parade : moteur de geste maison pour la timeline, `draggable` / `dropDestination` en `.json` pour le cross-conteneur, `UICollectionView` via `UIViewRepresentable` en dernier recours.
- **Processus multiples et SwiftData** : un changement fait par un autre processus n'est pas observable par l'app (seule `@Query` se rafraîchit ; un `fetch` manuel reste périmé sur iOS 17). Parade v1 : un seul processus écrivain. Si un `Toggle(intent:)` « cocher depuis le widget » arrive un jour : SwiftData History avec `context.author`, iOS 18+.
- **Isolation Swift 6.2** : `ModelContext` et modèles ne traversent jamais un acteur ; DTO `Sendable` ou `PersistentIdentifier` ; `@ModelActor` dans `Task.detached` pour le vrai arrière-plan (synchro).
- **Reloads de widget** : budget 40 à 70 par jour, non décompté quand l'app est au premier plan ; appeler `reloadTimelines(ofKind:)` après chaque écriture d'intent, accepter un délai sur appareil.
- **Compte Apple gratuit** : profils de 7 jours ; programme développeur payant avant le lot 4.

## Vérification de bout en bout

| Critère du cahier | Lot | Comment vérifier |
|---|---|---|
| 1. Siri, verrouillé, mode avion → tâche en inbox | 0 (spike), 4 | Test manuel sur appareil ; `source == siri` |
| 2. Drop du tiroir → durée par défaut, aucun formulaire | 3 | Test manuel + test `defaultDuration` |
| 3. +30 min décale les flottantes, jamais une ancre | 1, 3 | T1–T5 et invariants + test manuel |
| 4. Journée non faite reportée sans bruit | 1, 5 | Tests `rollover` + changement de date du téléphone |
| 5. Hors-ligne complet, réconciliation sans perte | 7, 8 | Scénario mode avion, deux sources de mutation, diff des bases |

Commandes : `swift test` dans chaque package (Windows pour `TimelineEngine`, Mac pour les deux), `xcodebuild test` sur la cible app, `uv run pytest` dans `backend/`, `docker compose up` local avant déploiement.

## Hors périmètre v1 (rappel)

v2 : récurrences, sessions (UI), vue mois en vrai onglet calendrier de planification (validé le 2026-10-13), points et progression, suggestion de découpage au-delà de 5 reports. v3 : import calendrier, notifications, statistiques, Apple Watch.

## Points encore ouverts (à trancher au design, pas dans le code)

- Forme de la vue semaine et de la progression.
- Position du tiroir en paysage.
- Revue quotidienne explicite ou construction au fil de l'eau.
- Calibrage des durées par catégorie et du seuil d'indicateur de débordement.
