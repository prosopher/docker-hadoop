#!/bin/bash

export K8S_LAUNCH_USER=xo
export K8S_JOB_NAME=c7-dnstest
export K8S_JOB_POSTFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 10 | head -n 1)
export K8S_JOB_COUNTS=8

IFS_BACKUP=$IFS
IFS_NL=$'\n'

# 00. service-domain
# do we need this block?

# 01a. launch job 01

export K8S_JOB_ID=$(sed 's/\$K8S_JOB_NAME/'"$K8S_JOB_NAME"'/g; s/\$K8S_JOB_POSTFIX/'"$K8S_JOB_POSTFIX"'/g;' job-centos7.yaml | kubectl apply -f - | cut -d' ' -f1 | sed "s/job.batch\///g")

# 01b. check job 01 status
for (( ; ; ))
do
  CHK_ALL_RUNNING=true
  K8S_PODS_LIST=$(kubectl get pods -o wide -l app=$K8S_JOB_ID | tail -n +2 | tr -s ' ')
  
  NUM_PODS=$(echo "$K8S_PODS_LIST" | wc -l)
  if [[ $NUM_PODS == "$K8S_JOB_COUNTS" ]]
  then true;
  else continue;
  fi

  IFS=$IFS_NL
  for K8S_POD_INST_ID in $K8S_PODS_LIST
  do
    CHK_POD_STATE=$(echo "$K8S_POD_INST_ID" | cut -d ' ' -f3 | tr '[:upper:]' '[:lower:]')
    if [[ $CHK_POD_STATE == "running" ]]
    then continue;
    else CHK_ALL_RUNNING=false;break;
    fi
  done
  IFS=$IFS_BACKUP
  
  if [[ $CHK_ALL_RUNNING == true ]]
  then echo "$K8S_PODS_LIST";break;
  else echo "CHK_ALL_RUNNING? $CHK_ALL_RUNNING";sleep 1;continue;
  fi
done

# 01c. set hostnames
K8S_JOB_PODS_HOSTS=$(kubectl get pods -o wide -l app=$K8S_JOB_ID | tail -n +2 | tr -s ' ' | cut -d' ' -f1,6)
IFS=$IFS_NL
for K8S_POD_INST_ID in $K8S_JOB_PODS_HOSTS
do
  K8S_POD_INST_TARGET=$(echo "$K8S_POD_INST_ID" | cut -d' ' -f1)
  K8S_PODS_HOSTSFILE=$(echo "$K8S_JOB_PODS_HOSTS" | awk '{print $2"\t"$1}')
  echo "working HOSTSFILE on $K8S_POD_INST_TARGET ..."
  
  kubectl exec -it $K8S_POD_INST_TARGET -- bash -c "cp /etc/hosts /etc/hosts.bkup;head -n -1 /etc/hosts.bkup >/etc/hosts;echo '$IFS_NL# MANUAL RESOLVE$IFS_NL$K8S_PODS_HOSTSFILE' >> /etc/hosts;cat /etc/hosts;"
  #kubectl exec -it $K8S_POD_INST_TARGET -- bash -c "cp /etc/hosts /etc/hosts.bkup;head -n -1 /etc/hosts.bkup >/etc/hosts;echo '$IFS_NL# MANUAL RESOLVE$IFS_NL$K8S_PODS_HOSTSFILE' >> /etc/hosts;"
done
IFS=$IFS_BACKUP

kubectl delete jobs $K8S_JOB_ID

#
# for jobid in $(kubectl get jobs | tail -n +2 | tr -s ' ' | cut -d' ' -f1);do kubectl delete jobs $jobid;done;