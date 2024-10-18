#!/bin/bash

# File path to the config
config_file="/root/ceremonyclient/node/.config/config.yml"

# Function to output in color
output_green() {
  echo -e "\n\033[0;32m$1\033[0m"
}

output_red() {
  echo -e "\n\033[0;31m$1\033[0m"
}

output_cyan() {
  echo -e "\n\033[0;36m$1\033[0m"
}

# Function to check and display the current protocol
check_protocol() {
  udp_found=false
  tcp_found=false
  
  if grep -q '^ *listenMultiaddr: /ip4/0.0.0.0/udp/8336/' "$config_file"; then
    output_green "Found: UDP version"
    udp_found=true
  else
    output_red "Not found: UDP version"
  fi

  if grep -q '^ *listenMultiaddr: /ip4/0.0.0.0/tcp/8336/' "$config_file"; then
    output_green "Found: TCP version"
    tcp_found=true
  else
    output_red "Not found: TCP version"
  fi

  # Return the results as "udp_found tcp_found"
  echo "$udp_found $tcp_found"
}

# Initial check
echo -e "\nChecking current protocol configuration:"
initial_state=$(check_protocol)
udp_initial=$(echo $initial_state | cut -d' ' -f1)
tcp_initial=$(echo $initial_state | cut -d' ' -f2)

# Prompt the user to switch the protocol
if [[ $udp_initial == "true" ]]; then
  read -p "$(echo -e "Do you want to switch to \033[0;36mTCP\033[0m? (y/n): ")" choice
  if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    sed -i 's|listenMultiaddr: /ip4/0.0.0.0/udp/8336/.*|listenMultiaddr: /ip4/0.0.0.0/tcp/8336/|' "$config_file"
    output_cyan "Switched from UDP to TCP."
  else
    output_cyan "No changes made."
  fi

elif [[ $tcp_initial == "true" ]]; then
  read -p "$(echo -e "Do you want to switch to \033[0;36mUDP\033[0m? (y/n): ")" choice
  if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    sed -i 's|listenMultiaddr: /ip4/0.0.0.0/tcp/8336/.*|listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic|' "$config_file"
    output_cyan "Switched from TCP to UDP."
  else
    output_cyan "No changes made."
  fi
else
  output_red "No recognized listenMultiaddr line found to switch."
  exit 1
fi

# Check the protocol again after the switch
echo -e "\nRechecking protocol configuration after the switch:"
final_state=$(check_protocol)
udp_final=$(echo $final_state | cut -d' ' -f1)
tcp_final=$(echo $final_state | cut -d' ' -f2)

# Confirm if the switch was successful
if [[ $udp_initial == "true" && $tcp_final == "true" ]]; then
  output_cyan "Switch successful: UDP was changed to TCP."
elif [[ $tcp_initial == "true" && $udp_final == "true" ]]; then
  output_cyan "Switch successful: TCP was changed to UDP."
else
  output_red "Switch was not successful."
fi

# End of script
