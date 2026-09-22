# POGS_Fr

Ce depot est un fork/adaptation locale de [CCI-MIT/POGS](https://github.com/CCI-MIT/POGS), utilise pour lancer POGS sans Docker avec trois processus separes :

- le serveur POGS Spring Boot
- un serveur Etherpad Lite
- un serveur Python de scoring

Le depot racine contient donc plus que l'application Java `POGS/` seule. La source applicative reste dans `POGS/`, mais l'exploitation locale se fait depuis la racine avec les scripts `start-pogs.sh`, `start-etherpad.sh`, `start-scoring.sh` et `script.sh`.

## Contenu du depot

- `POGS/` : application principale Spring Boot
- `etherpad-lite/` : instance Etherpad Lite embarquee dans le depot
- `start-pogs.sh` : lance le jar Spring Boot
- `start-etherpad.sh` : lance Etherpad
- `start-scoring.sh` : lance le serveur Python de scoring
- `script.sh` : lance les trois services dans `tmux`
- `pogs.sql`, `etherpad.sql`, `backup_all_db.sql` : dumps SQL locaux
- `pogs.service`, `etherpad.service` : unites systemd locales

## Architecture locale

Mode de fonctionnement attendu dans ce fork :

1. `POGS` ecoute sur `http://localhost:8080`
2. `Etherpad Lite` ecoute sur `http://localhost:9001`
3. `ScoringServer` ecoute sur `http://localhost:8082`
4. Le navigateur des joueurs se connecte a POGS, puis POGS ouvre au besoin une iframe Etherpad et appelle le serveur Python pour les taches a scoring externe

Points importants :

- Les scripts d'origine supposent un lancement depuis la racine du depot
- Les scripts d'origine ecrivent dans `/var/log`
- Plusieurs URLs et chemins sont hardcodes pour une machine Linux nommee `/root/POGS_Fr`
- Ce fork ne suit pas le workflow Docker documente dans le README upstream

## Dependances locales

Le fonctionnement local demande au minimum :

- Java 8
- Maven
- MySQL ou MariaDB
- Redis
- Python 3
- Node.js disponible dans le `PATH` pour Etherpad si on n'utilise pas `etherpad.service`
- `tmux` pour `script.sh`

Dependances versionnees visibles dans le code :

- `POGS/pom.xml` : Spring Boot `2.6.6`, Java `1.8`
- `POGS/pom.xml` : Node outille via Maven en `v12.13.1`, Yarn `v1.19.2`
- `etherpad.service` : chemin fige vers Node `v9.11.1` sous `nvm`

En pratique, ce depot melange donc au moins deux hypotheses de version Node :

- Etherpad/service : `v9.11.1`
- build front POGS via Maven : `v12.13.1`

## Lancement local

### Methode 1 : scripts shell d'origine

Depuis la racine du depot :

```bash
./start-etherpad.sh
./start-scoring.sh
./start-pogs.sh
```

Ou via `tmux` :

```bash
./script.sh
```

### Methode 2 : systemd

Les fichiers `pogs.service` et `etherpad.service` montrent l'intention de deploiement Linux, mais ils ne sont pas coherents a 100 % avec les scripts shell actuels.

## Configuration cle

### Application POGS

Fichiers :

- [application.yml](POGS/src/main/resources/application.yml)
- [application-database-config.yml](POGS/src/main/resources/application-database-config.yml)

Parametres saillants :

- port HTTP : `8080`
- timeout de session servlet : `7d`
- repertoire des plugins :
  `plugin.dir: /root/POGS_Fr/POGS/src/main/resources/plugins`
- base de donnees :
  `database.host: localhost:3306`
  `database.schema: pogs`
  `database.username: root`
  `database.password: admin`

### Etherpad

Les scripts de preparation des taches Etherpad appellent directement l'API Etherpad en local :

- [typingEtherpadPlugin/taskBeforeWork.js](POGS/src/main/resources/plugins/typingEtherpadPlugin/taskBeforeWork.js)
- [typingEtherpadPlugin/taskAfterWork.js](POGS/src/main/resources/plugins/typingEtherpadPlugin/taskAfterWork.js)
- [typingInColorsPlugin/taskBeforeWork.js](POGS/src/main/resources/plugins/typingInColorsPlugin/taskBeforeWork.js)
- [typingInColorsPlugin/taskAfterWork.js](POGS/src/main/resources/plugins/typingInColorsPlugin/taskAfterWork.js)

API configuree :

- `http://localhost:9001/api/1.2.13/`

### Scoring externe

Plugins concernes :

- [typingPlugin/pluginProperties.yml](POGS/src/main/resources/plugins/typingPlugin/pluginProperties.yml)
- [typingEtherpadPlugin/pluginProperties.yml](POGS/src/main/resources/plugins/typingEtherpadPlugin/pluginProperties.yml)
- [typingInColorsPlugin/pluginProperties.yml](POGS/src/main/resources/plugins/typingInColorsPlugin/pluginProperties.yml)

URLs configurees :

- `typingPlugin` : `http://10.192.132.11:8082/typingTask`
- `typingEtherpadPlugin` : `http://localhost:8082/typingTask`
- `typingInColorsPlugin` : `http://localhost:8082/typingInColorsTask`

## Differences principales avec CCI-MIT/POGS

Comparaison faite contre `CCI-MIT/POGS` commit `5d67d13294c62e5f3d4eb5c72de72bffa2962353`.

Principales differences fonctionnelles et d'exploitation :

1. Ce fork est exploite sans Docker
   Le README upstream est centre sur `docker-compose`, alors que ce depot fonctionne via scripts shell racine et une instance Etherpad embarquee.

2. Le repertoire de plugins est hardcode
L'upstream utilise `${user.home}/plugins`. Ici, [application.yml](POGS/src/main/resources/application.yml) force `/root/POGS_Fr/POGS/src/main/resources/plugins`.

3. Le chargement des plugins est plus strict
[ApplicationStartup.java](POGS/src/main/java/edu/mit/cci/pogs/listeners/ApplicationStartup.java) lance une exception si le repertoire de plugins n'existe pas ou est vide.

4. Etherpad est traite comme un service local du fork
   Le depot contient `etherpad-lite/`, un script `start-etherpad.sh`, une unite `etherpad.service`, et des plugins qui appellent explicitement Etherpad en local.

5. Plusieurs plugins ont ete modifies
   Les changements concernent surtout `typingEtherpadPlugin`, `typingInColorsPlugin`, `equationTypingPlugin`, `sudokuPlugin`, `pogs.js`, `pogsDashboard.js`, et le scoring Python.

6. Des assets de taches et de demos ont ete ajoutes
   Images Raven/RMET, demo `others/T1ShortDemo1`, fichiers utilitaires et binaires locaux.

7. Un controleur experimental "players ready" a ete ajoute
[GameController.java](POGS/src/main/java/edu/mit/cci/pogs/controller/GameController.java) n'existe pas upstream et n'est pas integre correctement au reste de l'application.

## Scoring des taches

POGS stocke en general les scores dans un objet `CompletedTaskScore` avec :

- `totalScore`
- `numberOfRightAnswers`
- `numberOfWrongAnswers`
- `numberOfEntries`
- `numberOfProcessedEntries`
- `scoringData`

Deux mecanismes existent :

1. scoring `script`
   Un `taskScore.js` calcule le score cote application

2. scoring `externalService`
   POGS poste les donnees au serveur Python `others/ScoringServer/server.py`

Reference d'integration :

- [CompletedTaskService.java](POGS/src/main/java/edu/mit/cci/pogs/service/CompletedTaskService.java)
- [CompletedTaskScoreService.java](POGS/src/main/java/edu/mit/cci/pogs/service/CompletedTaskScoreService.java)

### Typing et Brainstorming (`typingPlugin`, `typingEtherpadPlugin`)

Code principal :

- [typingTask.py](POGS/others/ScoringServer/typingTask.py)
- [textMatchingClasses.py](POGS/others/ScoringServer/scoring_algorithms/textMatchingClasses.py)

Deux modes existent selon `dictionaryHasGroundTruth`.

#### Cas 1 : dictionnaire avec ground truth

Le texte tape est compare a un texte de reference.

Principe :

- on decoupe en lignes non vides
- chaque ligne est comparee au texte de reference avec `SequenceMatcher`
- un mot est compte comme copie s'il appartient a un bloc de correspondance d'au moins 2 mots
- si `punishError = False`, le score est :
  nombre de mots uniques correctement recopies
- si `punishError = True`, un malus est applique pour les trous et mots deplaces

Dans `typingTask.py`, le score final d'equipe est ensuite normalise :

```text
normalized_total_score = score_groupe / score_max_theorique * 100
```

Le `scoringData` contient aussi un detail par auteur via les attributs `fullTextAuthor_*`.

#### Cas 2 : dictionnaire sans ground truth

Ce mode correspond au brainstorming de mots.

Principe actuel :

- POGS lit `fullText`
- coupe le texte par lignes
- compare chaque ligne a chaque entree du dictionnaire
- si une ligne correspond a une entree de type `C`, la categorie de cette entree est marquee comme trouvee
- le score final n'est pas le nombre de mots valides mais le nombre de categories correctes distinctes trouvees

Implications importantes :

- deux bons mots de la meme categorie rapportent `1` au total
- les lignes vides sont comptees dans `numberOfEntries`
- les reponses inconnues partent dans `unprocessedEntries` et peuvent etre enregistrees comme `UnprocessedDictionaryEntry`

Autrement dit, le "Brainstorming word" actuel mesure surtout la couverture des categories du dictionnaire, pas simplement le volume de bonnes idees.

### Typing in Colors

Code principal :

- [typingInColorsTask.py](POGS/others/ScoringServer/typingInColorsTask.py)

Principe :

- le blueprint de tache decrit des sections de texte et une couleur par section
- pour chaque couleur, le serveur recupere :
  le texte attendu, le texte tape par l'auteur assigne, et l'auteur associe
- un score de correspondance textuelle est calcule pour chaque section
- un score global sur le texte complet est aussi calcule
- le tout est normalise par le score maximal theorique du texte de reference

Le `scoringData` contient :

- les scores par couleur/auteur
- le score du texte global
- le score final normalise

### Survey

Code principal :

- [surveyPlugin/taskScore.js](POGS/src/main/resources/plugins/surveyPlugin/taskScore.js)

Principe :

- `RIGHT_ANSWER_REWARD = 1`
- `WRONG_ANSWER_REWARD = 0`
- une reponse correcte vaut `1`, une reponse incorrecte vaut `0`
- prise en charge des champs simples et de certains champs multiples

### Survey Two Answers

Code principal :

- [surveyTwoAnswersPlugin/taskScore.js](POGS/src/main/resources/plugins/surveyTwoAnswersPlugin/taskScore.js)

Principe :

- `RIGHT_ANSWER_REWARD = 1`
- `WRONG_ANSWER_REWARD = -3`
- la tache attend deux reponses pour une meme question
- le score d'equipe et les scores individuels peuvent etre fortement penalises en cas d'erreur

### Memory Grid

Code principal :

- [memoryGridPlugin/taskScore.js](POGS/src/main/resources/plugins/memoryGridPlugin/taskScore.js)

Principe :

- `RIGHT_ANSWER_REWARD = 1`
- `WRONG_ANSWER_REWARD = 0`
- chaque cellule correctement restituee vaut `1`

### Sudoku

Code principal :

- [sudokuPlugin/taskScore.js](POGS/src/main/resources/plugins/sudokuPlugin/taskScore.js)

Principe :

- `RIGHT_ANSWER_REWARD = 1`
- `WRONG_ANSWER_REWARD = 0`
- le score est la somme des cellules justes

### Equation Typing

Code principal :

- [equationTypingPlugin/taskScore.js](POGS/src/main/resources/plugins/equationTypingPlugin/taskScore.js)

Principe :

- `RIGHT_ANSWER_REWARD = 1`
- `WRONG_ANSWER_REWARD = 0`
- une equation est valide si elle respecte les contraintes du blueprint :
  somme finale, reutilisation de membres, nombres autorises, pas de repetition, pas de permutation d'une autre equation
- le `scoringData` liste les causes de rejet equation par equation

### Wack-A-Mole

Code principal :

- [wackamolePlugin/taskScore.js](POGS/src/main/resources/plugins/wackamolePlugin/taskScore.js)
- [wackamoleKeyboardPlugin/taskScore.js](POGS/src/main/resources/plugins/wackamoleKeyboardPlugin/taskScore.js)
- [coloredWackamolePlugin/taskScore.js](POGS/src/main/resources/plugins/coloredWackamolePlugin/taskScore.js)

Principe :

- le score est la somme des `teamScoreRound`
- `numberOfEntries` est la somme des `totalTargetsAppearedRound`
- le detail par round est garde dans `scoringData`

### Minimum Effort

Code principal :

- [minimumEffortPlugin/taskScore.js](POGS/src/main/resources/plugins/minimumEffortPlugin/taskScore.js)

Principe :

- chaque round collecte les choix des sujets
- le minimum choisi dans le groupe determine les payouts de chacun
- `totalScore` est la moyenne des payouts d'equipe par round
- `scoringData` contient le detail complet des rounds et paiements

### Tic Tac Toe

Code principal :

- [ticTacToePlugin/taskScore.js](POGS/src/main/resources/plugins/ticTacToePlugin/taskScore.js)

Principe :

- une partie non nulle rapporte `1`
- une partie nulle rapporte `0`
- le score porte sur une seule grille par tache

### Jeopardy

Le plugin existe, mais son scoring est incomplet dans cette branche :

- [jeopardyPlugin/pluginProperties.yml](POGS/src/main/resources/plugins/jeopardyPlugin/pluginProperties.yml) declare `indexedAnswerOneAnswerKey`
- [jeopardyPlugin/taskScore.js](POGS/src/main/resources/plugins/jeopardyPlugin/taskScore.js) est vide
- ce type ne correspond pas a l'enum [ScoringType.java](POGS/src/main/java/edu/mit/cci/pogs/model/dao/taskplugin/ScoringType.java)

Il faut donc considerer ce plugin comme non fiabilise tant qu'un chemin de scoring clair n'est pas reintroduit.

## Audit technique local

### Problemes critiques

1. Les scripts de lancement d'origine sont fragiles

- [start-pogs.sh](start-pogs.sh) suppose qu'on est deja dans la racine puis fait `cd ./POGS`
- [start-scoring.sh](start-scoring.sh) suppose le meme contexte
- [start-etherpad.sh](start-etherpad.sh) appelle `node` ou un chemin absolu dependant de la machine
- tous ecrivent dans `/var/log`, ce qui casse facilement en local non-root

2. `pogs.service` est incoherent avec `start-pogs.sh`

- [pogs.service](pogs.service) fixe `WorkingDirectory=/root/POGS_Fr/POGS`
- [start-pogs.sh](start-pogs.sh) refait `cd ./POGS`

Avec systemd, cela pointe probablement vers `/root/POGS_Fr/POGS/POGS`.

3. `start-etherpad.sh` et `etherpad.service` ne reposent pas sur la meme hypothese Node

- [start-etherpad.sh](start-etherpad.sh) exige `node` dans le `PATH`
- [etherpad.service](etherpad.service) pointe vers `/root/.nvm/versions/node/v9.11.1/bin/node`

Le symptome observe localement (`node: not found`) est coherent avec cet ecart.

4. Le repertoire de plugins est hardcode

- [application.yml](POGS/src/main/resources/application.yml)
- [ApplicationStartup.java](POGS/src/main/java/edu/mit/cci/pogs/listeners/ApplicationStartup.java)

Si le depot n'est pas exactement sous `/root/POGS_Fr`, l'application ne charge pas les plugins.

5. `typingPlugin` envoie le scoring vers une IP fixe

- [typingPlugin/pluginProperties.yml](POGS/src/main/resources/plugins/typingPlugin/pluginProperties.yml)

Le plugin de typing simple/brainstorming appelle `http://10.192.132.11:8082/typingTask` au lieu de `localhost:8082`.

6. Le plugin Etherpad recree un pad quand un `padID` existe deja

- [taskBeforeWork.js](POGS/src/main/resources/plugins/typingEtherpadPlugin/taskBeforeWork.js)

La logique est inversee :

- si `padID` est absent, le code tente un `createOrRetrieve`
- si `padID` est present, le code cree un nouveau pad

Cela peut separer des joueurs sur des pads differents.

7. L'adresse Etherpad navigateur est hardcodee

- [taskWork.js](POGS/src/main/resources/plugins/typingEtherpadPlugin/taskWork.js)
- [typingInColorsPlugin/taskWork.js](POGS/src/main/resources/plugins/typingInColorsPlugin/taskWork.js)

Le navigateur des joueurs ne devrait pas dependre d'une IP reseau statique ou de `pogs.info`.

8. Le serveur de scoring parse trop strictement le `Content-Type`

- [server.py](POGS/others/ScoringServer/server.py)

Le test se fait sur l'egalite exacte de `application/x-www-form-urlencoded`, alors que Java envoie souvent `application/x-www-form-urlencoded; charset=UTF-8`.

Le resultat probable est :

- `postvars = {}`
- erreur ou score vide cote Python

### Problemes eleves

1. Les deconnexions joueurs sont plausiblement reelles et recurrentes

Indices :

- [WebSocketConfig.java](POGS/src/main/java/edu/mit/cci/pogs/config/WebSocketConfig.java) expose `/ws` en SockJS
- [WebSecurityConfig.java](POGS/src/main/java/edu/mit/cci/pogs/config/WebSecurityConfig.java) n'ignore CSRF que pour `/jitsiwebhook`
- `pogs.sql` contient de nombreux logs `Whoops! Lost connection to .../ws`

2. Le timeout de presence est court

- [SubjectHasSessionCheckInService.java](POGS/src/main/java/edu/mit/cci/pogs/service/SubjectHasSessionCheckInService.java)

Le seuil de perte de session est `20s`, ce qui laisse peu de marge si WebSocket/SockJS ou l'onglet navigateur ralentit.

3. Le check-in n'actualise le ping que sur les URLs contenant `/start/`

- [WorkspaceCheckinWSController.java](POGS/src/main/java/edu/mit/cci/pogs/view/workspace/WorkspaceCheckinWSController.java)
- [WorkspaceCheckinWSController.java](POGS/src/main/java/edu/mit/cci/pogs/view/workspace/WorkspaceCheckinWSController.java)

Cela rend le mecanisme de presence assez dependant du flux de pages.

4. Le brainstorming sans ground truth ne score pas le nombre de bons mots

- [typingTask.py](POGS/others/ScoringServer/typingTask.py)

Le score final est un nombre de categories distinctes trouvees, pas un nombre de reponses correctes.

5. `typingTask.py` a aussi un bug de cle JSON dans le detail individuel

- [typingTask.py](POGS/others/ScoringServer/typingTask.py)

Le dictionnaire Python utilise `max_score` comme cle variable au lieu de la chaine `"max_score"`.

6. Le code "players ready" ajoute mais n'est pas exploitable

- [GameController.java](POGS/src/main/java/edu/mit/cci/pogs/controller/GameController.java)
- [pogs.js](POGS/src/main/resources/static/js/pogs.js)
- [pogsDashboard.js](POGS/src/main/resources/static/js/pogsDashboard.js)

Problemes constates :

- package `com.example.controller`, donc hors namespace principal de l'app
- le POST client est commente
- `allPlayersReady()` renvoie un booleen nu mais le JS attend `data.allReady`
- `proceedToNextTask()` est appelee sans `this`
- `playersStatus` est une map, mais le JS la traite comme un tableau avec `forEach`

### Problemes moyens

1. Le mot de passe DB est hardcode a `admin`

- [application-database-config.yml](POGS/src/main/resources/application-database-config.yml)

2. Le wrapper Maven est casse

- `POGS/mvnw` et `POGS/mvnw.cmd` existent
- le dossier `.mvn/wrapper` est absent

Le build via `./mvnw` ne peut donc pas fonctionner tel quel.

3. L'API Etherpad a ete redescendue de `1.2.15` vers `1.2.13`

- [typingEtherpadPlugin/taskBeforeWork.js](POGS/src/main/resources/plugins/typingEtherpadPlugin/taskBeforeWork.js)
- [typingEtherpadPlugin/taskAfterWork.js](POGS/src/main/resources/plugins/typingEtherpadPlugin/taskAfterWork.js)
- [typingInColorsPlugin/taskBeforeWork.js](POGS/src/main/resources/plugins/typingInColorsPlugin/taskBeforeWork.js)
- [typingInColorsPlugin/taskAfterWork.js](POGS/src/main/resources/plugins/typingInColorsPlugin/taskAfterWork.js)

Ce choix peut etre volontaire, mais il couple fortement le fork a une version precise d'Etherpad.

4. Des fichiers locaux et temporaires sont versionnes

Exemples :

- `others/ScoringServer/server copy.py`
- `__pycache__`
- binaires Node locaux dans `POGS/node/`
- dumps SQL volumineux

Cela alourdit le depot et brouille la lecture des vraies modifications metier.

5. `AbstractDao.get()` a ete modifie pour lever un `NullPointerException`

- [AbstractDao.java](POGS/src/main/java/edu/mit/cci/pogs/model/dao/api/AbstractDao.java)

Ce changement remplace un `null` implicite par une exception peu parlante.

## Ordre recommande de correction

1. Stabiliser l'exploitation locale

- fiabiliser `start-pogs.sh`, `start-scoring.sh`, `start-etherpad.sh`
- corriger `pogs.service` et `etherpad.service`
- rendre `plugin.dir` configurable
- unifier la version Node attendue

2. Corriger les taches de typing

- remettre `typingPlugin` sur `localhost:8082`
- corriger la logique `padID`
- remplacer les URLs Etherpad hardcodees cote navigateur
- corriger le parsing `Content-Type` du serveur Python

3. Corriger la connectivite joueurs

- verifier CSRF/SockJS sur `/ws`
- augmenter le timeout de ping
- revisiter le cycle de check-in

4. Clarifier le scoring

- decider si le brainstorming doit scorer :
  le nombre de mots corrects, le nombre de categories, ou les deux
- documenter la convention retenue dans l'UI admin si necessaire

## Resume

Ce fork n'est pas une simple copie de l'upstream : c'est une variante d'exploitation locale centree sur des scripts shell, une instance Etherpad embarquee et un scoring Python manuel. Les modifications les plus sensibles portent sur :

- les chemins et URLs hardcodes
- la robustesse de lancement
- la tache Etherpad
- le scoring du brainstorming
- la stabilite WebSocket des joueurs

Le point le plus important pour l'usage quotidien est que les symptomes de connexion et de scoring observes localement sont coherents avec le code actuel : ils ne ressemblent pas a des incidents aleatoires.
