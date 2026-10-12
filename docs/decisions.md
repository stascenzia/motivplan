# Décisions d'architecture (ADR)

Une entrée par décision structurante. Format court : contexte, décision, conséquences. Les décisions marquées « figée » ne se rouvrent pas pendant la v1 sans nouvelle entrée qui les remplace.

---

## ADR-001 — Stack native iOS, backend FastAPI

**Date** : 2026-10-08 · **Statut** : figée

**Contexte** : mono-utilisateur, hors-ligne obligatoire, capture par Siri et widget. Mac + Xcode disponibles ; machine principale sous Windows.

**Décision** : SwiftUI, SwiftData, App Intents, WidgetKit, App Group partagé. Backend FastAPI / SQLAlchemy 2 / Alembic / Pydantic v2 / PostgreSQL, conteneurisé. Projet Xcode généré par XcodeGen (`ios/project.yml`), jamais édité à la main.

**Conséquences** : le moteur de timeline est un package Swift pur (sans framework Apple) pour rester testable sous Windows ; le backend et ce moteur se développent sous Windows, le reste sur Mac. Versions courantes au 2026-10-08 : iOS 27, Xcode 27 (macOS 26.6+, Apple silicon). Cible minimum iOS 17.0.

---

## ADR-002 — Nom, identifiants

**Date** : 2026-10-08 · **Statut** : figée

**Décision** : app **MotivPlan**, bundle ID `fr.ascenzia.motivplan`, App Group `group.fr.ascenzia.motivplan`, scheme d'URL `motivplan://`. Le domaine inverse peut être remplacé par un domaine perso avant le premier build sur appareil, pas après.

---

## ADR-003 — Capture Siri en deux temps

**Date** : 2026-10-08 · **Statut** : figée, à confirmer par le spike hors-ligne du lot 0

