# Étude des maquettes (préparation du lot 10)

Étude faite le 2026-10-15 à partir de `docs/MotivPlan — maquettes.html`. Le fichier est un paquet de neuf écrans compressés (390 × 844 points, format iPhone). Ce document en extrait le système visuel, décrit chaque écran, et liste les écarts avec l'application telle qu'elle existe après les lots 0 à 8.

## 1. Système visuel

### Ambiance

L'application est entièrement sombre, sans mode clair dans les maquettes. Les surfaces sont des cartes très arrondies posées sur un fond presque noir, avec une seule couleur d'accent (lavande) pour ce qui est actif ou important. Aucun rouge n'apparaît : le retard utilise un ambre doux, ce qui respecte le principe « aucun rouge » du cahier des charges.

### Couleurs

| Rôle | Valeur |
|---|---|
| Fond de l'écran | `#0E0E11` |
| Surface basse (cartes discrètes, grille du mois) | `#141418` |
| Surface standard (cartes, lignes, pastilles) | `#18181C` |
| Barre d'onglets, tiroir replié | `#1B1B21` |
| Surface surélevée (ligne ouverte, ligne du tiroir) | `#202026` |
| Champ de saisie, puce inactive | `#23232B` |
| Contrôle (boutons ±, piste vide) | `#26262D` |
| Bordures | `#222228`, `#2C2C33`, `#3A3A44` |
| Texte principal | `#F4F4F6` |
| Texte secondaire | `#A3A3AD` |
| Texte tertiaire (heures, métadonnées) | `#8A8A95`, `#7C7C87` |
| Accent | `#8C8CFF` (variantes claires `#B9B9FF`, `#C4C4FF`) |
| Accent en fond léger | `rgba(140,140,255,0.16)` |
| Retard (ambre, jamais de rouge) | `#E2B062` |

L'accent est un réglage de la maquette : les options proposées sont `#8C8CFF` (défaut), `#6BA8F0`, `#5FC4B0` et `#E8E8EE`.

Chaque catégorie a une couleur vive (pour les points et les icônes) et une teinte sombre (pour les fonds de capsule) :

| Catégorie des maquettes | Vive | Fond sombre |
|---|---|---|
| Quotidienne | `#5FC4B0` | `#1F302D` |
| Courte | `#6BA8F0` | `#1E2A3A` |
| Moyenne | `#A592F2` | `#2A2638` |
| Longue | `#E58FB8` | `#3A2733` |
| Pro | `#C9D16E` | `#2E301E` |
| Heure fixe (ancre) | `#D8D8DE` | `#26262D` |
| Échéance | `#B9B9FF` | accent léger |
| Sans catégorie | `#8A8A95` | `#2E2E38` |

### Typographie

- Police **Manrope** (Google Fonts, licence libre OFL), graisses 400 à 800. À embarquer dans l'app.
- Titres d'écran : 30 pt, graisse 800, interlettrage −0,02 em.
- Titres de section : 17 à 22 pt, graisse 800.
- Texte des tâches : 15 pt, graisse 600 (700 pour la tâche en cours).
- Étiquettes de groupe : 12 pt, graisse 800, majuscules, interlettrage +0,06 em, couleur tertiaire.
- Métadonnées : 12 pt. Tous les chiffres (heures, durées, compteurs) utilisent des chiffres à chasse fixe (`monospacedDigit`).

### Formes et espacements

- Marges latérales : 16 pt pour les cartes, 20 pt pour les titres.
- Rayons : 18 à 22 pt pour les cartes et lignes, 24 à 26 pt pour les grandes cartes, capsules complètes pour les puces et boutons.
- Hauteurs : lignes de 52 à 58 pt, puces de 32 à 36 pt, cibles tactiles de 44 pt minimum partout.
- Ombres seulement sur les éléments flottants (barre d'onglets, tiroir, carte en cours de glissement).
- Icônes au trait (épaisseur 1,8 à 2,4), arrondies : l'équivalent iOS est SF Symbols.

## 2. Écrans

### Planning, vue Jour

- **En-tête** : nom du jour en petit, date en grand (« 12 octobre »), un bouton de recherche et une pastille d'initiale qui ouvre les réglages.
- **Bandeau de la semaine** : sept pastilles (L à D) avec le numéro du jour et une petite barre dont la longueur indique la charge. Le jour choisi est rempli d'accent.
- **Résumé** : trois puces : « 3 faites », « +45 pts », « Fin vers 16:15 ».
- **Frise** : une colonne d'heures (44 pt), une ligne verticale fine, puis pour chaque tâche une capsule verticale de 44 pt de large. La hauteur de la capsule suit la durée, et elle porte une icône. À côté de la capsule : « 09:15 – 10:15 · 1 h » puis le titre.
  - Une tâche faite a une capsule pleine de la couleur de sa catégorie, un titre barré et grisé, et une coche pleine.
  - La tâche en cours a une capsule sombre à bordure colorée avec un halo, un titre plus gros, et une puce « En cours · reste 1 h 23 ».
  - Une heure fixe a une capsule grise à bordure claire et le texte « heure fixe » à la place de la durée.
  - Une tâche à venir a une capsule sombre à bordure fine de sa couleur et un rond vide à cocher.
  - **Maintenant** : une ligne d'accent avec un point et l'heure (« 10:52 »).
  - **Trou** : une puce en pointillés « Créneau libre · 1 h 45 ».
- **Tiroir replié** : une barre posée **au-dessus** de la barre d'onglets (« Tiroir · 18 tâches · 2 pour aujourd'hui »). C'est ce qui corrige le défaut actuel du tiroir caché sous la barre d'iOS 26.
- **Barre d'onglets personnalisée**, flottante et arrondie, de gauche à droite : Planning, Boîte (avec un badge de nombre), un gros bouton « + » d'accent au centre (capture), Calendrier, Progrès.

