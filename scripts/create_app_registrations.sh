#!/bin/bash

# ==========================
# Configuration
# ==========================
APP_NAME="Neuralis Desk"
REDIRECT_URI="https://localhost/auth/callback"
SECRET_NAME="sharepoint"

# Permissions
GRAPH_API_ID="00000003-0000-0000-c000-000000000000"
# Permissions à ajouter — ici, Sites.Selected (Application)
SITES_SELECTED_ID="neuralisch.sharepoint.com,d10a7f0a-308a-4ed6-822c-954c35c5c8a9,13cf4b80-761b-4bc7-b38e-a49896782475"

# ==========================
# Lecture des arguments
# ==========================
CREATE_SECRET=false
CREATE_ROLES=false
CREATE_API_PERMS=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--secret) CREATE_SECRET=true ;;
        -r|--roles) CREATE_ROLES=true ;;
        -p|--api-permissions) CREATE_API_PERMS=true ;;
        *) echo "❌ Argument inconnu : $1"; exit 1 ;;
    esac
    shift
done

# ==========================
# Étape 1 : Vérifier l'app
# ==========================
echo "🔍 Vérification de l'existence de l'application $APP_NAME..."
EXISTING_APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

if [ -z "$EXISTING_APP_ID" ]; then
    echo "🆕 Application inexistante — création..."
    APP_ID=$(az ad app create \
        --display-name "$APP_NAME" \
        --web-redirect-uris "$REDIRECT_URI" \
        --enable-id-token-issuance true \
        --enable-access-token-issuance true \
        --query appId -o tsv)
else
    echo "♻️ Application déjà existante — mise à jour..."
    APP_ID=$EXISTING_APP_ID
    az ad app update \
        --id "$APP_ID" \
        --web-redirect-uris "$REDIRECT_URI" \
        --enable-id-token-issuance true \
        --enable-access-token-issuance true >/dev/null
fi

echo "✅ App ID : $APP_ID"

# ==========================
# Étape 2 : Créer un secret (optionnel)
# ==========================
if [ "$CREATE_SECRET" = true ]; then
    echo "🔑 Création d’un secret client..."
    SECRET_VALUE=$(az ad app credential reset \
        --id "$APP_ID" \
        --display-name "$SECRET_NAME" \
        --years 1 \
        --query password -o tsv)

    echo "✅ Secret client créé : $SECRET_VALUE"
else
    echo "⚠️ Étape 'secret' ignorée (--secret non fourni)"
fi

# ==========================
# Étape 3 : Créer ou mettre à jour les rôles (optionnel)
# ==========================
if [ "$CREATE_ROLES" = true ]; then
    echo "⚙️ Mise à jour des App Roles..."

    OBJECT_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)

    APP_ROLES_JSON=$(cat <<EOF
[
  {
    "id": "$(uuidgen)",
    "allowedMemberTypes": ["User"],
    "displayName": "Admin",
    "description": "Administrateur de l'application",
    "value": "admin",
    "isEnabled": true
  },
  {
    "id": "$(uuidgen)",
    "allowedMemberTypes": ["User"],
    "displayName": "User",
    "description": "Utilisateur standard",
    "value": "user",
    "isEnabled": true
  }
]
EOF
)

    az rest --method PATCH \
      --uri "https://graph.microsoft.com/v1.0/applications/$OBJECT_ID" \
      --headers "Content-Type=application/json" \
      --body "{ \"appRoles\": $APP_ROLES_JSON }" >/dev/null

    echo "✅ App roles mis à jour : admin, user"
else
    echo "⚠️ Étape 'roles' ignorée (--roles non fourni)"
fi

# ==========================
# Étape 4 : Ajouter des permissions API (optionnel)
# ==========================
if [ "$CREATE_API_PERMS" = true ]; then
    echo "🔐 Ajout des permissions API Microsoft Graph"

    az ad app permission add \
        --id "$APP_ID" \
        --api "$GRAPH_API_ID" \
        --api-permissions "$SITES_SELECTED_ID=Role" >/dev/null

    echo "✅ Permission ajoutée : Sites.Selected (Application)"
    echo "⚠️ Nécessite un consentement admin :"
    echo "   az ad app permission grant --id $APP_ID --api $GRAPH_API_ID --scope Sites.Selected"
    echo "   az ad app permission admin-consent --id $APP_ID"
else
    echo "⚠️ Étape 'api permissions' ignorée (--api non fourni)"
fi

echo "🚀 Script terminé avec succès."
