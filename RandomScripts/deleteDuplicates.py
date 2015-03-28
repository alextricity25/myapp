#!/usr/bin/python

from os import walk
from os import remove
import re
import sys
import argparse


MAP = {}
for dirpath, dirnames, filenames in walk("."):
	MAP[dirpath] = filenames
	#print "Dirpath: ", dirpath
	#print "Dirnames: ", dirnames
	#print "filenames: ", filenames


def main(argv):

  # The force yes variable is used to remove the files without prompt. If force_yes is False 
  # then the user will be prompted to confirm each file being deleted.
  force_yes = False

  # Argument parser
  parser = argparse.ArgumentParser()
  parser.add_argument("--force_yes", help="Don't prompt when removing a file",
                       action="store_true")
  args = parser.parse_args()

  if args.force_yes:
    print "force-yes is turned on"
    force_yes = True

  print "This script recursively deletes duplicate songs from the directory it's run in. Do you want to continue?" 
  
  answer = raw_input("(Yes/No)")
  
  if answer == "Yes": 
  	print "You said yes"
  else: 
  	print "You did not enter yes, the script will exit"
  	exit() 
  print "Continuing with the process..." 

  

  #Iterating through the hash
  for dirname, files in MAP.iteritems():
  	print dirname; 
  	#Iterating through the files in each directory
  	for file in files: 
  		deleteduplicate(file,dirname,force_yes)
  deletesamedir(force_yes)
  deleteConflicted(force_yes)





def deleteduplicate(file,dirname, force_yes):

	#Variables 
	deletedFile = "" 

	for dirname2, files in MAP.iteritems():
		
		for file2 in files:
			if  not re.search('^.*mp3$', file2):
				continue
			if file == file2: 
				# Delete the file in the most shallow directory, preserving the one i
				# in the deepest directory
				if len(dirname) < len(dirname2):
					path = "".join([dirname,"/",file])
					path2 = "".join([dirname2,"/",file])
					if path == deletedFile: 
						print "Already deleted this file. Continuing..."
						continue
					try:
							
						print "Found duplicate. One in ", path, " and one in ", path2
						print "Do you want to delete ", path ,"?"
						answer = ''
						if not force_yes:
							answer = raw_input("(Yes/No)")
						if answer == "Yes" or force_yes:
							deletedFile = path
							remove(path)
							print "Deleting " , path
					except:
						print "File must have already been deleted on surface directory, this means that you might have this song twice in different directories. Continuing.."
				elif dirname == dirname2:
					continue


#This method checks to see if duplicates exists in the same directory. 
#Duplicates in the same directory are appended with (#) where # is the nth copy of the duplicate song. 

def deletesamedir(force_yes): 
  for dirname, files in MAP.iteritems():
    for file in files: 
      if re.search('\(1\)\.[WwMm][a4pP][3aAvV]', file):
        answer = ''
        if not force_yes:
          print file," is a duplicate entry. Delete?"
          answer = raw_input("(Yes/No)")
        if answer == "Yes" or force_yes:
          print file, " removed." 
          remove("".join([dirname,"/",file]))
        else:
          print "File will not be deleted because 'Yes' was not typed"

def deleteConflicted(force_yes):
  for dirname, files in MAP.iteritems():
    for file in files:
      if re.search('\(.*conflict.*\)\.[WwMm][a4pP][3aAvV]', file):
        answer = ''
        if not force_yes:
          print file," is a duplicate entry. Delete?"
          answer = raw_input("(Yes/No)")
        if answer == "Yes" or force_yes:
          print file, " removed."
          remove("".join([dirname,"/",file]))
        else:
          print "File will not be deleted because 'Yes' was not typed"

if __name__ == "__main__":
  main(sys.argv[1:])
