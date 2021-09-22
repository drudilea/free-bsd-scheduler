#!/bin/bash

if [[ $1 != "" ]]; 
then 
	VBoxManage startvm $1 --type headless;
else 
	echo "Insert VM name as parameter (vmrun <image_name>)";
fi
