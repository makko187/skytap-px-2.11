#!/bin/bash

echo "PX 2.11 Deployment Script Running on FA Cloud Volumes"
sleep 1

echo "Checking K8 Nodes are Ready"
while true; do    
	NUM_READY=`kubectl get nodes 2> /dev/null | grep -v NAME | awk '{print $2}' | grep -e ^Ready | wc -l`
    if [ "${NUM_READY}" == "4" ]; then
        echo "All ${NUM_READY} Kubernetes nodes are ready !"
        break
    else
        echo "Waiting for all Kubernetes nodes to be ready. Current ready nodes: ${NUM_READY}"
        kubectl get nodes
    fi
    sleep 5
done

echo "Make Sure you're at the master node home directory: /home/pureuser"

echo " Step 1. Verify JSON file FA API token from home directory:"
cat pure.json
sleep 10

echo " Step 2. Create Kubernetes Secret called px-pure-secret:"
kubectl create secret generic px-pure-secret --namespace kube-system --from-file=pure.json
sleep 2
kubectl get secrets -A | grep px-pure-secret
sleep 5

echo " Step 3. Install PX Operator and check if the POD is running:"
kubectl apply -f 'https://install.portworx.com/2.11?comp=pxoperator'
while true; do
    NUM_READY=`kubectl get pods -n kube-system -o wide | grep portworx-operator | grep Running | wc -l`
    if [ "${NUM_READY}" == "1" ]; then
        echo "PX Operator pod is ready!"
        kubectl get pods -n kube-system -o wide | grep portworx-operator | grep Running
        break
    else
        echo "Waiting for PX Operator POD to be ready. Current ready pods: ${NUM_READY}"
    fi
    sleep 5
done
sleep 2

echo " Step 4. Install PortWorx 2.11 Spec using FlashArray Cloud Drives:"
sleep 5
kubectl apply -f px-spec-2.11.yaml

echo " Step 5. Wait for Portworx Installation to complete:"
while true; do
    NUM_READY=`kubectl get pods -n kube-system -l name=portworx -o wide | grep Running | grep 3/3 | wc -l`
    if [ "${NUM_READY}" == "3" ]; then
        echo "All portworx nodes are ready !"
        kubectl get pods -n kube-system -l name=portworx -o wide
        break
    else
        echo "Waiting for portworx nodes to be ready. Current ready nodes: ${NUM_READY}"
    fi
    sleep 5
done
echo " Checking Portworx Status"
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status
sleep 5

#########################
echo "Installing GRAFANA"


kubectl -n kube-system create configmap grafana-dashboard-config --from-file=grafana-dashboard-config.yaml
sleep 5

kubectl -n kube-system create configmap grafana-source-config --from-file=grafana-datasource.yaml
sleep 5

curl "https://docs.portworx.com/samples/k8s/pxc/portworx-cluster-dashboard.json" -o portworx-cluster-dashboard.json && \
curl "https://docs.portworx.com/samples/k8s/pxc/portworx-node-dashboard.json" -o portworx-node-dashboard.json && \
curl "https://docs.portworx.com/samples/k8s/pxc/portworx-volume-dashboard.json" -o portworx-volume-dashboard.json && \
curl "https://docs.portworx.com/samples/k8s/pxc/portworx-performance-dashboard.json" -o portworx-performance-dashboard.json && \
curl "https://docs.portworx.com/samples/k8s/pxc/portworx-etcd-dashboard.json" -o portworx-etcd-dashboard.json && \
kubectl -n kube-system create configmap grafana-dashboards --from-file=portworx-cluster-dashboard.json --from-file=portworx-performance-dashboard.json --from-file=portworx-node-dashboard.json --from-file=portworx-volume-dashboard.json --from-file=portworx-etcd-dashboard.json
sleep 5

kubectl apply -f grafana.yaml

sleep 10

echo "Portworx Installation Complete!!!!"

echo " Step 6. Login to the FlashArray and verify the Cloud Volumes have been created - http://10.0.0.11"
echo " Step 7. Configure Grafana using default user: admin | password: admin - http://10.0.0.30:30196"
