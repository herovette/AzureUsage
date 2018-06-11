-- DetailedUsageExtended
IF OBJECT_ID('DetailedUsageExtended', 'V') IS NOT NULL
	DROP VIEW DetailedUsageExtended
GO
CREATE VIEW DetailedUsageExtended
	AS
SELECT [dbo].DetailedAzureUsage.*, 
	iif(IsNull([dbo].[DetailedAzureUsage].[Instance ID],'null')='null','Other',[dbo].[InstanceID].[InstanceType]) AS InstanceType, 
	[dbo].Deployments.Deployment, 
	[dbo].Tenants.Tenant, 
	[dbo].Tenants.Customer, 
	[dbo].Deployments.DeploymentType, 
	[dbo].Deployments.DeploymentStatus, 
	[dbo].Deployments.DeploymentRegion, 
	IIf([Consumed Service]='Database',[Consumed Service],IIf([Consumed Service]='Compute',[Consumed Service],'Other')) AS Service, 
	DateFromParts([Year],[Month],1) AS FullMonth
FROM Tenants 
RIGHT JOIN (Deployments 
	RIGHT JOIN (InstanceID 
		RIGHT JOIN [dbo].DetailedAzureUsage ON InstanceID.[Instance ID] = [dbo].DetailedAzureUsage.[Instance ID])
	ON [dbo].Deployments.Deployment = InstanceID.Deployment) 
	ON [dbo].Tenants.Tenant = InstanceID.Tenant
GO

-- CloudOpCost
IF OBJECT_ID('CloudOpCost', 'V') IS NOT NULL
	DROP VIEW CloudOpCost
GO	

CREATE VIEW CloudOpCost
	AS
SELECT dbo.DetailedUsageExtended.FullMonth, 
	Sum(dbo.DetailedUsageExtended.ExtendedCost) AS CloudOpCost
FROM dbo.DetailedUsageExtended
WHERE (((dbo.DetailedUsageExtended.InstanceType)='CloudOp'))
GROUP BY dbo.DetailedUsageExtended.FullMonth
GO

-- TenantsPerMonth
IF OBJECT_ID('TenantsPerMonth', 'V') IS NOT NULL
	DROP VIEW TenantsPerMonth
GO	

CREATE VIEW TenantsPerMonth
	AS
SELECT dbo.TenantsPMonth.[Full Month], 
Count(dbo.TenantsPMonth.Tenant) AS CountOfTenant
FROM dbo.TenantsPMonth INNER JOIN dbo.Deployments ON dbo.TenantsPMonth.Deployment = dbo.Deployments.Deployment
WHERE (((dbo.Deployments.DeploymentType)='Public' Or (dbo.Deployments.DeploymentType)='Private'))
GROUP BY dbo.TenantsPMonth.[Full Month]
GO

-- CloudOpCostPerTenant
IF OBJECT_ID('CloudOpCostPerTenant', 'V') IS NOT NULL
	DROP VIEW CloudOpCostPerTenant
GO	

CREATE VIEW CloudOpCostPerTenant
	AS
SELECT FullMonth, 
CloudOpCost, 
CountOfTenant,
[CloudOpCost]/[CountOftenant] AS CloudOpCostPerTenant
FROM dbo.CloudOpCost INNER JOIN dbo.TenantsPerMonth ON CloudOpCost.FullMonth = TenantsPerMonth.[Full Month]
GO

-- CloudOpCostPerCustomer
IF OBJECT_ID('CloudOpCostPerCustomer', 'V') IS NOT NULL
	DROP VIEW CloudOpCostPerCustomer
GO	

CREATE VIEW CloudOpCostPerCustomer
	AS
SELECT FullMonth, 
TenantsPMonth.Deployment, 
TenantsPMonth.tenant, 
Tenants.Customer, 
Sum(CloudOpCostPerTenant) AS CloudOpCostPerTenant, 
Deployments.DeploymentType, 
Deployments.DeploymentStatus, 
Deployments.DeploymentRegion
FROM (dbo.CloudOpCostPerTenant INNER JOIN (dbo.TenantsPMonth INNER JOIN Tenants ON TenantsPMonth.Tenant = Tenants.Tenant) 
ON dbo.CloudOpCostPerTenant.FullMonth = dbo.TenantsPMonth.[Full Month]) INNER JOIN dbo.Deployments ON dbo.TenantsPMonth.Deployment = dbo.Deployments.Deployment
GROUP BY CloudOpCostPerTenant.FullMonth, 
TenantsPMonth.Deployment, 
TenantsPMonth.tenant, 
Tenants.Customer, 
Deployments.DeploymentType, 
Deployments.DeploymentStatus, 
Deployments.DeploymentRegion
GO

-- DeploymentCost
IF OBJECT_ID('DeploymentCost', 'V') IS NOT NULL
	DROP VIEW DeploymentCost
GO	

