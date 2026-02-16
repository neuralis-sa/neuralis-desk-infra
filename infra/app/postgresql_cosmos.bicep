@description('Nom du cluster Cosmos DB for PostgreSQL')
param name string

@description('Emplacement')
param location string = resourceGroup().location

@description('Tags')
param tags object = {}

@description('Mot de passe admin')
@secure()
param administratorLoginPassword string

@description('Version PostgreSQL')
@allowed(['11', '12', '13', '14', '15', '16'])
param postgresqlVersion string = '16'

@description('Nombre de nœuds worker')
param nodeCount int = 0

@description('Database name')
param databaseName string


resource cosmosPgCluster 'Microsoft.DBforPostgreSQL/serverGroupsv2@2023-03-02-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    administratorLoginPassword: administratorLoginPassword
    databaseName: databaseName
    nodeCount: nodeCount
    postgresqlVersion: postgresqlVersion
    coordinatorServerEdition: 'BurstableMemoryOptimized' // 'BurstableMemoryOptimized', 'BurstableGeneralPurpose', 'GeneralPurpose'
    coordinatorVCores: 1
    coordinatorStorageQuotaInMb: 32768 // 32 GB (32 * 1024) must be in MiB
  }
}

resource firewallRule 'Microsoft.DBforPostgreSQL/serverGroupsv2/firewallRules@2023-03-02-preview' = {
  name: 'AllowAllAzureIPs'
  parent: cosmosPgCluster
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output clusterName string = cosmosPgCluster.name
output clusterId string = cosmosPgCluster.id
output connectionPoolerString string = 'postgresql://citus:${administratorLoginPassword}@${cosmosPgCluster.properties.serverNames[0].fullyQualifiedDomainName}:6432/${databaseName}?pgbouncer=true&uselibpqcompat=true&sslmode=require&schema=neuralis-desk'
output connectionString string = 'postgresql://citus:${administratorLoginPassword}@${cosmosPgCluster.properties.serverNames[0].fullyQualifiedDomainName}:5432/${databaseName}?uselibpqcompat=true&sslmode=require&schema=neuralis-desk'
