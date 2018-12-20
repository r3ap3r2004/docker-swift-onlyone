# Docker OpenStack Swift onlyone

This is a docker file that creates an OpenStack Swift image which has only one replica and only one device. Why would this be useful? I think that Docker and OpenStack Swift go together like peas and carrots. Distributed files systems are a pain, so why not just use OpenStack Swift? Scaling is not as much of an issue with object storage. Many Docker containers, even on separate hosts, can use one OpenStack Swift container to persist files.

But then why only one replica and one device? I think that "onlyone" is a good starting point. It will make it easy for developers to get used to using object storage instead of a file system, and when they need the eventual consistency and multiple replicas provided by a larger OpenStack Swift cluster they can work on implementing that. I don't see one replica as an issue in small systems or for a proof-of-concept because it can just be backed up.

## startmain.sh

This Dockerfile uses [supervisord][] to manage the processes. The most idiomatic way to use docker is one container one service, but in this particular Dockerfile we will be starting several services in the container, such as rsyslog, memcached, and all the required OpenStack Swift daemons (of which there are quite a few). So in this case we're using Docker more as a role-based system, and the roles are both a Swift proxy and Swift storage, ie. a Swift "onlyone."" All of the required Swift services are running in this one container.

[supervisord]: http://supervisord.org/

## Usage

Create a volume for Swift.

```bash
$ docker volume create swift_storage
```

Create the "onlyone" container. 

```bash
$ docker run -d --name swift-onlyone -p 12345:8080 -v swift_storage:/srv -t fnndsc/docker-swift-onlyone
```

With that container running we can now check the logs.

```bash
$ docker logs swift-onlyone
```

At this point OpenStack Swift is running.

```bash
$ docker ps
CONTAINER ID        IMAGE                                     COMMAND                  CREATED             STATUS              PORTS                     NAMES
751d3b5b4575        fnndsc/docker-swift-onlyone               "/bin/sh -c /usr/loc…"   11 seconds ago      Up 10 seconds       0.0.0.0:12345->8080/tcp   swift-onlyone
```

We can now use the Swift python client to access Swift using the Docker forwarded port, in this example port 12345.

```bash
$ swift -A http://127.0.0.1:12345/auth/v1.0 -U chris:chris1234 -K testing stat
       Account: AUTH_chris
    Containers: 0
       Objects: 0
         Bytes: 0
  Content-Type: text/plain; charset=utf-8
   X-Timestamp: 1402463864.77057
    X-Trans-Id: tx4e7861ebab8244c09dad9-005397e678
X-Put-Timestamp: 1402463864.77057
```

If you want to add a storage container on start-up, just define an enviroment variable `SWIFT_DEFAULT_CONTAINER` with a name of required container.

```bash
$ docker run -d --name swift-onlyone -p 12345:8080 -e SWIFT_DEFAULT_CONTAINER=user_uploads -v swift_storage:/srv -t fnndsc/docker-swift-onlyone
```

If you want to allow temporary download url generation, just define an enviroment variable `SWIFT_TEMP_URL_KEY` with a secret key.

```bash
$ docker run -d --name swift-onlyone -p 12345:8080 -e SWIFT_TEMP_URL_KEY=my_secret_key -v swift_storage:/srv -t fnndsc/docker-swift-onlyone 
```

Try uploading a file:

```bash
$ swift -A http://127.0.0.1:12345/auth/v1.0 -U chris:chris1234 -K testing upload --object-name mypdf.pdf user_uploads ./anypdf.pdf
```

Try downloading a file:

```bash
$ swift -A http://127.0.0.1:12345/auth/v1.0 -U chris:chris1234 -K testing download user_uploads mypdf.pdf
```

That's it!

## Todo

* It seems supervisord running as root in the container, a better way to do this?
