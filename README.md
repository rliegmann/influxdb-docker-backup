# influxdb-docker-backup

A Docker container that saves an full Influxdb (v2) in files and then compresses them. Several versions can be maintained.


# Usage
## Backup
```shell
    docker run \
        -e INFLUX_HOST=http://192.168.0.100:8086 \
        -e INFLUX_ADMIN_TOKEN=xxxxxxxxxxxxxxxxxxx \
        -e BACKUP_INTERVAL=1m \
        -v ./current/:/backups/current \
        -v ./archive/:/backups/archive \
        rliegmann/influxdb-to-file:latest
```







## Restore
```shell
    docker run \
        -e INFLUX_HOST=http://192.168.0.100:8086 \
        -e INFLUX_ADMIN_TOKEN=xxxxxxxxxxxxxxxxxxx \
        -e BACKUP_INTERVAL=1m \
        rliegmann/influxdb-to-file:latest \
        restore
```


# Environment Variables (Docker Mode)

| Variable                  | Description                                            | Example Usage                      | Required? | Default |
| ------------------------- |  ----------------------------------------------------- | ---------------------------------  | --------  | ------- |
| `INFLUX_HOST`             |             InfluxDB Host                              | `http://192.168.0.100:8086`        |    Yes    |         |
| `INFLUX_ADMIN_TOKEN`      |             InfluxDB Admin Token                       | `Mu8Z55OdwHdp9NTmJGNbXeCL7YOY5j46esTS4_6LVWQnRLA_<br>9GN8EQKTZjI-qM6p0bo7U_KUuqLR634ZLzDmDQ==` |    Yes    |      |
| `BACKUP_PATH`             | Location where the last backup is stored uncompressed. | `/backups/current/`                |    No     |         |
| `BACKUP_ARCHIVE_PATH`     | Location where the last n backup is stored compressed. | `/backups/archive`                 |    No     |         |
| `BACKUP_INTERVAL`         | Interval how often the script is executed.             | `1m` `30m` `1h` `12h` `1w` `03.30` |    No     |   `1h`  |
| `BACKUP_ARCHIVE_ROTATION` | How many compressed backups should be kept             | `5 `                               |    No     |   `10`  |
