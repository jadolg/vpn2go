OVPN_DATA ?= $(PWD)/"ovpn-data"
SERVER_ADDRESS ?= "192.168.0.56"
CA ?= "myvpn"
DOCKER_IMAGE ?= guamulo/openvpn
REPOSITORY ?= https://github.com/jadolg/docker-openvpn.git

.PHONY:
build:
	git clone $(REPOSITORY)
	cd docker-openvpn && docker build -t $(DOCKER_IMAGE) .

.PHONY:
configure:
	docker run --rm -v $(OVPN_DATA):/etc/openvpn --log-driver=none $(DOCKER_IMAGE) ovpn_genconfig -u udp://$(SERVER_ADDRESS)
	docker run --rm -v $(OVPN_DATA):/etc/openvpn -i -e "EASYRSA_BATCH=1" -e "EASYRSA_REQ_CN="$(CA) $(DOCKER_IMAGE) ovpn_initpki nopass

.PHONY:
run:
	docker run --name openvpn -v $(OVPN_DATA):/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN -d $(DOCKER_IMAGE)

.PHONY:
clean:
	docker stop openvpn
	rm -Rf docker-openvpn
	docker rmi kylemanna/openvpn
