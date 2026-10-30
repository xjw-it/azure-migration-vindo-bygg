// monitoring.bicep - action group and alert rules in Azure Monitor

param actionGroupName string
param alertEmail string
param vmId string
param tags object

// Who gets notified: an email to IT operations
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: 'vindo-ops'
    enabled: true
    emailReceivers: [
      {
        name: 'it-operations'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// Rule 1 (performance): finance VM CPU above 80 % for 15 minutes
resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-vm-finance-cpu-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'Finance VM average CPU is above 80 % for 15 minutes'
    severity: 2
    enabled: true
    scopes: [
      vmId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCpu'
          criterionType: 'StaticThresholdCriterion'
          metricName: 'Percentage CPU'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Rule 2 (security): someone deletes a VM, a disk or a backup vault
resource deleteAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-rg-critical-resource-deleted'
  location: 'global'
  tags: tags
  properties: {
    description: 'A VM, a disk or a backup vault was deleted in the resource group'
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          anyOf: [
            {
              field: 'operationName'
              equals: 'Microsoft.Compute/virtualMachines/delete'
            }
            {
              field: 'operationName'
              equals: 'Microsoft.Compute/disks/delete'
            }
            {
              field: 'operationName'
              equals: 'Microsoft.RecoveryServices/vaults/delete'
            }
          ]
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}
