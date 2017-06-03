#!/bin/bash

# DESCRIPTION
# Create, backup and restore Tor onion services on Tails. By default it
# will create an onion service for Monero RPC daemon. This will allow
# remote Monero clients to sync wallets without storing the entire
# blockchain. All they have to do is point the wallet to the .onion
# hostname.
#
# Use the '-t' option to create so called 'stealth' onions. This
# will create a Tor .onion service that requires authentication
# before a connection can be created. This is useful when you want to
# keep your onion service private.
#
# The script also supports Monero P2P and SSH.

### VARS ###

# Monero RPC settings
readonly ip_monero="127.0.0.1"
readonly port_monero="18081"
readonly port_tor_monero="18081"
readonly dir_monero="monero_rpc"

# Monero P2P settings
readonly ip_monero_p2p="127.0.0.1"
readonly port_monero_p2p="18080"
readonly port_tor_monero_p2p="18080"
readonly dir_monero_p2p="monero_p2p"

# SSH settings
readonly ip_ssh="127.0.0.1"
readonly port_ssh="22"
readonly port_tor_ssh="22"
readonly dir_ssh="ssh_server"

# Tor and Tails settings
readonly tor_torrc="/etc/tor/torrc"
readonly tor_onions_dir="/var/lib/tor"
readonly tor_onions_owner="debian-tor"
readonly tor_onions_group="debian-tor"
readonly tor_onions_dir_permissions="2700"
readonly tor_onions_file_permissions="0600"
readonly persistent_dir="/home/amnesia/Persistent"
readonly persistent_dir_onions="${persistent_dir}/tor/onion_services"

### FUNCTIONS ###

usage()
{
cat << EOF

Usage: ${0} options

By default this script will create a Tor onion service for a
Monero RPC server.

It will backup the onion service to the 'persistent' directory:
${persistent_dir}

Use the options to change the defaults.

OPTIONS:
  -h   Show this message
  -m   Configure Tor onion service for Monero blockchain P2P server
  -s   Configure Tor onion service for SSH server
  -t   Configure a stealth/private Tor onion service
  -p   Disable backup Tor onion service to persistent storage
  -b   Create a backup to persistent storage
  -r   Restore onion service from persistent storage
  -o   Output .onion hostname(s) of service
  -u   Output .onion hostname(s) of service from backup on persistent
       storage

EOF
}

run_as_root() {
  if [[ "$(id -u)" != "0" ]]; then
    echo "ERROR: Must be run as root...exiting script"
    exit 0
  fi
}

set_service_vars() {
  # Use monero (RPC) by default
  if [[ -z "${service_name}" ]]; then
    service_name="monero"
  fi

  # Use config settings from the service
  dir_service=dir_$service_name
  ip_service=ip_$service_name
  port_service=port_$service_name
  port_tor_service=port_tor_$service_name
  persistent_dir_service=persistent_dir_$service_name
}

check_onion() {
  if [[ -d "${tor_onions_dir}"/"${!dir_service}" ]]; then
    echo "Tor onion service for ${service_name} is already configured."
    echo
    echo "The .onion name for the ${service_name} service is:"
    onion_hostname
    return 1
  fi
}

onion_hostname() {
  if [[ -f "${tor_onions_dir}"/"${!dir_service}"/hostname ]]; then
    cat "${tor_onions_dir}"/"${!dir_service}"/hostname
  fi
}

check_persistent() {
  if [[ ! -d "${persistent_dir}" ]]; then
    echo "WARNING: No persistent directory available at:"
    echo "${persistent_dir}"
    echo
    echo "The onion service will NOT survive a reboot."
    return 1
  fi
}

check_backup() {
  if [[ -d "${persistent_dir_onions}"/"${!dir_service}" ]]; then
    echo "ERROR: Backup available for ${service_name}. Backup is available at:"
    echo "${persistent_dir_onions}/${!dir_service}"
    echo
    echo "The .onion name of the backup is:"
    backup_hostname
    echo
    echo "Use '-r' option to restore backup. Example:"
    echo "${0} -r"
  else
    return 1
  fi
}

backup_hostname() {
  if [[ -f "${persistent_dir_onions}"/"${!dir_service}"/hostname ]]; then
    cat "${persistent_dir_onions}"/"${!dir_service}"/hostname
  fi
}

configure_onion() {
  if grep --quiet "${!dir_service}" "${tor_torrc}"; then
    echo "${service_name} is already configured in ${tor_torrc}"
    echo
  else
    echo >> "${tor_torrc}" 
    echo "## ${service_name} onion service" >> "${tor_torrc}"
    echo "HiddenServiceDir ${tor_onions_dir}/${!dir_service}" >> "${tor_torrc}" 
    echo "HiddenServicePort ${!port_tor_service} ${!ip_service}:${!port_service}" >> "${tor_torrc}"
      if [[ -n "${tor_stealth_onion}" ]]; then
        echo "HiddenServiceAuthorizeClient stealth ${service_name}_1" >> "${tor_torrc}"
      fi
  fi
}

