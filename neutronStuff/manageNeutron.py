import argparse
import os
import subprocess
from neutronclient.neutron import client


# Global variables
neutronClient = None


def load_source(source_file):
	print source_file

        # Running subprocess..
	command = ['bash','-c', 'source %s' % source_file]
        subprocess.Popen(command, stdout=subprocess.PIPE)
        
	print "Checking to see if credentials were loaded successfully..." 
        print os.environ['OS_USERNAME']
	print os.environ['OS_PASSWORD']



def create(args):
	global neutronClient
	print "You're about to create something"
	networks = neutronClient.list_networks(name='admin')
	print networks

def delete(args):
	#testing
	test = "test"

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Manage your neutron networks in bulk")
    parser.add_argument("--admin_token", type=str, required=True, help="Keystone admin auth token")
    parser.add_argument("--source_file", type=str, required=True, help="Your environments source file")  
    
    subparsers = parser.add_subparsers(title='subcommands')
    parser_create = subparsers.add_parser('create', help='Create the neutron networks in our SAT6 lab')
    parser_create.add_argument('-a','--all', action='store_true', required=False, help="Create all the networking components needed to get a functional flat neutron network environment in our SAT6 lab. This creates the physical provider network, routers, and a test tenant network using the vxlan tunneling protocol.")
    parser_create.set_defaults(func=create)

    parser_delete = subparsers.add_parser('delete', help='Delete the neutron networks in our SAT6 lab')
    parser_delete.add_argument('-a','--all', action='store_true', required=False, help="Delete everything. This deletes all neutron ports, any instances associated with these ports, floating IP ports, all neutron routers, and all networks. Use at your own risk.")
    parser_delete.set_defaults(func=delete)

    args = parser.parse_args()

    #Loading openstack credentials
    load_source(args.source_file)

    # Neutron Client
    neutronClient = client.Client('2.0', endpoint_url=os.environ['OS_AUTH_URL'], token=args.admin_token)

    # Run the subcommand
    args.func(args)


