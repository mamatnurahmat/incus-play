#!/bin/bash
VALID_IPS=$(kubectl get pods --field-selector spec.nodeName=rke2-agent01 -A -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' | grep '^10.42' | tr '\n' ' ')
echo "Keeping active IPs: ${VALID_IPS}"

incus exec rke2-agent01 -- bash -c "
cd /var/lib/cni/networks/k8s-pod-network || exit 0
for f in 10.*; do
  # Skip non-files or if no files match
  [ -e \"\${f}\" ] || continue
  
  # Check if the file name (which is an IP) is in the VALID_IPS list
  if [[ ! \" ${VALID_IPS} \" =~ \" \${f} \" ]]; then
    echo \"Deleting stale IP allocation: \${f}\"
    rm -f \"\${f}\"
  fi
done
"
echo "Restarting failed pods on rke2-agent01..."
kubectl delete pod -n cattle-fleet-system fleet-agent-b497bff4-n2z7r
