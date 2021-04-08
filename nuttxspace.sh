#!/bin/bash

#Reference: https://www.embarcados.com.br/primeiros-passos-com-o-esp32-e-o-nuttx-parte-1/


#vars shell script
dirNuttx=nuttxspace
dirCurr=`pwd`
dir=$dirCurr/$dirNuttx
serial=/dev/ttyUSB0

#test sudo
if [ "`which sudo`" == "" ]
then
	echo "######################################"
	echo " "
	echo "install sudo"
	echo "  "
	echo "COMMAND: #apt install sudo"
	echo "  "
	echo "add `whoami` in grup sudo"
	echo "  "
	echo "COMMAND: #usermod -aG sudo `whoami`"
	echo "  "
	echo "after try again"
	echo "  "
	echo "######################################"
	exit 1
fi

#test dialout
if [ "`groups|grep dialout`" == "" ]
then
	echo "#######################################"
	echo "  "
	echo "add user `whoami` in group dialout"
	echo "  "
	echo "COMMAND: \$sudo gpasswd -a `whoami` dialout"
	echo "  "
	echo "after login again"
	echo "  "
	echo " OR"
	echo "  "
	echo "COMANDO: \$newgrp dialout "
	echo "  "
	echo "#######################################"
	exit 1
fi

export PATH=$PATH:$dirCurr/$dirNuttx/xtensa-esp32-elf/bin

#install dialog
if [ "`dpkg -l dialog|grep ii|awk '{print $2}'`" != "dialog" ]
then
	sudo apt update
	sudo apt install dialog -y
fi

message()
{
	clear
	echo "##################################################################"
	echo "# "
	echo "# $1"
	echo "# "
	echo "##################################################################"
	sleep 2
}

pause()
{
	echo "##################################################################"
	echo "------>                    type RETURN                    <-------"
	echo "##################################################################"
	read a
	clear
}


createNuttxSpace()
{

	if [ -d $dirNuttx ]
	then
		message "there is nuttxspace directory. If you want to recreate delete the $dirNuttx directory"
		pause
		#echo "type RETURN"
		#read a
		return
	else
		message "Create RTOS Nuttx configuration space on Ubuntu for use in esp32-devkit"
		mkdir $dirNuttx && cd $dirNuttx

		echo "--> udpate apt and install packages"
		sleep 1
		sudo apt update	
		#sudo apt upgrade
		sudo apt install automake bison build-essential flex gperf git libncurses5-dev libtool libusb-dev  pkg-config kconfig-frontends curl picocom dialog -y

		echo "--> clone git nuttx and apps"
		sleep 1
		git clone https://github.com/apache/incubator-nuttx.git nuttx
		git clone https://github.com/apache/incubator-nuttx-apps.git apps

		echo "--> download cross compiler for ESP32"
		sleep 1
		curl https://dl.espressif.com/dl/xtensa-esp32-elf-gcc8_2_0-esp-2020r2-linux-amd64.tar.gz | tar -xz

		export PATH=$PATH:$dirCurr/$dirNuttx/xtensa-esp32-elf/bin

		if [ -e /usr/bin/esptool.py ]
		then
			echo "--> there is ESP8266 and ESP32 Bootloader Utility"
			sleep 1
		else
			echo "--> install ESP8266 and ESP32 ROM Bootloader Utility"
			sleep 1
			sudo apt install esptool -y
			sudo ln -s ../share/esptool/esptool.py /usr/bin/esptool.py
		fi

		echo "--> download particion table and bootloader for ESP32"
		sleep 1￼
		cd $dir
		mkdir esp-bins
		cd esp-bins
		curl -L "https://github.com/espressif/esp-nuttx-bootloader/releases/download/latest/bootloader-esp32.bin" -o bootloader-esp32.bin
		curl -L "https://github.com/espressif/esp-nuttx-bootloader/releases/download/latest/partition-table-esp32.bin" -o partition-table-esp32.bin
		cd ../nuttx
		pause

	fi
}


updateNuttxSpace()
{
	
	message "update apps and nuttx in $dir"
	cd $dir
	cd nuttx
	git pull
	cd ../apps
	git pull
	cd $dir
	pause
}

deleteNuttxSpace()
{
	
	message "delete $dirNuttx"
	cd $dirCurr
	rm -rf $dirNuttx
}

