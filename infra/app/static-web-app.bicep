@description('Name of the Static Web App')
param name string

@description('Location for Static Web App')
param location string = resourceGroup().location

@description('Tags for all resources')
param tags object = {}

@description('The id of the function app to integrate with')
param functionAppId string


@description('The SKU for the Static Web App')
@allowed(['Free', 'Standard'])
param sku string = 'Standard'

@description('Repository URL for the Static Web App source code')
param repositoryUrl string = ''

@description('Branch name for the Static Web App source code')
param branch string = 'main'

@description('GitHub token for CI/CD integration')
@secure()
param repositoryToken string = ''

@secure()
param clientId string 
@secure()
param clientSecret string

resource staticWebApp 'Microsoft.Web/staticSites@2024-04-01' = {
  name: name
  location: location 
  tags: tags
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    // Optional source control configuration - can be configured via GitHub Actions instead
    repositoryUrl: !empty(repositoryUrl) ? repositoryUrl : null
    branch: !empty(repositoryUrl) ? branch : null
    repositoryToken: !empty(repositoryUrl) ? repositoryToken : null
    buildProperties: {
      appLocation: '/apps/frontend'
      apiLocation: '' // Not using the built-in functions
      outputLocation: 'dist'
    }
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
  }
  identity: {
    type: 'SystemAssigned'
  }
  
}

resource staticWebAppConfig 'Microsoft.Web/staticSites/config@2024-04-01' = {
  parent: staticWebApp
  name: 'appsettings'
  properties:{
    AZURE_AUTH_CLIENT_ID: clientId
    AZURE_AUTH_CLIENT_SECRET: clientSecret
  }
}

// Link the Static Web App to the Function App API
// resource staticWebAppBackend 'Microsoft.Web/staticSites/linkedBackends@2024-11-01' = {
//   parent: staticWebApp
//   name: 'functionapp'
//   properties: {
//     backendResourceId: functionAppId
//     region: location
//   }
// }

// Add role assignment for Static Web App to call Function App
// resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(staticWebApp.id, functionAppId, 'contributor')
//   properties: {
//     roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role
//     principalId: staticWebApp.identity.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

output staticWebAppId string = staticWebApp.id
output staticWebAppName string = staticWebApp.name
output staticWebAppUrl string = staticWebApp.properties.defaultHostname
output staticWebAppApiUrl string = 'https://${staticWebApp.properties.defaultHostname}/api'
