# mongod.conf

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# Where and how to store data.
storage:
  dbPath: /var/lib/mongo
  journal:
    enabled: true

# how the process runs
processManagement:
  fork: true  # fork and run in background
  pidFilePath: /var/run/mongodb/mongod.pid  # location of pidfile
  timeZoneInfo: /usr/share/zoneinfo

# network interfaces
net:
  port: ${port}
  bindIpAll: true

replication:
  replSetName: ${replSetName}
%{ if clusterRole != ""}
sharding:
  clusterRole: ${clusterRole}
%{ endif }

${mongod_conf}