CREATE VIEW DeploymentCost
	AS
SELECT FullMonth, Deployment, Sum(ExtendedCost) AS DeploymentCost
FROM dbo.DetailedUsageExtended
WHERE (((Tenant) Is Null) AND ((InstanceType)='CloudProd'))
GROUP BY FullMonth, Deployment
HAVING ((Not (Deployment) Is Null))
GO

-- DeploymentTenantsPerMonth
IF OBJECT_ID('DeploymentTenantsPerMonth', 'V') IS NOT NULL
	DROP VIEW DeploymentTenantsPerMonth
GO	

CREATE VIEW DeploymentTenantsPerMonth
	AS
SELECT Deployment, [Full Month] AS FullMonth, Count(*) AS NoOfTenants
FROM dbo.TenantsPMonth
GROUP BY Deployment, [Full Month]
GO

-- DeploymentCostPerTenant
IF OBJECT_ID('DeploymentCostPerTenant', 'V') IS NOT NULL
	DROP VIEW DeploymentCostPerTenant
GO	

CREATE VIEW DeploymentCostPerTenant
	AS
SELECT DeploymentCost.FullMonth, 
DeploymentCost.Deployment, 
DeploymentCost.DeploymentCost, 
DeploymentTenantsPerMonth.NoOfTenants, 
[DeploymentCost]/[NoOfTenants] AS DeploymentCostPerTenant
FROM dbo.DeploymentCost INNER JOIN dbo.DeploymentTenantsPerMonth ON 
(dbo.DeploymentCost.Deployment = dbo.DeploymentTenantsPerMonth.Deployment) AND (dbo.DeploymentCost.FullMonth = dbo.deploymentTenantsPerMonth.FullMonth)
GO

-- DeploymentCostPerCustomer
IF OBJECT_ID('DeploymentCostPerCustomer', 'V') IS NOT NULL
	DROP VIEW DeploymentCostPerCustomer
GO	

CREATE VIEW DeploymentCostPerCustomer
	AS
SELECT dbo.DeploymentCostPerTenant.FullMonth, 
dbo.DeploymentCostPerTenant.Deployment, 
TenantsPMonth.tenant, 
Tenants.Customer, 
Sum(dbo.DeploymentCostPerTenant.DeploymentCostPerTenant) AS SumOfDeploymentCostPerTenant, 
Deployments.DeploymentType, 
Deployments.DeploymentStatus, 
Deployments.DeploymentRegion
FROM ((dbo.DeploymentCostPerTenant INNER JOIN dbo.Deployments ON dbo.DeploymentCostPerTenant.Deployment = Deployments.Deployment) 
INNER JOIN dbo.TenantsPMonth ON (dbo.DeploymentCostPerTenant.Deployment = TenantsPMonth.Deployment) AND (dbo.DeploymentCostPerTenant.FullMonth = TenantsPMonth.[Full Month])) 
INNER JOIN dbo.Tenants ON TenantsPMonth.Tenant = Tenants.Tenant
GROUP BY dbo.DeploymentCostPerTenant.FullMonth, 
dbo.DeploymentCostPerTenant.Deployment, 
TenantsPMonth.tenant, 
Tenants.Customer, 
Deployments.DeploymentType, 
Deployments.DeploymentStatus, 
Deployments.DeploymentRegion
GO

-- TenantCostPerCustomer
IF OBJECT_ID('TenantCostPerCustomer', 'V') IS NOT NULL
	DROP VIEW TenantCostPerCustomer
GO	

CREATE VIEW TenantCostPerCustomer
	AS
SELECT DetailedUsageExtended.FullMonth, DetailedUsageExtended.Deployment, DetailedUsageExtended.Tenant, Tenants.Customer, Sum(DetailedUsageExtended.ExtendedCost) AS TenantCost, Deployments.DeploymentType, Deployments.DeploymentStatus, Deployments.DeploymentRegion
FROM (dbo.DetailedUsageExtended INNER JOIN dbo.Tenants ON DetailedUsageExtended.Tenant = Tenants.Tenant) 
	INNER JOIN dbo.Deployments ON DetailedUsageExtended.Deployment = Deployments.Deployment
WHERE (((DetailedUsageExtended.InstanceType)='CloudProd'))
GROUP BY DetailedUsageExtended.FullMonth, 
DetailedUsageExtended.Deployment, 
DetailedUsageExtended.Tenant, 
Tenants.Customer, 
Deployments.DeploymentType, 
Deployments.DeploymentStatus, 
Deployments.DeploymentRegion
HAVING ((Not (DetailedUsageExtended.Deployment) Is Null) AND (Not (DetailedUsageExtended.Tenant) Is Null))
GO

-- TotalCostPerCustomer
IF OBJECT_ID('TotalCostPerCustomer', 'V') IS NOT NULL
	DROP VIEW TotalCostPerCustomer
GO	

