using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'env_name')

param resourceToken = readEnvironmentVariable('AZURE_RESOURCE_TOKEN', 'neuralis-desk')

param location = readEnvironmentVariable('AZURE_LOCATION', 'location')

param aiLocation = 'swedencentral'

// param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', 'principal_id')

param postgresAdminPassword = readEnvironmentVariable('POSTGRESQL_ADMIN_PASSWORD', '')

param clientId = readEnvironmentVariable('AZURE_AUTH_CLIENT_ID', '')

param clientSecret = readEnvironmentVariable('AZURE_AUTH_CLIENT_SECRET', '')

// Supplying these makes the environment reuse an existing database / Web PubSub instead of
// provisioning its own. Left empty, the template creates them as before.
param postgresConnectionStringParam = readEnvironmentVariable('POSTGRESQL_CONNECTION_STRING_PARAM', '')

param postgresPoolerConnectionStringParam = readEnvironmentVariable('POSTGRESQL_POOLER_CONNECTION_STRING_PARAM', '')

param webPubSubConnectionString = readEnvironmentVariable('WEB_PUB_SUB_CONNECTION_STRING', '')

param webPubSubLocation = readEnvironmentVariable('AZURE_WEBPUBSUB_LOCATION', '')

param postgresDatabaseName = readEnvironmentVariable('POSTGRESQL_DATABASE_NAME', 'neuralis-desk')

param postgresDatabaseSchema = readEnvironmentVariable('POSTGRESQL_DATABASE_SCHEMA', 'neuralis-desk')

