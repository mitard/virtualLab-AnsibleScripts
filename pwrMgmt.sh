#!/bin/bash
#
# Script de gestion du démarrage et de l'arrêt des VMs d'un Pod
#
# 2025-12-15 - Mitard V. : Création
# 2026-01-31 - Mitard V. : Utilisation du paramètre $PodID comme numéro de Pod par défaut
#
scriptName=`basename $0`
playbooks=/home/ansible/playbooks
ansibleHosts=/home/ansible/.ansible/hosts
authenticationFile=/home/ansible/pveAuthentication.yml

if [ $# -eq 0 ]; then
  echo -e "\n-E- Paramètre obligatoire absent !"
  echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"
  exit 1
fi

while getopts "dDe:hHs:" opt; do
  case $opt in
    d|D) set -x
	 ansibleDebug=-vv
	 ;;
    e) authenticationFile=$OPTARG
       ;;
    h|H) echo -e "\n-I- $scriptName permet de démarrer, redémarrer ou arrêter l'ensemble des routeurs d'un Pod."
	 echo -e "-I- $scriptName [-d|-D] [-h|-H] [-e <Fichier d'authentification>] On|Off|Restart [<No de Pod>]"
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
  2) Pod=Pod$2
     ;;
  1) Pod=Pod$PodID
     ;;
  *) echo -e "\n-E- Nombre de paramètres incorrects !"
     echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"
     exit 1
     ;;
esac

case ${1,,} in
  on) VMstate=started
      ;;
  off) VMstate=stopped
       ;;
  restart) VMstate=restarted
	   ;;
  *) echo -e "\n-E- Option $1 invalide !\n"
     exit 1
     ;;
esac

ansible-playbook -i $ansibleHosts $ansibleDebug -e @$authenticationFile -e "pattern='^$Pod-' status=$VMstate" $playbooks/pve/runVMs.yml