### Tiroir ouvert

- La journée reste visible en haut, atténuée.
- Le tiroir est une feuille qui monte depuis le bas : poignée, titre « Tiroir 18 », un bouton pour le refermer, un champ « Ajouter une tâche… » avec un bouton de dictée.
- Des puces de filtre défilent horizontalement (« Toutes 11 », puis une par catégorie avec son point de couleur).
- Les tâches sont groupées par catégorie (en-tête en majuscules avec un point de couleur). Chaque ligne a une poignée de glissement, le titre, des puces d'échéance (« Aujourd'hui » en accent, « Prévu jeu. » en ambre, « Ven. » en gris) et la durée à droite.
- **Pendant un glissement**, la carte flotte inclinée de −2° avec une grosse ombre, et un emplacement en pointillés d'accent apparaît dans la frise : « Déposer ici · 16:15 – 16:30 ».

### Boîte de réception

- Titre plus le sous-titre « Tout est noté. Trie quand tu veux. »
- Un champ de capture avec un bouton de dictée en accent.
- Une **grille de 3 × 2 tuiles**, une par catégorie avec son point de couleur et son nombre de tâches (« Non triées 5 »…). La tuile choisie a une bordure d'accent.
- La liste de la tuile choisie : chaque ligne montre l'**icône de la source** (Siri, widget, saisie dans l'app) et une métadonnée (« Siri · il y a 12 min »). Toucher une ligne la déplie et propose des actions rapides : **Aujourd'hui**, **Demain**, Catégorie, Échéance, Détail.

### Capture rapide (bouton « + », widget)

- Plein écran : titre « Capturer », sous-titre « Juste un titre. Tout part dans la boîte de réception. »
- La liste « Ajoutées à l'instant » montre les dernières captures.
- Un encart rappelle Siri et les widgets.
- Le champ de saisie, bordé d'accent avec un halo, est collé au-dessus du clavier et a un bouton d'ajout. Le clavier reste ouvert pour enchaîner les captures.

### Calendrier

- Un sélecteur segmenté **Semaine | Mois** en haut à droite.
- **Mois** : une grille de sept colonnes ; chaque jour porte jusqu'à trois points. Le jour sélectionné est rempli d'accent et aujourd'hui est cerclé. Sous la grille vient l'agenda du jour choisi, avec trois sortes de lignes : heure fixe, tâche, échéance. Si le jour est vide : « Rien de prévu. Journée libre. »
- **Semaine** : « 12 – 18 octobre · Semaine 42 · 24 h 30 planifiées ». Une carte par jour avec jusqu'à trois puces de tâches (plus « +2 »), une barre de charge (sur une base de 8 h) et le total à droite. Aujourd'hui est bordé d'accent, et toucher une carte ouvre la journée.

### Détail d'une tâche

- « Retour » à gauche et « Enregistré automatiquement » à droite. Le titre est modifiable directement, en grand.
- Des cartes empilées : Catégorie (puces de couleur), Importance (Basse, Normale, Haute en segmenté), Échéance (Aujourd'hui, Demain, une date, Choisir…, Aucune), Durée (− et + par pas de 15 min), Heure fixe (interrupteur, puis −1 h, −15, l'heure, +15, +1 h) et Notes.
- En pied de page : « Créée via Siri le 9 oct. · reportée 2 fois » et un bouton « Supprimer » discret. Le nombre de reports n'apparaît qu'ici, ce qui respecte la règle « aucun compteur d'échec hors détail ».

### Progrès

- Un total de points en très grand (« 1 284 pts »), « +45 aujourd'hui », une barre vers le prochain palier, et la mention « Le total ne redescend jamais ».
- Les cartes « Série en cours » et « Cochées en 7 jours », un histogramme des 7 derniers jours, et une mosaïque du mois.

### Réglages

