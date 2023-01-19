# AKSJavaSpringAppInsights

This is a simple Spring Boot CRUD app that is deployed to AKS. 

The core code for the sample scenario was taken and modified from https://github.com/RameshMF/springboot-postgresql-hibernate-crud-example 

* It uses Postgre as the database backend
* A simple JMS integration with Azure Service Bus
* App Insights integration via the codeless attach

Everything you need is in the deployscript.ps1 powershell file.

You can more details on app insights codeless attach at  https://learn.microsoft.com/en-us/azure/azure-monitor/app/java-in-process-agent
