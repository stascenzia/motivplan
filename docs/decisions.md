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

**Amendement 2026-10-12** : faute de Mac disponible, le lot 7 (backend) est réalisé juste après le lot 1, car il se développe et se teste entièrement sous Windows. Le principe ne change pas : l'app reste utilisable sans backend, le lot 8 (client de synchro) vient toujours après les lots iOS. Le déploiement sur le VPS reste à faire (aucun serveur encore loué).

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

## ADR-013 — Distribution sans programme développeur payant

**Date** : 2026-10-14 · **Statut** : figée

**Contexte** : le programme Apple Developer coûte 99 €/an ; l'utilisateur ne veut pas le payer pour une seule app personnelle. Aucun Mac n'est disponible en continu (celui de sa compagne est un poste de travail géré). Une PWA avec un Raccourci Siri a été étudiée : capture vocale possible, mais glisser-déposer, tiroir avec clavier et retour haptique nettement moins bons, et interface des lots 2 à 4 à réécrire.

**Décision** : app native conservée, installée avec un compte Apple gratuit par AltStore (renouvellement automatique depuis le PC Windows, allumé la plupart du temps) ou SideStore (renouvellement depuis l'iPhone). La CI GitHub Actions produit l'`.ipa` non signé ; l'outil le signe à l'installation. La configuration est faite plus tard.

**Conséquences** : signature valable 7 jours, renouvelée automatiquement ; limite de 3 apps actives (AltStore, l'app, le widget). Pas de TestFlight ni de notifications push (hors v1 de toute façon). App Intents et widget ne demandent aucun droit payant. Une mise à jour d'iOS peut casser l'outil quelques jours. Le passage au programme payant plus tard ne demande aucun changement de code : renseigner `DEVELOPMENT_TEAM` et signer normalement. Remplace la mention « compte payant recommandé » d'ADR-001 et du plan.

---

## ADR-014 — Sections, étiquettes et seconde mémoire

**Date** : 2026-10-14 · **Statut** : figée

**Contexte** : MotivPlan est aussi une seconde mémoire, pas seulement un planning. La boîte de réception doit se ranger en sections (quotidiennes, récurrentes, ponctuelles, courses, recettes, films et séries…) avec chacune ses règles : certaines se planifient, d'autres non (une série se regarde au fil des jours) ; certaines gardent la trace de ce qui a été fait, avec un avis. Les catégories du cahier (quotidienne, courte, moyenne, longue, pro) ne servaient qu'à suggérer une durée. Rien n'est encore installé : le schéma v1 se modifie sans migration.

**Décision** :
- **Sections personnalisables** (entité synchronisée) : nom, symbole, ordre, durée par défaut, et trois règles : `planifiable` (visible dans le tiroir, posable dans la journée), `mémoire` (une tâche terminée reste consultable avec son avis), `répétition` parmi `aucune`, `quotidienne`, `permanente`. Sections fournies au premier lancement : Quotidiennes (quotidienne, planifiable, 15 min), Récurrentes (permanente, planifiable, 30 min), Ponctuelles (aucune, planifiable, 30 min), Courses (non planifiable), Recettes (mémoire, non planifiable), Films et séries (mémoire, non planifiable). Toutes modifiables.
- Une capture (Siri, widget, champ) arrive **sans section**, dans « À trier ».
- **Étiquette** unique et facultative, qui remplace l'importance : Urgent, Travail, Medium, Détente (ordre de tri dans cet ordre).
- **Quotidienne** : posée seule chaque jour au report du matin (ADR-007), cochée ou non la veille, à sa place habituelle ; jamais comptée comme reportée.
- **Permanente** : cocher ne la consomme pas. Cochée depuis la boîte, elle y reste avec la date de la dernière fois ; cochée dans la journée, elle revient dans la boîte au report suivant.
- **Mémoire** : terminer demande un avis rapide (aimé, bof, pas aimé) et un commentaire facultatif ; l'élément quitte la liste « à faire » et rejoint la mémoire de la section, datée.
- Les catégories disparaissent ; la durée suggérée au dépôt vient de la tâche, sinon de sa section, sinon 30 min.

**Conséquences** : la récurrence, prévue en v2, entre en v1 sous ces deux formes simples ; les récurrences à jours fixes restent en v2. Backend : table `sections`, colonnes `section_id`, `tag`, `review`, `review_note` sur `tasks`, sections dans `POST /sync`. Le moteur de timeline ne change pas, hormis `Durations` qui ne connaît plus les catégories.

---

## ADR-015 — Deux espaces : la to-do et la Mémoire ; périodes datées

**Date** : 2026-11-03 · **Statut** : figée

**Contexte** : après une semaine de tests sur l'iPhone (`docs/retours-v1.md`), l'utilisateur voit deux applications en une : une to-do (boîte, journée, calendrier) et une mémoire (films, recettes, courses, voyages). Les mélanger dans les mêmes tuiles de la boîte brouille les deux. Les voyages ont besoin d'une date de début et de fin, et ne doivent pas apparaître dans la journée (pas d'heure, pas de conflit), mais doivent apparaître dans le calendrier. Les courses sont une liste qu'on coche en magasin.

**Décision** :
- Chaque section a un **type** : `tasks` (à faire, règles d'ADR-014), `memory` (envies avec avis : films, recettes), `checklist` (liste à cocher : courses), `periods` (périodes datées : voyages). Le type impose ses règles : hors `tasks`, une section n'est ni planifiable ni répétée, et seul `memory` garde la mémoire avec avis.
- Les sections `tasks` restent dans la boîte de réception. Les trois autres types vivent dans un nouvel onglet **Mémoire**, juste à droite du « + » dans la barre d'onglets.
- **Capture** : la voix et le widget arrivent toujours dans « À trier » (ADR-014). Ce qui est créé dans l'app (le « + », le champ d'une liste de la Mémoire) est rangé directement dans sa section. Le « + » ouvre une création complète (section, jour, durée, étiquette, échéance, notes), et ses champs suivent le type de la section choisie.
- **Envie planifiée** : un élément `memory` peut être posé sur un jour par son bouton « Planifier ». Coché dans la journée, il demande l'avis, puis rejoint la mémoire de sa section.
- **Liste à cocher** : cocher marque l'article comme fait ; « Vider les cochés » le supprime (tombstone).
- **Période** : deux clés-jour, `startDate` et `endDate`, bornes incluses. Une période n'a ni heure ni durée et ne se pose jamais dans la journée. Le calendrier l'affiche en bandeau sur ses jours, en vue Semaine et dans une nouvelle vue **Mois**, pour voir à combien de semaines tombe un voyage.
- **Sections d'avant la v2** : leur type n'est pas enregistré (`kind` nul). Il se déduit de leurs règles : mémoire → `memory`, non planifiable → `checklist`, nom évoquant un voyage (« voyage », « trip », « vacances », « séjour ») → `periods`, sinon `tasks`. Le type se change dans l'éditeur de section.

**Conséquences** : schéma SwiftData `SchemaV2` (champs facultatifs `kindRaw`, `startDate`, `endDate`), avec une migration légère depuis `SchemaV1`, testée sur un store écrit sur disque. Backend : colonnes `sections.kind`, `tasks.start_date`, `tasks.end_date` (migration Alembic 0002), dans `POST /sync`. Une période dont la fin précède le début est refusée. Une section « Voyages » est fournie aux nouvelles installations. Remplace la mention « vue mois en v2 » du plan.

---

## ADR-016 — Capture séparée, sous-tâches, modèles de la Mémoire, widgets d'affichage

**Date** : 2026-11-04 · **Statut** : figée

**Contexte** : nouvelles idées de l'utilisateur (`docs/retours-v1.md`, « Idées pour la Mémoire », « Idées sur les tâches et la capture », « Widgets et Siri ») : séparer tâches et mémoire dès la capture, découper une tâche en étapes, donner à chaque liste de la Mémoire ses propres champs, voir sa journée sur l'écran verrouillé et sa semaine sur l'écran d'accueil.

**Décision** :
- **Deux « À trier »** : une capture sans section porte un espace (`spaceRaw` : nul pour la boîte, `memory` pour la Mémoire). Siri a deux raccourcis (« Capturer », « Garder en mémoire »), le widget de capture deux zones en taille moyenne et un widget Mémoire à part. Une entrée rangée prend l'espace de sa section ; retirée de sa section, elle revient dans le bon « À trier ». Le « + » a deux onglets, Tâche et Mémoire.
- **Sous-tâches** : une liste ordonnée d'étapes (`Subtask` : id, titre, fait), rangée dans la tâche en JSON (`subtasksRaw`). Pas de modèle à part : les étapes se synchronisent avec leur tâche, sous la même règle « dernière écriture gagnante » (ADR-009). Cocher toutes les étapes ne termine pas la tâche.
- **Modèles de section** (`SectionTemplate`) : Courses, Films et séries, Recettes, Voyages, Liste simple. Le modèle décide du type d'ADR-015, de l'avis (films, recettes, voyages oui ; courses et liste simple non) et des photos (voyages, recettes). On crée autant de sections qu'on veut à partir d'un modèle ; un nouveau modèle s'ajoute dans le code. Les valeurs des champs (genre, plateforme, résumé, lieu, ingrédients, étapes) sont rangées dans la tâche en JSON (`fieldsRaw`, clés stables) ; leur présentation (libellés, choix proposés) vit dans l'app. Une section d'avant la v3 sans modèle enregistré le déduit de son type et de son nom (une liste mémoire inconnue devient une liste simple).
- **Avis** : cocher un élément d'une section qui demande l'avis ouvre la fenêtre d'avis, partout (journée, boîte, Mémoire) ; il reste modifiable depuis la fiche.
- **Photos** : gardées sur l'iPhone, un dossier par entrée dans l'espace de l'app. Ni synchronisées ni sauvegardées par le serveur pour l'instant (lot 15).
- **Courses vers Rappels** : « Copier pour Rappels » met les articles à acheter dans le presse-papiers, un par ligne ; collés dans une liste de Rappels, chaque ligne devient un rappel.
- **Widgets d'affichage** : un rectangle d'écran verrouillé (tâche en cours ou suivante, progression du jour) et un grand widget Semaine. L'app écrit un instantané calculé (`WidgetSnapshot`, deux semaines) dans les UserDefaults de l'App Group en passant au premier plan ou en le quittant ; le widget le lit sans ouvrir le store, qui garde un seul écrivain (ADR-006). Toucher le widget ouvre la journée ou le calendrier. Sans App Group (installation qui le retire, ADR-013), le widget invite à ouvrir l'app.

**Conséquences** : schéma SwiftData `SchemaV3` (champs facultatifs `spaceRaw`, `subtasksRaw`, `fieldsRaw` sur la tâche, `templateRaw` sur la section), migration légère depuis la v2, testée sur un store écrit sur disque. Backend : colonnes `tasks.space`, `tasks.subtasks`, `tasks.fields`, `sections.template` (migration Alembic 0003), dans `POST /sync` ; un espace ou un modèle inconnu est refusé. Les sections fournies portent leur modèle.

---

## ADR-017 — Import dans la Mémoire sans IA payante : TMDB, lecture des photos, partage

**Date** : 2026-11-04 · **Statut** : figée

**Contexte** : l'utilisateur veut surtout de l'aide pour la Mémoire : retrouver le résumé d'un film ou d'une série à partir de son nom, et transformer une photo, une capture ou un texte de recette (la plupart viennent de Picnic) en ingrédients et étapes (`docs/retours-v1.md`, « IA pour la Mémoire »). Contraintes : coût nul ou presque, pas de serveur en ligne pour l'instant, et un iPhone 14, donc sans l'IA intégrée d'Apple (réservée à l'iPhone 15 Pro et plus récents).

