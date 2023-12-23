# cp4ba-utilities


## PVC Lost state

https://stackoverflow.com/questions/69331594/is-it-possible-to-recover-the-kubernetes-lost-state-pvc

remove 

"annotations": {
   "pv.kubernetes.io/bind-completed": "yes"
},