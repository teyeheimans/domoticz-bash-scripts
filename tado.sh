#!/bin/bash

LOCKFILE="/tmp/synclock"

# Your tado account details
TADO_USER="your@email.address"
TADO_PASS="p@ssw0rd"
TADO_TOKENFILE="/tmp/tadotoken"

# Your domoticz account details
DOMOTICZ_USER="username"
DOMOTICZ_PASS="p@ssw0rd"
DOMOTICZ_PIN="1234"
DOMOTICZ_URL="https://your.domoticz.local:8443";

# Id's of the outside temperature device and the inside temp+humidity device
DOMOTICZ_INSIDE_TEMP_HUM_IDX=96
DOMOTICZ_OUTSIDE_TEMP_IDX=95

MYPATH=$(dirname $0);
VERBOSE=0;

SETTEMP="0";
SETMINS=120;


#
# Awesome parameter parsing, see http://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
#
for i in "$@"
do
case ${i} in
	--temp=* )
		SETTEMP="${i#*=}"
		shift ;
		;;

	--mins=* )
	    SETMINS="${i#*=}"
	    shift ;
	    ;;

	-v | --verbose | verbose)
		VERBOSE=1
		shift ;
		;;

	*)
	    (>&2 echo "Error, unknown parameter \"${i}\" given!");
		;;
	esac
done

#
# Include tado variables, if exists
#
if [ -f "${MYPATH}/tado.conf" ];
then
    source "${MYPATH}/tado.conf"
fi

type jq >/dev/null 2>&1 || { echo >&2 "I require JQ but it's not installed. Aborting."; exit 1; }

JQ=`which jq`

#
# Check if there is a lockfile. This prevents double execution of the script
#
if [[ -f ${LOCKFILE} ]];
then
    # Yes, there is a lockfile.
    # Check if it is more than 60 minutes old
    if test `find "$LOCKFILE" -mmin +60`
    then
        # Lockfile was too old, ignore it and remove it
        rm ${LOCKFILE}
    else
        PID=`cat ${LOCKFILE}`
        if ps -p ${PID} > /dev/null 2>/dev/null
        then
            # Lockfile was new enough, and process still exists. Do NOT run this cron!
            if [[ ${VERBOSE} -eq 1 ]]
            then
                echo >&2 "Job was already running"
            fi
            exit
        else
            # Lockfile was new enough, however process does not exist anymore. Remove lockfile and continue.
            rm ${LOCKFILE}
        fi
    fi
fi

#
# Display verbose output if wanted
#
function verbose()
{
    if [[ ${VERBOSE} -eq 1 ]];
    then
        echo $1;
    fi
}

#
# This function is responsible for fetching results from the TADO API.
# The response is placed in a variable called $JSON.
#
function fetchResponse()
{
    URL=$1
    PUTDATA="";
    ATTEMPT=1

    if [[ ! -z "$2" ]];
    then
        PUTDATA="$2";
    fi

    if [[ ! -z "$3" ]];
    then
        ATTEMPT="$3"
    fi

    if [[ "${PUTDATA}" != "" ]];
    then
        verbose "Fetch result for url: ${URL}";
        verbose "Putting data: ${PUTDATA}";
        JSON=$(curl -s -X PUT "${URL}" --connect-timeout 10 -H "Authorization: Bearer `cat ${TADO_TOKENFILE}`" -H "Content-Type:application/json;charset=UTF-8" --data-binary "${PUTDATA}");
    else
        verbose "Fetch result for url: ${URL}";
        JSON=$(curl -s "${URL}" --connect-timeout 10 -H "Authorization: Bearer `cat ${TADO_TOKENFILE}`");
    fi

    # Token failure? Then retry
    if [[ ${JSON} == *"Access token expired"* ]];
    then
        verbose "Access token is expired, fetch new one... (Attempt ${ATTEMPT})";

        # If we did not retried yet..
        if [[ ${ATTEMPT} -le 2 ]];
        then
            ATTEMPT=$((ATTEMPT+1));
            fetchToken;

            fetchResponse "${URL}" "${PUTDATA}" "${ATTEMPT}";
        fi
    fi
}

