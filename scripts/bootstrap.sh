#!/usr/bin/env bash

wait_for_network() {
  echo "Waiting for network service..."

  local count=0
  while true; do
    local net_up=$(systemctl list-units --type service | grep network.service | grep active | wc -l)

    [ $net_up -eq 1 ] && break
    if [ $count -ge 60 ]; then
      echo "ERROR: network not started"
      exit 1
    fi
    count=$((count+1))
    sleep 5
  done
}

# usage - hosts
wait_for_dns() {
  local count=0
  local hostname=""

  for hostname in $@
  do
    if [ "$hostname" == "local" ]; then
      hostname=$(hostname)
    fi
    echo "Waiting for DNS resolution of $hostname..."

    while true; do
      local records=$(host -t a $hostname | grep "has address" | wc -l)

      [ $records -gt 0 ] && break
      if [ $count -ge 60 ]; then
        echo "ERROR: Could not resolve DNS entry for $hostname"
        exit 1
      fi
      count=$((count+1))
      sleep 5
    done
  done
}

# usage <host:port>
wait_for_mongo() {
  local count=0

  for node in $@
  do
    echo "Waiting for node $node"
    while true; do
      mongo $node --eval 'rs.isMaster()' >/dev/null
      [ $? -eq 0 ] && break
      if [ $count -eq 60 ]; then
        echo "ERROR: Could not connect to MongoDB at $node"
        exit 1
      fi
      count=$((count+1))
      sleep 5
    done
  done

}

# usage <router_uri> <rs_name> <rs_hosts_csv> <shard_name>
add_shard() {
  wait_for_mongo $1

  echo "Adding shard to cluster"

  res=`mongo "$1" --quiet --eval "JSON.stringify(db.getSiblingDB(\"admin\").runCommand( { addShard: \"$2/$3\", name: \"$4\" }))" | tail -n 1`
  local ok=`echo $res | jq '.ok // 0'`

  if [ $ok -eq 0 ]; then
    echo "ERROR: failed to add shard to cluster: $res"
    exit 1
  fi

}

# usage <host:port> <rs cfg>
initiate_replica_set() {
  wait_for_mongo $(echo $2 | jq -r '[.members | .[] | .host] | join(" ")')

  echo "Initializing replica set"

  # try to initiate the replica set
  local res=`mongo "$1" --quiet --eval "JSON.stringify(rs.initiate($2))" | tail -n 1`
  local ok=`echo $res | jq '.ok // 0'`

  if [ $ok -eq 0 ]; then
    code=`echo $res | jq '.code // -1'`

    # if the replicaset is already initiated, try reconfiguring
    if [ $code -eq 23 ]; then
      echo "Replica set is already initialized!"
      reconfigure_replica_set $@
    else
      msg=`echo $res | jq '{ ok: .ok, code: .code, errmsg: .errmsg}'`
      echo "ERROR: failed to initiate replica set: $msg"
      exit 1
    fi
  fi
}

# usage <host:port> <rs cfg>
reconfigure_replica_set() {
  echo "Reconfiguring replica set"

  # tail -n1 is a hack to workaround SERVER-27159 and just get the latest line
  local st=`mongo "$1" --quiet --eval 'JSON.stringify(rs.status())' | tail -n 1`
  local primary=`echo $st | jq -r '.members | map(select( .state == 1)) | .[0].name // "-1"'`
  local res=""
  if [ "$primary" == "-1" ]; then
    res=`mongo "$1" --quiet --eval "JSON.stringify(rs.reconfig($2, {force:true}))" | tail -n 1`
  else
    res=`mongo "$primary" --quiet --eval "JSON.stringify(rs.reconfig($2))" | tail -n 1`
  fi

  local ok=`echo $res | jq '.ok // 0'`
  if [ $ok -eq 0 ]; then
    msg=`echo $res | jq '{ ok: .ok, code: .code, errmsg: .errmsg}'`
    echo "ERROR: failed to reconfigure replica set: $msg"
    exit 1
  fi
}

# -------------------------------------------------------------------------------------------------------------------------------------
#                                                    CLI
# -------------------------------------------------------------------------------------------------------------------------------------

wait() {
  case "$1" in
    mongo)
      shift
      wait_for_mongo $@
      ;;
    dns)
      shift
      wait_for_dns $@
      ;;
    network)
      shift
      wait_for_network
      ;;
    *)
      wait_help
      ;;
  esac
}

wait_help() {
  cli_name=${0##*/}
  echo "
MongoDB bootstrap CLI
Usage: $cli_name wait [command]
Commands:
  mongo     Wait for mongo connection
  dns       Wait for DNS resolution
  network   Wait for active network service
  *         Help
"
  exit 1
}

cli_help() {
  cli_name=${0##*/}
  echo "
MongoDB bootstrap CLI
Usage: $cli_name [command]
Commands:
  wait        Wait
  initiate    Initiate replica set
  add_shard   Add shard to cluster
  null        Do nothing
  *           Help
"
  exit 1
}

case "$1" in
  wait)
    shift
    wait $@
    ;;
  initiate)
    shift
    initiate_replica_set $@
    ;;
  add_shard)
    shift
    add_shard $@
    ;;
  null)
    exit 0
    ;;
  *)
    cli_help
    ;;
esac