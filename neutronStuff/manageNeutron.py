import argparse
import os
from neutronclient.neutron import client


def load_source(source_file):
	os.system("source /root/openrc")

def authenticate(self): 
	neutron = client.Client('2.0', endpoint_url=os.environ['OS_AUTH_URL'], token=args.admin-token)



















if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Manage your neutron networks in bluk")
    parser.add_argument("--admin-token", type=str, help="Keystone admin auth token")
    parser.add_argument("--source-file", type=str, help="Your environments source file")  