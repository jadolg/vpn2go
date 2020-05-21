import ipaddress
import logging
import os
from ipaddress import IPv4Address

import docker
from aiohttp import web
from aiohttp_basicauth import BasicAuthMiddleware

DOCKER_IMAGE = os.getenv('DOCKER_IMAGE', 'kylemanna/openvpn')
OVPN_DATA = os.getenv('OVPN_DATA', f'{os.getcwd()}/ovpn-data')
SERVICE_USER = os.getenv('SERVICE_USER')
SERVICE_PASSWORD = os.getenv('SERVICE_PASSWORD')
SERVER_ADDRESS = os.getenv('SERVER_ADDRESS', '127.0.0.1')


def run_on_vpn_docker(command):
    client = docker.from_env()
    return client.containers.run(image=DOCKER_IMAGE, command=command,
                                 remove=True,
                                 detach=False,
                                 volumes={OVPN_DATA: {'bind': '/etc/openvpn', 'mode': 'rw'}},
                                 stdout=True)


async def handle_create(request):
    post = await request.json()
    user = post.get('user')
    if user:
        if f'{user}.crt' in get_certs_list():
            return web.Response(text='duplicated', status=409)
        run_on_vpn_docker(command=f"easyrsa build-client-full {user} nopass")
        ip = post.get('ip')
        if ip:
            try:
                address = ipaddress.IPv4Interface(ip)
                run_on_vpn_docker(
                    f'bash -c "echo ifconfig-push {address.ip} {address.netmask} > /etc/openvpn/ccd/{user}"')
            except ipaddress.AddressValueError:
                logging.error(f'invalid IPv4 address/mask provided {ip}')

        output = run_on_vpn_docker(command=f"ovpn_getclient {user}")
    else:
        return web.Response(text="invalid user", status=400)
    return web.Response(text=output.decode('ascii'))


async def handle_revoke(request):
    user = request.match_info.get('user', "")
    if user != "" and f'{user}.crt' in get_certs_list():
        run_on_vpn_docker(command=f"bash -c \"echo 'yes' | ovpn_revokeclient {user}\"")
    else:
        return web.Response(text='not found', status=404)
    return web.Response(text='ok')


async def handle_get(request):
    user = request.match_info.get('user', "")
    if f'{user}.crt' in get_certs_list():
        output = run_on_vpn_docker(command=f"ovpn_getclient {user}")
        return web.Response(text=output.decode('ascii'))
    else:
        return web.Response(text='not found', status=404)


def get_certs_list():
    output = run_on_vpn_docker(command=f"ls /etc/openvpn/pki/issued")
    return output.decode('ascii').replace(SERVER_ADDRESS, '')


async def handle_get_all(request):
    output = run_on_vpn_docker('ovpn_listclients')
    return web.Response(text=output.decode('ascii'))


async def handle_status(request):
    client = docker.from_env()
    container = client.containers.get('openvpn')
    output = container.exec_run(cmd="cat /tmp/openvpn-status.log")
    return web.Response(text=output.output.decode('ascii'))


async def handle_healthcheck(request):
    return web.Response(text='alive')


if __name__ == '__main__':
    if SERVICE_USER and SERVICE_PASSWORD:
        auth = BasicAuthMiddleware(username=SERVICE_USER, password=SERVICE_PASSWORD)
        app = web.Application(middlewares=[auth])
    else:
        logging.warning('service is running without authentication')
        app = web.Application()

    app.add_routes([web.post('/', handle_create)])
    app.add_routes([web.get('/', handle_get_all)])
    app.add_routes([web.get('/status', handle_status)])
    app.add_routes([web.delete('/{user}', handle_revoke)])
    app.add_routes([web.get('/{user}', handle_get)])
    app.add_routes([web.get('/healthcheck', handle_healthcheck)])
    web.run_app(app, host='0.0.0.0', port=5000)
