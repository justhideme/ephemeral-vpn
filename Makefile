TAG = justhideme/openvpn:latest

CONTAINER = ephemeral-vpn

NOW = $(shell /bin/date '+%Y%m%d-%H%M')

.PHONY = build update clean kill rm push run conf sh logs

all: run

clean: kill rm

kill:
	docker kill $(CONTAINER)
rm:
	docker rm $(CONTAINER)

build: Dockerfile update
	docker build -t $(TAG) .

update: Dockerfile
	perl -pi -e 's/(ENV updated) .*/\1 $(NOW)/' Dockerfile

push: Dockerfile
	echo "not yet"

run: build
	docker run -dit --name $(CONTAINER) --cap-add=NET_ADMIN -p 1194:1194/udp -p 443:443 $(TAG)

conf:
	docker exec -it $(CONTAINER) "/get_config.sh"

sh:
	docker exec -it $(CONTAINER) sh

logs:
	docker logs $(CONTAINER)
