#!/usr/bin/python
import argparse
import time
import os
import subprocess
import pprint
import json
from neutronclient.v2_0 import client


# Global variables
neutronClient = None

# Global Constant, can be set by the admin running the script to
# change network labels.
PHYSICAL_NETWORK_LABEL = "vlan"
PHYSICAL_NETWORK_NAME = "external-net"
PHYSICAL_SUBNET_NAME = "external-subnet"

TENANT_NETWORK_NAME = "testnet1"
TENANT_SUBNET_NAME = "testsubnet1"

NEUTRON_ROUTER_NAME = "neutron-router"
NEUTRON_ROUTER_GATEWAY_IP = "192.168.100.1"

FLOATING_IP_START = "192.168.100.71"
FLOATING_IP_END = "192.168.100.90"


def load_source(source_file):
    # Running subprocess..
    command = ['bash', '-c', 'source %s && env' % source_file]
    process = subprocess.Popen(command, stdout=subprocess.PIPE)
    for line in process.stdout:
        (key, _, value) = line.partition("=")
        os.environ[key] = value.rstrip()
    process.communicate()


def create(args):
    global neutronClient
    print "You're about to create something"
    print args.all
    # The --all flag has been used, create default
    # networks according to global constants above
    if args.all:
        # The JSON object representation of the external network
        network = {
            "network": {
                "name": "external-net",
                "provider:physical_network": PHYSICAL_NETWORK_LABEL,
                "provider:network_type": "flat",
                "shared": True,
                "router:external": True
            }
        }
        response = neutronClient.create_network(network)
        print "Created external-net network"

        #Retriving the UUID of the external-net network
        external_net_id = response['network']['id']

        # The JSON object representation of the external subnet
        external_subnet = {
            "subnet": {
                "name": "external-subnet",
                "network_id": external_net_id,
                "ip_version": 4,
                "gateway_ip": "192.168.100.1",
                "cidr": "192.168.100.0/24",
                "allocation_pools": [{"start": FLOATING_IP_START, "end": FLOATING_IP_END}]
            }
        }
        neutronClient.create_subnet(external_subnet)
        print "Created external-subnet network"

        _create_tenant_network()

    else:
        print "This function has not been implented yet, try running with the -a option or -h option for help"


def delete(args):
    print "You're about to delete something.."

def debug(args):
    print "This program will eventually help with debugging environments and such..."


# List all the networks. Mainly for development testing purposes.
def list(args):
    global neutronClient
    networks = neutronClient.list_networks()
    pprint.pprint(networks)
    for nets in networks['networks']:
        print nets['name']

#Private helper functions
# This function creates a vxlan tenant network with it's corresponding subnet
def _create_tenant_network(subnet_cidr="10.10.10.0/24", net_name=TENANT_NETWORK_NAME, subnet_name=TENANT_SUBNET_NAME):
    global neutronClient

    # The JSON object representation of the tenant network
    tenant_network = {
        "network": {
            "name": net_name,
            "provider:network_type": "vxlan",
        }
    }
    response = neutronClient.create_network(tenant_network)
    print "Created %s network" % net_name
    #Retriving the UUID of the tenant_network
    tenant_network_id = response['network']['id']

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Manage your neutron networks in bulk. First, source openrc.")
    parser.add_argument("--source_file", type=str, required=True, help="Your environments source file")

    subparsers = parser.add_subparsers(title='subcommands')

    parser_create = subparsers.add_parser('create', help='Create the neutron networks in our SAT6 lab')
    parser_create.add_argument('-a','--all', action='store_true', required=False, help="Create all the networking components needed to get a functional flat neutron network environment in our SAT6 lab. This creates the physical provider network, routers, and a test tenant network using the vxlan tunneling protocol.")
    parser_create.set_defaults(func=create)

    parser_delete = subparsers.add_parser('delete', help='Delete the neutron networks in our SAT6 lab')
    parser_delete.add_argument('-a','--all', action='store_true', required=False, help="Delete everything. This deletes all neutron ports, any instances associated with these ports, floating IP ports, all neutron routers, and all networks. Use at your own risk.")
    parser_delete.set_defaults(func=delete)

    # Subcommand for listing the networks, mainly for dev testing purposes.
    parser_list = subparsers.add_parser('list', help='List networks in JSON format')
    parser_list.set_defaults(func=list)

    args = parser.parse_args()

    #Loading openstack credentials
    load_source(args.source_file)

    # Neutron Client
    neutronClient = client.Client(username=os.environ['OS_USERNAME'], password=os.environ['OS_PASSWORD'], tenant_name=os.environ['OS_TENANT_NAME'], auth_url=os.environ['OS_AUTH_URL'])

    # Run the subcommand
    args.func(args)
