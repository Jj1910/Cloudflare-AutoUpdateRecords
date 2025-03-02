#!/bin/bash
source ./config
date=$(date '+%m-%d-%y')
mylogfile=./$date.log
ipv4=$(curl --silent https://checkip.amazonaws.com)
oldip=${ip}
zone=${zone}
apikey=${apikey}
if [[ $oldip != $ipv4 ]]; then
        echo "Difference Found Old IP: $oldip New IP: $ipv4 " | tee -a $mylogfile
        echo "Changing IP..." | tee -a $mylogfile
        sed -i "s/ip=.*/ip=$ipv4/" config

        records=$(curl --silent https://api.cloudflare.com/client/v4/zones/$zone/dns_records -H "Authorization: Bearer $apikey")
        echo "$records" | jq -c '.result[]' | while read -r record; do
                name=$(echo "$record" | jq -r '.name')
                type=$(echo "$record" | jq -r '.type')
                content=$(echo "$record" | jq -r '.content')
                ttl=$(echo "$record" | jq -r '.ttl')
                id=$(echo "$record" | jq -r '.id')
                proxied=$(echo "$record" | jq -r '.proxied')

                if [[ ($type == "A" || $type == "AAAA") && $content != $ipv4 ]]; then
                        echo "Changing $name to point to $ipv4" | tee -a $mylogfile
                        curl --silent -X PATCH \
                        --url https://api.cloudflare.com/client/v4/zones/$zone/dns_records/$id \
                        -H "Authorization: Bearer $apikey" \
                        -H "Content-Type: application/json" \
                        -d '{
                                "content": "'$ipv4'",
                                "name": "'$name'",
                                "proxied": '$proxied',
                                "type": "'$type'",
                                "ttl": '$ttl'
                        }' | jq . | tee -a $mylogfile
                else
                        echo "IP Matches or type is not A or AAAA for $name" | tee -a $mylogfile
                fi
        done
else
        echo "No difference found" | tee -a $mylogfile
fi
