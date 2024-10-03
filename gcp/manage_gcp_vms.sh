#!/bin/bash

# Function to authenticate with GCP
authenticate() {
  echo "Authenticating with Google Cloud Platform..."
  gcloud auth login
}

# Function to set the GCP project
set_project() {
  local project_id=$1
  echo "Setting GCP project to $project_id..."
  gcloud config set project $project_id
}

# Function to stop VMs
stop_vms() {
  local zone=$1
  shift
  local vm_names=("$@")
  
  for vm_name in "${vm_names[@]}"; do
    echo "Stopping VM: $vm_name in zone: $zone..."
    gcloud compute instances stop "$vm_name" --zone "$zone"
  done
}

# Function to start VMs
start_vms() {
  local zone=$1
  shift
  local vm_names=("$@")
  
  for vm_name in "${vm_names[@]}"; do
    echo "Starting VM: $vm_name in zone: $zone..."
    gcloud compute instances start "$vm_name" --zone "$zone"
  done
}

# Main script
main() {
  if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <project_id> <zone> <action> <vm_name1> [<vm_name2> ... <vm_nameN>]"
    echo "Action must be 'start' or 'stop'."
    exit 1
  fi

  local project_id=$1
  local zone=$2
  local action=$3
  shift 3
  local vm_names=("$@")

  authenticate
  set_project "$project_id"

  if [ "$action" == "stop" ]; then
    stop_vms "$zone" "${vm_names[@]}"
  elif [ "$action" == "start" ]; then
    start_vms "$zone" "${vm_names[@]}"
  else
    echo "Invalid action: $action. Action must be 'start' or 'stop'."
    exit 1
  fi
}

# Run the main script
main "$@"
