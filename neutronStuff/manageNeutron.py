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
    # The --all flag has been used, create default
    # networks according to global constants above
    if args.all:
        # The JSON object representation of the external network
        network = {
            "network": {
                "name": PHYSICAL_NETWORK_NAME,
                "provider:physical_network": PHYSICAL_NETWORK_LABEL,
                "provider:network_type": "flat",
                "shared": True,
                "router:external": True
            }
        }
        response = neutronClient.create_network(network)
        print "Created %s network" % PHYSICAL_NETWORK_NAME

        #Retriving the UUID of the external-net network
        external_net_id = response['network']['id']

        # The JSON object representation of the external subnet
        external_subnet = {
            "subnet": {
                "name": PHYSICAL_SUBNET_NAME,
                "network_id": external_net_id,
                "ip_version": 4,
                "gateway_ip": "192.168.100.1",
                "cidr": "192.168.100.0/24",
                "allocation_pools": [{"start": FLOATING_IP_START, "end": FLOATING_IP_END}]
            }
        }
        neutronClient.create_subnet(external_subnet)
        print "Created %s subnet" % PHYSICAL_SUBNET_NAME

        #Creating the default tenant network and subnet.
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
        _delete_router(router_map, subnet_map)

        # Deleting default networks (eventually check if they exists)
        _delete_network(network_map, PHYSICAL_NETWORK_NAME)
        _delete_network(network_map, TENANT_NETWORK_NAME)



def debug(args):
    print "This program will eventually help with debugging environments and such..."
    global neutronClient

    if args.restart_services:
        _restart_neutron_services(args.inventory)



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
            "name": subnet_name,
            "network_id": tenant_network_id,
            "ip_version": 4,
            "cidr": subnet_cidr,
            "dns_nameservers": ["8.8.8.8", "4.2.2.2"]
        }
    }
    tenant_subnet_id = neutronClient.create_subnet(tenant_subnet)['subnet']['id']
    print "Created %s" % subnet_name

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
    print "Created %s router" % router_name

    #Get ID of router
    router_id = response['router']['id']

    #Json object representing the gateway for the router
    external_gateway = {
            "network_id": external_net_id
        }

    #Adding gateway to router
    neutronClient.add_gateway_router(router_id, external_gateway)
    print "Added %(gateway)s as gateway to %(router)s" % {"gateway": gateway_net,"router": router_name}

    #Adding tenant subnet inetrface to router
    neutronClient.add_interface_router(router_id, {"subnet_id": tenant_subnet_id})
    print "Added %(tenant_id)s as interface to %(router)s router" %  {"tenant_id": tenant_subnet_id,"router": router_name}

def _delete_router(router_map, subnet_map, router_name=NEUTRON_ROUTER_NAME, gateway_net=PHYSICAL_NETWORK_NAME, tenant_subnet_name=TENANT_SUBNET_NAME):
    global neutronClient

    # Removing the gateway from the default router
    neutronClient.remove_gateway_router(router_map[NEUTRON_ROUTER_NAME])
    print "Removed gateway from %s" % NEUTRON_ROUTER_NAME

    # Remvoing tenant network interface from the default router
    neutronClient.remove_interface_router(router_map[NEUTRON_ROUTER_NAME], {"subnet_id": subnet_map[TENANT_SUBNET_NAME]})
    print "Removed tenant network interface from router"

    #Deleting the router
    neutronClient.delete_router(router_map[NEUTRON_ROUTER_NAME])
    print "Deleted router %s" % NEUTRON_ROUTER_NAME

# This function deletes a network and it's corresponding subnets
def _delete_network(network_map, network_name):
    global neutronClient

    # Deleting network
    neutronClient.delete_network(network_map[network_name])
    print "Deleted %s network" % network_name

