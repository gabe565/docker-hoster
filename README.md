# Hoster

A simple "/etc/hosts" file injection tool to resolve names of local Docker containers on the host.

hoster is intended to run in a Docker container:

```sh
docker run -d \
    -v /var/run/docker.sock:/tmp/docker.sock \
    -v /etc/hosts:/tmp/hosts \
    gabe565/hoster
```

The `/tmp/docker.sock` is mounted to allow hoster to listen for Docker events and automatically register container's IP.

Hoster inserts into the host's `/etc/hosts` file an entry per running container and keeps the file updated with any started/stopped container.

## Container Registration

Hoster provides by default the entries `<container name>, <hostname>, <container id>` for each container and the aliases for each network. Containers are automatically registered when they start, and removed when they die.

For example, the following container would be available via DNS as `myname`, `myhostname`, `et54rfgt567` and `myserver.com`:

```sh
docker run --restart=unless-stopped -d \
    --name myname \
    --hostname myhostname \
    --network somenetwork \
    --network-alias "myserver.com" \
    mycontainer
```

If you need more features like **systemd integration** and **dns forwarding** please check [resolvable](https://hub.docker.com/r/mgood/resolvable/)

Any contribution is, of course, welcome. :)
