FROM influxdb:alpine

ENV TZ="Europe/Berlin"

# Install system dependancies
RUN apk add --no-cache tini bash dcron htop strace && rm -rf /var/cache/apk/*

WORKDIR /app

COPY ./influxdb-to-file.sh ./influxdb-to-file
#COPY lib/ /app/lib

RUN chmod +x /app/influxdb-to-file
#RUN chmod +x /app/lib/loglib.sh

RUN mkdir /backups
RUN mkdir /backups/archive

RUN chmod -R 777 /backups
#RUN chmod -R 777 /usr/bin/influxdb-to-file

ENTRYPOINT ["/sbin/tini", "-g", "/app/influxdb-to-file" ]
CMD [ "startcron"]

