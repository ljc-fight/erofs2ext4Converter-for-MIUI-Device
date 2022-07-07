#!/bin/bash


Green() {
    echo -e \[$(date +%T)\] "\e[1;32m"$@"\e[0m"
}

Red() {
    echo -e \[$(date +%T)\] "\e[1;31m"$@"\e[0m"
}

 Usage () {
	echo " "
	Red "Error reason: "$1""
	echo " "
	echo "Usage: erofs2ext4Converter.sh filePath"
	echo " "
	exit 1
 }

[ "$1" = "-h" -o "$1" = "--help" ] && Usage
 

zipFile=$1

Not Finished

