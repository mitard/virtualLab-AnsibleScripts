#!/bin/bash
#
# Script de création d'un environnement virtuel de TP réseau
#
# 2026-02-02 - V. Mitard : Création à partir du script podCreation.sh créé pour le TP MPLS
# 2026-02-11 - V. Mitard : Configuration multi-labs
# 2026-02-28 - V. Mitard : Utilisation d'un nom de template initialisé dans la VM Ansible
# 2026-05-10 - V. Mitard : Généralisation multi-environnement (BGP, MPLS, OSPF...)
#
scriptName=`basename $0`
scriptDir=`realpath $0`
scriptDir=`dirname $scriptDir`
playbooks=/home/ansible/playbooks
ansibleHosts=/home/ansible/.ansible/hosts
subnetGW=172.16.0.1
#routerTmplName=Deb12-FRR

if [ $# -eq 0 ]; then
  tput setaf 1; echo -e "\n-E- Paramètre obligatoire absent !"; tput sgr0
  tput setaf 3; echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"; tput sgr0
  exit 1
fi

while getopts "dDe:hHl:" opt; do
  case $opt in
    d|D) set -x
	 ansibleArgs="-vvv"
	 ;;
    e) authenticationFile=$OPTARG
       ;;
    h|H) tput setaf 3
	 echo -e "\n-I- $scriptName permet la création des zones, sous-réseaux et routeurs virtuels Proxmox d'un Pod pour l'environnement de TP réseau"
	 echo -e "-I- $scriptName [-d|-D] [-h|-H] [-e <Fichier d'authentification>] -l BGP1|BGP2|BGP3|MPLS|OSPF [<No de Pod>]"
	 echo -e "\t-d|-D: Activativation des traces de débogage."
	 echo -e "\t-h|-H: Affichage de cette aide en ligne."
	 echo -e "\t-e: Nom du fichier contenant les informations d'authentification pour l'accès au noeud Proxmox.\n"
	 tput sgr0
	 exit 0
	 ;;
    l) lab=$OPTARG
       ;;
    *) tput setaf 1; echo -e "\n-E- Option $opt invalide !\n"; tput sgr0
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
  *) tput setaf 1; echo -e "\n-E- Nombre de paramètres incorrects !"; tput sgr0
     tput setaf 3; echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"; tput sgr0
     exit 1
     ;;
esac

case ${lab^^} in
  BGP1) Routers="BGP1_Pod"$PodNo"RTR"
        routersCfg="cfgFiles/BGP-TP1.cfg"
        vnetList="cfgFiles/BGP-TP1_VNets.cfg"
        ;;
  BGP2) Routers="BGP2_Pod"$PodNo"RTR"
        routersCfg="cfgFiles/BGP-TP2.cfg"
        vnetList="cfgFiles/BGP-TP2_VNets.cfg"
        ;;
  BGP3) Routers="BGP3_Pod"$PodNo"RTR"
        routersCfg="cfgFiles/BGP-TP3.cfg"
        vnetList="cfgFiles/BGP-TP3_VNets.cfg"
        ;;
  MPLS) Routers="MPLS_Pod"$PodNo"RTR"
	routersCfg="cfgFiles/MPLS.cfg"
	vnetList="cfgFiles/MPLS_VNets.cfg"
	;;
  OSPF) Routers="OSPF_Pod"$PodNo"RTR"
	routersCfg="cfgFiles/OSPF.cfg"
	vnetList="cfgFiles/OSPF_VNets.cfg"
	;;
  *) tput setaf 1; echo -e "-E- Option $lab invalide !\n"; tput sgr0
     exit 1
     ;;
esac

tag=${lab,,}

# Création de la zone réseau et des sous-réseaux logiques associées pour le Pod
ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "PodID=$PodNo" $playbooks/pve/createSDNzone.yml
ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "PodID=$PodNo vnets=$scriptDir/$vnetList" $playbooks/pve/createSDNvnets.yml

# Lecture du fichier de configuration ligne à ligne
while IFS= read -r inputLine;
do
  # Pour chaque ligne, lecture des informations de configuration du routeur
  while IFS= read lineItem;
  do
    routerData+=($lineItem)
  done <<< "$inputLine"
  hostname="Pod"$PodNo"-RTR"${routerData[0]}
  ipAddress="172.16."$PodNo"."${routerData[0]}"/16"
  case ${#routerData[@]} in
    2) # Création d'un routeur à une seule interface
       ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "template_name=$routerTmplName VM_name=$hostname poolRessource=Pod$PodNo VM_ipAddress=$ipAddress VM_ipGateway=$subnetGW VMnet1=P$PodNo${routerData[1]} etiquettes=$tag" $playbooks/pve/singleItfRouterVMcreation.yml
       ;;
    3) # Création d'un routeur à deux interfaces
       ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "template_name=$routerTmplName VM_name=$hostname poolRessource=Pod$PodNo VM_ipAddress=$ipAddress VM_ipGateway=$subnetGW VMnet1=P$PodNo${routerData[1]} VMnet2=P$PodNo${routerData[2]} etiquettes=$tag" $playbooks/pve/2ItfRouterVMcreation.yml
       ;;
    4) # Création d'un routeur à trois interfaces
       ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "template_name=$routerTmplName VM_name=$hostname poolRessource=Pod$PodNo VM_ipAddress=$ipAddress VM_ipGateway=$subnetGW VMnet1=P$PodNo${routerData[1]} VMnet2=P$PodNo${routerData[2]} VMnet3=P$PodNo${routerData[3]} etiquettes=$tag" $playbooks/pve/3ItfRouterVMcreation.yml
       ;;
    5) # Création d'un routeur à quatre interfaces
       ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "template_name=$routerTmplName VM_name=$hostname poolRessource=Pod$PodNo VM_ipAddress=$ipAddress VM_ipGateway=$subnetGW VMnet1=P$PodNo${routerData[1]} VMnet2=P$PodNo${routerData[2]} VMnet3=P$PodNo${routerData[3]} VMnet4=P$PodNo${routerData[4]} etiquettes=$tag" $playbooks/pve/4ItfRouterVMcreation.yml
  esac
  unset routerData
  hosts+=("$hostname")
  routerList+=("$ipAddress")
done < $routersCfg

tput bold; read -p "Appuyer sur une touche une fois les VMs démarrées..." -n 1; tput sgr0

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
# Personnalisation des bannières de post-connexion
ansible-playbook $ansibleArgs -i $ansibleHosts -e "target=$Routers bannerTxt=$lab" $playbooks/linux-routers/setFRRbanner.yml
ansible-playbook $ansibleArgs -i $ansibleHosts -e "target=$Routers" $playbooks/linux-routers/setSSHbanner.yml

# Suppression des configurations de démarrage Cloud-Init
extraVarArg="{\"VM_list\":\""${hosts[@]}"\"}"
ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "$extraVarArg" $playbooks/pve/removeCloudInitConf.yml