- Une carte de profil (initiale, prénom, « Synchronisé il y a 2 min » avec un point vert).
- **Journée** : début de journée (− et +), signal de débordement (« Au-delà de 30 min »).
- **Durée proposée au dépôt**, par catégorie.
- **Capture** : Siri, Widgets.
- **Synchronisation** : serveur, jeton (« Enregistré dans le trousseau »), mode hors-ligne.
- On l'ouvre depuis la pastille d'initiale de la vue Jour, en écran poussé avec un bouton retour.

## 3. Écarts avec l'application actuelle

### Les maquettes datent d'avant l'ADR-014

C'est l'écart principal. Les maquettes utilisent cinq **catégories de durée** (Quotidienne, Courte, Moyenne, Longue, Pro) et une **importance** (Basse, Normale, Haute). L'app utilise maintenant :

- des **sections** personnalisables (Quotidiennes, Récurrentes, Ponctuelles, Courses, Recettes, Films et séries) ;
- quatre **étiquettes** (urgent, travail, medium, détente).

Il faut décider ce que porte la couleur d'une tâche. La proposition est de donner **la couleur à l'étiquette** : il y a quatre étiquettes, presque autant que les couleurs des maquettes, et c'est l'information qui sert quand on regarde sa journée. Les **sections** prennent la place des catégories pour regrouper : tuiles de la boîte, groupes et filtres du tiroir. Une tâche sans étiquette reste grise. L'« Importance » du détail disparaît, remplacée par le choix d'étiquette.

### Écrans sans maquette

- L'écran d'une section, avec ses parties « à faire » et « mémoire ».
- Les fiches de mémoire (recettes, films) et la note « aimé / pas aimé ».
- L'éditeur de section.
- La vue Semaine plein écran actuelle, qui devient le mode « Semaine » du calendrier.

Ces écrans seront habillés avec les mêmes composants (cartes, puces, en-têtes en majuscules), sans maquette dédiée.

### Éléments des maquettes hors périmètre v1

- **Points et onglet Progrès** : prévus en v2 (cahier des charges §5, plan-dev). Les puces « +45 pts » et l'onglet Progrès ne peuvent pas être branchés en v1.
- **Vue Mois** : prévue en v2. Le segment « Mois » peut attendre.
- **Recherche** (bouton de la vue Jour) : jamais spécifiée.
- **Dictée** dans les champs : le clavier iOS a déjà un micro ; un bouton dédié est optionnel.
- **Signal de débordement réglable** : l'app a un seuil fixe ; le réglage peut être ajouté facilement.

### Navigation

| Maquettes | App actuelle |
|---|---|
| Planning, Boîte, « + », Calendrier, Progrès | Jour, Semaine, Boîte |
| Réglages via la pastille d'initiale | Réglages via un bouton de la vue Jour |
| Barre d'onglets personnalisée | Barre native iOS 26 (Liquid Glass) |

Une barre d'onglets personnalisée, dessinée en SwiftUI, reproduit fidèlement la maquette, donne une place au bouton « + » central et règle le problème du tiroir sous la barre. Elle perd en revanche l'effet de verre natif d'iOS 26. C'est la recommandation, car la maquette en dépend.

## 4. Approche technique proposée pour le lot 10

1. **Thème central** (`MotivPlan/DesignSystem/`) : couleurs en constantes, couleurs par étiquette, police Manrope embarquée avec des styles de texte nommés (titre d'écran, titre de section, tâche, méta, étiquette de groupe), et des composants réutilisables (carte, puce, ligne de liste, bouton ±, en-tête de groupe).
2. **Mode sombre forcé** (`preferredColorScheme(.dark)`), puisque les maquettes n'existent qu'en sombre.
3. **Coque** : barre d'onglets personnalisée avec le bouton « + » et le badge de la boîte, tiroir replié au-dessus de la barre.
4. **Écrans dans l'ordre d'usage** : Jour (frise en capsules, ligne « maintenant », créneaux libres, en cours), tiroir, Boîte (tuiles de sections, actions rapides), capture plein écran, Calendrier/Semaine, détail, sections et mémoire, réglages.
5. **Vérification** : les captures d'écran de la CI sont comparées aux maquettes à chaque étape. La logique et les tests du moteur ne changent pas.

## 5. Décisions prises (2026-10-15)

- **La couleur d'une tâche vient de son étiquette.** Les quatre étiquettes reprennent quatre couleurs des maquettes. Une tâche sans étiquette reste grise. Les sections servent seulement à regrouper : tuiles de la boîte, groupes et filtres du tiroir.
- **L'onglet Progrès est masqué en v1.** La barre devient : Planning, Boîte, « + », Calendrier. Progrès arrivera avec les points en v2, et la puce « +45 pts » de la vue Jour disparaît d'ici là.
- **La barre d'onglets est personnalisée**, comme dans la maquette, avec le bouton « + » central et le tiroir replié posé au-dessus.
- **Le bandeau des 7 jours est gardé** dans la vue Jour. **La recherche n'est pas faite.**
- Le segment « Mois » du calendrier n'a pas été tranché. Par défaut, il reste masqué jusqu'à la v2.
