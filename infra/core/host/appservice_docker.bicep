param location string = resourceGroup().location
param appServicePlanName string = 'myAppServicePlan'
param appName string = 'myAppService'
param dockerImage string = 'mydockerimage:latest'
param registryUrl string = 'myregistry.azurecr.io'
param registryUsername string = 'myRegistryUsername'
param registryPassword string = 'myRegistryPassword'

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'P1v2'
    tier: 'PremiumV2'
    size: 'P1v2'
    capacity: 1
  }
}

resource appService 'Microsoft.Web/sites@2021-02-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${registryUrl}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: registryUsername
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: registryPassword
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'true'
        }
      ]
      linuxFxVersion: 'DOCKER|${dockerImage}'
    }
  }
}

output appServiceEndpoint string = appService.properties.defaultHostName
