kubectl config get-contexts

export CTX_CLUSTER1=$(kubectl config view -o jsonpath='{.contexts[0].name}')
export CTX_CLUSTER2=$(kubectl config view -o jsonpath='{.contexts[1].name}')
echo "CTX_CLUSTER1 = ${CTX_CLUSTER1}, CTX_CLUSTER2 = ${CTX_CLUSTER2}"

kubectl create --context=$CTX_CLUSTER1 namespace foo
kubectl label --context=$CTX_CLUSTER1 namespace foo istio-injection=enabled
kubectl apply --context=$CTX_CLUSTER1 -n foo -f istio-1.7.4/samples/sleep/sleep.yaml

sleep 2

export SLEEP_POD=$(kubectl get --context=$CTX_CLUSTER1 -n foo pod -l app=sleep -o jsonpath={.items..metadata.name})

kubectl create --context=$CTX_CLUSTER2 namespace bar
kubectl label --context=$CTX_CLUSTER2 namespace bar istio-injection=enabled
kubectl apply --context=$CTX_CLUSTER2 -n bar -f istio-1.7.4/samples/httpbin/httpbin.yaml

sleep 4

export CLUSTER2_GW_ADDR=$(kubectl get --context=$CTX_CLUSTER2 svc --selector=app=istio-ingressgateway \
    -n istio-system -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

kubectl apply --context=$CTX_CLUSTER1 -n foo -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-bar
spec:
  hosts:
  # must be of form name.namespace.global
  - httpbin.bar.global
  # Treat remote cluster services as part of the service mesh
  # as all clusters in the service mesh share the same root of trust.
  location: MESH_INTERNAL
  ports:
  - name: http1
    number: 8000
    protocol: http
  resolution: DNS
  addresses:
  # the IP address to which httpbin.bar.global will resolve to
  # must be unique for each remote service, within a given cluster.
  # This address need not be routable. Traffic for this IP will be captured
  # by the sidecar and routed appropriately.
  - 240.0.0.2
  endpoints:
  # This is the routable address of the ingress gateway in cluster2 that
  # sits in front of sleep.foo service. Traffic from the sidecar will be
  # routed to this address.
  - address: ${CLUSTER2_GW_ADDR}
    ports:
      http1: 15443 # Do not change this port value
EOF


kubectl exec --context=$CTX_CLUSTER1 $SLEEP_POD -n foo -c sleep -- curl -I httpbin.bar.global:8000/headers

#kubectl apply --context=$CTX_CLUSTER1 -n foo -f istio-1.7.4/samples/httpbin/httpbin.yaml
#kubectl exec --context=$CTX_CLUSTER1 $SLEEP_POD -n foo -c sleep -- curl -I httpbin:8000/headers
#kubectl exec --context=$CTX_CLUSTER1 $SLEEP_POD -n foo -c sleep -- curl -I httpbin.foo.svc.cluster.local:8000/headers
#kubectl exec --context=$CTX_CLUSTER1 $SLEEP_POD -n foo -c sleep -- nslookup httpbin.bar.global
#kubectl exec -it $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage | grep -o "<title>.*</title>"

#CONTEXT="gke" ./istio-install.sh ; CONTEXT="onprem" ./istio-install.sh ; CONTEXT="gke" ./istio-coredns.sh ; CONTEXT="onprem" ./istio-coredns.sh

#istioctl x uninstall --purge -y --context=onprem ; istioctl x uninstall --purge -y --context=gke ; kubectl delete ns istio-system --context gke ; kubectl delete ns istio-system --context onprem ; kubectl delete ns hipster2 --context gke ; kubectl delete ns hipster1 --context onprem ; 

#CONTEXT="gke" ./istio-install.sh ; CONTEXT="gke1" ./istio-install.sh ; CONTEXT="gke" ./istio-coredns.sh ; CONTEXT="gke1" ./istio-coredns.sh

#istioctl x uninstall --purge -y --context=gke1 ; istioctl x uninstall -y --purge --context=gke ; kubectl delete ns istio-system --context gke ; kubectl delete ns istio-system --context gke1 ; kubectl delete --context=$CTX_CLUSTER1 ns foo ; kubectl delete --context=$CTX_CLUSTER2 ns bar

#kubectl delete --context=$CTX_CLUSTER1 ns foo ; kubectl delete --context=$CTX_CLUSTER2 ns bar
