-- DetailedUsageExtended
IF OBJECT_ID('DetailedUsageExtended', 'V') IS NOT NULL
	DROP VIEW DetailedUsageExtended
GO
CREATE VIEW DetailedUsageExtended
	AS
	SELECT        DateFromParts([Year], [Month], 1) AS FullMonth, [Account Name], [Subscription Name], [Resource Location], InstanceType, InstanceID.Deployment, InstanceID.Tenant, CustomerTenant.Customer, DeploymentType, 
                         DeploymentStatus, DeploymentRegion, IIf([Meter Category]='Data Servcies',[Meter Category],IIf([Meter Category]='Cloud Services',[Meter Category],'Other')) AS Service, AS Service, [Consumed Service], AdditionalInfo, 
                         [Meter Category], [Meter Sub-Category], [Meter Region], [Meter Name], ExtendedCost, [Billing Country], [Account Owner], [MediusFlow version], [Type], [Invoice volume (annual)], [Partner/Reseller], [Delivery unit], 
                         [Mediusflow version hotfix], [AP Workflow system], [ERP], [ERP version], [Installation type]
FROM            dbo.CustomerTenant RIGHT JOIN
                         (dbo.Deployments RIGHT JOIN
                         (dbo.InstanceID RIGHT JOIN
                         [dbo].DetailedAzureUsage ON InstanceID.[InstanceID] = [dbo].DetailedAzureUsage.[Instance ID]) ON [dbo].Deployments.Deployment = InstanceID.Deployment) ON [dbo].CustomerTenant.Tenant = InstanceID.Tenant
GO
