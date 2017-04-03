# domoticz-bash-scripts
Bash scripts to collect data for domoticz.

This project contains 2 simple bash scripts which I use to collect data and push it to domoticz. 

### Dependencies ### 

Both scripts depend on the [`jq`](https://stedolan.github.io/jq/) binary. jq is a json processor for bash. 

Both scripts check if there is already another process running the script. It's not possible to run multple instances 
of the same script simultaneously.

# tado.sh #

This script collects the inside temperature, humidity and the outside temperature from a Tado Thermostat. It pushes 
these values to domoticz.
 
##### Domoticz preperation #####

To make this script work you should have added two dummy devices to your domoticz. 
  1. `Temp+Hum` virtual sensor for the inside temperature and humidity.  
  2. `Temperature` for the outside temperature.

You need to write down the `IDX` id's of these devices. You can find these in the domoticz menu: <br />
`Setup` -> `More options` -> `Events` and then press the button in the right bottom corner: `Show current states`.

##### Tado preperation #####

You should have a Tado Thermostat installed, and thus have a Tado account. For the rest there is no preperation needed.

##### Configuring the script #####

You should place a file called `tado.conf` in the same directory as the script. This file should contain these variables:
```bash

# Enter here your TADO email address
TADO_USER="your@email.address"

# Enter here your TADO password
TADO_PASS="p@ssw0rd"

# Enter here your domoticz username
DOMOTICZ_USER="username"

# Enter here your domoticz password
DOMOTICZ_PASS="p@ssw0rd"

# Enter here your domoticz pincode. Leave blank if you do not use this
DOMOTICZ_PIN="1234"

# Enter here the domoticz URL with port number.
DOMOTICZ_URL="https://your.domoticz.local:8443"

# Id of the inside temp+humidity device
DOMOTICZ_INSIDE_TEMP_HUM_IDX=96

# Id of the outside temperature device
DOMOTICZ_OUTSIDE_TEMP_IDX=95
```

##### Executing the script #####

You can execute the script is easy. You can call it like this:
```bash 
# Call the tado script (assume its in your current working directory)
bash ./tado.sh

# Or call it in verbose mode:
bash ./tado.sh --verbose

# Or give the script execute permissions:
sudo chmod u+x ./tado.sh
# and then call it like this:
./tado.sh --verbose
```

# phone-presence.sh #

This script is used to detect if a phone is in the network. We use ARP because iPhone's won't respond on ping when the
are in sleep mode.

By default we will assume that your phone is "gone" after it has received 5 times an offline status. This is to prevent 
hickups which will keep flapping your device status.

##### Domoticz preperation #####

To make this script work you should have added a dummy device (switch) to your domoticz. This represents the on/off 
(presence) state of your phone.

You need to write down the `IDX` id of the device. You can find these in the domoticz menu: <br />
`Setup` -> `More options` -> `Events` and then press the button in the right bottom corner: `Show current states`.

##### Configuring the script #####

You should place a file called `phone-presence.conf` in the same directory as the script. This file should contain these variables:
```bash
# Enter here your domoticz username
DOMOTICZ_USER="username"

# Enter here your domoticz password
DOMOTICZ_PASS="p@ssw0rd"

# Enter here your domoticz pincode. Leave blank if you do not use this
DOMOTICZ_PIN="1234"

# Enter here the domoticz URL with port number.
DOMOTICZ_URL="https://your.domoticz.local:8443"

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
)

# attempts before we assume it's offline
COOLDOWN_COUNTER=5
```

##### Executing the script #####

You can execute the script is easy. You can call it like this:
```bash 
# Call the tado script (assume its in your current working directory)
bash ./phone-presence.sh

# Or call it in verbose mode:
bash ./phone-presence.sh --verbose

# Or give the script execute permissions:
sudo chmod u+x ./phone-presence.sh
# and then call it like this:
./phone-presence.sh --verbose
```