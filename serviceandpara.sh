sudo mkdir -p /root/ceremonyclient/node && sudo bash -c 'cat > /root/ceremonyclient/node/para.sh <<EOF
#!/bin/bash
DIR_PATH=\$( cd "\$(dirname "\${BASH_SOURCE[0]}")" ; pwd -P )

os=\$1
architecture=\$2
startingCore=\$3
maxCores=\$4
pid=\$\$
version=\$5
crashed=0

start_process() {
  pkill node-*
  if [ \$startingCore == 0 ]
  then
    \$DIR_PATH/node-\$version-\$os-\$architecture &
    pid=\$!
    if [ \$crashed == 0 ]
    then
      maxCores=\$(expr \$maxCores - 1)
    fi
  fi

  echo Node parent ID: \$pid;
  echo Max Cores: \$maxCores;
  echo Starting Core: \$startingCore;

  for i in \$(seq 1 \$maxCores)
  do
    echo Deploying: \$(expr \$startingCore + \$i) data worker with params: --core=\$(expr \$startingCore + \$i) --parent-process=\$pid;
    \$DIR_PATH/node-\$version-\$os-\$architecture --core=\$(expr \$startingCore + \$i) --parent-process=\$pid &
  done
}

is_process_running() {
    ps -p \$pid > /dev/null 2>&1
    return \$?
}

start_process

while true
do
  if ! is_process_running; then
    echo "Process crashed or stopped. restarting..."
    crashed=\$(expr \$crashed + 1)
    start_process
  fi
  sleep 440
done
EOF
sudo chmod +x /root/ceremonyclient/node/para.sh' && echo "[Unit]
Description=Para Script Service
After=network.target

[Service]
# Set Your beginning core (0) and Workers You run (1)
ExecStart=/bin/bash /root/ceremonyclient/node/para.sh linux amd64 0 1 1.4.21.1
Restart=always
User=root
Group=root
WorkingDirectory=/root/ceremonyclient/node
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=para

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/para.service && sudo systemctl daemon-reload && sudo systemctl enable para.service
