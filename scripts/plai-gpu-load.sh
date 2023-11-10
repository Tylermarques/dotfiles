gcloud compute instances list --filter="name~discord-api-gpu-autoscalling-instance-group" | awk '$1 ~ /^discord/ {print $5}' | while read -r ip; do
    result=$(websocat "ws://$ip:8189/ws" </dev/null | jq -r ".data.status.exec_info.queue_remaining")
    echo -e "$ip\t$result"
done
