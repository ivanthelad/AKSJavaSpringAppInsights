$PREFIX='ahms'
$SUFFIX='010'
$RGNAME='aksappinsightdemo' + $SUFFIX + '-rg'
$LOCATION='westeurope'
$AKSCLUSTERNAME= $PREFIX+ 'testaks' + $SUFFIX
$ACRNAME=$PREFIX+ 'testacr' + $SUFFIX
$LAWORKSPACENAME=$PREFIX+ 'testlogws' + $SUFFIX
$APPNAME='aksAI'
$PGSERVER=$PREFIX+ 'pgserver' + $SUFFIX
$PGADMIN='azureuser'
$PGPASSWORD='Pa$$w0rD'
$PGSKU='GP_Gen5_2'
$STARTIP='0.0.0.0'
$ENDIP='0.0.0.0'
$DBNAME='employees'
$SBNAMESPACE=$PREFIX+ 'sbns' + $SUFFIX
$SBQUEUENAME='aksspringqueue'
$IMAGENAME='javaaksdemo:v1'

# create the resource group
az group create --name $RGNAME --location $LOCATION

# create log analytics workspace
az monitor log-analytics workspace create --resource-group $RGNAME   --workspace-name $LAWORKSPACENAME

# extract the log workspace id
$LAWORKSPACEID= az monitor log-analytics workspace show --resource-group $RGNAME --workspace-name $LAWORKSPACENAME --query id -o tsv
echo $LAWORKSPACEID

# create app insights inside the log workspace
az monitor app-insights component create --app $APPNAME --location $LOCATION --kind web -g $RGNAME --workspace $LAWORKSPACEID

# extract the app insights connections string
$AICONNSTRING=az monitor app-insights component show --app $APPNAME -g $RGNAME --query connectionString -o tsv
echo $AICONNSTRING

# create azure container registry
az acr create -n $ACRNAME -g $RGNAME --sku basic

# create aks cluster, connect to it log analytics workspace and acr resources created previously
az aks create -g $RGNAME -n $AKSCLUSTERNAME --attach-acr $ACRNAME --enable-managed-identity --node-count 1 --enable-addons monitoring  --workspace-resource-id $LAWORKSPACEID   --generate-ssh-keys

# create postgres server
az postgres server create --name $PGSERVER --resource-group $RGNAME --location $LOCATION --admin-user $PGADMIN --admin-password $PGPASSWORD --sku-name $PGSKU

# Configure a firewall rule for the server. This is very open. Not a good idea... 
echo "Configuring a firewall rule for $server for the IP address range of $startIp to $endIp"
az postgres server firewall-rule create --resource-group $RGNAME --server $PGSERVER --name AllowIps --start-ip-address $STARTIP --end-ip-address $ENDIP


# create the database in the postgre server
az postgres db create -g $RGNAME -s $PGSERVER -n $DBNAME

# extract connection string.. needed for setting up kubernetes deployment
$PGCONNECTIONSTRING= az postgres show-connection-string --admin-password $PGPASSWORD --admin-user $PGADMIN --database-name $DBNAME --server-name $PGSERVER --query connectionStrings.jdbc -o tsv
echo $PGCONNECTIONSTRING

# create service bus - Basic should be fine for demo
az servicebus namespace create --resource-group $RGNAME --name $SBNAMESPACE --location $LOCATION --sku Basic
# create service bus queue
az servicebus queue create --resource-group $RGNAME --namespace-name $SBNAMESPACE --name $SBQUEUENAME

# extra service bus connection string.. needed for kubernetes deployment
$SBCONNECTIONSTRING=az servicebus namespace authorization-rule keys list --resource-group $RGNAME --namespace-name $SBNAMESPACE --name RootManageSharedAccessKey --query primaryConnectionString --output tsv
echo $SBCONNECTIONSTRING

# build the java code. assumes you have all relevant java dependencies on local machine
cd javacode
mvn clean
mvn package

# create the docker container.. Let azure container registry do all the work.
az acr build --registry $ACRNAME -g $RGNAME --image $IMAGENAME .

# install kubectl - might not be needed
az aks install-cli

# connect to the AKS cluster. call get nodes just to verify
az aks get-credentials --resource-group $RGNAME --name $AKSCLUSTERNAME
kubectl get nodes

# create the secrets needed for deployment. Probably better to put in keyvault

echo $PGPASSWORD  
echo $PGCONNECTIONSTRING 
echo $PGADMIN 
echo $SBCONNECTIONSTRING 
echo $AICONNSTRING 
echo $SBQUEUENAME 

kubectl delete secret javasecrets
kubectl create secret generic javasecrets  --from-literal=SPRING_DATASOURCE_PASSWORD=$PGPASSWORD  --from-literal=SPRING_DATASOURCE_URL=$PGCONNECTIONSTRING `
--from-literal=SPRING_DATASOURCE_USERNAME=$PGADMIN --from-literal=SPRING_JMS_SERVICEBUS_CONNECTION-STRING=$SBCONNECTIONSTRING `
--from-literal=APPLICATIONINSIGHTS_CONNECTION_STRING=$AICONNSTRING --from-literal=QUEUENAME=$SBQUEUENAME 

# do the kubernetes deployment
cd ..
cd .\manifests

# put in the correct name of the docker container in the yml file but using ps replace
$FULLIMAGENAME=$ACRNAME + '.azurecr.io/' + $IMAGENAME
echo $FULLIMAGENAME
((Get-Content -path deploymentTemplate.yml -Raw) -replace 'REPLACEIMAGE',$FULLIMAGENAME) | Set-Content -Path deployment.yml

# create the k8s deployment
kubectl apply -f deployment.yml

# create the k8s service 
kubectl apply -f service.yml

# wait 30 seconds and hopefully the external ip is created
Start-Sleep -Seconds 30
$EXTERNAL_IP= kubectl get service  springaks -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo $EXTERNAL_IP

# swagger endpoint. Can put this in browser
$SWAGGERENDPOINT= 'http://' + $EXTERNAL_IP + '/swagger-ui/index.html'
echo $SWAGGERENDPOINT

# build out the rest endpoint
$RESTENDPOINT = 'http://' + $EXTERNAL_IP + '/api/v1/employees'
echo $RESTENDPOINT

# make a warmup call to this
$response =Invoke-RestMethod -Uri $RESTENDPOINT -Method GET

# goto the app insights live metrics before you run this.. and should see the traffic
# check out the the other app insights views. eg the map

# create 10 random records
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("conte", "application/json")
$headers.Add("Content-Type", "application/json")

for (($i = 0), ($j = 0); $i -lt 10; $i++)
{
$body = @{
    "firstName" = "firstname" + $i
    "lastName" = "lastname" +$i
    "emailId" = "f" + $i + "@demo.com"
} | ConvertTo-Json

$body


# create a record
$response = Invoke-RestMethod $RESTENDPOINT -Method 'POST' -Headers $headers -Body $body
$response | ConvertTo-Json
}

# end create


# show all records.. There is a simulated random failure in code - so this might give an error
for (($i = 0), ($j = 0); $i -lt 10; $i++)
{
$response =Invoke-RestMethod -Uri $RESTENDPOINT -Method GET
$response | ConvertTo-Json
}

# get employee 2000 that likely does not exist so should give exception
$response =Invoke-RestMethod -Uri $RESTENDPOINT/2000 -Method GET



# just a different way of setting up body. Should not be needed
#$body = "{
#`n    `"firstName`" : `"Lional`",
#`n    `"lastName`" : `"Messi`",
#`n    `"emailId`": `"Lional@messi.com`"
#`n}"