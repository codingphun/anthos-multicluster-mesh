# anthos-multicluster-mesh
The purpose of this repo is to demonstrate the capability to run a multicluster service mesh with multiple clusters. The install scripts will do the following

1. Creates a GCP GKE cluster and a kops cluster on GCE to simulate a self managed k8s cluster
1. Installs Istio in multicluster multi control plane mode and link the two clusters together
1. Connects both clusters to Anthos
1. Deploy a sample application spread across both clusters


### Configuration steps 
1. Only works and tested in GCP Cloud Shell.

1. In the GCP Cloud Shell terminal window, clone this repo
    ```
    $ git clone https://github.com/codingphun/anthos-multicluster-mesh.git

1. Go into the clone directory and run bootstrap script
    ```
    # change to the install directory
    $ cd ~/anthos-multicluster-mesh

    $ source ./boostrap.sh
    ```
1. Run Athos hub connection scripts
    ```
    $ source ./gke-connect-hub.sh
    $ source ./onprem-k8s-connect-hub.sh
    ```

1. Install Sample App
    ```
    $  ./hybrid-multicluster/istio-deploy-hipster.sh
    ```
    
    
