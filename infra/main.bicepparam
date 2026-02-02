using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'env_name')

param resourceToken = 'neuralis-desk'

param location = readEnvironmentVariable('AZURE_LOCATION', 'location')

param aiLocation = 'swedencentral'

// param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', 'principal_id')

param postgresAdminPassword = readEnvironmentVariable('POSTGRESQL_ADMIN_PASSWORD', '')

param clientId = readEnvironmentVariable('AZURE_AUTH_CLIENT_ID', '')

param clientSecret = readEnvironmentVariable('AZURE_AUTH_CLIENT_SECRET', '')

