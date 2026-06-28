# Readme

## Remove a node

```bash

# Delete the node
kubectl delete node <node-name>

# Clean up the node
sudo kubeadm reset
sudo rm -rf /etc/kubernetes/ /var/lib/kubelet/ /var/lib/etcd/

# Join with new token from output
kubeadm token create --print-join-command

```
