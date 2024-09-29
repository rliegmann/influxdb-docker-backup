#!/bin/bash

set -e
# Check to see what environment I'm running in 
if [ -f /.dockerenv ]; then
    echo "Script runs in Docker environment";
    export BACKUP_PATH=${BACKUP_PATH:-/backups/current/}
    export BACKUP_ARCHIVE_PATH=${BACKUP_ARCHIVE_PATH:-/backups/archive}

    : ${INFLUX_ADMIN_TOKEN:?"INFLUX_ADMIN_TOKEN env variable is required"}
    : ${INFLUX_HOST:?"INFLUX_HOST env variable is required"}
else
    echo "Script runs in real world!";

    # Check missing environment vars
    : ${BACKUP_PATH:?"BACKUP_PATH env variable is required"}
    : ${BACKUP_ARCHIVE_PATH:?"BACKUP_ARCHIVE_PATH env variable is required"}
fi


 export BACKUP_ARCHIVE_ROTATION=${BACKUP_ARCHIVE_ROTATION:-10}
 export BACKUP_INTERVAL=${BACKUP_INTERVAL:-1h}


  # Funktion, die auf SIGTERM reagiert
cleanup() {
    echo "SIGTERM empfangen, das Skript wird beendet."
    # Hier kannst du Aufräumarbeiten durchführen
    exit 0
}

# Signal-Handler für SIGTERM einrichten
trap cleanup SIGTERM

# Add this script to the crontab and start crond
startcron() {
  cron_time=$1

  # Überprüfe das Zeitformat und wandle es in ein Crontab-Format um
  case "$cron_time" in
    *m)
      minutes=$(echo $cron_time | sed 's/m//')
      cron_format="*/$minutes * * * *"
      ;;
    *h)
      hours=$(echo $cron_time | sed 's/h//')
      cron_format="0 */$hours * * *"
      ;;
    *d)
      days=$(echo $cron_time | sed 's/d//')
      cron_format="0 0 */$days * *"
      ;;
    *w)
      weeks=$(echo $cron_time | sed 's/w//')
      cron_format="0 0 * * $((weeks % 7))"
      ;;
    *M)
      months=$(echo $cron_time | sed 's/M//')
      cron_format="0 0 1 */$months *"
      ;;
    *y)
      years=$(echo $cron_time | sed 's/y//')
      cron_format="0 0 1 1 */$years"
      ;;
    [0-9][0-9]:[0-9][0-9])
      # Bestimmte Uhrzeit im Format HH:MM
      hours=$(echo $cron_time | cut -d':' -f1)
      minutes=$(echo $cron_time | cut -d':' -f2)
      cron_format="$minutes $hours * * *"
      ;;
    *)
      echo "Ungültiges Zeitformat. Beispiele: '10m', '2h', '1d', '1w', '1M', '1y', '00:00'."
      exit 1
      ;;
  esac


  # Cron-Job Eintrag vorbereiten
  cron_job="$cron_format $0 backup >> /var/log/influxdb-to-file.log 2>&1"

  # Überprüfen, ob der Cron-Job bereits existiert und ggf. hinzufügen
  (crontab -l 2>/dev/null | grep -qF "$cron_job") || (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

  echo "Das Skript wurde als Cron-Job hinzugefügt: $cron_time."

  touch /var/log/influxdb-to-file.log
  
  crond start &&  tail -f  /var/log/influxdb-to-file.log
}

# Dump the database to a file and push it to S3
backup() {
  echo '******************** Backup *************************************'
  
  # Dump database to directory
  echo "Backing up to $BACKUP_PATH"
 
  if [ -d $BACKUP_PATH ]; then
    rm -rf ${BACKUP_PATH}/*
  fi
 
 
  influx backup  --host $INFLUX_HOST $BACKUP_PATH -t $INFLUX_ADMIN_TOKEN
  if [ $? -ne 0 ]; then
    echo "Failed to backup --host $DATABASE to $BACKUP_PATH"
    exit 1
  fi
 

  # --------------------------------------------
  # Suche nach der .manifest-Datei im Ordner
  manifest_file=$(find "$BACKUP_PATH" -maxdepth 1 -name "*.manifest")

  # Überprüfen, ob die Datei existiert
  if [[ -f "$manifest_file" ]]; then
      # Extrahiere den Dateinamen ohne den Pfad
      filename=$(basename "$manifest_file")
      
      # Überprüfen, ob der Dateiname das Zeitstempelmuster enthält
      if [[ $filename =~ ([0-9]{8}T[0-9]{6}Z) ]]; then
          timestamp="${BASH_REMATCH[1]}"

          echo "Dateiname: $filename"
          echo "Extrahierter Zeitstempel: $timestamp"
      else
          echo "Kein gültiger Zeitstempel im Dateinamen: $filename"
      fi
  else
      echo "Keine .manifest-Datei im Ordner gefunden."
  fi


  # -----------------  Compress   -----------------  
  echo '******************** Compress ***********************************'
  tar -cvzf ${BACKUP_ARCHIVE_PATH}/${timestamp}.tar $BACKUP_PATH   


  # -----------------  Cleaning Up  -----------------  
  echo '******************** Cleanup ************************************'
  cd "$BACKUP_ARCHIVE_PATH" || exit
  files=()

  # Durchlaufe alle Dateien im Ordner und extrahiere die Timestamps
  for file in *; do
      if [[ $file =~ ([0-9]{8}T[0-9]{6}Z) ]]; then
          timestamp="${BASH_REMATCH[1]}"
          files+=("$timestamp:$file")  # Füge Timestamp und Dateiname im Format "timestamp:filename" hinzu
      fi
  done

  # Sortiere die Dateien nach Timestamp
  IFS=$'\n' sorted_files=($(sort <<<"${files[*]}"))

  # Berechne die Anzahl der zu behaltenden Dateien
  num_files=${#sorted_files[@]}
  files_to_keep=$((num_files - $BACKUP_ARCHIVE_ROTATION))  # Hier wird die Berechnung sichergestellt

  # Lösche die älteren Dateien, wenn es mehr als 10 gibt
  if [ "$files_to_keep" -gt 0 ]; then
      for ((i=0; i<files_to_keep; i++)); do
          file_to_delete="${sorted_files[i]#*:}"  # Extrahiere den Dateinamen
          rm "$file_to_delete"
          echo "Deleted: $file_to_delete"
      done
  fi

  echo "Cleanup completed. The last 10 files remain."
  echo "Done"
}

# Pull down the latest backup from S3 and restore it to the database
restore() {  

  # Restore database from backup file
  echo "Running restore"  

  if influx restore  --host $INFLUX_HOST --t $INFLUX_ADMIN_TOKEN $BACKUP_PATH --full ; then
    echo "Successfully restored"
  else
    echo "Restore failed"
    exit 1
  fi
  echo "Done"
  exit 0

}

# Handle command line arguments
case "$1" in
  "startcron")
    #startcron "$CRON"
    startcron $BACKUP_INTERVAL
    ;;
  "backup")
    backup
    ;;
  "restore")
    restore
    ;;
  *)
    echo "Invalid command '$@'"
    echo "Usage: $0 {backup|restore|startcron}"
esac