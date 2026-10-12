# Cahier des charges — Application de planning personnel

**Version** : 0.1 (logique fonctionnelle et technique — le design visuel sera traité séparément)
**Utilisateur cible** : une seule personne (l'auteur). Pas de multi-utilisateur, pas de collaboration.

---

## 1. Contexte et objectif

L'utilisateur tient depuis un an des plannings quotidiens à cocher dans l'app Notes d'iPhone. Le système fonctionne sur le fond (cocher des tâches le motive) mais échoue sur la forme :

- les tâches auxquelles il pense en journée sont oubliées avant d'être notées ;
- le planning doit être réécrit à la main chaque jour ;
- l'interface ne permet aucune organisation.

L'application doit conserver ce qui marche (la satisfaction de cocher, la liste qui se remplit) et supprimer les frictions.

### Principes directeurs — non négociables

Ces principes priment sur toute fonctionnalité en cas de conflit.

1. **Capturer une tâche doit coûter un seul geste et un seul champ.** Le titre est le seul champ obligatoire, partout, toujours.
2. **L'app ne culpabilise jamais.** Pas de rouge, pas d'alerte, pas de score qui régresse, pas de compteur d'échecs mis en avant. Une journée ratée doit être invisible ou neutre. L'app est utilisée en priorité les jours où l'utilisateur va mal : si elle punit, elle sera désinstallée.
3. **L'app fonctionne intégralement hors-ligne.** Le réseau ne doit jamais bloquer une action, en particulier la capture.
4. **La manipulation se fait au doigt.** Drag & drop et boutons ±, pas de formulaires ni de sélecteurs d'heure.

---

## 2. Modèle de données

### 2.1 Entités

#### `Task`

Entité centrale. Une tâche existe d'abord en boîte de réception, puis peut être planifiée.

| Champ | Type | Obligatoire | Notes |
|---|---|---|---|
| `id` | UUID | oui | **Généré côté client** (nécessaire pour la création hors-ligne) |
| `title` | string | oui | Seul champ saisi à la capture |
| `notes` | string? | non | Texte libre |
| `category` | enum? | non | `quotidienne`, `courte`, `moyenne`, `longue`, `pro` |
| `importance` | enum? | non | `basse`, `normale`, `haute` — niveau intrinsèque, stable dans le temps |
| `due_date` | date? | non | Échéance. C'est ce champ, et non `importance`, qui porte le « à faire aujourd'hui » |
| `duration_min` | int? | non | Durée estimée en minutes. Nul tant que la tâche est en boîte de réception |
| `status` | enum | oui | `inbox`, `scheduled`, `done`, `archived` |
| `scheduled_date` | date? | non | Jour où la tâche est posée. Nul si `inbox` |
| `order_index` | int? | non | Position dans la séquence du jour (voir §3.1) |
| `is_anchored` | bool | oui | `false` par défaut. Si `true`, la tâche est fixée à une heure |
| `anchor_time` | time? | non | Heure de début fixe. Requis si `is_anchored` |
| `completed_at` | datetime? | non | |
| `postpone_count` | int | oui | Nombre de reports automatiques. Défaut 0 |
| `source` | enum | oui | `manual`, `siri`, `widget` — pour mesurer quels canaux servent réellement |
| `created_at` / `updated_at` | datetime | oui | |
| `deleted_at` | datetime? | non | Suppression logique (tombstone), nécessaire à la synchro |

**Note sur les catégories** : `courte` / `moyenne` / `longue` sont des **noms de catégories**, pas des durées. Elles ne doivent pas être interprétées comme une valeur de `duration_min`. Elles peuvent en revanche fournir une *suggestion* de durée par défaut au moment du drop, paramétrable et modifiable.

#### `Session`

Uniquement pour les tâches trop longues pour tenir dans une journée (typiquement catégorie `longue`). Une tâche peut avoir 0..n sessions.

| Champ | Type | Notes |
|---|---|---|
| `id` | UUID | Généré côté client |
| `task_id` | UUID | |
| `scheduled_date` | date | |
| `order_index` | int | |
| `duration_min` | int | |
| `completed_at` | datetime? | |

Une tâche possédant des sessions n'est **pas** posée directement dans la timeline : ce sont ses sessions qui le sont. Cocher une session ne termine pas la tâche ; la tâche se termine explicitement, ou lorsque l'utilisateur la marque comme faite.

#### `RecurrenceRule` (v2 — voir §8)

Pour les tâches `quotidienne`. Un modèle de tâche génère une occurrence par jour concerné.

| Champ | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `template_task_id` | UUID | |
| `frequency` | enum | `daily`, `weekly` |
| `weekdays` | int[]? | Pour `weekly` |
| `active_from` / `active_until` | date? | |

**Règle impérative** : une occurrence non faite **ne s'accumule pas** et **n'est pas reportée**. Elle disparaît silencieusement avec la journée. Une habitude ratée trois jours de suite ne doit pas produire trois tâches en retard.

#### `DayProgress`

Un enregistrement par jour, calculé à la clôture.

| Champ | Type | Notes |
|---|---|---|
| `date` | date | Clé |
| `tasks_planned` | int | |
| `tasks_done` | int | |
| `minutes_done` | int | |
| `points` | int | Voir §5 |

---

## 3. Règles métier

### 3.1 Positionnement dans la journée — modèle en séquence

La journée n'est **pas** une grille horaire. C'est une **séquence ordonnée de bulles**, à la manière de Structured.

- Une tâche planifiée n'a pas d'heure de début stockée : elle a un `order_index`.
- Les heures de début sont **calculées** à l'affichage : `heure_de_début(n) = heure_de_départ_du_jour + somme(durées des tâches 0..n-1)`.
- `heure_de_départ_du_jour` est un réglage global (par défaut 09:00).

Conséquences :

- **Décalage automatique en cascade** : rallonger une tâche de 30 min repousse mécaniquement toutes les suivantes. C'est le comportement souhaité — une journée qui dérape se replie sur elle-même au lieu d'afficher des conflits.
- **Réordonner = changer `order_index`**, une seule écriture, pas de recalcul d'heures à stocker.

### 3.2 Ancres

Une tâche avec `is_anchored = true` (rendez-vous, cours, réunion) est **fixée** à `anchor_time`.

- Les ancres découpent la journée en segments. La cascade s'applique à l'intérieur de chaque segment, jamais au travers d'une ancre.
- Si la séquence flottante déborde sur une ancre, l'excédent est poussé **après** l'ancre. L'ancre ne bouge jamais.
- Signalement visuel discret si le débordement est important. **Pas d'alerte bloquante, pas de rouge.**

### 3.3 Report automatique en fin de journée

À la première ouverture de l'app après minuit :

- toute tâche `scheduled` non faite de la veille voit `scheduled_date` passer au jour courant et `postpone_count` s'incrémenter ;
- l'ordre relatif est préservé ;
- **le report est silencieux** : pas de notification, pas d'écran de bilan, pas de mention de l'échec ;
- les occurrences récurrentes non faites ne sont pas reportées (§2.1).

`postpone_count` n'est **jamais** affiché sur la timeline. Il n'apparaît que dans le détail de la tâche, et au-delà d'un seuil (5 par défaut) il peut déclencher une suggestion neutre et actionnable, du type « découper cette tâche en sessions ? ». Jamais un reproche.

### 3.4 Échéances

- `due_date` dans le futur : la tâche remonte dans le tiroir à l'approche de la date.
- `due_date` = aujourd'hui : mise en avant dans le tiroir.
- `due_date` passée : la tâche est signalée comme en retard **dans le tiroir uniquement**, de façon sobre (pas de rouge agressif ni de badge alarmiste).
- « À faire absolument aujourd'hui » s'exprime par `due_date = today`, **pas** par `importance = haute`. C'est ce qui permet au signal de se périmer tout seul au lieu de saturer.

### 3.5 Durée

- `duration_min` est nul en boîte de réception.
- Au drop dans la timeline, la tâche reçoit une durée par défaut (30 min, ou la suggestion liée à sa catégorie si définie).
- Ajustement par poignée de redimensionnement (drag) ou par boutons ±15 min. Minimum 5 min.

---

## 4. Parcours fonctionnels

### 4.1 Capture (priorité absolue)

Trois canaux, tous devant aboutir à une `Task` avec `status = inbox` et le seul `title` renseigné :

1. **Siri / App Intents** — « Ajoute *sortir les poubelles* à [nom de l'app] ». Doit fonctionner écran verrouillé et sans ouvrir l'app.
2. **Widget écran d'accueil et écran verrouillé** — un bouton de saisie rapide, un champ, validation. Widget interactif (iOS 17+).
3. **Dans l'app** — champ de saisie permanent en haut du tiroir.

Contraintes : aucune des trois voies ne demande de catégorie, de date ou de durée. Aucune ne nécessite le réseau. Le retour visuel de confirmation doit être immédiat (< 200 ms perçus).

### 4.2 Tri de la boîte de réception

Écran listant les tâches `inbox`. Pour chaque tâche, en gestes rapides : attribuer une catégorie, une importance, une échéance, ou la glisser directement dans un jour. Aucun tri n'est imposé : une tâche peut rester en boîte de réception indéfiniment sans générer d'alerte.

### 4.3 Construction de la journée

Écran principal. Timeline du jour en haut ou au centre, tiroir de tâches accessible en bas (feuille modale glissante) ou sur le côté en paysage. On glisse une tâche du tiroir vers la timeline ; on réordonne par drag ; on redimensionne par poignée ou boutons ±.

Le tiroir est groupé par catégorie (les 5), avec tri interne par échéance puis importance.

### 4.4 Exécution

Cocher une tâche déclenche une animation de complétion (gratifiante, brève, < 600 ms) et un retour haptique. La tâche reste visible dans la journée, barrée ou repliée — voir la liste se remplir fait partie de ce qui motive l'utilisateur, elle ne doit pas disparaître.

---

## 5. Progression et récompense

Mécanique volontairement simple et **strictement monotone**.

- Cocher une tâche rapporte des points (proposition : 10 points + 1 point par tranche de 15 min de durée).
- Les points s'accumulent dans un total qui **ne diminue jamais**. Une journée vide rapporte zéro point — elle ne retire rien.
- Une série (`streak`) peut être affichée, mais elle se rompt sans conséquence chiffrée et redémarre à zéro sans commentaire.
- **Aucun mécanisme de punition, de dégradation ou de perte.** Pas d'animal virtuel qui dépérit, pas de score négatif, pas de rappel des échecs passés.

La forme visuelle de cette progression (barre, collection, vignettes) sera décidée lors du travail de design. Le backend expose les points, l'app décide de leur représentation.

---

## 6. Vues

| Vue | Contenu | Priorité |
|---|---|---|
| **Jour** | Timeline en bulles séquentielles, vue par défaut à l'ouverture | v1 |
| **Semaine** | 7 colonnes compactes, drag & drop entre jours | v1 |
| **Mois** | Densité par jour (nombre de tâches / taux de complétion), navigation | v2 |
| **Tiroir** | Backlog groupé par catégorie | v1 |
| **Boîte de réception** | Tâches non triées | v1 |

---

## 7. Architecture technique

### 7.1 Client — iOS natif

- **Swift 5.9+ / SwiftUI**, cible **iOS 17.0 minimum** (requis pour les widgets interactifs).
- **SwiftData** pour la persistance locale. La base locale fait autorité : toutes les lectures et écritures de l'interface passent par elle, jamais directement par le réseau.
- **App Intents** pour Siri et les raccourcis.
- **WidgetKit** pour le widget d'accueil et de verrouillage, partageant la base via un **App Group**.
- Drag & drop natif SwiftUI (`draggable` / `dropDestination`).
- Retour haptique via `CoreHaptics` ou `UIImpactFeedbackGenerator`.

Organisation recommandée : une cible principale, une extension widget, un module partagé contenant modèles et logique de calcul de timeline.

### 7.2 Backend — FastAPI / PostgreSQL

Rôle : miroir des données, synchronisation, sauvegarde. **Le backend ne doit jamais être sur le chemin critique d'une action utilisateur.**

- **FastAPI**, **SQLAlchemy 2.x**, **Alembic** pour les migrations, **Pydantic v2** pour les schémas.
- **PostgreSQL**.
- Déploiement conteneurisé (Docker), une seule instance suffit.
- Authentification : jeton statique stocké dans le Keychain pour la v1 (mono-utilisateur). Prévoir Sign in with Apple si l'app est un jour distribuée.

### 7.3 Synchronisation

Modèle **offline-first, réconciliation par horodatage**.

- Les identifiants sont des UUID générés par le client, ce qui permet de créer hors-ligne sans collision.
- Le client maintient une file d'opérations en attente, rejouée à la reconnexion.
- Réconciliation : **dernière écriture gagnante** sur `updated_at`. C'est suffisant pour un utilisateur unique sur un appareil ; ne pas sur-concevoir.
- Suppressions logiques via `deleted_at` afin qu'elles se propagent.
- Synchro déclenchée au passage en premier plan, après toute mutation locale, et en tâche de fond périodique.

### 7.4 API

```
GET    /health

POST   /sync                 # Échange bidirectionnel : le client envoie ses
                             # changements locaux + un curseur `since`,
                             # le serveur renvoie les changements distants.
                             # Endpoint principal — les routes ci-dessous
                             # servent au débogage et aux outils.

GET    /tasks?status=&date=
POST   /tasks
PATCH  /tasks/{id}
DELETE /tasks/{id}           # suppression logique

GET    /sessions?task_id=
POST   /sessions
PATCH  /sessions/{id}
DELETE /sessions/{id}

GET    /days/{date}          # tâches + sessions + progression du jour
GET    /progress?from=&to=   # séries de DayProgress
```

Schéma de `/sync` :

```json
// requête
{
  "since": "2026-09-14T08:00:00Z",
  "tasks": [ /* Task complètes modifiées localement */ ],
  "sessions": [ /* idem */ ]
}

// réponse
{
  "server_time": "2026-09-14T08:04:12Z",
  "tasks": [ /* Task modifiées côté serveur depuis `since` */ ],
  "sessions": [ /* idem */ ]
}
```

---

## 8. Lotissement

**v1 — le socle**
Capture (Siri, widget, in-app) · boîte de réception · 5 catégories · importance · échéance · vue jour en séquence avec cascade · ancres · drag & drop depuis le tiroir · redimensionnement · cochage avec animation · report automatique · vue semaine · synchro backend.

**v2 — la profondeur**
Récurrence des tâches quotidiennes · sessions pour les tâches longues · vue mois · progression et points · suggestion de découpage au-delà du seuil de reports.

**v3 — le confort**
Import du calendrier iOS en lecture seule (comme ancres) · notifications · statistiques personnelles · Apple Watch.

---

## 9. Points volontairement laissés ouverts

À trancher plus tard, ne pas décider par défaut dans le code :

- Représentation visuelle de la progression (§5).
- Emplacement exact du tiroir selon l'orientation (§4.3).
- Faut-il un moment de revue quotidien explicite, ou la construction de la journée se fait-elle au fil de l'eau ?
- Durées suggérées par catégorie : valeurs à calibrer sur l'usage réel.

---

## 10. Critères d'acceptation de la v1

1. Ajouter une tâche par Siri, téléphone verrouillé et en mode avion, aboutit à une tâche en boîte de réception visible à l'ouverture de l'app.
2. Glisser une tâche du tiroir vers la journée lui attribue une durée par défaut sans ouvrir le moindre formulaire.
3. Rallonger une tâche de 30 min décale toutes les tâches flottantes suivantes, sans jamais déplacer une ancre.
4. Une journée entière non faite est reportée au lendemain sans notification, sans écran de bilan et sans marqueur d'échec.
5. L'app reste pleinement utilisable, en lecture comme en écriture, sans aucune connexion réseau ; les données se réconcilient à la reconnexion sans perte.
