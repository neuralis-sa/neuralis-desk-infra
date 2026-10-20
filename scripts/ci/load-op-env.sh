#!/usr/bin/env bash
# Lit un fichier KEY=VALUE depuis 1Password et expose chaque variable en sortie de step.
# Chaque valeur est masquée dans les logs avant d'être écrite.
# Usage : load-op-env.sh <op://vault/item/field>
set -euo pipefail

REFERENCE="${1:?Référence 1Password manquante}"

# Lecture en mémoire uniquement : aucun fichier temporaire sur le runner
CONTENT=$(op read "$REFERENCE")

while IFS='=' read -r key value; do
  # Ignorer les lignes vides et les commentaires
  if [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  # Nettoyer la clé (supprimer les espaces)
  key=$(echo "$key" | xargs)

  # Nettoyer la valeur (supprimer les guillemets si présents)
  value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')

  if [[ -n "$value" ]]; then
    echo "::add-mask::$value"
  fi

  echo "Loaded $key"
  echo "$key=$value" >> "$GITHUB_OUTPUT"
done <<< "$CONTENT"
