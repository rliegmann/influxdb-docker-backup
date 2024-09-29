FROM influxdb:alpine

ENV TZ="Europe/Berlin"

# Install system dependancies
RUN apk add --no-cache tini bash dcron htop && rm -rf /var/cache/apk/*

COPY ./influxdb-to-file.sh /usr/bin/influxdb-to-file
RUN chmod +x /usr/bin/influxdb-to-file

RUN mkdir /backups
RUN mkdir /backups/archive

RUN chmod -R 777 /backups
RUN chmod -R 777 /usr/bin/influxdb-to-file

ENTRYPOINT ["/sbin/tini", "-g", "/usr/bin/influxdb-to-file" ]
CMD [ "startcron"]

