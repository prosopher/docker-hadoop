#!/bin/bash

export K8S_LAUNCH_USER=xo
export K8S_JOB_NAME=hadoop-jobtest
export K8S_JOB_POSTFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)
export K8S_JOB_COUNTS=1
export K8S_JOB_APPGROUP="$K8S_JOB_NAME-$K8S_JOB_POSTFIX"
IFS_BACKUP=$IFS
IFS_NL=$'\n'

export HADOOP_ENV_YAML="01a-hadoop-env.yaml"
export NAMENODE_YAML="01b-namenode.yaml"
export RESOURCEMANAGER_YAML="01c-resourcemanager.yaml"
export DATANODEMANAGER_YAML="01d-dnm.yaml"
export HISTORYSERVER_YAML="01e-historyserver.yaml"

sed 's/\$K8S_JOB_NAME/'"$K8S_JOB_NAME"'/g; s/\$K8S_JOB_POSTFIX/'"$K8S_JOB_POSTFIX"'/g;' $HADOOP_ENV_YAML | kubectl apply -f -
sed 's/\$K8S_JOB_NAME/'"$K8S_JOB_NAME"'/g; s/\$K8S_JOB_POSTFIX/'"$K8S_JOB_POSTFIX"'/g;' $NAMENODE_YAML | kubectl apply -f -
sed 's/\$K8S_JOB_NAME/'"$K8S_JOB_NAME"'/g; s/\$K8S_JOB_POSTFIX/'"$K8S_JOB_POSTFIX"'/g;' $RESOURCEMANAGER_YAML | kubectl apply -f -
sed 's/\$K8S_JOB_NAME/'"$K8S_JOB_NAME"'/g; s/\$K8S_JOB_POSTFIX/'"$K8S_JOB_POSTFIX"'/g;' $DATANODEMANAGER_YAML | kubectl apply -f -
sed 's/\$K8S_JOB_NAME/'"$K8S_JOB_NAME"'/g; s/\$K8S_JOB_POSTFIX/'"$K8S_JOB_POSTFIX"'/g;' $HISTORYSERVER_YAML | kubectl apply -f -

# 00. service-domain
# do we need this block?

# 01a. launch job 01
#export K8S_JOB_ID=$(sed 's/\$K8S_JOB_NAME/'"$K8S_JOB_NAME"'/g; s/\$K8S_JOB_POSTFIX/'"$K8S_JOB_POSTFIX"'/g;' job-centos7.yaml | kubectl apply -f - | cut -d' ' -f1 | sed "s/job.batch\///g")
sleep 5;

# 01b. check job 01 status
for (( ; ; ))
do
  CHK_ALL_RUNNING=true
  K8S_PODS_LIST=$(kubectl get pods -o wide -l appgroup=$K8S_JOB_APPGROUP | tail -n +2 | tr -s ' ')
  
  #NUM_PODS=$(echo "$K8S_PODS_LIST" | wc -l)
  #if [[ $NUM_PODS == "$K8S_JOB_COUNTS" ]]
  #then true;
  #else continue;
  #fi

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
  then break;
  else echo "CHK_ALL_RUNNING? $CHK_ALL_RUNNING";sleep 1;continue;
  fi
done

# 01c. set hostnames
K8S_JOB_PODS_HOSTS=$(kubectl get pods -o wide -l appgroup=$K8S_JOB_APPGROUP | tail -n +2 | tr -s ' ' | cut -d' ' -f1,6)

IFS=$IFS_NL
for K8S_POD_INST_ID in $K8S_JOB_PODS_HOSTS
do
  K8S_POD_INST_TARGET=$(echo "$K8S_POD_INST_ID" | cut -d' ' -f1)
  K8S_PODS_HOSTSFILE=$(echo "$K8S_JOB_PODS_HOSTS" | gawk -v appgroup=$K8S_JOB_APPGROUP '{match($1,appgroup"-(.*)-(.*)",arr);print $2"\t"arr[1]"\t"$1;}')
  #echo "working HOSTSFILE on $K8S_POD_INST_TARGET ..."
  
  #kubectl exec -it $K8S_POD_INST_TARGET -- bash -c "cp /etc/hosts /etc/hosts.bkup;head -n -1 /etc/hosts.bkup >/etc/hosts;echo '$IFS_NL# MANUAL RESOLVE$IFS_NL$K8S_PODS_HOSTSFILE' >> /etc/hosts;cat /etc/hosts;"
  kubectl exec -it $K8S_POD_INST_TARGET -- bash -c "cp /etc/hosts /etc/hosts.bkup;head -n -1 /etc/hosts.bkup >/etc/hosts;echo '$IFS_NL# MANUAL RESOLVE$IFS_NL$K8S_PODS_HOSTSFILE' >> /etc/hosts;"
  #echo "----------"
  #echo 
done
IFS=$IFS_BACKUP

# kubectl delete configmap -l appgroup=$K8S_JOB_APPGROUP
# kubectl delete jobs -l appgroup=$K8S_JOB_APPGROUP

#
# for jobid in $(kubectl get jobs | tail -n +2 | tr -s ' ' | cut -d' ' -f1);do kubectl delete jobs $jobid;done;