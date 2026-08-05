targetScope = 'subscription'

@minLength(1)
@maxLength(20)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@description('Name of the resource group to deploy all resources to.')
param resourceToken string

//Key vault
var keyVaultName = 'kv-${resourceToken}'

@description('Location for all resources.')
param location string

param aiLocation string = location

//Resources group
param rgName string = 'rg-${resourceToken}'

//Storage
@description('Name of Storage Account')
param storageAccountName string = 'storage${replace(resourceToken, '-', '')}'

// param blobContainerDocumentToHandleName string = 'document-to-handle'
// param blobContainerAppConfigName string = 'app-config-files'
// param documentQueueName string = 'documents'

// OpenAI
@description('Name of Azure OpenAI Resource')
param azureOpenAIResourceName string = 'openai-${resourceToken}'
@description('Name of Azure OpenAI Resource SKU')
param azureOpenAISkuName string = 'S0'

@description('Azure OpenAI Model Deployment Name')
param azureOpenAIModel string = 'gpt-5-mini'
@description('Azure OpenAI Model Name')
param azureOpenAIModelName string = 'gpt-5-mini'
param azureOpenAIModelVersion string = '2025-08-07'

@description('Azure OpenAI Turbo Model Deployment Name')
param azureOpenAITurboModel string = 'gpt-5-nano'
@description('Azure OpenAI Model Name')
param azureOpenAITurboModelName string = 'gpt-5-nano'
param azureOpenAITurboModelVersion string = '2025-08-07'

//Form recognition
@description('Azure Form Recognizer Name')
param documentIntelligenceName string = 'document-ai-${resourceToken}'

//function app name
@description('Name of the Function App')
param functionAppName string = 'func-${resourceToken}'

@description('Name of the Static Web App')
param staticWebAppName string = 'stapp-${resourceToken}'

@description('Name of the Static Web App')
param webPubSubAppName string = 'webpubsub-${resourceToken}'

@secure()
@description('Optional: Existing WebPubSub connection string. If provided, no new instance will be created.')
param webPubSubConnectionString string = ''

@description('PostgreSQL Flexible Server name')
param postgresServerName string = 'pg-${resourceToken}'

@description('PostgreSQL database name')
param postgresDatabaseName string = 'neuralis-desk'

@description('Schema the app and its migrations live in. Defaults to the production schema so an environment that omits it cannot end up with an empty `schema=` in its connection string.')
param postgresDatabaseSchema string = 'neuralis-desk'

@secure()
@description('Optional: Existing PostgreSQL pooler connection string. If provided, no new instance will be created.')
param postgresPoolerConnectionStringParam string = ''

@secure()
@description('Optional: Existing PostgreSQL connection string. If provided, no new instance will be created.')
param postgresConnectionStringParam string = ''

@secure()
@description('PostgreSQL administrator password')
param postgresAdminPassword string

@secure()
param clientId string 
@secure()
param clientSecret string


@allowed([
  'CRITICAL'
  'ERROR'
  'WARN'
  'INFO'
  'DEBUG'
])
param logLevel string = 'INFO'

var tags = { 'azd-env-name': environmentName }

// Only used when this environment creates its own instance. The free tier is capped at 5 per region
// and the default region is already full, so a new instance needs a region with quota left.
param webPubSubLocation string = ''
var resolvedWebPubSubLocation = !empty(webPubSubLocation) ? webPubSubLocation : location

param githubUserPrincipalId string = '2f64aaa1-ba64-4793-94cb-802b125a25af'
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
  tags: tags
}

// Store secrets in a keyvault
module keyvault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: keyVaultName
    location: location
    tags: tags
  }
}

module storage 'core/storage/storage-account.bicep' = {
  name: storageAccountName
  scope: rg
  params: {
    name: storageAccountName
    location: location
    sku: {
      name: 'Standard_GRS'
    }
    deleteRetentionPolicy: {}
    containers: [
     
    ]
    queues: [
     
    ]
  }
}

module openai_datazone 'core/ai/cognitiveservices.bicep' = {
  name: '${azureOpenAIResourceName}-datazone'
  scope: rg
  params: {
    name: '${azureOpenAIResourceName}-datazone'
    location: aiLocation
    tags: tags
    sku: {
      name: azureOpenAISkuName
    }
    managedIdentity: false
    deployments: [
      {
        name: azureOpenAIModel
        model: {
          format: 'OpenAI'
          name: azureOpenAIModelName
          version: azureOpenAIModelVersion
        }
        sku: {
          name: 'DataZoneStandard'
          capacity: 1
        }
      }
      {
        name: azureOpenAITurboModel
        model: {
          format: 'OpenAI'
          name: azureOpenAITurboModelName
          version: azureOpenAITurboModelVersion
        }
        sku: {
          name: 'DataZoneStandard'
          capacity: 1
        }
      }
    ]
  }
}

module documentIntelligence 'core/ai/cognitiveservices.bicep' = {
  name: documentIntelligenceName
  scope: rg
  params: {
    name: documentIntelligenceName
    location: location
    tags: tags
    kind: 'FormRecognizer'
  }
}

