#!/bin/bash

#
# Make the rings if they don't exist already
#

# These can be set with docker run -e VARIABLE=X at runtime
SWIFT_PART_POWER=${SWIFT_PART_POWER:-7}
SWIFT_PART_HOURS=${SWIFT_PART_HOURS:-1}
SWIFT_REPLICAS=${SWIFT_REPLICAS:-1}

if [ -e /srv/account.builder ]; then
	echo "Ring files already exist in /srv, copying them to /etc/swift..."
	cp /srv/*.builder /etc/swift/
	cp /srv/*.gz /etc/swift/
else
	echo "No existing ring files, creating them..."

	(
	cd /etc/swift

	# 2^& = 128 we are assuming just one drive
	# 1 replica only

	swift-ring-builder object.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
	swift-ring-builder object.builder add r1z1-127.0.0.1:6010/sdb1 1
	swift-ring-builder object.builder rebalance
	swift-ring-builder container.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
	swift-ring-builder container.builder add r1z1-127.0.0.1:6011/sdb1 1
	swift-ring-builder container.builder rebalance
	swift-ring-builder account.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
	swift-ring-builder account.builder add r1z1-127.0.0.1:6012/sdb1 1
	swift-ring-builder account.builder rebalance
	)

 	# Back these up for later use
 	echo "Copying ring files to /srv to save them if it's a docker volume..."
 	cp /etc/swift/*.gz /srv
 	cp /etc/swift/*.builder /srv
fi

# Ensure device exists
mkdir -p /srv/devices/sdb1

# Ensure that supervisord's log directory exists
mkdir -p /var/log/supervisor

# Ensure that files in /srv are owned by swift.
chown -R swift:swift /srv

keystone-manage db_sync
keystone-manage fernet_setup --keystone-user root --keystone-group root
touch /db-init

# Keystone bootstrap
# - Partially from Monasca : https://github.com/monasca/monasca-docker/tree/master/keystone
admin_username=${KEYSTONE_USERNAME:-"admin"}
admin_password=${KEYSTONE_PASSWORD:-"s3cr3t"}
admin_project=${KEYSTONE_PROJECT:-"admin"}
admin_role=${KEYSTONE_ROLE:-"admin"}
admin_service=${KEYSTONE_SERVICE:-"keystone"}
admin_region=${KEYSTONE_REGION:-"RegionOne"}

public_host=${PUBLIC_HOST:-"localhost"}

if [[ "$KEYSTONE_HOST" ]]; then
    admin_url="http://${KEYSTONE_HOST}:35357"
    public_url="http://${KEYSTONE_HOST}:5000"
    internal_url="http://${KEYSTONE_HOST}:5000"
else
    admin_url=${KEYSTONE_ADMIN_URL:-"http://localhost:35357"}
    public_url=${KEYSTONE_PUBLIC_URL:-"http://${public_host}:5000"}
    internal_url=${KEYSTONE_INTERNAL_URL:-"http://localhost:5000"}
fi

export OS_USERNAME=$admin_project
export OS_PASSWORD=$admin_password
export OS_PROJECT_NAME=$admin_project
export OS_AUTH_URL=$internal_url/v2.0/

echo "export OS_USERNAME=$OS_USERNAME" >> ~/.bashrc
echo "export OS_PASSWORD=$OS_PASSWORD" >> ~/.bashrc
echo "export OS_PROJECT_NAME=$OS_PROJECT_NAME" >> ~/.bashrc
echo "export OS_AUTH_URL=$OS_AUTH_URL" >> ~/.bashrc

echo "Creating bootstrap credentials..."
keystone-manage bootstrap \
    --bootstrap-password "$admin_password" \
    --bootstrap-username "$admin_username" \
    --bootstrap-project-name "$admin_project" \
    --bootstrap-role-name "$admin_role" \
    --bootstrap-service-name "$admin_service" \
    --bootstrap-region-id "$admin_region" \
    --bootstrap-admin-url "$admin_url" \
    --bootstrap-public-url "$public_url" \
    --bootstrap-internal-url "$internal_url"

# If you are going to put an ssl terminator in front of the proxy, then I believe
# the storage_url_scheme should be set to https. So if this var isn't empty, set
# the default storage url to https.
if [ ! -z "${SWIFT_STORAGE_URL_SCHEME}" ]; then
	echo "Setting default_storage_scheme to https in proxy-server.conf..."
	sed -i -e "s/storage_url_scheme = default/storage_url_scheme = https/g" /etc/swift/proxy-server.conf
	grep "storage_url_scheme" /etc/swift/proxy-server.conf
fi

# Start supervisord
echo "Starting supervisord..."
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

echo "Waiting for openstack to become available at $OS_AUTH_URL..."
success=false
for i in {1..10}; do
    if curl -sSf "$OS_AUTH_URL" > /dev/null; then
        echo "Openstack API is up, continuing..."
        success=true
        break
    else
        echo "Connection to openstack failed, attempt #$i of 10"
        sleep 1
    fi
done
if [[ "$success" = false ]]; then
    echo "Connection failed after max retries, preload may fail!"
    exit 1
fi
openstack service create --name swift object-store
sleep 1
openstack endpoint create \
    --publicurl "http://${public_host}:8080/v1/AUTH_\$(tenant_id)s" \
    --adminurl 'http://localhost:8080/' \
    --internalurl 'http://localhost:8080/v1/AUTH_$(tenant_id)s' \
    --region RegionOne swift

#
# Tail the log file for "docker log $CONTAINER_ID"
#

echo "Starting to tail /var/log/syslog...(hit ctrl-c if you are starting the container in a bash shell)"
exec tail -n 0 -F /var/log/syslog
