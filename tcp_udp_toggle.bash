#!/bin/bash

# File path to the config
config_file="/root/ceremonyclient/node/.config/config.yml"

# Function to output in cyan
output_cyan() {
  echo -e "\033[0;36m$1\033[0m"
}

# Function to prompt user to switch the protocol
prompt_switch() {
  read -p "$(echo -e "Do you want to switch to \033[0;36m$1\033[0m? (y/n): ")" choice
  if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

# Check for tcp or udp in the listenMultiaddr line
listen_addr=$(grep '^ *listenMultiaddr:' "$config_file")

# Output current value and prompt user for switch
if echo "$listen_addr" | grep -q 'udp'; then
  output_cyan "Current protocol: UDP"
  if [[ "$(prompt_switch "TCP")" == "yes" ]]; then
    # Replace with TCP
    sed -i 's|listenMultiaddr:.*udp.*|listenMultiaddr: /ip4/0.0.0.0/tcp/8336/|' "$config_file"
    output_cyan "Switched to TCP."
  else
    output_cyan "No changes made."
  fi
elif echo "$listen_addr" | grep -q 'tcp'; then
  output_cyan "Current protocol: TCP"
  if [[ "$(prompt_switch "UDP")" == "yes" ]]; then
    # Replace with UDP
    sed -i 's|listenMultiaddr:.*tcp.*|listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic|' "$config_file"
    output_cyan "Switched to UDP."
  else
    output_cyan "No changes made."
  fi
else
  output_cyan "No recognized protocol in listenMultiaddr."
fi

# Verify the change
new_listen_addr=$(grep '^ *listenMultiaddr:' "$config_file")
output_cyan "Updated line: $new_listen_addr"
