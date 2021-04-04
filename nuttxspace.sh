#!/bin/bash

#Reference: https://www.embarcados.com.br/primeiros-passos-com-o-esp32-e-o-nuttx-parte-1/


#vars shell script
dirNuttx=nuttxspace
dirCurr=`pwd`
dir=$dirCurr/$dirNuttx
serial=/dev/ttyUSB0


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

#echo $dir
#sleep 5
export PATH=$PATH:$dirCurr/$dirNuttx/xtensa-esp32-elf/bin

#install dialog
if [ "`dpkg -l dialog|grep ii|awk '{print $2}'`" != "dialog" ]
then
	sudo apt update
	sudo apt install dialog -y
fi

createNuttxSpace()
{
	echo "################################################################"
	echo " "
	echo "Create RTOS Nuttx configuration space on Ubuntu for use in esp32-devkit"
	echo " "
	echo "################################################################"
	sleep 2

	if [ -d $dirNuttx ]
	then
		echo "########################################################"
		echo "there is nuttxspace directory "
		echo "if you want to recreate delete the $ dirNuttx directory"
		echo "TYPE RETURN"
		echo "#######################################################"
		read a
		return
	else
		mkdir $dirNuttx && cd $dirNuttx
	fi

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

	echo "type RETURN"
	read a
}


updateNuttxSpace()
{
	
	echo "########################################################"
	echo "update apps and nuttx in $dir"
	echo "########################################################"
	sleep 2
	cd $dir
	cd nuttx
	git pull
	cd ../apps
	git pull
	cd $dir
	echo "type RETURN"
	read a
}

deleteNuttxSpace()
{
	
	echo "########################################################"
	echo "delete $dirNuttx"
	echo "########################################################"
	sleep 2
	cd $dirCurr
	rm -rf $dirNuttx
}

distClean()
{
	
	echo "########################################################"
	echo "remove configuration"
	echo "########################################################"
	sleep 2
	cd $dir/nuttx
	make -j4 distclean
	echo "type RETURN"
	read a
}

clean()
{
	echo "########################################################"
	echo "remove configuration"
	echo "########################################################"
	sleep 2
	cd $dir/nuttx
	make -j4 clean
	echo "type RETURN"
	read a
}



selectConfig()
{

	echo "########################################################"
	echo "select ready configuration for ESP32"
	echo "########################################################"
	sleep 1

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
	echo "type RETURN"
	read a

}

buildDownload()
{
	if [ "$config" != "" ]
	then
		echo "########################################################"
		echo "build and download configuration $config"
		echo "########################################################"
		sleep 1
		cd $dir/nuttx
		sleep 2
		make download ESPTOOL_PORT=$serial #ESPTOOL_BAUD=115200 ESPTOOL_BINDIR=../esp-bins
	else
		echo "########################################################"
		echo "Select a configuration in menu selectconfig"
		echo "########################################################"
		sleep 2
	fi
	echo "type RETURN"
	read a
}

menuConfig()
{
	echo "########################################################"
	echo "make menuconfig"
	echo "########################################################"
	sleep 1
	cd $dir/nuttx
	make menuconfig
}


serialShell()
{
	clear
	echo "########################################################"
	echo "connect shell nsh $serial. EXIT = Crtl + A + X "
	echo "########################################################"
	sleep 2
	picocom $serial -b 115200
	echo "type RETURN"
	read a

}

configBackup()
{
	clear
	date=`date +"%Y-%m-%d-_%H:%M:%S"`
	file=config.$date
	echo "########################################################"
	echo "create file $file in $dir with last configuration "
	echo "########################################################"
	sleep 3
	cd $dir && mkdir backup.config
	cp $dir/nuttx/.config backup.config/$file && echo "arquivo criado"
	echo "type RETURN"
	read a
	cd $dir/nutts

}

helpConfig()
{
	dialog --msgbox 'Basics steps for configuration, build, download and access shell nsh in ESP32:
	1 - create --> create work space nuttx for ESP32;
	2 - selectconfig --> use option nsh
	3 - connect --> connect ESP32-devkit (NODEMCU) to the PC using the usb port
	4 - builddownload --> build and download RTOS
	5 - serialshell --> access shell nsh by serial' 12 80 
}

while true
do
	option=$(dialog --stdout --title "Very simple NUTTX for ESP32" --menu 'Select options (see helpconfig):' 0 0 0 \
		create    'Create RTOS Nuttx Space for ESP32'\
		delete    'Delete Nuttx Space'\
		update    'Update nuttx and apps'\
		distclean 'Remove configuration'\
		clean     'Remove bins'\
		selectconfig 'Select ready configuration'\
		builddownload 'Build and download for ESP32'\
		menuconfig 'Load menuconfig Nuttx'\
		serialshell 'access shell nsh in ESP32 by '$serial\
		configbackup 'Create a config.DATE in directory backup.config'\
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
	configbackup)
		configBackup
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


