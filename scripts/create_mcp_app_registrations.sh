#!/bin/bash
set -euo pipefail

# ==========================================================================
# Inscriptions Entra ID du serveur MCP de Neuralis Desk.
#
# Deux applications, deux rôles distincts :
#   1. l'API MCP — c'est elle qui définit les portées `mcp.read` / `mcp.write`
#      et dont les jetons portent l'audience ; l'API ne fait que les vérifier ;
#   2. le client — celui que Claude utilise pour mener le flux d'autorisation.
#      Entra ID ne propose pas d'enregistrement dynamique (RFC 7591), son
#      identifiant se saisit donc à la main dans le connecteur.
#
# Le script est idempotent : relancé, il met à jour au lieu de dupliquer.
# Il n'accorde pas le consentement administrateur (`az ad app permission
# admin-consent`), qui demande des droits d'annuaire : la dernière étape
# l'affiche, à exécuter par qui les a.
#
#   ./scripts/create_mcp_app_registrations.sh                 # production
#   ./scripts/create_mcp_app_registrations.sh --env staging
# ==========================================================================

ENVIRONMENT="production"
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -e|--env) ENVIRONMENT="$2"; shift ;;
        *) echo "❌ Argument inconnu : $1"; exit 1 ;;
    esac
    shift
done

case "$ENVIRONMENT" in
    production) SUFFIX="";     PUBLIC_URL="https://desk.neuralis.ch" ;;
    staging)    SUFFIX=" STG"; PUBLIC_URL="https://desk.neuralis.dev" ;;
    *) echo "❌ Environnement inconnu : $ENVIRONMENT (production|staging)"; exit 1 ;;
esac

# L'identifiant de ressource publié par l'API (`MCP_RESOURCE_URL`) doit être un
# URI d'ID d'application de cette inscription : c'est lui que le client transmet
# à Entra comme indicateur de ressource, et Entra n'y rattache les portées
# demandées que s'il connaît l'URI. Sinon l'autorisation échoue par
# `AADSTS9010010`. Il exige un domaine vérifié dans le tenant — à défaut, le
# script retombe sur le seul `api://<app-id>` et le dit.
RESOURCE_URL="$PUBLIC_URL/api/mcp"

API_APP_NAME="Neuralis Desk MCP${SUFFIX}"
CLIENT_APP_NAME="Neuralis Desk MCP Client${SUFFIX}"

# claude.ai renvoie ici après autorisation ; Claude Desktop et Claude Code
# utilisent une adresse de boucle locale, qu'on déclare aussi.
CLAUDE_REDIRECT_URIS=(
    "https://claude.ai/api/mcp/auth_callback"
    "https://claude.com/api/mcp/auth_callback"
)

GRAPH="https://graph.microsoft.com/v1.0"

echo "🌍 Environnement : $ENVIRONMENT ($PUBLIC_URL)"

# ==========================================================================
# 1. L'application d'API : porte les portées et l'audience des jetons
# ==========================================================================
API_APP_ID=$(az ad app list --display-name "$API_APP_NAME" --query "[0].appId" -o tsv)

if [ -z "$API_APP_ID" ]; then
    echo "🆕 Création de « $API_APP_NAME »…"
    API_APP_ID=$(az ad app create \
        --display-name "$API_APP_NAME" \
        --sign-in-audience AzureADMyOrg \
        --query appId -o tsv)
else
    echo "♻️  « $API_APP_NAME » existe déjà — mise à jour…"
fi

API_OBJECT_ID=$(az ad app show --id "$API_APP_ID" --query id -o tsv)
echo "✅ API   : $API_APP_ID"

# Les identifiants des portées et des rôles doivent rester stables d'une
# exécution à l'autre : on relit ceux qui existent avant d'en tirer de nouveaux,
# sans quoi un consentement déjà accordé serait invalidé.
read_scope_id() {
    az ad app show --id "$API_APP_ID" \
        --query "api.oauth2PermissionScopes[?value=='$1'].id | [0]" -o tsv 2>/dev/null
}
read_role_id() {
    az ad app show --id "$API_APP_ID" \
        --query "appRoles[?value=='$1'].id | [0]" -o tsv 2>/dev/null
}
or_new_uuid() { [ -n "${1:-}" ] && [ "$1" != "null" ] && echo "$1" || uuidgen | tr 'A-Z' 'a-z'; }

READ_SCOPE_ID=$(or_new_uuid "$(read_scope_id mcp.read)")
WRITE_SCOPE_ID=$(or_new_uuid "$(read_scope_id mcp.write)")
READ_ROLE_ID=$(or_new_uuid "$(read_role_id mcp.read)")
WRITE_ROLE_ID=$(or_new_uuid "$(read_role_id mcp.write)")