create_onion() {
  local wait_for_onions="0"
  local max_wait_for_onions="24"

  if $(systemctl --quiet is-active tor.service); then
    systemctl restart tor.service
  else
    systemctl start tor.service
  fi
  while [[ ! -d "${tor_onions_dir}"/"${!dir_service}" ]]; do
    if [[ "${wait_for_onions}" -ge "${max_wait_for_onions}" ]]; then
      echo "ERROR: The creation of the Tor onion service is taking"
      echo "too long. Please run the script again. Exiting script."
      exit 1
    fi
  wait_for_onions=$(($wait_for_onions + 1 ))
  echo "Cooking onions... please wait"
  sleep 5
  done
}

create_backup() {
  if ! check_backup &>/dev/null && check_persistent &>/dev/null; then
    mkdir -p "${persistent_dir_onions}"/"${!dir_service}"
    cp -r -p "${tor_onions_dir}"/"${!dir_service}" "${persistent_dir_onions}"
    echo "WARNING: A persistent backup of the Tor onion service for ${service_name} is created at:"
    echo "${persistent_dir_onions}/${!dir_service}"
    echo
    echo "You can use this backup to restore the onion service."
  elif check_backup &>/dev/null; then
    echo "ERROR: Backup for ${service_name} already available at:"
    echo "${persistent_dir_onions}"/"${!dir_service}"
    echo "Will not overwrite backup."
  fi
}

restore_backup() {
  if ! check_backup &>/dev/null; then
    echo "ERROR: No backup available for ${service_name}"
    exit 1
  fi

  if ! check_onion &>/dev/null; then
    echo "ERROR: Tor .onion service for ${service_name}" is already configured
    echo "Will not overwrite the existing files."
    exit 1
  fi

  # Copy files from persistent storage to tor onions directory
  cp -r -p "${persistent_dir_onions}"/"${!dir_service}" "${tor_onions_dir}"
  sleep 1

  # Set file permissions
  chown -R "${tor_onions_owner}":"${tor_onions_group}" "${tor_onions_dir}"/"${!dir_service}"
  chmod "${tor_onions_dir_permissions}" "${tor_onions_dir}"/"${!dir_service}"
  chmod "${tor_onions_file_permissions}" "${tor_onions_dir}"/"${!dir_service}"/hostname
  chmod "${tor_onions_file_permissions}" "${tor_onions_dir}"/"${!dir_service}"/private_key

  # Check for 'client_keys' to enable HiddenServiceAuthorizeClient option
  if [[ -f "${tor_onions_dir}"/"${!dir_service}"/client_keys ]]; then
    chmod "${tor_onions_file_permissions}" "${tor_onions_dir}"/"${!dir_service}"/client_keys
    tor_stealth_onion="true"
  fi
}

main() {
  run_as_root
  set_service_vars

  # Check command line arguments
  if [[ -n "${only_restore_backup}" ]]; then
    restore_backup
    configure_onion && exit
    check_onion && exit
    create_onion
    echo "The .onion name for the ${service_name} service is:"
    onion_hostname
  elif [[ -n "${only_create_backup}" ]]; then
    create_backup
  elif [[ -n "${non_persistent_onion}" ]]; then
    check_onion || exit
    configure_onion || exit
    create_onion || exit
    echo
    echo "The .onion name for the ${service_name} service is:"
    onion_hostname
  elif [[ -n "${output_onion_hostname}" ]]; then
    onion_hostname
  elif [[ -n "${output_backup_hostname}" ]]; then
    backup_hostname
  else
    # Default action when no command line arguments are given
    check_onion || exit
    check_persistent
    check_backup && exit
    configure_onion || exit
    create_onion || exit
    create_backup
    echo
    echo "The .onion name for the ${service_name} service is:"
    onion_hostname
  fi
}

# Arguments
while getopts "hmstpbrou" option; do
  case "${option}" in
    h) usage
       exit
       ;;
    m) service_name="monero_p2p"
       ;;
    s) service_name="ssh"
       ;;
    t) tor_stealth_onion="true"
       ;;
    p) non_persistent_onion="true"
       ;;
    b) only_create_backup="true"
       ;;
    r) only_restore_backup="true"
       ;;
    o) output_onion_hostname="true"
       ;;
    u) output_backup_hostname="true"
       ;;
    ?) usage
       exit
       ;;
  esac
done

main
