#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "Create PCie $CURRMODEM" "$@"
}


display_top() {
	log "*****************************************************************"
	log "*"
}

display_bottom() {
	log "*****************************************************************"
}


display() {
	local line1=$1
	log "* $line1"
	log "*"
}

ifname1="ifname"
if [ -e /etc/newstyle ]; then
	ifname1="device"
fi

echo 1 > /tmp/gotpcie

if [ ! -f /tmp/bootend.file ]; then
	log "Delay for boot up"
	sleep 1
	while [ ! -f /tmp/bootend.file ]; do
		sleep 1
	done
	sleep 1
fi

log "Connecting a MHI Modem"

lspci -k > /tmp/mhipci
while IFS= read -r line; do
	dev=$(echo "$line" | grep "Device")
	if [ ! -z "$dev" ]; then
		read -r line
		kd=$(echo "$line" | grep "Kernel driver")
		if [ -z "$kd" ]; then
			read -r line
		fi
		mhi=$(echo "$line" | grep "mhi-pci-generic")
		if [ ! -z "$mhi" ]; then
			dev=$(echo "$dev" | tr " " "," | cut -d, -f1)
			size=${#dev}
			if [ "$size" -eq 7 ]; then
				pcinum="0000:$dev"
			else
				pcinum="$dev"
			fi
			break			
		fi
	fi
done < /tmp/mhipci
echo 'on' > /sys/devices/platform/soc/11280000.pcie/pci0000:00/0000:00:00.0/$pcinum/power/control
vendor=$(cat /sys/bus/pci/devices/$pcinum/vendor)
vendor=${vendor:2:4}
device=$(cat /sys/bus/pci/devices/$pcinum/device)
device=${device:2}

subvendor=$(cat /sys/bus/pci/devices/$pcinum/subsystem_vendor)
subvendor=${subvendor:2:4}
subdevice=$(cat /sys/bus/pci/devices/$pcinum/subsystem_device)
subdevice=${subdevice:2}

PCI_VENDOR_ID_QCOM="17cb"
PCI_VENDOR_ID_QUECTEL="1eac"
PCI_VENDOR_ID_FOXCONN="105b"
PCI_VENDOR_ID_THALES="1269"
CURRMODEM=1

case "$vendor" in
	"$PCI_VENDOR_ID_QCOM" )
		if [ "$device" = 0308 ]; then
			if [ "$subvendor" = 1c5d ]; then
				log "Telit FN990 not supported"
				exit 0
			else
				uVid="2c7c"
				uMa="Quectel"
				uPid="0800"
				uPr="RM520"
			fi
		
		fi
	;;
	"$PCI_VENDOR_ID_QUECTEL" )
		if [ "$device" = 1004 -o "$device" = 1007 ]; then 
			uVid="2c7c"
			uMa="Quectel"
			uPid="0800"
			uPr="RM520"
		fi
		if [ "$device" = 1001  -o "$device" = 2001 ]; then
			log "Quectel EM120 not supported"
			exit 0
		fi
		if [ "$device" = 1002  -o "$device" = 100d ]; then
			uVid="2c7c"
			uMa="Quectel"
			uPid="0620"
			uPr="EM160"
		fi
	;;
	"$PCI_VENDOR_ID_FOXCONN" )
		if [ "$device" = e0ab  -o "$device" = e0b0 -o "$device" = e0b1 -o "$device" = e0bf -o "$device" = e0c3 ]; then
			uVid="413c"
			uMa="Foxconn"
			uPid="81d8"
			uPr="T99W175"
		else
			log "Foxconn not supported"
			exit 0
		fi
	;;
	"$PCI_VENDOR_ID_THALES" )
		log "Thales not supported"
		exit 0
	;;
	
esac


display_top; display "Start of Modem Detection and Connection Information"
display "Product=${uPr:-?} $vendor $device Sub $subvendor $subdevice"; display_bottom
	
uci set modem.modem$CURRMODEM.empty=0
uci set modem.modem$CURRMODEM.uVid=$uVid
uci set modem.modem$CURRMODEM.uPid=$uPid
uci set modem.modem$CURRMODEM.idV=$uVid
uci set modem.modem$CURRMODEM.idP=$uPid
uci set modem.modem$CURRMODEM.baseport=0
uci set modem.modem$CURRMODEM.maxport=0
uci set modem.modem$CURRMODEM.proto=91
uci set modem.modem$CURRMODEM.manuf=$uMa
uci set modem.modem$CURRMODEM.model=$uPr
uci set modem.modem$CURRMODEM.serial=xxxx
uci set modem.modem$CURRMODEM.celltype="-"
uci set modem.modem$CURRMODEM.active=1
uci set modem.modem$CURRMODEM.connected=0
uci commit modem
if [ -e $ROOTER/modem-led.sh ]; then
	$ROOTER/modem-led.sh $CURRMODEM 1
fi

/usr/lib/rooter/mhi/create_mhi.sh $CURRMODEM

exit 0
