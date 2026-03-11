#!/bin/bash
#
# Script d'initialisation de la configuration des routeurs
#
# 2026-01-02 - Mitard V. : Création
# 2026-02-15 - Mitard V. : Ajout des configurations des labs BGP
# 2026-03-11 - Mitard V. : Suppression de l'initialisation du fichier d'authentification (Initialisé par défaut dans le .profile de l'utilisateur)
#
#
scriptName=`basename $0`
playbooks=/home/ansible/playbooks
ansibleHosts=/home/ansible/.ansible/hosts
authenticationFile=/home/ansible/lolaAuthentication.yml

if [ $# -eq 0 ]; then
  echo -e "\n-E- Paramètre obligatoire absent !"
  echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"
  exit 1
fi

while getopts "dDe:hH" opt; do
  case $opt in
    d|D) set -x
	 ansibleDebug=-vv
	 ;;
    e) authenticationFile=$OPTARG
       ;;
    h|H) echo -e "\n-I- $scriptName permet d'initialiser la configuration l'ensemble des routeurs d'un Pod."
	 echo -e "-I- $scriptName [-d|-D] [-h|-H] [-e <Fichier d'authentification>] RAZ|BGP<n>|PW|L2VPN|L3VPN [<No de Pod>]"
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

case ${1^^} in
  RAZ)   playbook=$playbooks/linux-routers/clearFRRconf.yml
         ;;
  # TP routage BGP
  BGP1)  playbook=$playbooks/linux-routers/copyFRRconf.yml
         configuration=_BGP_TP1
         targets=BGP1_"$Pod"RTR
         ;;
  BGP2)  playbook=$playbooks/linux-routers/copyFRRconf.yml
         configuration=_BGP_TP2
         targets=BGP2_"$Pod"RTR
         ;;
  # TP IP/MPLS
  BGP)   playbook=$playbooks/linux-routers/copyFRRconf.yml
         configuration=_MPLS_lab1
         targets="$Pod"RTR
         ;;
  PW)    playbook=$playbooks/linux-routers/copyFRRconf.yml
         configuration=_PW
         targets="$Pod"RTR
         ;;
  L2VPN) playbook=$playbooks/linux-routers/copyFRRconf.yml
         configuration=_VPLS
         targets="$Pod"RTR
         ;;
  L3VPN) playbook=$playbooks/linux-routers/copyFRRconf.yml
         configuration=_MPLS_lab2
         targets="$Pod"RTR
         ;;
  *) echo -e "\n-E- Option $1 invalide !\n"
     exit 1
     ;;
esac

edges=Pod$2Edge

ansible-playbook -i $ansibleHosts $ansibleDebug -e @$authenticationFile -e "target=$targets suffix=$configuration" $playbook
ansible-playbook -i $ansibleHosts $ansibleDebug -e @$authenticationFile -e "target=$targets cmd=reboot" $playbooks/linux-routers/execCommand.yml
if [ "${1^^}" = "L3VPN" ]; then
  ansible-playbook -i $ansibleHosts $ansibleDebug -e @$authenticationFile -e "target=$edges cmd=/usr/local/bin/clients-vrf-conf.sh" $playbooks/linux-routers/execCommand.yml
fi
