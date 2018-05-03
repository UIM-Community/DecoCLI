# DecoCLI
CA UIM - Agent/Device decomission CLI too

A Commande Line Interface (CLI) tool for deleting UIM Robot/Device.

## Goals

The script mainly aims to provide a "**safe**" way to decom an UIM Robot or a Network device (that work with snmpcollector or a third-party device).

## Features

Most of these features have to be activated on start. (see the Usage section).

- Remove the device from UIM (remove_master_devices_by_cskeys).
- Acknowledge active alarms.
- Cleanup alarms history and logs.
- Remove UIM Robot from his hub.
- Remove all QoS.
- Remove network device from "activated" snmpcollector probe(s).
- Remove NAS service entry.

## Usage

The script has to be runned with these options (each option have to be prefixed with `--`).

```bash
perl decocli.pl [options]
```

it must be run with Nimsoft's perl (normally installed in `nimsoft/perl/bin/perl5.14.2`).

| command name | description | default | mandatory |
| --- | --- | --- | --- |
| help | Output usage and all available options with description (**it will exit the script on start**). | none | no |
| version | Ouput the CLI version (**it will exit the script on start**). | none | no |
| device | The device name that have to be removed/decom. | none | yes |
| type | Define if we have to remove a network `device` or an UIM (Nimsoft) `robot` | robot | no |
| alarms | Enable acknowledge of all active alarms | 0 | no |
| qos | Enable deletion of all QOS History | 0 | no |
| remove | Remove the robot from his hub (work only when option --type is equal to robot) | 0 | no |
| clean | Clean alarms history and logs | 0 | no |
| force | Continue to work even if remove_from_uim() method fail (useful to remove devices that are not in cm_computer table). | 0 | no |

## Configuration

```xml
<setup>
    nimbus_login =
    nimbus_password = 
    close_alarms_by = decocli
</setup>
<database>
    type = mysql
    database = ca_uim
    host = 
    port = 3306
    user = 
    password = NimSoft!01
</database>
```

The **nimbus_login** and **nimbus_password** are required to authenticate the script to NimBUS (remember this script has not been created to be runned as a probe).

**close_alarms_by** is used when all alarms are acknowledged (to know who is responsible for).

### Available DB Type are :

- mysql
- mssql (GDBC)
- oracle

> Warning: This script has been tested on MySQL. Please open an issue if the script doesnt work with a others.


## To be implemented 

- Refactor findProbesByName to return all ADDR.
- Implement QoS cleanup for SSR/MCS
- More test(s) around Database connection string & Request compatibility