#!/bin/bash
#
# Script de gestion du démarrage et de l'arrêt des VMs d'un Pod
#
# 2026-02-03 - Mitard V. : Création
#
scriptName=`basename $0`
playbooks=/home/ansible/playbooks
ansibleHosts=/home/ansible/.ansible/hosts

while getopts "dDe:hHs:" opt; do
  case $opt in
    d|D) set -x
	 ansibleDebug=-vv
	 ;;
    e) authenticationFile=$OPTARG
       ;;
    h|H) echo -e "\n-I- $scriptName permet de supprimer l'ensemble des routeurs d'un Pod (Les routeurs doivent au préalable être arrêtés)."
	 echo -e "-I- $scriptName [-d|-D] [-h|-H] [-e <Fichier d'authentification>] [<No de Pod>]"
	 echo -e "\t-d|-D : Activativation des traces de débogage."
	 echo -e "\t-h|-H : Affichage de cette aide en ligne."
	 echo -e "\t-e : Nom du fichier contenant les informations d'authentification pour l'accès au noeud Proxmox."
	 exit 0
	 ;;
    *) echo -e "\n-E- Option $opt invalide !\n"
       exit 1
       ;;
  esac
done

shift $((OPTIND-1))

case $# in
  1) Pod=Pod$1
     ;;
  0) Pod=Pod$PodID
     ;;
  *) echo -e "\n-E- Nombre de paramètres incorrects !"
     echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"
     exit 1
     ;;
esac

ansible-playbook -i $ansibleHosts $ansibleDebug -e @$authenticationFile -e "pattern='^$Pod-' status=absent" $playbooks/pve/runVMs.yml
