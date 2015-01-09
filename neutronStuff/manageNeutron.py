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

        tenant_subnet_id = _create_tenant_network()

        #Creating the router
        _create_router(tenant_subnet_id, external_net_id)

    else:
        print "This function has not been implented yet, try running with the -a option or -h option for help"


def delete(args):
    global neutronClient
    # Getting IDs of all the resources and mapping them out, since
    # the neutron api only accepts ids and not resource names.
    networks = neutronClient.list_networks()
    subnets = neutronClient.list_subnets()
    routers = neutronClient.list_routers()
    network_map = {}
    subnet_map = {}
    router_map = {}

    for network in networks['networks']:
        network_map[network['name']] = network['id']

    for subnet in subnets['subnets']:
        subnet_map[subnet['name']] = subnet['id']

    for router in routers['routers']:
        router_map[router['name']] = router['id']

    print "Make sure all instances or associated neutron ports are deleted before running this operation"
    # If -a options is set, remove the default networking components
    if args.all:

        # Removing the gateway from the default router
        neutronClient.remove_gateway_router(router_map[NEUTRON_ROUTER_NAME])
        print "Removed gateway from %s" % NEUTRON_ROUTER_NAME
        # Remvoing tenant network interface from the default router
        neutronClient.remove_interface_router(router_map[NEUTRON_ROUTER_NAME], {"subnet_id": subnet_map[TENANT_SUBNET_NAME]})
        print "Removed tenant network interface from router"

        #Deleting the router
        neutronClient.delete_router(router_map[NEUTRON_ROUTER_NAME])
        print "Deleted router %s" % NEUTRON_ROUTER_NAME


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

    # The JSON object representation of the tenant subnet
    tenant_subnet = {
        "subnet": {
            "name": "testsubnet1",
            "network_id": tenant_network_id,
            "ip_version": 4,
            "cidr": subnet_cidr,
            "dns_nameservers": ["8.8.8.8", "4.2.2.2"]
        }
    }
    tenant_subnet_id = neutronClient.create_subnet(tenant_subnet)['subnet']['id']
    print "Created external-subnet"

    #Returning tenant subnet id because it's needed for attaching subnet to router
    return tenant_subnet_id


#This function creates a neutron router, sets it's gateway,
# and attaches a subnet interface
def _create_router(tenant_subnet_id, external_net_id, router_name=NEUTRON_ROUTER_NAME, gateway_net=PHYSICAL_NETWORK_NAME):
    global neutronClient

    #Json object for the router
    router = {
        "router": {
            "name": router_name,
            "admin_state_up": True
        }
    }
    #Creating the router
    response = neutronClient.create_router(router)

    #Get ID of router
    router_id = response['router']['id']

    #Json object representing the gateway for the router
    external_gateway = {
            "network_id": external_net_id
        }

    #Adding gateway to router
    neutronClient.add_gateway_router(router_id, external_gateway)

    #Adding tenant subnet inetrface to router
    neutronClient.add_interface_router(router_id, {"subnet_id": tenant_subnet_id})



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
