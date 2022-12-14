#!/bin/bash

source ./init_db.sh

echo "started"
TOKEN_PATH=/var/run/secrets/kubernetes.io/serviceaccount
CACERT=${TOKEN_PATH}/ca.crt
DB2_NAMESPACE="db2"
CP4BA_NAMESPACE="cp4ba"

echo "configuring db2"

# set +e so the job executes without failing and doesnt hold up future sync waves
set +e 

# fetches instancepassword secret and returns base64 encoded password
function fetch_db2_password {
    local DB2_SECRET=$(oc get secrets -n $DB2_NAMESPACE  | grep instancepassword | awk '{print $1}')
    echo "found secret $DB2_SECRET"
    DB2_PASSWORD=$(oc get secret -n $DB2_NAMESPACE $DB2_SECRET -o jsonpath='{..password}')
}

# patch value of secret when given secret name, key and new value
function patch_secret {
    local SECRET=$1
    local KEY=$2
    local NEW_VALUE=$3

    echo "patching secret: $SECRET key:$KEY"
    oc patch secret -n $CP4BA_NAMESPACE $SECRET --type='json' -p="[{\"op\": \"replace\", \"path\": \"$KEY\", \"value\":\"$NEW_VALUE\"}]"
}


function update_secrets {
    echo "fetching db2 instance password from db2 project: $DB2_NAMESPACE"
    fetch_db2_password
    echo "starting secret patch in namespace: $CP4BA_NAMESPACE"
    patch_secret ibm-fncm-secret /data/gcdDBPassword $DB2_PASSWORD
    patch_secret ibm-fncm-secret /data/os1DBPassword $DB2_PASSWORD
    patch_secret ibm-fncm-secret /data/os2DBPassword $DB2_PASSWORD
    patch_secret ibm-ban-secret /data/navigatorDBPassword $DB2_PASSWORD
    patch_secret ibm-dba-ums-secret /data/oauthDBPassword $DB2_PASSWORD
    patch_secret ibm-dba-ums-secret /data/tsDBPassword $DB2_PASSWORD
    echo "complete!"
}

function seed_databases {
    echo $execstr > /tmp/commands

    echo "Listing current databases on pod $DB2_POD_NAME" && echo
    oc exec $DB2_POD_NAME -c db2u -- su - db2inst1 -c "db2 list database directory"

    echo "Starting database creation on pod $DB2_POD_NAME" && echo
    oc cp $DB2_COMMANDS $DB2_POD_NAME:$DB2_COMMANDS -c db2u
    oc exec $DB2_POD_NAME -it -c db2u -- chmod +rwx $DB2_COMMANDS
    oc exec $DB2_POD_NAME -it -c db2u -- su - db2inst1 -c "nohup $DB2_COMMANDS &"

    echo "Database setup in progress" && echo
    echo "To list the databases, run:"
    echo "oc exec $DB2_POD_NAME -c db2u -- su - db2inst1 -c \"db2 list database directory\""

}

function create_users {
    # users we need to configure initially: gcd, fpos, ros, icndb, os1, 
  if [ -z "$USER_LIST" ]
  then 
    echo "user list empty" 
    # we can leave it up to people to provide no user list if they have precreated users. If we want to ensure a user list is provided we can exit 1
  else 
    # The secret universal-password is already created at this stage. This job has a sync wave of 282 and the secret is at wave 250.
    UNIVERSAL_PASSWORD=$(oc get secret universal-password -n $CP4BA_NAMESPACE -o jsonpath='{.data.universalPassword}' | base64 --decode) 
    DB2_LDAP_POD_NAME=$(oc get pod -l role=ldap -ojsonpath='{.items[0].metadata.name}')

    # We can pass in a list of separated users as an env variable. 
    echo $USER_LIST
    for user in ${USER_LIST//,/ }
    do 
      echo " creating $user in $DB2_LDAP_POD_NAME" 
      USER=$(oc exec $DB2_LDAP_POD_NAME -it -c ldap -- /opt/ibm/ldap_scripts/addLdapUser.py -u $user -p $UNIVERSAL_PASSWORD -r user)
    done
  fi
    # Could also follow a similar pattern to configuring db2 but use a different flag (i.e. -u), write all commands to a file or variable, exec once then execute. completely up to you. 
}
create_users
while getopts ":i:" opt; do
  case $opt in
    i)
      set -f; IFS=','
      argv=($2)
      argc=${#argv[@]}
      echo "Total Number of databases to initialise = $argc" >&2
      echo -n "Requested databases: "
      for i in "${argv[@]}"; do
        echo -n "$i "
      done
      echo ""

      oc_token=$(cat ${TOKEN_PATH}/token)
      oc_server='https://kubernetes.default.svc'
      oc login $oc_server --token=${oc_token} --certificate-authority=${CACERT} --kubeconfig="/tmp/config"

      echo "setting project to $DB2_NAMESPACE" && echo
      oc project $DB2_NAMESPACE

      echo "Identifying DB2 pod" && echo
      DB2_POD_NAME=$(oc get pod -l role=db -ojsonpath='{.items[0].metadata.name}')

      DB2_COMMANDS="/tmp/commands"
      
      # echo "Updating secrets" (This may not be required after all - remove after testing)
      # update_secrets 

      execstr=$(init_CP4BA_db);
      echo "Executing create DB commands for $i: ";
      echo $execstr;
      seed_databases

      echo "Wait till CP4BA DB up and running.."
      sleep 800

      for i in "${argv[@]}"; do
        if [[ $supported_databases =~ (^|[[:space:]])$i($|[[:space:]]) ]];  then
          # spit create db commands to stdout and capture them into a variable
          execstr=$(init_${i}_db);
          echo "Executing create DB commands for $i: ";
          echo $execstr;
          seed_databases
        else
          echo "Initialisation of database $i is not yet supported"
        fi
      done

      # filesystem cleanup
      # rm -f /tmp/commands
      # oc exec $DB2_POD_NAME -c db2u rm -f DB2_COMMANDS
      echo "Completed dbs configuration"
      
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
