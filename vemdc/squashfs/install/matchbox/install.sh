#!/usr/bin/env bash

wget https://github.com/poseidon/matchbox/releases/download/v0.10.0/matchbox-v0.10.0-linux-amd64.tar.gz
tar xzvf matchbox-v0.10.0-linux-amd64.tar.gz

cd matchbox-v0.10.0-linux-amd64/
sudo cp matchbox /usr/local/bin
sudo cp contrib/systemd/matchbox.service /etc/systemd/system/matchbox.service

useradd -U matchbox