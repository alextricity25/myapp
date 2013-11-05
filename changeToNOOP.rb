#!/usr/bin/ruby 
devices = `fdisk -l`.split("\n")
iscsiDevices = Array.new

#Get rid of empty entries 
devices.reject! { |d| d.empty? }


#Segregate sd* devices
devices.each do |device| 
	if /Disk \/dev\/(sd.)/ =~ device
		puts $1
		iscsiDevices.push($1)
	end 
end 


