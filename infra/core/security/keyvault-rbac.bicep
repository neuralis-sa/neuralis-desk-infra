metadata description = 'Assigns RBAC roles to Azure Key Vault.'

param keyVaultName string
param principalId string

@allowed([
  'admin'
  'reader'
  'secrets-user'
  'secrets-officer'
  'crypto-user'
  'crypto-officer'
  'certificates-officer'
])
@description('Role level to assign to the principal')
param roleLevel string = 'reader'

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
  'ForeignGroup'
  'Device'
])
param principalType string = 'User'

// Mapping des rôles simplifiés vers les IDs Azure
var roleMapping = {
  admin: '00482a5a-887f-4fb3-b363-3b7fe8e74483'              // Key Vault Administrator
  reader: '21090545-7ca7-4776-b22c-e363652d74d2'             // Key Vault Reader
  'secrets-user': '4633458b-17de-408a-b874-0445c86b69e6'     // Key Vault Secrets User
  'secrets-officer': 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'  // Key Vault Secrets Officer
  'crypto-user': '12338af0-0e69-4776-b22c-e363652d74d2'      // Key Vault Crypto User
  'crypto-officer': '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'   // Key Vault Crypto Officer
  'certificates-officer': 'a4417e6f-fecd-4de8-b567-7b0420556985' // Key Vault Certificates Officer
}


resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, principalId, roleMapping[roleLevel])
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleMapping[roleLevel])
    principalId: principalId
    principalType: principalType
  }
}

output roleAssignmentId string = roleAssignment.id
output assignedPrincipalType string = principalType
output assignedRoleId string = roleMapping[roleLevel]
output roleLevel string = roleLevel
