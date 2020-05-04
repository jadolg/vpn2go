import logging
import os

import docker
from aiohttp import web
from aiohttp_basicauth import BasicAuthMiddleware

DOCKER_IMAGE = os.getenv('DOCKER_IMAGE', 'kylemanna/openvpn')
OVPN_DATA = os.getenv('OVPN_DATA', f'{os.getcwd()}/ovpn-data')
SERVICE_USER = os.getenv('SERVICE_USER')
SERVICE_PASSWORD = os.getenv('SERVICE_PASSWORD')


async def handle_create(request):
    post = await request.json()
    user = post.get('user')
    if user:
        if f'{user}.crt' in get_certs_list():
            return web.Response(text='duplicated', status=409)
        client = docker.from_env()
        client.containers.run(image=DOCKER_IMAGE, command=f"easyrsa build-client-full {user} nopass", remove=True,
                              volumes={OVPN_DATA: {'bind': '/etc/openvpn', 'mode': 'rw'}})
        output = client.containers.run(image=DOCKER_IMAGE, command=f"ovpn_getclient {user}",
                                       remove=True,
                                       detach=False,
                                       volumes={OVPN_DATA: {'bind': '/etc/openvpn', 'mode': 'rw'}},
                                       stdout=True)
    else:
        return web.Response(text="invalid user", status=400)
    return web.Response(text=output.decode('ascii'))


async def handle_revoke(request):
    user = request.match_info.get('user', "")
    if user != "" and f'{user}.crt' in get_certs_list():
        client = docker.from_env()
        client.containers.run(image=DOCKER_IMAGE, command=f"bash -c \"echo 'yes' | ovpn_revokeclient {user}\"",
                              remove=True,
                              volumes={OVPN_DATA: {'bind': '/etc/openvpn', 'mode': 'rw'}})
    else:
        return web.Response(text='not found', status=404)
    return web.Response(text='ok')


async def handle_get(request):
    user = request.match_info.get('user', "")
    client = docker.from_env()
    if f'{user}.crt' in get_certs_list():
        output = client.containers.run(image=DOCKER_IMAGE, command=f"ovpn_getclient {user}",
                                       remove=True,
                                       detach=False,
                                       volumes={OVPN_DATA: {'bind': '/etc/openvpn', 'mode': 'rw'}},
                                       stdout=True)
        return web.Response(text=output.decode('ascii'))
    else:
        return web.Response(text='not found', status=404)


def get_certs_list():
    client = docker.from_env()
    output = client.containers.run(image=DOCKER_IMAGE, command=f"ls /etc/openvpn/pki/issued",
                                   remove=True,
                                   detach=False,
                                   volumes={OVPN_DATA: {'bind': '/etc/openvpn', 'mode': 'rw'}},
                                   stdout=True)
    return output.decode('ascii')


async def handle_get_all(request):
    return web.Response(text=get_certs_list().replace('.crt', ''))


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
