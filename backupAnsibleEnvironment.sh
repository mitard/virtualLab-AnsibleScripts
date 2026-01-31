#!/bin/bash
#
# 2026-01-18 - V. Mitard : Création
# 2026-01-30 - V. Mitard : Suppression des scripts et playbooks
#
scriptName=`basename $0`
initialDirectory=$PWD
cd ~

echo "-I- Création d'une archive de la configuration Ansible"
echo "-I- Sauvegarde de la clé privée de l'utilisateur"
tar --absolute-name --create --file AnsibleEnv.tar $HOME/.ssh/id_rsa
echo "-I- Sauvegarde de fichier de configuration pour l'authentification avec l'hyperviseur"
tar --absolute-name --append --file AnsibleEnv.tar $HOME/pveAuthentication.yml
echo "-I- Sauvegarde de fichier HOST"
tar --absolute-name --append --file AnsibleEnv.tar $HOME/.ansible/hostsPod
echo "-I- Sauvegarde des roles"
tar --absolute-name --append --file AnsibleEnv.tar $HOME/.ansible/roles
echo "-I- Sauvegarde des plugins"
tar --absolute-name --append --file AnsibleEnv.tar $HOME/.ansible/plugins
echo "-I- Compression du fichier d'archives"
gzip --force AnsibleEnv.tar

cd $initialDirectory