#
# Retrieve a new TADO token and put it in the $TADO_TOKENFILE file.
#
function fetchToken {
    verbose "Retrieving new tado token... ";
    curl --connect-timeout 10 -s "https://my.tado.com/oauth/token" -d client_id=public-api-preview -d client_secret=4HJGRffVR8xb3XdEUQpjgZ1VplJi6Xgw -d grant_type=password -d scope=home.user -d username=${TADO_USER} -d password=${TADO_PASS} | ${JQ} -r '.access_token' > ${TADO_TOKENFILE};
}

#
# Start execution of the script
#
DATE=$(date +"%d-%m-%Y %k:%M");
verbose "Date: ${DATE}"

if [[ ! -f ${TADO_TOKENFILE} ]];
then
    verbose "Tado token file is missing, fetch new one...";
    fetchToken;
fi

TOKEN=`cat ${TADO_TOKENFILE}`
if [[ "${TOKEN}" = "" ]] || [[ "${TOKEN}" = "null" ]];
then
	verbose "Token is empty, fetching new one...";
	fetchToken;
fi

#
# First, fetch the home id.
#
fetchResponse "https://my.tado.com/api/v2/me"
HOMEID=$(echo ${JSON} | ${JQ} -r '.homes[0].id' )

verbose "HOME ID: ${HOMEID}" ;

if [[ "${HOMEID}" = "null" ]] || [[ "${HOMEID}" = "" ]];
then
  (>&2 echo "Error, we failed to fetch HOME id")
  exit 1;
fi

#
# Set the temperature if wanted
#
if [[ ${SETTEMP} != "0" ]];
then
    SETSEC=$((SETMINS*60))
    verbose "Set current temperature for ${SETMINS} minutes ( = ${SETSEC} seconds)"
    fetchResponse "https://my.tado.com/api/v2/homes/${HOMEID}/zones/1/overlay" "{\"setting\":{\"type\":\"HEATING\",\"power\":\"ON\",\"temperature\":{\"celsius\":${SETTEMP}}},\"termination\":{\"type\":\"TIMER\",\"durationInSeconds\":${SETSEC}}}"
    verbose ${JSON};

    TADOTEMP=$(echo ${JSON} | ${JQ} '.setting.temperature.celsius');

    if [[ ${TADOTEMP} -eq ${SETTEMP} ]];
    then
        verbose "Temperature SUCCESSFUL set to ${SETTEMP} C";
    else
        verbose "ERROR, something went wrong while setting the temperature. Raw response: ${JSON}";
    fi

    # Stop the script
    verbose "Done!\n";
    exit 0;
fi

#
# Now fetch the inside temperature and humidity. Note: we assume that device 1 is the thermostat.
#
fetchResponse "https://my.tado.com/api/v2/homes/${HOMEID}/zones/1/state"
TEMP=$(echo ${JSON} | ${JQ} '.sensorDataPoints.insideTemperature.celsius');
HUMIDITY=$(echo ${JSON} | ${JQ} '.sensorDataPoints.humidity.percentage');

#
# Now fetch the outside temperature
#
fetchResponse "https://my.tado.com/api/v2/homes/${HOMEID}/weather"
OUTSIDE_TEMP=$(echo ${JSON} | ${JQ} '.outsideTemperature.celsius');

verbose "Temperature: ${TEMP}";
verbose "Humidity: ${HUMIDITY}"
verbose "Outside Temperature: ${OUTSIDE_TEMP}";
verbose "Push values to domoticz...";
URL="${DOMOTICZ_URL}/json.htm?type=command&param=udevice&idx=${DOMOTICZ_OUTSIDE_TEMP_IDX}&nvalue=0&svalue=${OUTSIDE_TEMP}&passcode=${DOMOTICZ_PIN}";

verbose "Requesting URL: ${URL}";
OUTPUT=$(curl --connect-timeout 10 -u ${DOMOTICZ_USER}:${DOMOTICZ_PASS} -k -s "${URL}");
verbose "$OUTPUT";

URL="${DOMOTICZ_URL}/json.htm?type=command&param=udevice&idx=${DOMOTICZ_INSIDE_TEMP_HUM_IDX}&nvalue=0&svalue=${TEMP};${HUMIDITY};0&passcode=${DOMOTICZ_PIN}";
verbose "Requesting URL: ${URL}";
OUTPUT=$(curl --connect-timeout 10 -u ${DOMOTICZ_USER}:${DOMOTICZ_PASS} -k -s "${URL}");
verbose "$OUTPUT";

verbose "Done!\n";
exit 0;
