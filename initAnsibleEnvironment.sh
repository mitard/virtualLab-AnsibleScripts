#!/bin/bash
#
# 2026-01-19 - V. Mitard : Création
#
scriptName=`basename $0`
bannerFile=/etc/ssh/ssh_banner

echo "-I- Initialisation de l'environnement d'automatisation pour l'utilisateur Ansible"
# Changement des droits sur répertoire .ansible créé par l'utilisateur root lors de l'initialisation de la VM
#sudo chown ansible $HOME/.ansible
#sudo chgrp ansible $HOME/.ansible
#ansible-galaxy collection install community.proxmox
# Personnalisation de la bannière de connexion
sudo echo "" > $bannerFile
sudo figlet -f slant -c -k "Pod ${HOSTNAME: -1}" >> $bannerFile
sudo echo "" >> $bannerFile
