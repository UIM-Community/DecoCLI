# DecoCLI
CA UIM - Agent/Device decomission CLI too

A Commande Line Interface (CLI) tool for deleting **one** UIM Agent (Robot) / Network device **at a time**.

## Goals

The script mainly aims to provide a "**safe**" way to decom an UIM Agent or a Network device (that work with the probe snmpcollector).

The script can work with only one equipment at a time and there is no mechanism to filters Alarms or QoS (these kinds of features are not the purpose of this script).

## Features

Most of these features have to be activated on start. (**see the Usage section**).

- Remove the device from UIM (remove_master_devices_by_cskeys).
- Acknowledge active alarms.
- Cleanup alarms history and logs.
- Remove UIM Robot from his hub.
- Remove all QoS.
- Remove MCS/SSR Profile(s).
- Remove network device from "activated" snmpcollector probe(s).
- Remove NAS service entry.

## Prerequisites

To run the script you will to download or get:

- A CA UIM (Nimsoft) **Hub** to deploy the decocli package.
- SDK_Perl (**version 5.10 at least**).

The database library is not bundled with the NimSoft package (there is a chance that you will need to install it with **cpan** on your cible system).

Required cpan package are (for MySQL): 

- [DBI::DBD](http://search.cpan.org/dist/DBI/lib/DBI/DBD.pm)
- [DBD::mysql](http://search.cpan.org/~capttofu/DBD-mysql-4.046/lib/DBD/mysql.pm)

For another database you will have to look for the right driver !

## Usage

The script has to be runned from a terminal with these options (each option have to be prefixed with characters `--`).

```bash
perl decocli.pl [options]
```

For example, if you want to remove an UIM Agent and acknowledge all active alarms you will have to write the following command:

```bash
perl decocli.pl --device yourArgentName --remove --alarms
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

> **Note** The "device" option doesn't have to take any kind of string quote. The device have to match the following regex: **^[a-zA-Z0-9-_@]{2,50}$**

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


## Roadmap

- Audit mode (with a reporting mechanism)
- On demand mode
- More test(s) around Database connection string & Request compatibility