#!/bin/bash
#
# Script de création d'un environnement virtuel de TP réseau
#
# 2025-11-23 - V. Mitard : Création
# 2026-01-19 - V. Mitard : Généralisation de la création suivant le No de Pod
# 2026-01-31 - V. Mitard : Utilisation de la variable d'environnement $PodID comme numéro de Pod par défaut
#
#
scriptName=`basename $0`
scriptDir=`realpath $0`
scriptDir=`dirname $scriptDir`
playbooks=/home/ansible/playbooks
ansibleHosts=/home/ansible/.ansible/hosts
subnetGW=172.16.0.1
template=Deb12-FRR8.4

routersType=All
core=false
client=false
edge=false
nbParam=0

if [ $# -eq 0 ]; then
  echo -e "\n-E- Paramètre obligatoire absent !"
  echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"
  exit 1
fi

while getopts "dDe:hHt:" opt; do
  case $opt in
    d|D) set -x
	 ansibleArgs="-vvvvv"
	 ;;
    e) authenticationFile=$OPTARG
       nbParam+=1
       ;;
    h|H) echo -e "\n-I- $scriptName permet la création des zones, sous-réseaux et routeurs virtuels Proxmox d'un Pod pour l'environnement de TP réseau"
	 echo -e "-I- $scriptName [-d|-D] [-h|-H] [-t all|Core|Edge|Client] -e <Fichier d'authentification> <No de Pod>"
	 echo -e "\t-d|-D: Activativation des traces de débogage."
	 echo -e "\t-h|-H: Affichage de cette aide en ligne."
	 echo -e "\t-e: Nom du fichier contenant les informations d'authentification pour l'accès au noeud Proxmox."
	 echo -e "\t-t: Type de routeurs à configurer : All, Core, Edge ou Client"
	 echo -e "\tLes fichiers de configurations sont déduits du No de Pod : Podn-Core.cfg, Podn-Edge.cfg & Podn-Client.cfg\n"
	 exit 0
	 ;;
    t) routersType=$OPTARG
       nbParam+=1
       ;;
    *) echo -e "\n-E- Option $opt invalide !\n"
       exit 1
       ;;
  esac
done

shift $((OPTIND-1))

case $# in
  0) PodNo=$PodID
     ;;
  1) PodNo=$1
     ;;
  *) echo -e "\n-E- Nombre de paramètres incorrects !"
     echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"
     exit 1
     ;;
esac

Routers="Pod"$PodNo"RTR"

case ${routersType,,} in
  all)    core=true
          edge=true
          client=true
          ;;
  core)   core=true
          Routers="Pod"$PodNo"Core"
	  ;;
  client) client=true
          Routers="Pod"$PodNo"Client"
	  ;;
  edge)   edge=true
          Routers="Pod"$PodNo"Edge"
	  ;;
  *) echo -e "-E- Option $routersType invalide !\n"
     exit 1
     ;;
esac

CoreRoutersCfg="cfgFiles/Cores.cfg"
EdgeRoutersCfg="cfgFiles/Edges.cfg"
ClientRoutersCfg="cfgFiles/Clients.cfg"
vnetList="cfgFiles/VNets.cfg"

# Création de la zone réseau et des sous-réseaux logiques associées pour le Pod
ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "PodID=$PodNo" $playbooks/pve/createSDNzone.yml
ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "PodID=$PodNo vnets=$scriptDir/$vnetList" $playbooks/pve/createSDNvnets.yml

if [[ "$core" = true ]]; then
# Création des routeurs 'core'
  while IFS=" " read -r routerID net1 net2 net3
  do
    # Création du routeur virtuel
    hostname="Pod"$PodNo"-RTR"$routerID
    ipAddress="172.16."$PodNo"."$routerID"/16"
    ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "template_name=$template VM_name=$hostname VM_ipAddress=$ipAddress VM_ipGateway=$subnetGW VMnet1=P$PodNo$net1 VMnet2=P$PodNo$net2 VMnet3=P$PodNo$net3" $playbooks/pve/3ItfRouterVMcreation.yml
    hosts+=("$hostname")
    routerList+=("$ipAddress")
  done < $CoreRoutersCfg
fi

if [[ "$edge" = true ]]; then
# Création des routeurs 'edge'
  while IFS=" " read -r routerID net1 net2 net3 net4
  do
  # Création du routeur virtuel
    hostname="Pod"$PodNo"-RTR"$routerID
    ipAddress="172.16."$PodNo"."$routerID"/16"
    ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "template_name=$template VM_name=$hostname VM_ipAddress=$ipAddress VM_ipGateway=$subnetGW VMnet1=P$PodNo$net1 VMnet2=P$PodNo$net2 VMnet3=P$PodNo$net3 VMnet4=P$PodNo$net4" $playbooks/pve/4ItfRouterVMcreation.yml
    hosts+=("$hostname")
    routerList+=("$ipAddress")
  done < $EdgeRoutersCfg
fi

if [[ "$client" = true ]]; then
# Création des routeurs clients
  while IFS=" " read -r routerID net1 net2
  do
  # Création du routeur virtuel
    hostname="Pod"$PodNo"-RTR"$routerID
    ipAddress="172.16."$PodNo"."$routerID"/16"
    ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "template_name=$template VM_name=$hostname VM_ipAddress=$ipAddress VM_ipGateway=$subnetGW VMnet1=P$PodNo$net1" $playbooks/pve/singleItfRouterVMcreation.yml
    hosts+=("$hostname")
    routerList+=("$ipAddress")
  done < $ClientRoutersCfg
fi

read -p "Appuyer sur une touche une fois les VMs démarrées..." -n 1

for ipAddress in ${routerList[@]}
do
    host=`echo $ipAddress | cut -d'/' -f1`
    # Suppression de l'empreinte éventuelle d'une ancienne machine avec la même adresse
    if ssh-keygen -F $host > /dev/null; then
      ssh-keygen -R $host > /dev/null
    fi

    # Enregistrement de l'empreinte de la VM
    ssh-keyscan -H $host >> /home/ansible/.ssh/known_hosts
done

# Ajout des utilisateurs 'linux' (SSH) et 'cli' (VTYSH)
ansible-playbook $ansibleArgs -i $ansibleHosts -e "target=$Routers" $playbooks/linux-routers/linuxUserCreation.yml
ansible-playbook $ansibleArgs -i $ansibleHosts -e "target=$Routers" $playbooks/linux-routers/cliUserCreation.yml
# Configuration de la VRF de Management
ansible-playbook $ansibleArgs -i $ansibleHosts -e "target=$Routers" $playbooks/linux-routers/setMgmtVRF.yml

# Suppression des configurations de démarrage Cloud-Init
extraVarArg="{\"VM_list\":\""${hosts[@]}"\"}"
ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "$extraVarArg" $playbooks/pve/removeCloudInitConf.yml
