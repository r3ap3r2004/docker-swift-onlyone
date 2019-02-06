FROM ubuntu:16.04
LABEL Author="beaukode <jeremie.colombo@gmail.com>"

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
        && apt-get install -y supervisor \
        swift python-swiftclient rsync \
        swift-proxy swift-object memcached python-keystone python-keystoneclient \
        python-swiftclient swift-plugin-s3 python-netifaces \
        python-xattr python-memcache \
        swift-account swift-container swift-object pwgen \
        rsyslog curl python-openstackclient keystone \
        uwsgi uwsgi-plugin-python \
        && rm -rf /var/lib/apt/lists/*

COPY files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Swift configuration
# - Partially fom http://docs.openstack.org/developer/swift/development_saio.html

COPY swift/ /etc/swift/
COPY files/rsyncd.conf /etc/rsyncd.conf
COPY files/startmain.sh /usr/local/bin/startmain.sh
RUN chmod 755 /usr/local/bin/*.sh

EXPOSE 8080 5000

CMD /usr/local/bin/startmain.sh
