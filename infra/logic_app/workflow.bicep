param logicAppName string = 'file-to-blob-logicapp'
param storageAccountName string
param fileShareName string
param blobContainerName string
param location string

// Référence au compte de stockage existant
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

// Récupérer la clé d'accès du compte de stockage
var storageAccountKey = listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value

// Définir les connections API
resource fileStorageConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'azurefilestorage'
  location: location
  properties: {
    displayName: 'Azure File Storage Connection'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azurefilestorage')
    }
    parameterValues: {
      accountName: storageAccountName
      accessKey: storageAccountKey
    }
  }
}

resource blobStorageConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'azureblob'
  location: location
  properties: {
    displayName: 'Azure Blob Storage Connection'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
    }
    parameterValues: {
      accountName: storageAccountName
      accessKey: storageAccountKey
    }
  }
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowDefinition.json#'
      'contentVersion': '1.0.0.0'
      'parameters': {
        '$connections': {
          'defaultValue': {}
          'type': 'Object'
        }
      }
      'triggers': {
        'When_a_file_is_added_or_modified': {
          'inputs': {
            'host': {
              'connection': {
                'name': '@parameters(\'$connections\')[\'azurefilestorage\'][\'connectionId\']'
              }
            }
            'method': 'get'
            'path': '/datasets/default/triggers/batch/onupdatedfile'
            'queries': {
              'folderId': fileShareName
              'maxFileCount': 10
            }
          }
          'recurrence': {
            'frequency': 'Minute'
            'interval': 5
          }
          'splitOn': '@triggerBody()'
          'type': 'ApiConnection'
        }
      }
      'actions': {
        'Get_file_content': {
          'inputs': {
            'host': {
              'connection': {
                'name': '@parameters(\'$connections\')[\'azurefilestorage\'][\'connectionId\']'
              }
            }
            'method': 'get'
            'path': '/datasets/default/files/@{encodeURIComponent(triggerBody()?[\'Path\'])}'
            'queries': {
              'inferContentType': true
            }
          }
          'runAfter': {}
          'type': 'ApiConnection'
        }
        'Create_blob': {
          'inputs': {
            'body': '@body(\'Get_file_content\')'
            'host': {
              'connection': {
                'name': '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
              }
            }
            'method': 'post'
            'path': '/datasets/default/files'
            'queries': {
              'folderPath': '/${blobContainerName}'
              'name': '@triggerBody()?[\'Name\']'
              'overwrite': true
            }
          }
          'runAfter': {
            'Get_file_content': [
              'Succeeded'
            ]
          }
          'type': 'ApiConnection'
        }
      }
    }
    parameters: {
      '$connections': {
        'value': {
          'azurefilestorage': {
            'connectionId': fileStorageConnection.id
            'connectionName': 'azurefilestorage'
            'id': subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azurefilestorage')
          }
          'azureblob': {
            'connectionId': blobStorageConnection.id
            'connectionName': 'azureblob'
            'id': subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
        }
      }
    }
  }
}

// Sortie de l'ID de la Logic App pour référence
output logicAppId string = logicApp.id
output logicAppName string = logicApp.name
