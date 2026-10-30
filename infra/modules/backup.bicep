// backup.bicep - Recovery Services vault, daily backup policy and VM protection

param location string
param vaultName string
param policyName string
param vmName string
param vmId string
param tags object

// The "bank vault": backups are stored here, separate from the VM.
// GeoRedundant: backups are also copied to the paired region (Sweden South, still in the EU)
resource vault 'Microsoft.RecoveryServices/vaults@2024-04-01' = {
  name: vaultName
  location: location
  tags: tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    redundancySettings: {
      standardTierStorageRedundancy: 'GeoRedundant'
      crossRegionRestore: 'Disabled'
    }
  }
}

// The "contract": back up every day at 21:00, keep for 7 days (lab)
resource policy 'Microsoft.RecoveryServices/vaults/backupPolicies@2024-04-01' = {
  parent: vault
  name: policyName
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRpRetentionRangeInDays: 2
    timeZone: 'W. Europe Standard Time'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2026-01-01T21:00:00Z'
      ]
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2026-01-01T21:00:00Z'
        ]
        retentionDuration: {
          count: 7
          durationType: 'Days'
        }
      }
    }
  }
}

// The "box we hand to the bank": protect the finance VM with the policy above
var containerName = 'iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
var protectedItemName = 'vm;iaasvmcontainerv2;${resourceGroup().name};${vmName}'

resource protectedItem 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-04-01' = {
  name: '${vault.name}/Azure/${containerName}/${protectedItemName}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: policy.id
    sourceResourceId: vmId
  }
}

output vaultName string = vault.name
