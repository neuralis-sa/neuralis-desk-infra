@description('Name of the PostgreSQL Flexible Server')
param name string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Tags for all resources')
param tags object = {}

@description('The administrator login for the PostgreSQL server')
param administratorLogin string = 'postgresadmin'

@description('The administrator password for the PostgreSQL server')
@secure()
param administratorLoginPassword string

@description('Database name')
param databaseName string

@description('PostgreSQL version')
@allowed(['11', '12', '13', '14', '15', '16'])
param version string = '16'

@description('PostgreSQL sku')
param skuName string = 'Standard_D2s_v3'

@description('PostgreSQL tier - Burstable, GeneralPurpose, or MemoryOptimized')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param tier string = 'Burstable'

@description('PostgreSQL storage size in GB')
param storageSizeGB int = 32

@description('Enable high availability')
param highAvailabilityMode string = 'Disabled'

@description('Backup retention days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Geo redundant backup')
param geoRedundantBackup string = 'Disabled'

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: tier
  }
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: highAvailabilityMode
    }
  }
}

// Database
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  name: databaseName
  parent: postgresServer
}

// Configure firewall rules - Allow Azure services
resource firewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  name: 'AllowAllAzureIPs'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Outputs
output postgresServerName string = postgresServer.name
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output databaseName string = database.name
output administratorLogin string = administratorLogin
output postgresId string = postgresServer.id
output postgresConnectionString string = 'postgresql://${administratorLogin}:${administratorLoginPassword}@${postgresServer.properties.fullyQualifiedDomainName}:5432/${databaseName}?connection_limit=1'
