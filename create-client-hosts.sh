#!/bin/bash

numEsxiVMs=$(vagrant status --machine-readable | grep 'esxi-.*,state,running' | wc -w)

result_string=""

for ((i = 1; i <= numEsxiVMs; i++)); do
  ip=$(vagrant ssh-config esxi-$i | grep HostName | awk '{printf $2}')
  result_string+="$ip      esxi-$i.esxi.test\n"
done

echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" > client_hosts_file
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> client_hosts_file
echo -e "${result_string::-2}" >> client_hosts_file
