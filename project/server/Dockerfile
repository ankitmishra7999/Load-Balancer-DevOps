FROM mysql:8.0-debian

COPY deploy.sh /always-initdb.d/
COPY . /app
WORKDIR /app

RUN apt-get update
RUN apt-get install -y python3
RUN apt-get install -y python3-pip

RUN pip install --upgrade pip --break-system-packages
RUN pip install -r requirements.txt --break-system-packages
RUN chmod +x /app/custom-entry.sh

ENV USER=theuser
RUN adduser --home /home/$USER --disabled-password --gecos GECOS $USER \
  && chsh -s /bin/zsh $USER
RUN chown -R $USER /app

USER $USER
ENV HOME=/home/$USER
ENV MYSQL_ROOT_PASSWORD="mysql1234"

EXPOSE 5000

ENTRYPOINT ["/app/custom-entry.sh"]
# MySQL's defaults assume a dedicated host - unreasonable when two of
# these run alongside a load balancer, shard manager, Prometheus and
# Grafana on a single free-tier 1 GB RAM instance. This isn't a demo-only
# hack: uncapped, multiple replicas on this instance size can OOM the box
# hard enough to freeze sshd itself, observed while testing this exact
# setup on a t3.micro.
#   --innodb-buffer-pool-size=64M : default is 128M per instance; halved
#   --performance-schema=OFF      : its internal tables cost real memory
#                                    and aren't needed for this project
#   --max-connections=20          : default 151 - each reserves memory;
#                                    this app never needs more than a
#                                    handful of concurrent connections
#   --table-open-cache=64         : default 4000 - way oversized here
CMD ["mysqld", \
     "--innodb-buffer-pool-size=64M", \
     "--performance-schema=OFF", \
     "--max-connections=20", \
     "--table-open-cache=64"]