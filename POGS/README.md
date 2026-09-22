# POGS — Fork FR

Fork de [CCI-MIT/POGS](https://github.com/CCI-MIT/POGS) adapté pour un déploiement Linux sans Docker, avec corrections de bugs et améliorations du scoring.

Le dépôt racine `POGS_Fr/` contient l'ensemble de l'infrastructure :

```
POGS_Fr/
├── POGS/                  ← application Spring Boot (ce dépôt)
├── etherpad-lite/         ← instance Etherpad Lite embarquée
├── start-pogs.sh          ← lance le jar Spring Boot
├── start-etherpad.sh      ← lance Etherpad
├── start-scoring.sh       ← lance le serveur Python de scoring
├── script.sh              ← lance les trois services dans tmux
├── pogs.service           ← unité systemd pour POGS
└── etherpad.service       ← unité systemd pour Etherpad
```

---

## Architecture

```
Navigateur joueur
      │
      ▼
POGS Spring Boot  :8080   ←──── MySQL :3306
      │                   ←──── Redis  :6379
      ├── iframe ──────▶  Etherpad Lite :9001
      └── scoring ──────▶ Python ScoringServer :8082
```

| Service | Technologie | Port |
|---------|-------------|------|
| Application principale | Spring Boot 2.6.6 / Java 8 | 8080 |
| Collaboration temps réel | Etherpad Lite (API 1.2.13) | 9001 |
| Serveur de scoring | Python 3 | 8082 |
| Base de données | MySQL 8 | 3306 |
| Cache de session | Redis | 6379 |

---

## Prérequis

- Java 8 JDK
- Maven 3.x
- MySQL 8
- Redis
- Python 3 (bibliothèques standard uniquement)
- Node.js (pour Etherpad — version recommandée : v14+)
- `tmux` (optionnel, pour `script.sh`)

---

## Installation

### 1. Base de données MySQL

```sql
CREATE SCHEMA pogs;
```

Configurer les identifiants dans `src/main/resources/application-database-config.yml` :

```yaml
database:
  host: localhost:3306
  schema: pogs
  username: root
  password: admin
```

### 2. Redis

```bash
redis-cli ping   # doit retourner PONG
# sinon :
redis-server &
```

### 3. Répertoire des plugins

Le chemin est défini dans `src/main/resources/application.yml` :

```yaml
plugin:
  dir: /root/POGS_Fr/POGS/src/main/resources/plugins
```

Adapter ce chemin si le dépôt n'est pas sous `/root/POGS_Fr/`.

### 4. Build

```bash
cd POGS/
mvn clean package -DskipTests
```

### 5. Lancement

#### Via scripts shell (depuis la racine `POGS_Fr/`)

```bash
./start-etherpad.sh
./start-scoring.sh
./start-pogs.sh
```

Ou tout en une fois avec tmux :

```bash
./script.sh
```

#### Via systemd

```bash
systemctl start pogs
systemctl start etherpad
cd POGS_Fr/POGS/others/ScoringServer && nohup python3 server.py > /tmp/scoring.log 2>&1 &
```

Rebuild et redémarrage :

```bash
cd POGS_Fr/POGS && mvn clean package -DskipTests 2>&1 | tail -5 && systemctl restart pogs
```

### 6. Initialisation de la base

Ouvrir dans un navigateur :

```
http://<serveur>:8080/initialize
```

Charger un fichier de configuration (ex : `others/T1ShortDemo.zip`) et cliquer sur **INITIALIZE**.

### 7. Interface admin

```
http://<serveur>:8080/admin
```

Identifiants par défaut :

```
Utilisateur : admin@pogs.info
Mot de passe : pogs1234
```

---

## Serveur de scoring Python

Lance indépendamment sur le port **8082** :

```bash
cd POGS/others/ScoringServer
python3 server.py
```

Redémarrage rapide après modification d'un fichier `.py` :

```bash
pkill -f 'python.*server.py'
nohup python3 server.py > /tmp/scoring.log 2>&1 &
```

---

## Types de sessions

| Type | Description |
|------|-------------|
| `SCHEDULED_DATE` | Session planifiée à une date et heure fixes |
| `PERPETUAL` | Session perpétuelle avec script de condition de démarrage |
| `PERPETUAL_LANDING_PAGE` | Session perpétuelle avec landing page publique |

### Fonctionnement des sessions perpétuelles

1. Les joueurs accèdent à `/sessions/{nom}` et s'enregistrent
2. Ils attendent sur la page `pre_check_in` (salle d'attente)
3. Le runner perpétuel vérifie toutes les 10 secondes le nombre de joueurs en attente
4. Quand le seuil est atteint, une sous-session est clonée automatiquement
5. Les joueurs sont redirigés vers leur sous-session via WebSocket

Le timeout de présence est de **60 secondes** — un joueur qui ne pingue plus est retiré de la file.

---

## Plugins et méthodes de scoring

POGS stocke les résultats dans un objet `CompletedTaskScore` :

| Champ | Description |
|-------|-------------|
| `totalScore` | Score final de l'équipe |
| `numberOfRightAnswers` | Nombre de bonnes réponses |
| `numberOfWrongAnswers` | Nombre de mauvaises réponses |
| `numberOfEntries` | Nombre total d'entrées soumises |
| `numberOfProcessedEntries` | Nombre d'entrées traitées (reconnues dans le dictionnaire) |
| `scoringData` | JSON détaillé (par round, par auteur, par catégorie…) |

Deux mécanismes de scoring existent :

- **`script`** : un fichier `taskScore.js` calcule le score côté application Java (Nashorn)
- **`externalService`** : POGS envoie les données au serveur Python et reçoit le score en retour

---

### Typing simple / Brainstorming (`typingPlugin`, `typingEtherpadPlugin`)

**Fichiers** : `others/ScoringServer/typingTask.py`

Le comportement dépend du paramètre `dictionaryHasGroundTruth`.

#### Mode avec vérité terrain (`dictionaryHasGroundTruth = true`)

Utilisé pour les tâches de recopie ou de complétion de texte.

- Le texte tapé par le groupe est comparé à un texte de référence (première entrée du dictionnaire)
- La comparaison utilise `SequenceMatcher` (algorithme LCS)
- Un mot est considéré correct s'il appartient à un bloc de correspondance d'au moins 2 mots consécutifs
- Le score est normalisé sur 100 : `score = (score_groupe / score_max) × 100`
- Un détail par auteur est calculé via les attributs `fullTextAuthor_*`
- `punishError = True` pour le score groupe (pénalise les trous et déplacements), `False` pour les scores individuels

#### Mode sans vérité terrain — Brainstorming (`dictionaryHasGroundTruth = false`)

Utilisé pour les tâches de génération libre de mots ou d'idées.

- Le texte est découpé ligne par ligne
- Les lignes vides et les doublons (insensibles à la casse) sont ignorés
- Chaque ligne est comparée à toutes les entrées du dictionnaire (comparaison insensible à la casse)
- Une entrée de type `C` (correcte) incrémente `correct_words_count` et enregistre la catégorie
- **`totalScore` = nombre de bons mots reconnus** (type C)
- `numberOfRightAnswers` = même valeur
- `numberOfWrongAnswers` = lignes non reconnues dans le dictionnaire
- `scoringData` contient le nombre de catégories distinctes trouvées et le détail par catégorie
- Les entrées non reconnues sont enregistrées dans `unprocessedEntries`

> Un mot écrit plusieurs fois ne compte qu'une seule fois (dédoublonnage avant scoring).

---

### Typing in Colors (`typingInColorsPlugin`)

**Fichiers** : `others/ScoringServer/typingInColorsTask.py`

Tâche de recopie collaborative où chaque section de texte est assignée à une couleur (et donc un auteur).

- Le blueprint décrit les sections et leurs couleurs attendues
- Pour chaque couleur : texte attendu, texte tapé, auteur associé
- Un score de correspondance textuelle est calculé par section avec `SequenceMatcher`
- Un score global sur le texte complet est aussi calculé
- Tout est normalisé par le score théorique maximum
- `scoringData` contient les scores par couleur/auteur et le score global normalisé

---

### Survey (`surveyPlugin`)

**Fichiers** : `plugins/surveyPlugin/taskScore.js`

- Bonne réponse : `+1`
- Mauvaise réponse : `0`
- `totalScore` = somme des bonnes réponses

---

### Survey Two Answers (`surveyTwoAnswersPlugin`)

**Fichiers** : `plugins/surveyTwoAnswersPlugin/taskScore.js`

- Bonne réponse : `+1`
- Mauvaise réponse : `−3`
- La tâche attend deux réponses par question
- Les scores individuels et d'équipe peuvent être fortement pénalisés

---

### Memory Grid (`memoryGridPlugin`)

**Fichiers** : `plugins/memoryGridPlugin/taskScore.js`

- Bonne cellule restituée : `+1`
- Mauvaise cellule : `0`
- `totalScore` = nombre de cellules correctes

---

### Sudoku (`sudokuPlugin`)

**Fichiers** : `plugins/sudokuPlugin/taskScore.js`

- Bonne case : `+1`
- Mauvaise case : `0`
- `totalScore` = nombre de cases correctement remplies

---

### Equation Typing (`equationTypingPlugin`)

**Fichiers** : `plugins/equationTypingPlugin/taskScore.js`

- Bonne équation : `+1`
- Mauvaise équation : `0`
- Une équation est valide si elle respecte toutes les contraintes du blueprint :
  - somme correcte
  - membres autorisés
  - pas de répétition d'une même équation
  - pas de permutation d'une équation déjà soumise
- `scoringData` liste les causes de rejet équation par équation

---

### Wack-A-Mole (`wackamolePlugin`, `wackamoleKeyboardPlugin`, `coloredWackamolePlugin`)

**Fichiers** : `plugins/wackamolePlugin/taskScore.js` (et variantes)

- `totalScore` = somme des `teamScoreRound` sur tous les rounds
- `numberOfEntries` = somme des cibles apparues (`totalTargetsAppearedRound`)
- `scoringData` contient le détail par round

---

### Minimum Effort (`minimumEffortPlugin`)

**Fichiers** : `plugins/minimumEffortPlugin/taskScore.js`

- À chaque round, chaque sujet choisit un effort
- Le minimum choisi dans le groupe détermine les paiements de chacun
- `totalScore` = moyenne des paiements d'équipe sur tous les rounds
- `scoringData` contient le détail complet des rounds et paiements individuels

---

### Tic Tac Toe (`ticTacToePlugin`)

**Fichiers** : `plugins/ticTacToePlugin/taskScore.js`

- Partie gagnée : `1`
- Partie nulle : `0`
- Score sur une seule grille par tâche

---

### Jeopardy (`jeopardyPlugin`)

Plugin présent mais scoring non implémenté dans cette version — `taskScore.js` est vide. À ne pas utiliser en production.

---

## Différences par rapport à CCI-MIT/POGS

| # | Modification |
|---|-------------|
| 1 | Déploiement sans Docker (scripts shell + systemd) |
| 2 | Etherpad embarqué dans le dépôt racine |
| 3 | URL scoring `typingPlugin` : IP fixe → `localhost:8082` |
| 4 | Logique `padID` corrigée dans `typingEtherpadPlugin/taskBeforeWork.js` |
| 5 | URLs Etherpad navigateur dynamiques (suppression des IPs en dur) |
| 6 | Parsing `Content-Type` robuste dans `server.py` (`cgi.parse_header`) |
| 7 | Scoring brainstorming : compte les bons mots, dédoublonnage des réponses |
| 8 | `scoringData` en JSON valide (`json.dumps` au lieu de `str()` Python) |
| 9 | Timeout de ping : 20s → 60s |
| 10 | Réinitialisation du flag `hasLostSession` à la reconnexion |
| 11 | Cookie path : `subjectCheckIn` appelé pour les sessions perpétuelles |
| 12 | Race condition corrigée dans `/check_in` (sous-session pas encore démarrée) |
| 13 | Guard null `JSON.parse` dans `pogs.js` pour `perpetualSubjectsChosen` |
| 14 | Comparaison `waitingRoomExpireTime` corrigée (`Date.getTime()`) |
| 15 | NPE corrigé dans `AbstractDao.get()` → retourne `null` au lieu de lever une exception |
| 16 | NPE corrigés dans `WorkspaceController` (lignes 263, 527, 1170) |
| 17 | NPE corrigé dans `EventLogService` (champs null dans JSON after-work) |
| 18 | `CompletedTaskService` : `totalScore` sauvegardé même si `scoringData` est mal formé |
| 19 | Suppression du code mort (`GameController`, méthodes JS inutilisées) |

---

## Fix Etherpad — encodage UTF-8

Si la base Etherpad présente des problèmes d'encodage après mise à jour :

```sql
ALTER DATABASE `etherpad_lite_db` CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin;
ALTER TABLE `store` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
ALTER TABLE `store` CHANGE `key` `key` VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
ALTER TABLE `store` CHANGE `value` `value` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
```
