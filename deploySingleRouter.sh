#!/bin/bash
#
# Script de création d'un environnement virtuel de TP réseau
#
# 2026-03-14 - V. Mitard : Création à partir du script de création d'un Pod
#
scriptName=`basename $0`
scriptDir=`realpath $0`
scriptDir=`dirname $scriptDir`
playbooks=/home/ansible/playbooks
ansibleHosts=/home/ansible/.ansible/hosts
subnetGW=172.16.0.1
template=Deb12-FRR10

while getopts "a:dDe:g:hHt:n:" opt; do
  case $opt in
    a)   ipAddress=$OPTARG
	 ;;
    d|D) set -x
	 ansibleArgs="-vvvvv"
	 ;;
    e)   authenticationFile=$OPTARG
         ;;
    g)   subnetGW=$OPTARG
	 ;;
    h|H) tput setaf 6
	 echo -e "\n-I- $scriptName permet le déploiement d'un routeur virtuel à partir d'un modèle de machine virtuelle."
	 echo -e "-I- $scriptName [-d|-D] [-h|-H] -a <Adr. IP de management> [-e <Fichier d'authentification>] [-g <Adr. IP de la passerelle par défaut] -n <Nom du routeur>"
	 echo -e "\t-d|-D: Activativation des traces de débogage."
	 echo -e "\t-h|-H: Affichage de cette aide en ligne."
	 echo -e "\t-e: Nom du fichier contenant les informations d'authentification pour l'accès au noeud Proxmox.\n"
	 tput sgr0
	 exit 0
	 ;;
    n)   hostname=$OPTARG
	 ;;
    *)   echo -e "\n-E- Option $opt invalide !\n"
         exit 1
         ;;
  esac
done

if [ -z $ipAddress ]; then
  tput setaf 1; echo -e "\n-E- Paramètre adresse de management du routeur absent !"; tput sgr0
  tput setaf 3; echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"; tput sgr0
  exit 1
fi

if [ -z $hostname ]; then
  tput setaf 1; echo -e "\n-E- Paramètre nom du routeur absent !"; tput sgr0
  tput setaf 3; echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"; tput sgr0
  exit 1
fi

ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "template_name=$template VM_name=$hostname VM_ipAddress=$ipAddress VM_ipGateway=$subnetGW" $playbooks/pve/noItfRouterVMcreation.yml

read -p "Appuyer sur une touche une fois la VM démarrée..." -n 1

host=`echo $ipAddress | cut -d'/' -f1`
# Suppression de l'empreinte éventuelle d'une ancienne machine avec la même adresse
if ssh-keygen -F $host > /dev/null; then
  ssh-keygen -R $host > /dev/null
fi

# Enregistrement de l'empreinte de la VM
ssh-keyscan -H $host >> /home/ansible/.ssh/known_hosts

target=`echo $hostname | tr -d '-'`
# Ajout des utilisateurs 'linux' (SSH) et 'cli' (VTYSH)
ansible-playbook $ansibleArgs -i $ansibleHosts -e "target=$target" $playbooks/linux-routers/linuxUserCreation.yml
ansible-playbook $ansibleArgs -i $ansibleHosts -e "target=$target" $playbooks/linux-routers/cliUserCreation.yml
# Configuration de la VRF de Management
ansible-playbook $ansibleArgs -i $ansibleHosts -e "target=$target" $playbooks/linux-routers/setMgmtVRF.yml
# Personnalisation de la bannière de post-connexion
ansible-playbook $ansibleArgs -i $ansibleHosts -e "target=$target" $playbooks/linux-routers/setFRRbanner.yml

# Suppression des configurations de démarrage Cloud-Init
ansible-playbook $ansibleArgs -i $ansibleHosts -e @$authenticationFile -e "VM_list=$hostname" $playbooks/pve/removeCloudInitConf.yml
