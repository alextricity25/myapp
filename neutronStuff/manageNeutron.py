import argparse
import os
import subprocess
import pprint
#from neutronclient.neutron import client
from neutronclient.v2_0 import client


# Global variables
neutronClient = None


# Still doesn't load environment variables, needs work
def load_source(source_file):
        # Running subprocess..
	command = ['bash','-c', 'source %s' % source_file]
        subprocess.Popen(command, stdout=subprocess.PIPE)

def create(args):
	global neutronClient
	print "You're about to create something"

def delete(args):
	#testing
	test = "test"
	print "You're about to delete something.."

# List all the networks. Mainly for development testing purposes.
def list(args):
	global neutronClient
	networks = neutronClient.list_networks()
	pprint.pprint(networks)

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