CREATE VIEW TotalCostPerCustomer
	AS
SELECT 
	CloudOpCostPerCustomer.FullMonth, 
	CloudOpCostPerCustomer.Deployment, 
	CloudOpCostPerCustomer.tenant, 
	CloudOpCostPerCustomer.Customer, 
	0 AS TenantCost, 
	0 AS DeploymentCost, 
	CloudOpCostPerCustomer.CloudOpCostPerTenant AS CloudOpCost, 
	CloudOpCostPerCustomer.CloudOpCostPerTenant AS TotalCost, 
	'CloudOpCost' AS CostType, 
	CloudOpCostPerCustomer.DeploymentType, 
	CloudOpCostPerCustomer.DeploymentStatus, 
	CloudOpCostPerCustomer.DeploymentRegion
FROM dbo.CloudOpCostPerCustomer
UNION
SELECT 
	DeploymentCostPerCustomer.FullMonth, 
	DeploymentCostPerCustomer.Deployment, 
	DeploymentCostPerCustomer.tenant, 
	DeploymentCostPerCustomer.Customer, 
	0 AS TenantCost, 
	DeploymentCostPerCustomer.SumOfDeploymentCostPerTenant AS DeploymentCost, 
	0 AS CloudOpCost, 
	DeploymentCostPerCustomer.SumOfDeploymentCostPerTenant AS TotalCost, 
	'DeploymentCost' AS CostType, 
	DeploymentCostPerCustomer.DeploymentType, 
	DeploymentCostPerCustomer.DeploymentStatus, 
	DeploymentCostPerCustomer.DeploymentRegion
FROM dbo.DeploymentCostPerCustomer
UNION
SELECT 
	TenantCostPerCustomer.FullMonth, 
	TenantCostPerCustomer.Deployment, 
	TenantCostPerCustomer.Tenant, 
	TenantCostPerCustomer.Customer, 
	TenantCostPerCustomer.TenantCost, 
	0 AS DeploymentCost, 
	0 AS CloudOpCost, 
	TenantCostPerCustomer.TenantCost AS TotalCost, 
	'TenantCost' AS CostType, 
	TenantCostPerCustomer.DeploymentType, 
	TenantCostPerCustomer.DeploymentStatus, 
	TenantCostPerCustomer.DeploymentRegion
FROM dbo.TenantCostPerCustomer
GO

-- InvoicesPerMonth
IF OBJECT_ID('InvoicesPerMonth', 'V') IS NOT NULL
	DROP VIEW InvoicesPerMonth
GO	

CREATE VIEW InvoicesPerMonth
	AS
SELECT 
	Deployments.Deployment, 
	InvoicesPMonth.tenant, 
	Tenants.Customer, 
	DateFromParts([InvoicesPMonth].[Year],[InvoicesPMonth].[MonthNo],1) AS FullMonth, 
	InvoicesPMonth.Count, 
	Deployments.DeploymentType, 
	Deployments.DeploymentStatus, 
	Deployments.DeploymentRegion
FROM (dbo.InvoicesPMonth INNER JOIN dbo.Deployments ON InvoicesPMonth.Deployment = Deployments.Deployment) 
	INNER JOIN dbo.Tenants ON InvoicesPMonth.tenant = Tenants.Tenant
GO

-- InvoicesPerMonthProd
IF OBJECT_ID('InvoicesPerMonthProd', 'V') IS NOT NULL
	DROP VIEW InvoicesPerMonthProd
GO	

CREATE VIEW InvoicesPerMonthProd
	AS
SELECT InvoicesPerMonth.*
FROM dbo.InvoicesPerMonth
WHERE (((InvoicesPerMonth.DeploymentStatus)='Prod'))
GO

-- CustomersPerMonth
IF OBJECT_ID('CustomersPerMonth', 'V') IS NOT NULL
	DROP VIEW CustomersPerMonth
GO	

CREATE VIEW CustomersPerMonth
	AS
SELECT DISTINCT 
	TenantsPMonth.[Full Month], 
	Tenants.Customer, 
	Deployments.DeploymentType, 
	Sum(InvoicesPerMonthProd.Count) AS SumOfCount
FROM ((dbo.TenantsPMonth INNER JOIN dbo.Tenants ON TenantsPMonth.Tenant = Tenants.Tenant) 
INNER JOIN dbo.Deployments ON TenantsPMonth.Deployment = Deployments.Deployment) 
LEFT JOIN dbo.InvoicesPerMonthProd ON (TenantsPMonth.Tenant = InvoicesPerMonthProd.tenant) AND 
	(TenantsPMonth.Deployment = InvoicesPerMonthProd.Deployment) AND 
	(TenantsPMonth.[Full Month] = InvoicesPerMonthProd.FullMonth)
GROUP BY TenantsPMonth.[Full Month], Tenants.Customer, Deployments.DeploymentType
GO