distClean()
{
	
	message "remove configuration"
	cd $dir/nuttx
	make -j4 distclean
	pause
}

clean()
{
	message "remove configuration"
	cd $dir/nuttx
	make -j4 clean
	pause
}



selectConfig()
{

	message "select ready configuration for ESP32"

	declare -a array
	 i=1
	 j=1
	while read line
	do
		array[ $i ]=$j
    		(( j++ ))
		array[ ($i + 1) ]=$line
		(( i=($i+2) ))
	done < <(ls $dir/nuttx/boards/xtensa/esp32/esp32-devkitc/configs) #consume file path provided as argument

	CHOICE=$(dialog --stdout --clear \
                 --backtitle "Configuration" \
                 --title "Configuration" \
                 --menu "Choose a config:" \
                 0 0 0 \
                 "${array[@]}" )
	config=${array[($CHOICE * 2)]}
	cd $dir
	cd nuttx
	./tools/configure.sh esp32-devkitc:$config
	pause

}

buildDownload()
{
	if [ "$config" != "" ] | [ -e $dir/nuttx/.config ]
	then
		message "build and download configuration $config"
		cd $dir/nuttx
		make download ESPTOOL_PORT=$serial ESPTOOL_BINDIR=../esp-bins #ESPTOOL_BAUD=115200
	else
		message "Select a configuration in menu selectconfig"
	fi
	pause
}

menuConfig()
{
	message "make menuconfig"
	cd $dir/nuttx
	make menuconfig
	config="owner"
	pause
}


serialShell()
{
	message "connect shell nsh $serial. EXIT = Crtl + A + X "
	picocom $serial -b 115200
	pause

}

backupConfig()
{
	clear
	date=`date +"%Y-%m-%d-_%H:%M:%S"`
	file=config.$date
	message "create file $file in $dir with last configuration "
	cd $dirCurr && mkdir backup.config 2> /dev/null
	cp -v $dir/nuttx/.config backup.config/$file && echo "arquivo criado"
	cd $dir/nuttx
	pause

}

restoreConfig()
{
	cd $dirCurr/backup.config && lastconfig=`ls|tail -n 1`
	message "restore last config $lastconfig" in file $dir/nuttx/.config
        cp -v $lastconfig $dir/nuttx/.config
	pause
}

helpConfig()
{
	dialog --msgbox 'Basics steps for configuration, build, download and access shell nsh in ESP32:
	1 - create --> create work space nuttx for ESP32;
	2 - selectconfig --> use option nsh
	3 - connect --> connect ESP32-devkit to the PC using the usb port
	4 - builddownload --> build and download RTOS
	5 - serialshell --> access shell nsh by serial' 12 80 

}

while true
do
	option=$(dialog --stdout --title "Very simple NUTTX for ESP32" --menu 'Select options (see helpconfig):' 0 0 0 \
		create    'Create RTOS Nuttx Space for ESP32'\
		delete    'Delete Nuttx Space in '$dir\
		update    'Update nuttx and apps (git pull)'\
		distclean 'Remove configuration'\
		clean     'Remove bins'\
		selectconfig 'Select ready configuration'\
		builddownload 'Build and download for ESP32 --> connect ESP32'\
		menuconfig 'Load menuconfig Nuttx'\
		serialshell 'Access shell nsh in ESP32 by '$serial\
		backupconfig 'Create a config.DATE in directory backup.config'\
		restoreconfig 'Restore last configuration in directory backup.config'\
		helpconfig 'Show help with configuration steps'\
		)

	[ $? -eq 1 ] && break

	case $option in
	create)
		createNuttxSpace
		;;
	delete)
		deleteNuttxSpace
		;;
	update)
		updateNuttxSpace
		;;
	distclean)
		distClean
		;;
	clean)
		clean
		;;
	selectconfig)
		selectConfig
		;;
	builddownload)
		buildDownload
		;;
	menuconfig)
		menuConfig
		;;
	serialshell)
		serialShell
		;;
	backupconfig)
		backupConfig
		;;
	restoreconfig)
		restoreConfig
		;;
	helpconfig)
		helpConfig
		;;
	
	*)
		echo "Sorry, I don't understand"
		;;
  esac
done



exit 0


