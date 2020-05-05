import click
from pymongo import MongoClient
import socket
import time

# ------------------------- CLI ----------------------

@click.group()
def cli():
    pass


@cli.command()
@click.argument('hostname')
def wait_for_dns(hostname):
    __wait_for_dns(hostname)

@cli.command()
def wait_for_local_dns():
    __wait_for_dns(socket.gethostname())

@cli.command()
@click.argument('hosts', nargs=-1)
def wait_for_mongo(hosts):
    __wait_for_mongo(hosts)

# ------------------------- internal ----------------------

def __wait_for_mongo(hosts):
    for host in hosts:
        # try to connect for 60s
        click.echo("waiting for " + host)
        client = MongoClient(host = [host], serverSelectionTimeoutMS = 60000)
        client.server_info()

def __wait_for_dns(hostname):

    # check for 5 min, we should have a DNS entry by then
    for i in range(0,1):
        try:
            socket.gethostbyname(hostname)
            return None
        except socket.gaierror as err:
            time.sleep(5)
            pass
        except:
            raise
    raise TimeoutException("Timed out trying to resolve " + hostname)

class TimeoutException(Exception):
    def __init__(self, msg):
        self.msg = msg
    def __str__(self):
        return repr(self.msg)

if __name__ == '__main__':
    cli()
