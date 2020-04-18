# mongos.conf

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongos.log

# how the process runs
processManagement:
  fork: true  # fork and run in background
  pidFilePath: /var/run/mongodb/mongos.pid  # location of pidfile
  timeZoneInfo: /usr/share/zoneinfo

sharding:
  configDB: ${configReplSetName}/${configServerHosts}

net:
  port: ${port}
  bindIp: localhost,${hostname}

${mongos_conf}