#!/bin/bash
# AUTHOR: GRAOUI ABDERRAHMANE
# THIS IS THE MAIN SCRIPT, RUN THIS AS ROOT

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Load OS info
source /etc/os-release

# Check OS compatibility
if ! ([[ "$ID" == "ubuntu" || "$ID" == "debian" ]] || [[ "$ID_LIKE" == *"debian"* ]]); then
  echo "This system is not Debian or Ubuntu based. Exiting..." >&2
  exit 72
fi

# Install dependencies
if ! command -v dialog >/dev/null 2>&1; then
  echo "Installing dependencies..."
  apt update
  apt install dialog -y || { echo "Installation failed"; exit 72; }
fi

# Function for prompt
confirm_kerberos_ssh() {
  dialog --colors \
         --backtitle "Apache Hadoop Install script" \
         --title "WARNING!!!" \
         --msgbox "\Zb\Z1This installation depends on Kerberos and SSH being preconfigured.\Zn" 8 60

  dialog --backtitle "Apache Hadoop Install script" \
         --title "Confirmation" \
         --yesno "Is Kerberos and SSH key setup complete?" 7 60
  return $?
}

confirm_install() {
    dialog --backtitle "Apache Hadoop Install script" \
         --title "Confirmation" \
         --yesno "Installing $1 on this machine, confirm ?" 7 60
    return $?
}

# Function for installing a DataNode
install_datanode() {
  local node="$1"
  if confirm_install "$node"; then
    echo "Installing for $node..."
    cd hadoop_install/
    bash ./hadoopusr_setup.sh && bash ./hadoop_install.sh && bash ./dn_nm_config.sh "$node"
    cd ../
  else
    echo "Aborted by user."
  fi
}

# Main dialog menu
HEIGHT=0
WIDTH=0
CHOICE_HEIGHT=5
BACKTITLE="Apache Hadoop Install script"
TITLE="Main Menu"
MENU="What would you like to install on this machine?"

OPTIONS=(1 "MasterNode"
         2 "DataNode"
         3 "Kerberos + OpenLDAP + Docker + Authentik Server + AlpineSSH"
         4 "Docker + Secure Web Application Gateway + Authentik Worker/Redis/PostgreSQL + AlpineSSH"
         5 "Exit")

while true; do
  CHOICE=$(dialog --clear \
                  --backtitle "$BACKTITLE" \
                  --title "$TITLE" \
                  --menu "$MENU" \
                  $HEIGHT $WIDTH $CHOICE_HEIGHT \
                  "${OPTIONS[@]}" \
                  2>&1 >/dev/tty)

  echo "DEBUG: CHOICE='$CHOICE'" >&2


  clear
  case $CHOICE in
    1)
      if confirm_kerberos_ssh; then
        if confirm_install "MasterNode"; then
          echo "Installing for MasterNode..."
          cd hadoop_install/
          bash ./hadoopusr_setup.sh && bash ./hadoop_install.sh && bash ./nn_rm_config.sh
          cd ../
        fi
      else
        break
      fi
      ;;

    2)
      if confirm_kerberos_ssh; then
        while true; do
          CHOICE_HEIGHT=3
          BACKTITLE="Apache Hadoop Install script"
          TITLE="Datanode Select"
          MENU="Choose a DataNode to install"

          DN_OPTIONS=(1 "DataNode 1"
                      2 "DataNode 2"
                      3 "Return")

          DN_CHOICE=$(dialog --clear \
                              --backtitle "$BACKTITLE" \
                              --title "$TITLE" \
                              --menu "$MENU" \
                              $HEIGHT $WIDTH $CHOICE_HEIGHT \
                              "${DN_OPTIONS[@]}" \
                              2>&1 >/dev/tty)

          clear
          case $DN_CHOICE in
            1) install_datanode "DataNode 1" ;;
            2) install_datanode "DataNode 2" ;;
            3) break ;;
          esac
        done
      else
        break
      fi
      ;;

    3)
      if confirm_install "Kerberos Stack"; then
        echo "Installing for Kerberos Stack..."
        cd krb_install/
        bash ./kerberos.sh && bash ./ldap.sh
        cd ../
        cd docker_install/
        bash install_docker.sh krb
        cd ../
      else
        break
      fi
      ;;

    4)
      if confirm_install "Docker Web Stack"; then
        echo "Installing for Docker Web Stack..."
        cd docker_install/
        bash install_docker.sh proxy
        cd ../
      else
        break
      fi
      ;;

    5)
      echo "Exiting..."
      exit 0
      ;;
  esac
done
