// Bicep template to provision the infrastructure for the Document Translator Demo
// This template should be deployed at the SUBSCRIPTION level.
// Example Deployment Command:
// az deployment sub create --name DocumentTranslatorDeploy --location westus3 --template-file main.bicep --parameters projectName=doctranslatordemo

// PARAMETERS
@description('The base name for all resources. Must be globally unique and contain only lowercase letters and numbers.')
@minLength(5)
@maxLength(16)
param projectName string = 'doctranslatordemo'

@description('The Azure region where the resources will be deployed.')
param location string = deployment().location

@description('The name of the resource group to create.')
var resourceGroupName = '${projectName}-rg'

// VARIABLES
var storageAccountName = '${projectName}st'
var translatorServiceName = '${projectName}-translator'
var staticWebAppName = '${projectName}-app'
var documentStateTableName = 'documentstate'
var sourceContainerName = 'originals'
var destinationContainerName = 'translated'

// RESOURCE GROUP
// This creates the resource group that will contain all our services.
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

// AZURE STORAGE ACCOUNT
// This will hold our original, translated, and edited documents (in Blobs)
// and track the status of each translation job (in a Table).
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  resourceGroup: resourceGroupName
  sku: {
    // Standard_LRS is the most cost-effective option for this demo.
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// BLOB SERVICE and CONTAINERS
// We need two containers: one for uploaded original documents
// and one for the output of the translation service.
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource sourceContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: sourceContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource destinationContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: destinationContainerName
  properties: {
    publicAccess: 'None'
  }
}


// TABLE SERVICE and TABLE
// This table will store the metadata for each document, such as its ID,
// status (Queued, Processing, Completed, Rejected), and URLs.
resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource documentStateTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-01-01' = {
  parent: tableService
  name: documentStateTableName
}

// AZURE AI TRANSLATOR SERVICE
// This is the core AI service that will perform the document translation.
resource translatorService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: translatorServiceName
  location: 'global' // Document Translation service must be in a specific region or 'global'.
  resourceGroup: resourceGroupName
  kind: 'TextTranslation'
  sku: {
    // The S1 SKU is the standard pay-as-you-go tier.
    name: 'S1'
  }
  properties: {
    customSubDomainName: translatorServiceName
    publicNetworkAccess: 'Enabled'
  }
}

// AZURE STATIC WEB APP
// This service will host our React frontend and our .NET backend Functions.
// It simplifies deployment and hosting by bundling them together.
resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: staticWebAppName
  location: location
  resourceGroup: resourceGroupName
  sku: {
    // The 'Free' tier is sufficient for this demo.
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    // We will link the GitHub repository to this resource later in the Azure Portal.
    // This enables CI/CD.
  }
}

// OUTPUTS
// These outputs provide the names of the created resources, which will be useful for
// configuring our application settings later.
output resourceGroupName string = rg.name
output storageAccountName string = storageAccount.name
output translatorEndpoint string = translatorService.properties.endpoint
output staticWebAppName string = staticWebApp.name
output staticWebAppDefaultHostName string = staticWebApp.properties.defaultHostname