// Deploy WebPubSub only if connection string is not provided
module webPubSub './app/webPubSub.bicep' = if (empty(webPubSubConnectionString)) {
  name: webPubSubAppName
  scope: rg
  params: {
    name: webPubSubAppName
    location: resolvedWebPubSubLocation
    tags: tags
  }
}

module webPubSubConnectionSringSecret './core/security/keyvault-secret.bicep' = {
  name: 'webPubSub-connection-string'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    name: 'WEBPUBSUB-CONNECTION-STRING'
    secretValue: empty(webPubSubConnectionString)
      ? webPubSub.outputs.webPuSubConnectionString
      : webPubSubConnectionString
  }
}


// PostgreSQL Flexible Server
// module postgresql './app/postgresql.bicep' = {
//   name: postgresServerName
//   scope: rg
//   params: {
//     name: postgresServerName
//     location: location
//     tags: tags
//     administratorLogin: postgresAdminLogin
//     administratorLoginPassword: postgresAdminPassword
//     databaseName: postgresDatabaseName
//     version: '16'
//     tier: 'Burstable'  // Options: Burstable, GeneralPurpose, MemoryOptimized
//     skuName: 'Standard_B1ms'  // For dev/test - adjust for production
//     storageSizeGB: 32
//     backupRetentionDays: 7
//     highAvailabilityMode: 'Disabled'  // Use 'ZoneRedundant' for production
//   }
// }
// Deploy PostgreSQL only if connection strings are not provided
module postgresql './app/postgresql_cosmos.bicep' = if (empty(postgresPoolerConnectionStringParam) && empty(postgresConnectionStringParam)) {
  name: postgresServerName
  scope: rg
  params: {
    name: postgresServerName
    location: location
    tags: tags
    administratorLoginPassword: postgresAdminPassword
    databaseName: postgresDatabaseName
    schemaName: postgresDatabaseSchema
  }
}

// Store PostgreSQL credentials in Key Vault
module postgresPoolerConnectionString './core/security/keyvault-secret.bicep' = {
  name: 'postgres-pooler-connection-string'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    name: 'POSTGRES-POOLER-CONNECTION-STRING'
    secretValue: empty(postgresPoolerConnectionStringParam)
      ? postgresql.outputs.connectionPoolerString
      : postgresPoolerConnectionStringParam
  }
}

module postgresConnectionString './core/security/keyvault-secret.bicep' = {
  name: 'postgres-connection-string'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    name: 'POSTGRES-CONNECTION-STRING'
    secretValue: empty(postgresConnectionStringParam)
      ? postgresql.outputs.connectionString
      : postgresConnectionStringParam
  }
}

module storekeys './app/storekeys.bicep' = {
  name: 'storekeys'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    storageAccountName : storage.outputs.name
    azureOpenAIName: openai_datazone.outputs.name
    documentIntelligenceName: documentIntelligence.outputs.name
    rgName: rgName
  }
}

module githubkeyvaultaccess './core/security/keyvault-rbac.bicep' = {
  name: 'github-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    principalId: githubUserPrincipalId
    roleLevel: 'secrets-officer'
    principalType: 'ServicePrincipal'
  }
}

// Azure Functions avec plan de consommation
module function './app/function.bicep' = {
  name: functionAppName
  scope: rg
  params: {
    name: functionAppName
    location: location
    tags: tags
    storageAccountName: storageAccountName
    keyVaultName: keyVaultName
    appSettings: {
      'AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT': documentIntelligence.outputs.endpoint
      'AZURE_DOCUMENT_INTELLIGENCE_KEY': '@Microsoft.KeyVault(SecretUri=${storekeys.outputs.DOCUMENT_INTELLIGENCE_KEY_SECRET_URI})'
      'AZURE_OPENAPI_VERSION': '2024-12-01-preview'
      'AZURE_OPENAPI_KEY': '@Microsoft.KeyVault(SecretUri=${storekeys.outputs.OPENAI_KEY_SECRET_URI})'
      'AZURE_OPENAPI_ENDPOINT': openai_datazone.outputs.endpoint
      'AZURE_OPENAPI_DEPLOYMENT_NAME': azureOpenAIModelName
      'AZURE_OPENAPI_TURBO_DEPLOYMENT_NAME': azureOpenAITurboModelName
      'DATABASE_URL': '@Microsoft.KeyVault(SecretUri=${postgresPoolerConnectionString.outputs.secretUri})'
      'WebPubSubConnectionString' : '@Microsoft.KeyVault(SecretUri=${webPubSubConnectionSringSecret.outputs.secretUri})'
    }
  }
}

// Static Web App with Function API integration
module staticWebApp './app/static-web-app.bicep' = {
  name: staticWebAppName
  scope: rg
  params: {
    name: staticWebAppName
    location: 'westeurope'
    tags: tags
    functionAppId: function.outputs.functionId
    sku: 'Standard' // Use Standard for production workloads
    clientId: clientId
    clientSecret: clientSecret
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// TODO: Streamline to one key=value pair
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = rgName

output LOGLEVEL string = logLevel

output AZURE_BLOB_ACCOUNT_NAME string = storageAccountName

// Add outputs for frontend integration
output STATIC_WEB_APP_URL string = staticWebApp.outputs.staticWebAppUrl
output STATIC_WEB_APP_API_URL string = staticWebApp.outputs.staticWebAppApiUrl
