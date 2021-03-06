﻿#region Prep

Login-AzureRmAccount -ServicePrincipal -Tenant  "72f988bf-86f1-41af-91ab-2d7cd011db47"  -Credential (Get-Credential -Message "Password" -UserName "ce72d709-728d-45f7-ab6e-cd8e1c432b4d" )
Select-AzureRmSubscription  -SubscriptionName "Demos"

#Start-AzureRMVM -Name VSTSBuildLinux -ResourceGroupName "DevEnvironment-VSTSBuildLinux-788587"  
Start-AzureRMVM -Name containerhost  -ResourceGroupName "DevOpsDemo-ContainerHost"  
# DevOpsDemo-ContainerHost-
# start ACS
Get-AzureRmVM  -ResourceGroupName DevOpsDemo-ACSSwarm | Start-AzureRMVM 


foreach ($vmss in Get-AzureRmVmss  -ResourceGroupName DevOpsDemo-ACSSwarm )
{
    Start-AzureRmVmss  -ResourceGroupName DevOpsDemo-ACSSwarm -VMScaleSetName $vmss.Name
}
 

$SessionDir = "C:\Repos\Microsoft-and-Containers"
cd $SessionDir 
$ServerCoreIP =  (Get-AzureRmPublicIpAddress -Name ContainerHost-IP -ResourceGroupName DevOpsDemo-ContainerHost).IpAddress

#cleanup previous demo

 $env:DOCKER_HOST = "tcp://$($ServerCoreIP):2375"
Get-Container  | Remove-Container -Force
Get-ContainerImage | Where-Object { $_.RepoTags -notlike '*microsoft/windowsservercore*' -notlike '*servercoreiis*'}  | Remove-ContainerImage

#set-item WSMan:\localhost\Client\TrustedHosts  $ServerCoreIP -Force


$env:DOCKER_HOST = "tcp://127.0.0.1:2375"
Get-Container  | Remove-Container -Force
Get-ContainerImage | Where-Object { $_.RepoTags -like '*linuxwebsite*'}  | Remove-ContainerImage  -Force

# clean up ACS
#$env:DOCKER_HOST = "tcp://marcusacsswarmmgmt.westeurope.cloudapp.azure.com:2375"
#Get-Container  | Remove-Container -Force

# check ACS
$env:DOCKER_HOST = "tcp://marcusacsswarmmgmt.westeurope.cloudapp.azure.com:2375"
docker info

#endregion 

#region Windows Containers

# Connect Docker client to server core VM on Azure 
$env:DOCKER_HOST = "tcp://$($ServerCoreIP):2375"

# Show details of Docker engine connected to
docker info

# Show images, should just be core base image and servercoreiis
docker images


# Show Docker Hub
Start-Process 'https://hub.docker.com/search/?isAutomated=0&isOfficial=0&page=1&pullCount=0&q=iis&starCount=0'

# How built
cd "ServerCoreIIS"
& "C:\Program Files (x86)\Microsoft VS Code\Code.exe" .
# Already built this using: docker build --tag 'servercoreiis' .

#Nothing running on port 80...
Start-Process "http://$($ServerCoreIP):80"

# run container based on that image
docker run --name 'servercoreiis1' -d -p 80:80 'servercoreiis'

# view web output
Start-Process "http://$($ServerCoreIP):80"

# change to website demo
cd "..\CoreWindowsWebsite"
& "C:\Program Files (x86)\Microsoft VS Code\Code.exe" .

#build the windows website
docker build --tag 'windowswebsite' .

# view nothign on port 81
Start-Process "http://$($ServerCoreIP):81"

#start container based on new image on port 81
docker run  -d -p 81:80 'windowswebsite'

# view output
Start-Process "http://$($ServerCoreIP):81"

# view all containers
docker ps -a

# powershell
Get-Container 
Get-Container | Remove-Container -Force

Get-Container

# Proof gone!
Start-Process "http://$($ServerCoreIP):81"

#endregion

#region Linux App Service
# Run in BASH for Windows!!

# change to website demo
cd "..\LinuxWebsite"
& "C:\Program Files (x86)\Microsoft VS Code\Code.exe" "Linux WebApps DemoSteps.sh"


# change to Windows file system source lcoation
cd /mnt/c/Repos/Microsoft-and-Containers/LinuxWebsite


#Connect to docker for windows
export DOCKER_HOST=tcp://0.0.0.0:2375


# build continer
docker build --tag 'linuxwebsite' . 

# run container

docker run -d -p 80:80 linuxwebsite
# check all works
Start-Process "http://localhost"

# login to Azure Container Registry
docker login -u 'ce72d709-728d-45f7-ab6e-cd8e1c432b4d' containerregistry-microsoft.azurecr.io

# Tag image with registry
docker tag  'linuxwebsite' 'containerregistry-microsoft.azurecr.io/linuxwebsite:latest'

# Push image
docker push 'containerregistry-microsoft.azurecr.io/linuxwebsite:latest'

# create webapp

# image: containerregistry-microsoft.azurecr.io/linuxwebsite:latest
# regsitry url:  https://containerregistry-microsoft.azurecr.io
# username: "ce72d709-728d-45f7-ab6e-cd8e1c432b4d"


#endregion

#region Azure Container Service

az login
az account set --subscription "Demos"

az group create -n "tmpACSCluster" -l "westeurope"

az acs create -n "acs-cluster" -g "tmpACSCluster" -d "tmpmarcusacs" --orchestrator-type "Kubernetes"  --master-count 1 --agent-count 3 --generate-ssh-keys

#endregion

#region VSTS
# View Azure Container solutions

# View App
start-process "http://marcusacsswarmagents.westeurope.cloudapp.azure.com:5000/"
start-process "http://marcusacsswarmagents.westeurope.cloudapp.azure.com:5001/"

#Edit, commit and push changes
& "C:\Program Files (x86)\Microsoft VS Code\Code.exe" "C:\Repos\example-voting-app\"

# View changes on GitHub and view service arch.
Start-Process 'https://github.com/marrobi/example-voting-app/'

#View build and release on VSTS
Start-Process 'https://marrobi.visualstudio.com/Docker%20Example%20Voting%20App/'

# View App
start-process "http://marcusacsswarmagents.westeurope.cloudapp.azure.com:5000/"
start-process "http://marcusacsswarmagents.westeurope.cloudapp.azure.com:5001/"

#endregion