def _restart_neutron_services(inventory_file):
    #Load inventory file into JSON object

    inventory = []
    with open(inventory_file) as f:
        inventory = json.load(f)

    #Make a list of hosts that have neutron services running on them
    #by using the JSON object. These hosts will include:
    # - Hypervisors; all bare metal nodes running KVM.
    # - Neutron agent containers hosted on the infra nodes
    # - Neutron server containers hosted on the infra nodes
    #compute_hosts = inventory['compute_hosts']['hosts']
    neutron_linuxbridge_agent = inventory['neutron_linuxbridge_agent']['hosts']
    neutron_dhcp_agent = inventory['neutron_dhcp_agent']['hosts']
    neutron_l3_agent = inventory['neutron_l3_agent']['hosts']
    neutron_metadata_agent = inventory['neutron_metadata_agent']['hosts']
    neutron_metering_agent = inventory['neutron_metering_agent']['hosts']
    neutron_server = inventory['neutron_server']['hosts']
    #pprint.pprint(inventory)

    #Running the commands on the compute hosts to restart
    #neutron-linuxbridge-agent service
    print "Restarting the neutron-linuxbridge-agent service on all compute hosts..."
    for host in neutron_linuxbridge_agent:
        command = ['bash', '-c', "ssh -o 'StrictHostKeyChecking no' root@%s restart neutron-linuxbridge-agent" % host]
        proc = subprocess.Popen(command, stdout = subprocess.PIPE)
        proc.stdout = proc.communicate()
        print proc.stdout[0].rstrip()

    print "Restarting the neutron-dhcp-agent services.."
    for host in neutron_dhcp_agent:
        command = ['bash', '-c', "ssh -o 'StrictHostKeyChecking no' root@%s restart neutron-dhcp-agent" % host]
        proc = subprocess.Popen(command, stdout = subprocess.PIPE)
        proc.stdout = proc.communicate()
        print proc.stdout[0].rstrip()

    print "Restarting l3 agent.."
    for host in neutron_l3_agent:
        command = ['bash', '-c', "ssh -o 'StrictHostKeyChecking no' root@%s restart neutron-l3-agent" % host]
        proc = subprocess.Popen(command, stdout = subprocess.PIPE)
        proc.stdout = proc.communicate()
        print proc.stdout[0].rstrip()

    print "Restarting neutron metadata agent.."
    for host in neutron_metadata_agent:
        command = ['bash', '-c', "ssh -o 'StrictHostKeyChecking no' root@%s restart neutron-metadata-agent" % host]
        proc = subprocess.Popen(command, stdout = subprocess.PIPE)
        proc.stdout = proc.communicate()
        print proc.stdout[0].rstrip()

    print "Restarting neutron metering agent..."
    for host in neutron_metering_agent:
        command = ['bash', '-c', "ssh -o 'StrictHostKeyChecking no' root@%s restart neutron-metering-agent" % host]
        proc = subprocess.Popen(command, stdout = subprocess.PIPE)
        proc.stdout = proc.communicate()
        print proc.stdout[0].rstrip()

    print "Restarting neutron server..."
    for host in neutron_server:
        command = ['bash', '-c', "ssh -o 'StrictHostKeyChecking no' root@%s restart neutron-server" % host]
        proc = subprocess.Popen(command, stdout = subprocess.PIPE)
        proc.stdout = proc.communicate()
        print proc.stdout[0].rstrip()




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

    #Subcommand for debugging neutron in an RPC environment, this options
    #requires the location of the rpc_inventory file. The information in
    #there is used to debug the environement. The debug subcommand
    #can also perform a variety of debug actions such as:
    # - Restarting all the neutron services across the environment
    # - Check all neutron ports
    # - Check connectivity between vxlan endpoints
    # - Check connectivity between the neutron router and the outside
    # - Check connectivity between the neutron router and tenant network dhcp namespace
    # - Check neutron logs for any recent ERROR messages.
    # - more to come!!

    parser_debug = subparsers.add_parser('debug', help="This can be used to help debug neutron in an RPC environment, see help (-h) for more information. This command can only be ran from the deployment host")
    parser_debug.add_argument('-i','--inventory', type=str, required=True, help="The path of the environment's rpc_inventory.json file", default='/etc/rpc_deploy/rpc_inventory.json')
    parser_debug.add_argument('-r','--restart_services', action='store_true', required=False, help="Restart all the services across the environment, even the ones in the container. SSH is used to restart services inside a container.")
    parser_debug.set_defaults(func=debug)

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
