TAG = justhideme/openvpn:latest

NOW = $(shell /bin/date '+%Y%m%d-%H%M')

.PHONY = build update push run sh websh vpnsh

build: Dockerfile update
	docker build -t $(TAG) .

update: Dockerfile
	sed -i '' -e 's/\(ENV updated\) .*/\1 $(NOW)/' Dockerfile

push: Dockerfile
	echo "not yet"

sh: build
	docker run -it --rm -v `pwd`/vpn.sh:/vpn.sh $(TAG) sh

run: build
	docker run -dit --name justhideme_vpn --cap-add=NET_ADMIN -p 1194:1194/udp -p 443:443 $(TAG)
	sleep 2
	docker exec -it justhideme_vpn "/web.sh"

websh: build
	docker run -it --rm -p 443:443 $(TAG)

vpnsh: build
	docker run -it --rm --cap-add=NET_ADMIN -p 1194:1194/udp $(TAG) sh