# `requestedAccessTokenVersion: 2` est indispensable : en v1 l'émetteur des
# jetons reste `https://sts.windows.net/<tenant>/`, et la portée n'arrive pas
# dans `scp` — l'API refuserait tout.
#
# Les rôles d'application homonymes des portées permettent d'accorder
# l'écriture personne par personne (« Utilisateurs et groupes » de
# l'entreprise), là où une portée déléguée vaut pour tout le monde.
cat > /tmp/mcp-api-manifest.json <<JSON
{
  "identifierUris": ["$RESOURCE_URL", "api://$API_APP_ID"],
  "api": {
    "requestedAccessTokenVersion": 2,
    "oauth2PermissionScopes": [
      {
        "id": "$READ_SCOPE_ID",
        "value": "mcp.read",
        "type": "User",
        "isEnabled": true,
        "adminConsentDisplayName": "Lire Neuralis Desk via MCP",
        "adminConsentDescription": "Permet à un assistant de consulter les données de Neuralis Desk, dans la limite des droits de l'utilisateur.",
        "userConsentDisplayName": "Lire vos données Neuralis Desk",
        "userConsentDescription": "L'assistant pourra consulter ce que vous pouvez consulter."
      },
      {
        "id": "$WRITE_SCOPE_ID",
        "value": "mcp.write",
        "type": "User",
        "isEnabled": true,
        "adminConsentDisplayName": "Modifier Neuralis Desk via MCP",
        "adminConsentDescription": "Permet à un assistant de modifier les données de Neuralis Desk, dans la limite des droits de l'utilisateur.",
        "userConsentDisplayName": "Modifier vos données Neuralis Desk",
        "userConsentDescription": "L'assistant pourra modifier ce que vous pouvez modifier."
      }
    ]
  },
  "appRoles": [
    {
      "id": "$READ_ROLE_ID",
      "value": "mcp.read",
      "allowedMemberTypes": ["User"],
      "isEnabled": true,
      "displayName": "MCP — lecture",
      "description": "Autorise ce collaborateur à consulter Neuralis Desk depuis un assistant."
    },
    {
      "id": "$WRITE_ROLE_ID",
      "value": "mcp.write",
      "allowedMemberTypes": ["User"],
      "isEnabled": true,
      "displayName": "MCP — écriture",
      "description": "Autorise ce collaborateur à modifier Neuralis Desk depuis un assistant."
    }
  ]
}
JSON

patch_api_app() {
    az rest --method PATCH \
        --uri "$GRAPH/applications/$API_OBJECT_ID" \
        --headers "Content-Type=application/json" \
        --body @/tmp/mcp-api-manifest.json
}

AUDIENCE="$RESOURCE_URL"
if ! patch_api_app; then
    # Presque toujours : « identifierUris must use a verified domain ». On ne
    # bloque pas l'installation pour autant — les jetons statiques et Claude
    # Code fonctionnent —, mais le connecteur claude.ai butera sur
    # AADSTS9010010 tant que le domaine n'est pas vérifié.
    echo "⚠️  L'URI $RESOURCE_URL a été refusé (domaine non vérifié dans le tenant ?)."
    echo "    Nouvel essai avec le seul api://$API_APP_ID."
    sed -i.bak "s|\"$RESOURCE_URL\", ||" /tmp/mcp-api-manifest.json
    patch_api_app
    AUDIENCE="api://$API_APP_ID"
    echo "⚠️  Le connecteur claude.ai refusera l'autorisation (AADSTS9010010) tant"
    echo "    que MCP_RESOURCE_URL ne sera pas un URI d'ID d'application : vérifier"
    echo "    le domaine ${PUBLIC_URL#https://} dans Entra, puis relancer ce script."
fi
rm -f /tmp/mcp-api-manifest.json /tmp/mcp-api-manifest.json.bak
echo "✅ Portées mcp.read / mcp.write et audience $AUDIENCE"

# ==========================================================================
# 2. L'application cliente : celle que Claude utilise
# ==========================================================================
CLIENT_APP_ID=$(az ad app list --display-name "$CLIENT_APP_NAME" --query "[0].appId" -o tsv)

if [ -z "$CLIENT_APP_ID" ]; then
    echo "🆕 Création de « $CLIENT_APP_NAME »…"
    CLIENT_APP_ID=$(az ad app create \
        --display-name "$CLIENT_APP_NAME" \
        --sign-in-audience AzureADMyOrg \
        --web-redirect-uris "${CLAUDE_REDIRECT_URIS[@]}" \
        --query appId -o tsv)
else
    echo "♻️  « $CLIENT_APP_NAME » existe déjà — mise à jour…"
    az ad app update --id "$CLIENT_APP_ID" \
        --web-redirect-uris "${CLAUDE_REDIRECT_URIS[@]}" >/dev/null
fi

echo "✅ Client : $CLIENT_APP_ID"

az ad app permission add \
    --id "$CLIENT_APP_ID" \
    --api "$API_APP_ID" \
    --api-permissions "$READ_SCOPE_ID=Scope" "$WRITE_SCOPE_ID=Scope" \
    2>/dev/null || echo "ℹ️  Permissions déjà déclarées"

echo ""
echo "──────────────────────────────────────────────────────────────────────"
echo "Réglages de la Function App (déjà dans env/$ENVIRONMENT/appsettings.$ENVIRONMENT.json"
echo "pour MCP_RESOURCE_URL ; les deux autres sont à y ajouter) :"
echo ""
echo "  MCP_OAUTH_ISSUER   = https://login.microsoftonline.com/$(az account show --query tenantId -o tsv)/v2.0"
echo "  MCP_OAUTH_AUDIENCE = $AUDIENCE"
echo "  MCP_RESOURCE_URL   = $PUBLIC_URL/api/mcp"
echo ""
echo "Connecteur claude.ai — URL $PUBLIC_URL/api/mcp, client $CLIENT_APP_ID"
echo "(un secret client se crée avec : az ad app credential reset --id $CLIENT_APP_ID)"
echo ""
echo "Reste le consentement administrateur, à exécuter par qui a les droits :"
echo "  az ad app permission admin-consent --id $CLIENT_APP_ID"
echo "──────────────────────────────────────────────────────────────────────"
