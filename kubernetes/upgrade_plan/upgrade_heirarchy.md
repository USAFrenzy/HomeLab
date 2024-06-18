<h1 align=center> Upgrading Hierarchy <br>
<h4><p align=center>NOTE: <br>
                    This file is being written due to a lesson learned when initializing a k3s cluster with v1.29 while rancher only supported 1.28 at the time. <br>
                    The k3s cluster's sole purpose at this moment was to separate the responsibilities of the main cluster with future multi-cluster environments<br>
                    by utilizing Rancher for administration of services among those clusters. Therefore there's a strict requirement to follow Rancher's versioning <br>
                    support<br>
    </p>
</h4>
<h1>

<br>

## Current Kubernetes Cluster Version:
### - k8s cluster: ```1.30.2``` ---> EOL: ```28JUN2025```
### - k3s cluster: ```v1.28.10+k3s1 (v1.28.10)```

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

<br>


<h1 align=center> NOTE: Before Any Upgrades Take Place, Make Backups Of VMs Hosting The Clusters And Cluster Storage </h3>

<br>

## Kubernetes Version Upgrade

### Before Upgrading Kubernetes Version On Cluster, Refer To The Following Charts For Versioning Support Of Version-Dependent Services:
- [rancher support matrix](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-8-4/)
- [cert-manager support matrix](https://cert-manager.io/docs/releases/#kubernetes-supported-versions)


## Charts And Deployments Upgrade

### - cert-manager via helm
- Current Version: ```v1.15```
- Current Kubernetes Support: ```v1.30```
- Version EOL: ```Release of 1.17```
- Steps To Update:
  - [place_holder]

### - rancher:
- Current Version: ```v2.8.5```
- Current Kubernetes Support: ```1.28.10 (default)```
- Current Downstream Kubernetes Version Certified: ```v1.28```
- Current Longhorn Version Supported: ```v1.5.4```
- Steps To Update:
  -  Check The [Github Releases](https://github.com/rancher/rancher/releases) Page For Any Specific Instructions