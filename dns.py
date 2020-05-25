import os

from dnslib.dns import RR
from dnslib.server import DNSLogger, DNSServer

server_name = os.getenv("SERVER_ADDRESS")


class TestResolver:
    def resolve(self, request, handler):
        reply = request.reply()
        query = str(request.q.qname)
        if query.endswith(f'.{server_name}.'):
            query_name = query.replace(f'.{server_name}.', '')
            ccd_file = f'/etc/openvpn/ccd/{query_name}'
            if os.path.exists(ccd_file):
                data = open(ccd_file, 'r').read()
                reply.add_answer(*RR.fromZone(f"{query} 60 A {data.split()[1]}"))

        return reply


if __name__ == '__main__':
    resolver = TestResolver()
    logger = DNSLogger(prefix=False)
    server = DNSServer(resolver, logger=logger)
    server.start()
