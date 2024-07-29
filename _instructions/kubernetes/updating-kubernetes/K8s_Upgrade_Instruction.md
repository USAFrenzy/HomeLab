
--------------------------------------------------------------------------------------------------------

# [ Switching Package Repositories Before Updating - Necessary For Every Minor Revision Change (Not Necessary For Patch Changes) ]

- Verify That The Community Packages Are Currently Being Used Before Continuing By Running:
  - ```pager /etc/apt/sources.list.d/kubernetes.list```

- Now, To Change The Target Version, Run The Following To Open The List Containing The Current Version Installed On The Cluster:
  - ```nano /etc/apt/sources.list.d/kubernetes.list```

- Change ```<kube_version>``` In The Line ```deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v<kube_version>/deb/ /```
To The Desired Target Version
  - For Example, If This Line Read ```deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29.6/deb/ /```
    - Change ```1.29.6``` To ```1.30.2```

- Save The File And Exit

- Now We Need To Update Our Package Repos. To Do This, Run:
  - ```sudo apt update && sudo apt upgrade -y```
- To Verify What Upgrade Paths Are Now Available, Run:
  - ```sudo apt-cache madison kubeadm | tac```

- Locate The Patch You Would Like To Update To And Use That For The Below Control Node(s) And Worker Node(s) Steps
  - For Example, ```1.30.2``` Would Be ```1.30.2-1.1``` In This Case

--------------------------------------------------------------------------------------------------------

# [ Control Node(s) ]

- To Update ```kubeadm``` Run The Following, Changing ```<kubeadm_version>``` To The Appropriate Version (Example: If 1.30.2 Was Selected Above, This Would Be 1.30.2-1.1):
  - ```apt-mark unhold kubeadm && \```
  - ```apt-get update && sudo apt-get install -y kubeadm=<kubeadm_version> && \```
  - ```apt-mark hold kubeadm```

- Run ```kubeadm upgrade plan``` To See What Will Be Updated

- To Apply The Update On The Cluster To The Desired Version, Run The Following Changing ```<kubeadm_version>``` To The Appropriate Version (Example: If 1.30.2 Was Selected Above, This Would Be 1.30.2-1.1):
- ```kubeadm upgrade apply <kubeadm_version>```

- To Cordon The Node And Evict Pods, Run The Following Changing ```<master_node>``` To Whatever Node Is Currently Being Targeted:
  - ```kubectl drain <master_node> --ignore-daemonsets --delete-emptydir-data```

- To Update Both ```kubelet``` And ```kubectl``` Run The Following, Changing Both ```<kubelet_version>``` And ```<kubectl_version>``` To The Appropriate Version (Example: If 1.30.2 Was Selected Above, This Would Be 1.30.2-1.1):
  - ```apt-mark unhold kubelet kubectl && \```
  - ```apt-get update && sudo apt-get install -y kubelet=<kubelet_version> kubectl=<kubectl_version> && \```
  - ```apt-mark hold kubelet kubectl```

- Then Reload The Daemons Running On The Node, Run:
  - ```systemctl daemon-reload```
- Then Restart The ```kubelet``` Service by Running:
  - ```systemctl restart kubelet```

- Finally, To Allow Pod Scheduling To Resume, Bring The Node Back Up By Running The Following, Changing ```<master_node>``` To Whatever Node Is Currently Being Targeted:
  - ```kubectl uncordon <master_node>```

- To Check And See If The Node Successfully Updated, Run:
  - ```kubectl get nodes```

- If There Other Control Nodes (HA For Example), Follow The Above Process For Each Node.
  - ```kubeadm upgrade plan``` Isn't Necessary For The Update Process, It Just Provides A Way To Verify What Will Be Automatically Updated In This Process And What May Need Extra Attention
  -  Additionally, It May Throw An Error Stating Version Conflicts Between Master Nodes If Run On Other Master Nodes While The Update Process Is Occurring - This Is Safe To Ignore And Proceed On

--------------------------------------------------------------------------------------------------------

# [ Worker Node(s) - Almost Identical To Master Node Update Process ]

- To Update ```kubeadm``` Run The Following, Changing ```<kubeadm_version>``` To The Appropriate Version (Example: If 1.30.2 Was Selected Above, This Would Be 1.30.2-1.1):
  - ```apt-mark unhold kubeadm && \```
  - ```apt-get update && sudo apt-get install -y kubeadm=<kubeadm_version> && \```
  - ```apt-mark hold kubeadm```

- For This Step, Go To A Master Node To Cordon The Node And Evict Pods By Running The Following Changing ```<worker_node>``` To Whatever Node Is Currently Being Targeted:
  - ```kubectl drain <worker_node> --ignore-daemonsets --delete-emptydir-data```

- Now Return Back To The Node Currently Being Updated And Run The Following, Changing Both ```<kubelet_version>``` And ```<kubectl_version>``` To The Appropriate Version (Example: If 1.30.2 Was Selected Above, This Would Be 1.30.2-1.1):
  - Run:
    - ```apt-mark unhold kubelet kubectl && \```
    - ```apt-get update && sudo apt-get install -y kubelet=<kubelet_version> kubectl=<kubectl_version> && \```
    - ```apt-mark hold kubelet kubectl```

- Then Reload The Daemons Running On The Node, Run:
  - ```systemctl daemon-reload```
- Then Restart The ```kubelet``` Service by Running:
  - ```systemctl restart kubelet```

- Now Return Back To A Control Node To Bring The Current Worker Node Back Up By Running The Following, Changing ```<worker_node>``` To Whatever Node Is Currently Being Targeted:
  - ```kubectl uncordon <worker_node>```

- To Check And See If The Node Successfully Updated, Run:
  - ```kubectl get nodes```

- If There Other Worker Nodes, Follow The Above Process For Each Node.

--------------------------------------------------------------------------------------------------------