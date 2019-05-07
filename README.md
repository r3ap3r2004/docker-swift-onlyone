**WARNING**: This container is suitable **only for devloppement and testing do not use in production** this is my first openstack (as server) project and it wasn't done with security or stability in mind.

# Docker OpenStack Swift onlyone

This is a docker file based on the Ubuntu 16.04 official docker image that creates an OpenStack Swift image which has only one replica and only one device. Why would this be useful? I think that Docker and OpenStack Swift go together like peas and carrots. Distributed files systems are a pain, so why not just use OpenStack Swift? Scaling is not as much of an issue with object storage. Many Docker containers, even on separate hosts, can use one OpenStack Swift container to persist files.

But then why only one replica and one device? I think that "onlyone" is a good starting point. It will make it easy for developers to get used to using object storage instead of a file system, and when they need the eventual consistency and multiple replicas provided by a larger OpenStack Swift cluster they can work on implementing that. I don't see one replica as an issue in small systems or for a proof-of-concept because it can just be backed up.

## startmain.sh

This Dockerfile uses [supervisord][] to manage the processes. The most idiomatic way to use docker is one container one service, but in this particular Dockerfile we will be starting several services in the container, such as rsyslog, memcached, and all the required OpenStack Swift daemons (of which there are quite a few). So in this case we're using Docker more as a role-based system, and the roles are both a Swift proxy and Swift storage, ie. a Swift "onlyone."" All of the required Swift services are running in this one container.

[supervisord]: http://supervisord.org/

## Usage

Default configuration **allow only localhost** access to swift.
If you need access from external container you need to **set environment variable PUBLIC_HOST** to this container hostname.

When swift service is ready this container open TCP 5001 port.
This is usefull to know when you can start running tests by waiting this port with dockerize for example.

```bash
dockerize -wait tcp://swift-onlyone:5001 -timeout 60s
```

Create a volume for Swift.

```bash
$ docker volume create swift_storage
```

Create the "onlyone" container. 

```bash
$ docker run -d --rm --name swift-onlyone -p 8080:8080 -p 5000:5000 -v swift_storage:/srv -t beaukode/docker-swift-onlyone-authv2-keystone
```

With that container running we can now check the logs.

```bash
$ docker logs swift-onlyone
```

At this point OpenStack Swift is running.

```bash
$ docker ps
CONTAINER ID        IMAGE                                           COMMAND                  CREATED             STATUS              PORTS                                            NAMES
5d67fd3dd72b        beaukode/docker-swift-onlyone-authv2-keystone   "/bin/sh -c /usr/loc…"   3 seconds ago       Up 2 seconds        0.0.0.0:5000->5000/tcp, 0.0.0.0:8080->8080/tcp   swift-onlyone
```

We can now use the Swift python client to access Swift using the Docker forwarded port, in this example port 8080.

```bash
$ swift -A http://127.0.0.1:5000/v2.0 --os-username admin --os-password s3cr3t --os-tenant-name admin stat
        Account: AUTH_bdc0f7b92bdb4545ba9742d9b81fd29c
     Containers: 0
        Objects: 0
          Bytes: 0
   Content-Type: text/plain; charset=utf-8
    X-Timestamp: 1549462858.74897
X-Put-Timestamp: 1549462858.74897
     X-Trans-Id: tx141a2866e0564cc6a8526-005c5aed4a
```

If you want to add a storage container on start-up, just define an enviroment variable `SWIFT_DEFAULT_CONTAINER` with a name of required container.

```bash
$ docker run -d --name swift-onlyone -p 8080:8080 -p 5000:5000 -e SWIFT_DEFAULT_CONTAINER=user_uploads -v swift_storage:/srv -t beaukode/docker-swift-onlyone-authv2-keystone
```

Try uploading a file:

```bash
$ swift -A http://127.0.0.1:5000/v2.0 --os-username admin --os-password s3cr3t --os-tenant-name admin upload --object-name mypdf.pdf user_uploads ./mypdf.pdf
```

Try downloading a file:

```bash
$ swift -A http://127.0.0.1:5000/v2.0 --os-username admin --os-password s3cr3t --os-tenant-name admin download user_uploads mypdf.pdf
```

That's it!

## Todo

* Test and fix usage of env vars KEYSTONE_* + SWIFT_DEFAULT_CONTAINER. May don't work anymore since fork
* Update to ubuntu 18.04

Any fix or features are welcome, please open a pull request
