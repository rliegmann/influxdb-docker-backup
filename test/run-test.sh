#!/bin/bash
env_file=./.env.test


# Start InfluxDB Test Server
cat<< "EOF" 
  ____  _             _     _        __               _                   _                  
 / ___|| |_ __ _ _ __| |_  (_)_ __  / _|_ __ __ _ ___| |_ _ __ _   _  ___| |_ _   _ _ __ ___ 
 \___ \| __/ _` | '__| __| | | '_ \| |_| '__/ _` / __| __| '__| | | |/ __| __| | | | '__/ _ \
  ___) | || (_| | |  | |_  | | | | |  _| | | (_| \__ \ |_| |  | |_| | (__| |_| |_| | | |  __/
 |____/ \__\__,_|_|   \__| |_|_| |_|_| |_|  \__,_|___/\__|_|   \__,_|\___|\__|\__,_|_|  \___|
--------------------------------------------------------------------------------------------- 
EOF

docker compose -f ../compose-test.yml --env-file ${env_file} up source target -d
sleep 2

# Run Backup  (Standard by Glenn Chappell & Ian Chai)
cat<< "EOF"
 ____                ____             _                      
|  _ \ _   _ _ __   | __ )  __ _  ___| | ___   _ _ __        
| |_) | | | | '_ \  |  _ \ / _` |/ __| |/ / | | | '_ \       
|  _ <| |_| | | | | | |_) | (_| | (__|   <| |_| | |_) |      
|_| \_\\__,_|_| |_| |____/ \__,_|\___|_|\_\\__,_| .__/       
                                                 |_|          
---------------------------------------------------------
EOF

docker compose -f ../compose-test.yml --env-file $env_file up backup 
sleep 2


# Run Restore
cat<< "EOF"
  ____                ____           _                 
 |  _ \ _   _ _ __   |  _ \ ___  ___| |_ ___  _ __ ___ 
 | |_) | | | | '_ \  | |_) / _ \/ __| __/ _ \| '__/ _ \
 |  _ <| |_| | | | | |  _ <  __/\__ \ || (_) | | |  __/
 |_| \_\\__,_|_| |_| |_| \_\___||___/\__\___/|_|  \___|
 ------------------------------------------------------
EOF

docker compose -f ../compose-test.yml --env-file $env_file up restore 
sleep 2


timestamp=$(date +%s)

# Schreibe den Datensatz in die InfluxDB
#    influx write \
#        --bucket test_db \
#        --org myorg \
#        --token IFw21qBbYfD8scQcVH7R25uB47jjsgHochQQ0kOly1UAVIFruk8DIKPUplQWJa4C \
#        --host "http://192.168.178.20:1234" \
#        --precision s \
#        "test_data,metric=percent_value value=144 $timestamp"


cat<< "EOF"
   ____                                       ____        _        
  / ___|___  _ __ ___  _ __   __ _ _ __ ___  |  _ \  __ _| |_ __ _ 
 | |   / _ \| '_ ` _ \| '_ \ / _` | '__/ _ \ | | | |/ _` | __/ _` |
 | |__| (_) | | | | | | |_) | (_| | | |  __/ | |_| | (_| | || (_| |
  \____\___/|_| |_| |_| .__/ \__,_|_|  \___| |____/ \__,_|\__\__,_|
                      |_|
 ------------------------------------------------------------------
EOF


queryTime=$(date +%s)
queryTime=$(($queryTime-4000))
queryStopTime=$(($queryTime+10800))

# Schritt 3: Abfrage der Daten in der Quell-InfluxDB
echo "Abfrage der Daten aus der alten InfluxDB..."
OLD_DATA=$(influx query '
from(bucket: "test_db")
  |> range(start: '$queryTime', stop: '$queryStopTime')
  |> filter(fn: (r) => r._measurement == "test_data")
  |> filter(fn: (r) => r["_field"] == "value")' --org myorg --host http://192.168.178.20:1234 --token IFw21qBbYfD8scQcVH7R25uB47jjsgHochQQ0kOly1UAVIFruk8DIKPUplQWJa4C -r)

if [ $? -eq 0 ]; then
    echo "Daten erfolgreich aus der alten InfluxDB abgefragt."
else
    echo "Fehler bei der Abfrage der Daten aus der alten InfluxDB."
   
fi
sleep 2
echo $queryTime

# Schritt 4: Abfrage der Daten in der neuen InfluxDB
echo "Abfrage der Daten aus der neuen InfluxDB..."
NEW_DATA=$(influx query '
from(bucket: "test_db")
  |> range(start: '$queryTime', stop: '$queryStopTime')
  |> filter(fn: (r) => r._measurement == "test_data")
  |> filter(fn: (r) => r["_field"] == "value")' --org myorg --host http://192.168.178.20:1235 --token IFw21qBbYfD8scQcVH7R25uB47jjsgHochQQ0kOly1UAVIFruk8DIKPUplQWJa4C -r)

if [ $? -eq 0 ]; then
    echo "Daten erfolgreich aus der neuen InfluxDB abgefragt."
else
    echo "Fehler bei der Abfrage der Daten aus der neuen InfluxDB."
  
fi

testFailed = true

# Schritt 5: Vergleiche die Daten
echo "Vergleiche die Daten aus beiden Datenbanken..."
if [ "$OLD_DATA" == "$NEW_DATA" ]; then    
    echo "Daten aus alter InfluxDB:"
    echo "$OLD_DATA"
    echo "Daten aus neuer InfluxDB:"
    echo "$NEW_DATA"

    echo "Daten sind identisch!"
    testFailed=false
    
else    
    echo "Daten aus alter InfluxDB:"
    echo "$OLD_DATA"
    echo "Daten aus neuer InfluxDB:"
    echo "$NEW_DATA"

    echo "Daten unterscheiden sich!"
    testFailed=true
fi

docker compose -f ../compose-test.yml --env-file $env_file down source target backup restore -v

rm -Rf ./temp


if $testFailed; then
    echo Test failed
    exit 1
fi
echo Test successful
exit 0