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

##### Example verbose output #####

```
Date: 03-04-2017 21:27
Fetch result for url: https://my.tado.com/api/v2/me
HOME ID: 1234
Fetch result for url: https://my.tado.com/api/v2/homes/1234/zones/1/state
Fetch result for url: https://my.tado.com/api/v2/homes/1234/weather
Temperature: 20.35
Humidity: 60.3
Outside Temperature: 8.03
Push values to domoticz...
{ "status" : "OK", "title" : "Update Device" }
{ "status" : "OK", "title" : "Update Device" }
Done!
```

# phone-presence.sh #

This script is used to detect if a phone is in the network. We use ARP because iPhone's won't respond on ping when the
are in sleep mode.

To make this script work you should assign a static ip address to your device based on your devices mac address.

By default we will assume that your phone is "gone" after it has received 5 times an offline status. This is to prevent 
hickups which will keep flapping your device status.

In general the ON detection will be quite fast, but the OFF detection will take some longer. This is because there are
a lot of "false-positives" where it seems that the device is offline, but it is not. This is also why the cooldown 
period is build in. 

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

##### Example verbose output #####

```
=== Starting scan for device with idx 72 on ip 10.0.1.213 with Mac address 34:ee:fd:60:9a:11 ===
Idx: 72, ip: 10.0.1.213, mac: 34:ee:fd:60:9a:11
Status of request: OK
Current device status: On
Mac address: 34:ee:fd:60:9a:11
State: ON, known state: On

=== Starting scan for device with idx 71 on ip 10.0.1.212 with Mac address e0:ff:45:9e:2c:22 ===
Idx: 71, ip: 10.0.1.212, mac: e0:ff:45:9e:2c:22
Status of request: OK
Current device status: On
Mac address: e0:ff:45:9e:2c:22
State: OFF, known sate: On, attempt 5/5
UPDATE STATE TO OFF!
{ "status" : "OK", "title" : "SwitchLight" }
```