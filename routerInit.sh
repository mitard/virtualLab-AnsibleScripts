#!/bin/bash
#
# Script d'initialisation de la configuration des routeurs
#
# 2026-01-02 - Mitard V. : Création
# 2026-02-15 - Mitard V. : Ajout des configurations des labs BGP
# 2026-03-11 - Mitard V. : Suppression de l'initialisation du fichier d'authentification (Initialisé par défaut dans le .profile de l'utilisateur)
# 2026-05-23 - Mitard V. : Ajout d'une 3ème topologie pour les TPs BGP (BGP3)
# 2026-05-24 - Mitard V. : Ajout d'une topologie pour le TP OSPFv2
#
#
scriptName=`basename $0`
playbooks=/home/ansible/playbooks
ansibleHosts=/home/ansible/.ansible/hosts

if [ $# -eq 0 ]; then
  tput setaf 1; echo -e "\n-E- Paramètre obligatoire absent !"; tput sgr0
  tput setaf 3; echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"; tput sgr0
  exit 1
fi

while getopts "dDe:hH" opt; do
  case $opt in
    d|D) set -x
	 ansibleDebug=-vv
	 ;;
    e) authenticationFile=$OPTARG
       ;;
    h|H) tput setaf 3
	 echo -e "\n-I- $scriptName permet d'initialiser la configuration l'ensemble des routeurs d'un Pod."
	 echo -e "-I- $scriptName [-d|-D] [-h|-H] [-e <Fichier d'authentification>] RAZ|BGP<n>|L2VPN|L3VPN|OSPFv2|PW [<No de Pod>]"
	 echo -e "\t-d|-D : Activativation des traces de débogage."
	 echo -e "\t-h|-H : Affichage de cette aide en ligne."
	 echo -e "\t-e : Nom du fichier contenant les informations d'authentification pour l'accès au noeud Proxmox.\n"
	 tput sgr0
	 exit 0
	 ;;
    *) tput setaf 1; echo -e "\n-E- Option $opt invalide !\n"; tput sgr0
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
  *) tput setaf 1; echo -e "\n-E- Nombre de paramètres incorrects !"; tput sgr0
     tput setaf 3; echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"; tput sgr0
     exit 1
     ;;
esac

case ${1^^} in
  RAZ)    playbook=$playbooks/linux-routers/clearFRRconf.yml
          ;;
  # TP routage OSPF
  OSPFV2) playbook=$playbooks/linux-routers/copyFRRconf.yml
          configuration=_OSPFv2_lab
          targets=OSPF_"$Pod"RTR
          ;;
  # TP routage BGP
  BGP1)   playbook=$playbooks/linux-routers/copyFRRconf.yml
          configuration=_BGP_TP1
          targets=BGP1_"$Pod"RTR
          ;;
  BGP2)   playbook=$playbooks/linux-routers/copyFRRconf.yml
          configuration=_BGP_TP2
          targets=BGP2_"$Pod"RTR
          ;;
  BGP3)   playbook=$playbooks/linux-routers/copyFRRconf.yml
          configuration=_BGP_TP3
          targets=BGP3_"$Pod"RTR
          ;;
  # TP IP/MPLS
  BGP)    playbook=$playbooks/linux-routers/copyFRRconf.yml
          configuration=_MPLS_lab1
          targets=MPLS_"$Pod"RTR
          ;;
  PW)     playbook=$playbooks/linux-routers/copyFRRconf.yml
          configuration=_PW
          targets="$Pod"RTR
          ;;
  L2VPN)  playbook=$playbooks/linux-routers/copyFRRconf.yml
          configuration=_VPLS
          targets="$Pod"RTR
          ;;
  L3VPN)  playbook=$playbooks/linux-routers/copyFRRconf.yml
          configuration=_MPLS_lab2
          targets=MPLS_"$Pod"RTR
          ;;
  *)      tput setaf 1; echo -e "\n-E- Option $1 invalide !\n"; tput sgr0
          exit 1
          ;;
esac

edges=Pod$2Edge

ansible-playbook -i $ansibleHosts $ansibleDebug -e @$authenticationFile -e "target=$targets suffix=$configuration" $playbook
ansible-playbook -i $ansibleHosts $ansibleDebug -e @$authenticationFile -e "target=$targets cmd=reboot" $playbooks/linux-routers/execCommand.yml
if [ "${1^^}" = "L3VPN" ]; then
  ansible-playbook -i $ansibleHosts $ansibleDebug -e @$authenticationFile -e "target=$edges cmd=/usr/local/bin/clients-vrf-conf.sh" $playbooks/linux-routers/execCommand.yml
i