**Contexte** : une phrase d'App Shortcut ne peut porter qu'un paramètre `AppEnum` ou `AppEntity`, jamais un `String` libre. Vérifié : [WWDC22 10170](https://developer.apple.com/videos/play/wwdc2022/10170/), [forum Apple 779109](https://developer.apple.com/forums/thread/779109). Le fonctionnement hors-ligne des App Shortcuts tiers n'est pas documenté par Apple.

**Décision** : `AddTaskIntent` avec `@Parameter var title: String` et `requestValueDialog` ; Siri demande le titre après « Ajoute une tâche dans MotivPlan ». Pas de pont par l'app Rappels. Un spike sur appareil (verrouillé, mode avion) valide le critère d'acceptation 1 avant tout investissement UI ; en cas d'échec hors-ligne, le critère est reformulé et le widget, Raccourcis et le bouton Action restent les canaux hors-ligne.

**Conséquences** : phrases non paramétrées contenant `\(.applicationName)` ; piège connu, Siri filtre certains mots de la dictée ([forum 729773](https://developer.apple.com/forums/thread/729773)), à tester avec des titres français variés.

---

## ADR-004 — Widget = lien vers le champ de capture

**Date** : 2026-10-08 · **Statut** : figée

**Contexte** : WidgetKit n'autorise aucun champ texte ; seuls `Button` et `Toggle` sont interactifs, et ils sont inactifs sur écran verrouillé. Apple recommande `Link` / `widgetURL` pour toute interaction qui ouvre l'app. Sources : [SwiftUI views for widgets](https://developer.apple.com/documentation/widgetkit/swiftui-views), [Adding interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities).

**Décision** : `CaptureWidget` (accueil + verrouillage) ne contient qu'un `widgetURL("motivplan://capture")` qui ouvre l'app sur le champ de capture, clavier levé. Aucun `Button(intent:)` en v1.

**Conséquences** : un seul processus écrit dans le store (voir ADR-006).

---

## ADR-005 — Séquence unique avec les ancres dedans

**Date** : 2026-10-08 · **Statut** : figée

**Contexte** : le cahier (§3.1, §3.2) décrit une séquence ordonnée et des ancres fixes, sans dire si l'on peut poser une tâche « après la réunion de 14h » en laissant un trou.

**Décision** : les ancres occupent une place dans la séquence du jour (triées par heure, non réordonnables par drag). Une flottante placée après une ancre démarre à la fin de l'ancre, trou autorisé. Une flottante qui déborderait sur une ancre est poussée entière après l'ancre, jamais découpée. Algorithme et cas de test T1–T5 dans `plan-dev.md`.

**Conséquences** : `orderIndex` à trous (pas de 1024) ; le store re-slotte une ancre quand son heure change et normalise la séquence après une poussée pour que séquence stockée = séquence affichée. Heures en minutes depuis minuit, dates-jour en clés `yyyy-MM-dd`, aucun `Date` dans le moteur.

---

## ADR-006 — Un seul processus écrivain SwiftData en v1

**Date** : 2026-10-08 · **Statut** : figée

**Contexte** : un changement fait par un autre processus (widget, extension) n'est pas observable par l'app ; seule `@Query` se rafraîchit, un `fetch` manuel reste périmé sur iOS 17. SwiftData History (iOS 18+) est la réponse officielle. Sources : [forum 791794](https://developer.apple.com/forums/thread/791794), [forum 789173](https://developer.apple.com/forums/thread/789173), [SwiftData History](https://developer.apple.com/documentation/swiftdata/fetching-and-filtering-time-based-model-changes).

**Décision** : l'intent Siri s'exécute dans le processus app (lancé en arrière-plan), le widget n'écrit pas. `ModelConfiguration` explicite (`groupContainer: .identifier(...)`, `cloudKitDatabase: .none`) dès le premier commit, App Group sur les deux cibles dès le premier commit. Modèles `@Model nonisolated class` ([forum 788262](https://developer.apple.com/forums/thread/788262)), `TaskItem` plutôt que `Task`.

**Conséquences** : tout futur `Toggle(intent:)` dans un widget exige SwiftData History et iOS 18 minimum, par une nouvelle ADR.

---

## ADR-007 — Report automatique

**Date** : 2026-10-08 · **Statut** : figée, ordre d'insertion réversible

**Décision** : à la première ouverture après minuit, les flottantes non faites de tous les jours passés passent à aujourd'hui, `postponeCount` +1 une seule fois, ajoutées à la suite des tâches déjà posées sur aujourd'hui, ordre relatif préservé. Les ancrées non faites retournent en boîte de réception, désancrées, avec `dueDate` = ancien jour planifié ; elles apparaissent « en retard » par la règle §3.4, avec une pastille sobre (ambre doux ou gris), jamais rouge (principe 2 du cahier).

---

## ADR-008 — Drag & drop : natif pour le cross-conteneur, geste maison pour la timeline

**Date** : 2026-10-08 · **Statut** : figée

**Contexte** : avant iOS 27, le réordonnancement natif avec placeholder n'existe que dans `List` ; `reorderable()` arrive en iOS 27. Une `.sheet` désactive la vue derrière elle. Bug Xcode 26 : `UTType` custom non déclenché avec `CodableRepresentation`. Sources : [Reordering items](https://developer.apple.com/documentation/swiftui/reordering-items-in-lists-stacks-grids-and-custom-layouts), [forum 763013](https://developer.apple.com/forums/thread/763013), [forum 792586](https://developer.apple.com/forums/thread/792586).

**Décision** : tiroir en overlay maison (ZStack, paliers) plutôt que `.sheet`. Tiroir → timeline et semaine avec `draggable` / `dropDestination`, `Transferable` DTO `Codable` en `.json`. Réordonnancement dans la timeline par moteur de geste maison (long press, offset, index par géométrie, auto-scroll). `reorderable()` sous `#available(iOS 27)` plus tard. Repli garanti : « Ajouter au jour » par menu contextuel.

---

## ADR-009 — Synchronisation par drapeau, LWW, cursor serveur

**Date** : 2026-10-08 · **Statut** : figée

**Décision** : pas de file d'opérations ; un drapeau `needsSync` par enregistrement. `POST /sync` applique « dernière écriture gagnante » sur `updated_at` (horloge client) et renvoie les changements filtrés sur `server_updated_at` (horloge serveur) depuis `since` ; le client stocke `server_time` comme prochain `since`. Tombstones `deletedAt`. Jeton statique dans le Keychain. Hébergement : VPS perso, Docker Compose (api + postgres + Caddy), ~6 € HT/mois.

---

## ADR-010 — Séquençage : iOS d'abord, backend en fin de v1

**Date** : 2026-10-08 · **Statut** : figée

**Décision** : lots 0 à 6 livrent une app utilisable hors-ligne ; lots 7 et 8 ajoutent le backend et la synchro. Le backend n'est jamais sur le chemin critique d'une action utilisateur.

---

## ADR-011 — App native confirmée face à une web app

**Date** : 2026-10-12 · **Statut** : figée

**Contexte** : l'utilisateur est presque toujours connecté, ce qui rendait envisageable une web app ajoutée à l'écran d'accueil, utilisable aussi sur le PC Windows. Une web app ne peut pas déclarer d'App Intent : Siri ne passerait que par un raccourci qui envoie le texte au serveur. Elle perd aussi l'haptique (pas de Vibration API dans Safari iOS), les widgets, un drag au doigt fluide et un stockage local garanti (Safari peut l'effacer). Elle rendrait le backend obligatoire dès le premier jour, contre ADR-010.

**Décision** : app native iOS, plan inchangé. Le principe 3 (hors-ligne intégral) est conservé, puisqu'il ne coûte rien en natif.

**Conséquences** : l'accès depuis le PC passera plus tard par une page web légère adossée au backend du lot 7 (consultation et capture), hors v1.

---

## ADR-012 — Délégation à un agent IA externe (Instinct) et capture longue : v2

**Date** : 2026-10-12 · **Statut** : idée, hors v1

**Contexte** : envie de déléguer certaines tâches planifiées à Instinct, un assistant IA joignable par WhatsApp (bêta sur invitation, aucune API publique connue au 2026-10-12). Un envoi automatique par l'API WhatsApp Business partirait d'un numéro Business, donc non reconnu par Instinct, et serait soumis aux modèles de messages pré-approuvés ; automatiser le compte WhatsApp personnel est interdit par les conditions de WhatsApp.

**Décision** : rien en v1. Pistes v2 :
- bouton « Déléguer à Instinct » sur une tâche, qui ouvre WhatsApp avec le message prérempli (lien `wa.me` avec texte : la tâche et comment la réaliser) ; l'utilisateur appuie sur Envoyer ;
- route d'ajout de tâche sur le backend, utilisable par n'importe quel agent (Instinct, Claude, autre) si ces agents exposent un jour des appels sortants ;
- capture longue « vidage de tête » : dictée de plusieurs minutes, transcription sur l'appareil, découpage en plusieurs tâches par un LLM quand le réseau est là. Granola écarté : conçu pour les réunions, API réservée à l'offre Business, dépend du réseau.

**Conséquences** : la capture courte reste celle d'ADR-003 (Siri, bouton Action, Raccourcis, widget). Garder l'API du backend propre et documentée pour faciliter ces branchements.

---

## Journal du spike Siri hors-ligne (lot 0)

À remplir après le test sur appareil : modèle d'iPhone, version d'iOS, résultat verrouillé, résultat mode avion (phrase puis dictée), titres français qui ont été filtrés par Siri.
