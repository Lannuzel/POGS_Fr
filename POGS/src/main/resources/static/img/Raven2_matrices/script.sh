#!/bin/bash

# Dossier contenant les fichiers .png (ici, on suppose que c'est le dossier courant)
DIR="."

# Initialiser le compteur à 1
count=1

# Boucler sur les fichiers .png du dossier, triés par nom
for file in $(ls $DIR/*.png | sort -V); do
    # Renommer le fichier avec le compteur actuel
    mv "$file" "$DIR/$count.png"
    
    # Incrémenter le compteur
    count=$((count + 1))
done

echo "Tous les fichiers ont été renommés de 1 à $((count - 1))."