**Décision** :
- **Pas de modèle de langage.** Ni API payante, ni offre gratuite d'un tiers (Gemini) : on revient sur cette option seulement si les règles ne suffisent pas à l'usage.
- **Films et séries : TMDB.** L'app cherche le titre saisi sur TMDB (recherche « multi », en français), puis lit la fiche choisie avec ses plateformes d'abonnement en France, en une requête (`append_to_response=watch/providers`). Elle remplit le format, le genre, la plateforme, le résumé, l'identifiant TMDB et l'affiche. Les genres et les plateformes sont ramenés aux noms proposés par l'app (« Crime » → « Policier », « Disney Plus » → « Disney+ »). Tous les genres sont aussi gardés dans un champ `genres`, un par ligne, pour permettre plus tard plusieurs genres. L'affiche est gardée en cache sur l'iPhone.
- **Jeton TMDB** : le « jeton d'accès en lecture » de l'utilisateur, collé dans les réglages, rangé dans le trousseau. Il n'est jamais dans le code (le dépôt est public), ni dans les journaux, ni dans la synchro. Sans jeton ou sans réseau, la fiche se remplit à la main comme avant. La mention exigée par TMDB figure dans les réglages, et « Données de TMDB » sous les résultats.
- **Recettes : lecture du texte sur l'iPhone (Vision), puis découpage par règles** (paquet `MemoryImport`, Foundation seule, testé sous Windows et Linux). Les titres « Ingrédients », « Préparation », « Étapes » délimitent les parties ; une ligne avec une quantité est un ingrédient ; une étape commence par un numéro, « Étape N », ou une majuscule après un point. La disposition de Picnic est gérée : nom et quantité en colonnes (« Lentilles corail (200 g) »), numéros d'étape seuls, rubrique « Dans votre placard ». Plusieurs photos (les pages d'une recette) sont lues dans l'ordre puis découpées ensemble. Le résultat est **toujours relu** avant d'être posé dans la fiche.
- **Couverts** : nouveau champ `servings` des recettes, lu par le découpage (« pour 4 personnes », « 4 couverts »). La fiche recalcule les quantités pour un autre nombre de couverts (première quantité de chaque ligne, arrondis de cuisine), sans changer la recette enregistrée.
- **Pages web** : un lien partagé est lu par l'app. La plupart des sites de recettes décrivent leur recette pour les moteurs de recherche (schema.org `Recipe`), ce qui donne les ingrédients et les étapes sans IA. Sans cette description, seuls le titre de la page et le lien (champ `source`) restent.
- **Extension de partage « MotivPlan »** : depuis Picnic, Safari ou Photos, une ou plusieurs images, un texte ou un lien. L'extension n'ouvre pas le store : elle dépose une fiche dans un dossier de l'App Group, puis l'app la transforme en recette dans la première section Recettes en passant au premier plan. Le store garde ainsi un seul écrivain (ADR-006). Sans App Group (installation qui le retire, ADR-013), l'extension renvoie vers « Importer une recette » dans l'app. Les images partagées deviennent les photos de la recette, gardées sur l'iPhone.

**Conséquences** : aucun changement de schéma ni de backend : les nouveaux champs (`servings`, `source`, `tmdb`, `poster`, `genres`) vivent dans `fieldsRaw` (ADR-016) et se synchronisent avec lui. Nouveau paquet `MemoryImport`, testé dans le job Linux de la CI. Nouvelle cible d'extension, donc un identifiant d'app de plus à signer avec le compte Apple gratuit (trois en tout : app, widget, partage).

---

## Journal du spike Siri hors-ligne (lot 0)

À remplir après le test sur appareil : modèle d'iPhone, version d'iOS, résultat verrouillé, résultat mode avion (phrase puis dictée), titres français qui ont été filtrés par Siri.
