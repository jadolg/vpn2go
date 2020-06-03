# You should REALLY change the credentials for production environments
SERVICE_USER ?= admin
SERVICE_PASSWORD ?= JY9yZhXuKhNfGwfu+OrKfkBMFiHVwg0ehlP1NLthCIs
SERVER_ADDRESS ?= 192.168.0.56
SERVER_IP_ADDRESS ?= 192.168.0.56
CA ?= myvpn

PROTOCOL ?= udp
VPN_PORT ?= 1194
SERVER_SUBNET ?= 192.168.253.0/24
DNS_SERVER ?= 1.1.1.1
CLIENT_TO_CLIENT ?= no
COMPRESSION ?= yes

ifeq ($(CLIENT_TO_CLIENT), yes)
	CLIENT_TO_CLIENT_FLAG := -c
else
	CLIENT_TO_CLIENT_FLAG :=
endif

ifeq ($(COMPRESSION), yes)
	COMPRESSION_FLAG := -z
else
	COMPRESSION_FLAG :=
endif

OVPN_DATA ?= $(PWD)/"ovpn-data"
DOCKER_IMAGE ?= kylemanna/openvpn
REPOSITORY ?= https://github.com/kylemanna/docker-openvpn.git
EXAMPLE_USER ?= user1

.PHONY:
build:
	docker build -t vpn2go .
	git clone $(REPOSITORY)
	cd docker-openvpn && docker build -t $(DOCKER_IMAGE) .
	rm -Rf docker-openvpn

.PHONY:
configure:
	docker run --rm -v $(OVPN_DATA):/etc/openvpn $(DOCKER_IMAGE) ovpn_genconfig -u $(PROTOCOL)://$(SERVER_ADDRESS):$(VPN_PORT) $(CLIENT_TO_CLIENT_FLAG) $(COMPRESSION_FLAG) -s $(SERVER_SUBNET) -n $(SERVER_IP_ADDRESS) -e "topology subnet"
	docker run --rm -v $(OVPN_DATA):/etc/openvpn -i -e "EASYRSA_BATCH=1" -e "EASYRSA_REQ_CN="$(CA) $(DOCKER_IMAGE) ovpn_initpki nopass
	printf "localhost, $(SERVER_ADDRESS)\nreverse_proxy vpn2go:5000\nroute /dnsmasq/* {\nuri strip_prefix /dnsmasq\nreverse_proxy dnsmasq:8080\n}" > Caddyfile
	printf "log-queries\nno-resolv\nserver=$(DNS_SERVER)\nstrict-order" > dnsmasq.conf

.PHONY:
run:
	docker run --restart always --name openvpn -v $(OVPN_DATA):/etc/openvpn -d -p $(VPN_PORT):1194/$(PROTOCOL) --cap-add=NET_ADMIN -d $(DOCKER_IMAGE)
	docker run --restart always --name vpn2go -e SERVER_ADDRESS=$(SERVER_ADDRESS) -e SERVICE_USER=$(SERVICE_USER) -e SERVICE_PASSWORD=$(SERVICE_PASSWORD) -e DOCKER_IMAGE=$(DOCKER_IMAGE) -e OVPN_DATA=$(OVPN_DATA) -v /var/run/docker.sock:/var/run/docker.sock -p 127.0.0.1:5000:5000 -d vpn2go
	docker run --restart always --name dnsmasq -d -p 53:53/udp -v $(PWD)/dnsmasq.conf:/etc/dnsmasq.conf --log-opt "max-size=100m" -e "HTTP_USER=$(SERVICE_USER)" -e "HTTP_PASS=$(SERVICE_PASSWORD)" jpillora/dnsmasq
	docker run --restart always --name proxy-vpn2go -p 80:80 -p 443:443 -v $(PWD)/Caddyfile:/etc/caddy/Caddyfile -v $(PWD)/caddy:/data/ --link vpn2go --link dnsmasq -d caddy

.PHONY:
stop:
	docker stop openvpn vpn2go proxy-vpn2go dnsmasq
	docker rm openvpn vpn2go proxy-vpn2go dnsmasq


.PHONY:
create_example_user:
	docker run -v $(OVPN_DATA):/etc/openvpn --log-driver=none --rm $(DOCKER_IMAGE) easyrsa build-client-full $(EXAMPLE_USER) nopass
	docker run -v $(OVPN_DATA):/etc/openvpn --log-driver=none --rm $(DOCKER_IMAGE) ovpn_getclient $(EXAMPLE_USER) > $(EXAMPLE_USER).ovpn

.PHONY:
revoke_example_user:
	docker run --rm -it -v $(OVPN_DATA):/etc/openvpn $(DOCKER_IMAGE) bash -c "echo 'yes' | ovpn_revokeclient $(EXAMPLE_USER)"

.PHONY:
clean:
	rm -Rf docker-openvpn
	sudo rm -Rf $(OVPN_DATA)
	sudo rm -Rf caddy
	rm -f $(EXAMPLE_USER).ovpn
	rm -f Caddyfile
	rm -f dnsmasq.conf
	docker rmi $(DOCKER_IMAGE)
