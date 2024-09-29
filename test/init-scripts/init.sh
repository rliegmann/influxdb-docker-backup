#!/bin/bash

set -e

echo "**************************   Init Test Data BEGINN  **************************"

# Funktion, um den Status von InfluxDB zu überprüfen
wait_for_influxdb() {
    echo "Warte auf InfluxDB, bis sie vollständig bereit ist..."
    until influx ping --host "http://127.0.0.1:9999"  &> /dev/null; do
        echo "InfluxDB ist noch nicht bereit - warte 5 Sekunden..."
        sleep 5
    done
    echo "InfluxDB ist bereit!"
}


# Warte auf InfluxDB
wait_for_influxdb

# Anzahl der zu erstellenden Datensätze
num_records=100

# Aktueller Timestamp in Sekunden
#timestamp=$(date +%s)
timestamp=$(date -d "-1 hours" +"%s")
echo $timestamp
#timestamp=$((timestamp - 10000))


# Schleife, um 100 Datensätze zu erzeugen
for i in $(seq 1 $num_records); do
    # Generiere einen zufälligen Prozentwert zwischen 0 und 100
    #percent_value=$(shuf -i 0-100 -n 1)
    percent_value=$i

    # Schreibe den Datensatz in die InfluxDB
    influx write \
        --bucket "$DOCKER_INFLUXDB_INIT_BUCKET" \
        --org "$DOCKER_INFLUXDB_INIT_ORG" \
        --token "$DOCKER_INFLUXDB_INIT_ADMIN_TOKEN" \
        --host "http://127.0.0.1:9999" \
        --precision s \
        "test_data,metric=percent_value value=$percent_value $timestamp"
    echo 'Write Timestamp: ' $timestamp

    # Inkrementiere den Timestamp um 10 Sekunden (oder einen anderen Wert)
    timestamp=$((timestamp + 10))   

    # Optionaler Sleep, um den Prozess zu verlangsamen (falls gewünscht)
    #sleep 1
done

echo "Daten erfolgreich in die InfluxDB geschrieben!"




echo '**************************   Init Test Data END  ****************************'