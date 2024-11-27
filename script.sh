#!/bin/bash

# Créer une nouvelle session tmux nommée "my_session"
tmux new-session -d -s my_session

# Dans la première fenêtre (0), exécuter la première commande
tmux send-keys -t my_session:0 'cd ./Bureau/POGS; java -jar target/pogs-0.0.1-SNAPSHOT.jar' C-m

# Créer une nouvelle fenêtre (1) dans la même session pour la deuxième commande
tmux new-window -t my_session:1
tmux send-keys -t my_session:1 'cd ./Bureau/etherpad-lite; ./bin/run.sh' C-m

# Attacher la session tmux pour voir les commandes s'exécuter dans les deux fenêtres
tmux attach-session -t my_session

