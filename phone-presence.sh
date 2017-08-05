#!/bin/bash

LOCKFILE="/tmp/synclock"

# Enter your domoticz account details here.
DOMOTICZ_USER="username"
DOMOTICZ_PASS="p@ssw0rd"
DOMOTICZ_PIN=12344
DOMOTICZ_URL="https://domoticz.url:8443";

# attempts before we assume it's offline
COOLDOWN_COUNTER=5;

type hping3 >/dev/null 2>&1 || { echo >&2 "I require hping3 but it's not installed. Aborting."; exit 1; }
type jq >/dev/null 2>&1 || { echo >&2 "I require JQ but it's not installed. Aborting."; exit 1; }

#
# Here is a list of devices we want to check.
# Each line has:
# '${idx} ${ip} ${mac-address}'
#
# Note! Mac address is case sensitive!
#
PHONE_DEVICES=(
    '72 10.0.1.213 34:ee:fd:60:9a:11'
    '71 10.0.1.212 e0:ff:45:9e:2c:22'
);

MYPATH=$(dirname $0);
VERBOSE=0;

if [[ "$#" -ge 1 ]] ;
then
    if [[ $1 == "verbose" ]] || [[ $1 == "--verbose" ]] || [[ $1 == "-v" ]];
    then
        VERBOSE=1;
    fi;
fi;

#
# Include variables file, if exists
#
if [ -f "${MYPATH}/phone-presence.conf" ];
then
    source "${MYPATH}/phone-presence.conf"
fi


JQ=`which jq`
HPING=`which hping3`


# check if there is a lockfile
if [ -f $LOCKFILE ];
then
    # Yes, there is a lockfile.
    # Check if it is more than 60 minutes old
    if test `find "$LOCKFILE" -mmin +60`
    then
        # Lockfile was too old, ignore it and remove it
        rm $LOCKFILE
    else
        PID=`cat $LOCKFILE`
        if ps -p $PID > /dev/null 2>/dev/null
        then
            # Lockfile was new enough, and process still exists. Do NOT run this cron!
            if [[ $VERBOSE -eq 1 ]]
            then
                echo "Job was already running" >/dev/stderr
            fi
            exit
        else
            # Lockfile was new enough, however process does not exist anymore. Remove lockfile and continue.
            rm $LOCKFILE
        fi
    fi
fi

#
# Display verbose output if wanted
#
function verbose {
    if [[ $VERBOSE -eq 1 ]];
    then
        echo $1;
    fi
}

#
# Function to check device
#
function check_device {
	idx=$1
	ip=$2
	mac=$3

	# Ping device to fetch ARP record
	verbose "Executing hping command:"
	verbose "$HPING -2 -c 10 -p 5353 -i u1 ${ip} -q"
	$HPING -2 -c 10 -p 5353 -i u1 ${ip} -q >/dev/null 2>&1;

	# Fetch all current devices
	declare -a DEVICES
	DEVICES=`/usr/sbin/arp -an | awk '{print $4}'`

	verbose "Idx: ${idx}, ip: ${ip}, mac: ${mac}";

	# Fetch known state
	json=$(curl -u ${DOMOTICZ_USER}:${DOMOTICZ_PASS} --connect-timeout 10 -k -s "${DOMOTICZ_URL}/json.htm?type=devices&filter=all&used=true&order=Name")

	status=`echo $json | ${JQ} -r '.status'`
	verbose "Status of request: ${status}";

	if [[ "${status}" == "OK" ]] ;
	then
		known_state=$(echo $json | ${JQ} -r ".result[] | select(.idx == \"${idx}\") | .Status")
		verbose "Current device status: ${known_state}"
	else
		echo >&2 "${DOMOTICZ_URL}/json.htm?type=devices&filter=all&used=true&order=Name";
		echo >&2 "Error, failed to fetch JSON response from domoticz";
		exit 1;
	fi

	failfile="/tmp/${idx}-offline-check"


	if [ -f ${failfile} ];
	then
		failcounter=`cat ${failfile}`
	else
		failcounter=1;
	fi

	verbose "Mac address: ${mac}"
	#echo ${DEVICES[*]}
	if [[ ${DEVICES[*]} =~ ${mac} ]]
	then
		verbose "State: ON, known state: ${known_state}"
		if [ -f ${failfile} ];
		then
			rm "${failfile}";
		fi

		if [ "${known_state}" != "On" ];
		then
			verbose "UPDATE STATE TO ON!";
			response=$(curl -u ${DOMOTICZ_USER}:${DOMOTICZ_PASS} --connect-timeout 10 -k -s "${DOMOTICZ_URL}/json.htm?type=command&param=switchlight&idx=${idx}&switchcmd=On&level=0&passcode=${DOMOTICZ_PIN}")
			verbose "$response"
		fi
	else
		verbose "State: OFF, known sate: ${known_state}, attempt ${failcounter}/${COOLDOWN_COUNTER}";

		if [ "${known_state}" != "Off" ];
		then
			((failcounter++));

			# store max attempts
			echo "${failcounter}" > "${failfile}";

			if [[ ${failcounter} -le ${COOLDOWN_COUNTER} ]];
			then
				verbose "We are still in cooldown period. Do nothing...";
			else 
				verbose "UPDATE STATE TO OFF!";
				response=$(curl -u ${DOMOTICZ_USER}:${DOMOTICZ_PASS} --connect-timeout 10 -k -s "${DOMOTICZ_URL}/json.htm?type=command&param=switchlight&idx=${idx}&switchcmd=Off&level=0&passcode=${DOMOTICZ_PIN}")
				verbose "$response"
			fi			
		else
			verbose "Known state is already off. Do nothing...";
			if [ -f ${failfile} ];
	        then
    	        rm "${failfile}";
	        fi
		fi
	fi
	verbose "";
}

#
# Walk all devices to check
#
i=0;
while [ "$i" -lt "${#PHONE_DEVICES[@]}" ];
do
    DEVICE=(${PHONE_DEVICES[i]});
    IDX=${DEVICE[0]};
    IP=${DEVICE[1]};
    MAC=${DEVICE[2]};

    verbose "=== Starting scan for device with idx ${IDX} on ip ${IP} with Mac address ${MAC} === ";

    check_device ${IDX} ${IP} ${MAC};
    ((i++));
done

