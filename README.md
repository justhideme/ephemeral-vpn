# Ephemeral VPN

A portable installer for an ephemeral VPN server. Use once and throw away.

It's like a burner phone for your Internet connection. Come to think of it, "burner VPN" would have made a good name too.

[![Build Status](https://travis-ci.org/justhideme/ephemeral-vpn.svg)](https://travis-ci.org/justhideme/ephemeral-vpn)
[![Docker Stars](https://img.shields.io/docker/stars/justhideme/ephemeral-vpn.svg)](https://hub.docker.com/r/justhideme/ephemeral-vpn)
[![Docker Pulls](https://img.shields.io/docker/pulls/justhideme/ephemeral-vpn.svg)](https://hub.docker.com/r/justhideme/ephemeral-vpn)


#### Links

* [justhide.me](https://justhide.me)
* [GitHub](https://github.com/justhideme/ephemeral-vpn)
* [Docker Hub](https://hub.docker.com/r/justhideme/ephemeral-vpn)


#### Credits

* Inspired by [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn) 
* Which itself is based on [jpetazzo/dockvpn](https://github.com/jpetazzo/dockvpn)


## Instructions

1. Create a cloud VM (on [Vultr](https://vultr.com), [DigitalOcean](https://digitalocean.com), [OVH](https://ovh.com), [Atlantic.net](https://atlantic.net), etc... -- see below for those we've tested)

2. Run a bootstrap command (they all do the same thing):

  Fast:

  `curl -fs justhide.me | bash`
  
  \- or -

  Slightly paranoid:

  `curl -fs https://justhideme.github.io/bootstrap/run | bash`

  \- or -

  Super paranoid:

  `docker run -dit --name justhideme_vpn --cap-add=NET_ADMIN -p 1194:1194/udp justhidme/vpn:latest`

  `docker exec -it justhideme_vpn "/get_config.sh"`

3. Use the VPN, then destroy the cloud host


### How it works

1. Create a Linux cloud VM on the provider of your choice (see below for those we've tested).

2. `curl` is used to download a [boostrap script](https://github.com/justhideme/bootstrap/blob/master/run) which is then piped to `bash`

3. The bootstrap script ensures (Docker)[https://docker.com] is available, then does this:

  `docker run -dit --name ephemeral-vpn --cap-add=NET_ADMIN -p 1194:1194/udp -p 443:443 justhidme/ephemeral-vpn:latest`

  `docker exec -it ephemeral-vpn "/get_config.sh"`

  It also creates a "watchdog" process that will destroy the VPN Docker image when it exits. This helps ensure that sensitive files like logs and private keys are cleaned up.

4. The first `docker` command launches the image and runs its default command (`/run_vpn.sh`), which:

  - Creates a small PKI infrastructure including a CA, client, and server keys

  - Prepares the client configuration

  - Configures and starts [OpenVPN Community Edition](https://openvpn.net/index.php/open-source.html)

  - Removes the CA and server keys

5. The second docker command runs as a foreground process. This waits for the VPN to start up, and then asks how you want to retreive the client configuration file. There are two options.

  - It can display the config file, which you will need to copy and paste onto your client host.

  - It can start a webserver and provide a URL for you to download the config file from. If you select this option, it provides both the URL, as well as a [QR code](https://en.wikipedia.org/wiki/QR_code) you can scan with a phone/tablet. The webserver runs for two minutes and then shuts down.
      
6. To avoid the nicities of boostrapping and the various friendly messages, you can create the VPN and fetch the client config by simply running the following `docker` commands:

  `docker run -dit --name ephemeral-vpn --cap-add=NET_ADMIN -p 1194:1194/udp justhidme/vpn:latest`

  `docker exec -it ephemeral-vpn "cat /etc/openvpn/client.conf"`


### Details

* Full stack instances (host VM + VPN) can be created easily and destroyed at any time

* The bootstrap process takes a plain cloud VM and turns it into a VPN server in one command

* Everything runs in a single docker instance and no volumes are used

* The VPN process is intended to be single-user and can be run on an inexpensive cloud VM

* The entire stack is ephemeral; there is no permanent data storage at all

* The VM can be safely destroyed at any time (and _should_ be destroyed as soon as you're done with the VPN)


## Why run your own ephemeral VPN

* The JustHideMe process makes running a VPN server simple.

* You can use the hosting provider of your choice (see below for those we've tested).

* Unlike a hosted VPN, our process provides complete transparency.

* You know exactly what your server is doing and the encryption keys remain under your control at all times.

* No logs are recorded and you destroy the entire stack when you're done.


#### Pros

* Easy to use, completely secure

* The VPN itself is free

* Works perfectly on pennies-per-hour cloud hosting providers

* You don't pay for downtime if you create new instances when you need them and tear them down when you're done

* Portable between different providers

* You're not restricted to the known VPN provider IP pools 

* Completely transparent solution (JustHideMe is [FOSS](https://en.wikipedia.org/wiki/Free_and_open-source_software), [here's the code](https://github.com/justhideme))


#### Cons

* Is not "set it and forget it"

* You must re-download the client configuration every time

* Is a single-user system and does not consider scaling at all


#### How is this different from an OpenVPN one-click-app?

Some cloud providers (for example, [Vultr](https://www.vultr.com/apps/openvpn)) offer one-click OpenVPN installations. They're a great solution for some use-cases, and our offering is different in a few ways:

* JustHideMe may or may not be easier to set up (depends on the steps you want to take)

* JustHideMe is more transparent

* JustHideMe is portable between cloud providers


#### How is this different from [Kyle Manna's image](https://github.com/kylemanna/docker-openvpn)?

JustHideMe is inspired by, and to some degree an evolution of the work done by Kyle Manna on his OpenVPN image for Docker. It's a great solution for building persistent self-hosted VPNs, and if that's what you want then you should consider using it. Our offering is different in a few ways:

* JustHideMe is designed to be ephemeral. Think of it like a burner phone: you throw it out when you're done

* JustHideMe is meant for only one or two users/devices

* JustHideMe goes to great pains to keep your [PII](https://en.wikipedia.org/wiki/Personally_identifiable_information) from floating around

* JustHideMe is meant to be as simple as possible for less-tech-savvy folks who need an easy VPN


## VPN and Security Details

* The VPN uses `tun` mode, because it works on the widest range of devices

* The VPN uses UDP in the IP range `192.168.255.0/25` for clients (together with the default `net30` topology this means the VPN should support ~30 clients)

* The VPN will assign the OpenDNS resolvers to clients

* After establishing a connection, clients will route all traffic through the VPN

* Traffic is encrypted with AES128-CBC using SHA256 for message authentication because the combination is secure and performs well on the widest range of devices

* The control channel is encrypted with `TLS_DHE_RSA_WITH_AES_128_CBC_SHA256` (IANA 0x0067) because the cipher suite is secure and performs well on a wide range of devices

* The Docker container runs its own ephemeral Certificate Authority using a dynamic CA

* The entire ephemeral Certificate Authority is built in the Docker container at run time and the all private keys are deleted when the container stops running


## Tested On

#### Hosting providers

* :heart: [Vultr](https://vultr.com/?ref=7052201) VM with 512 MB RAM running Ubuntu 14.04

  \* *Recommended!* This is the provider we use. If you sign up with Vultr, please consider supporting this project by using our affiliate link [here](http://www.vultr.com/?ref=7062649-3B) or [here](http://www.vultr.com/?ref=7052201).

* :question: TODO: [Digital Ocean](https://digitalocean.com/) Droplet with 512 MB RAM running Ubuntu 14.04

* :question: TODO: [OVH](https://ovh.com) VPS 2016 SSD1 running Docker on Ubuntu 14.04 (Server 64bit)

* :question: TODO: [Atlantic.net](https://atlantic.net) General Purpose G2.1GB VM running Ubuntu 14.04 LTS + Docker


#### Clients

Virtually any modern VPN client should work with the JustHideMe setup. While it's fully secure, there's nothing particularly exotic about it. The following clients have been explicitly tested and verified to work.

* Android

  - :question: TODO: OpenVPN Connect

* iOS

  - 10.1

    - :thumbsup: OpenVPN Connect 1.0.7 (build 199)

* OS X

  - 10.11
  
    - :thumbsup: Tunnelblick 3.6.1 (build 4543.4551)

* Linux

  - :question: TODO

* Windows

  - :question: TODO

