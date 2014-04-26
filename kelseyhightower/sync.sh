#!/bin/bash

ssh core@${1} 'sudo mkdir -p /opt/ipxeserver'
ssh core@${1} 'sudo chown core /opt/ipxeserver'
rsync -av /opt/ipxeserver core@${1}:/opt/

ssh core@${1} 'mkdir /home/core/bin'
scp ipxeserver/ipxeserver core@${1}:/home/core/bin/
scp ipxeserver/ipxeserver.service core@${1}:~/
ssh core@${1} 'sudo mv ipxeserver.service /etc/systemd/system/ipxeserver.service'
