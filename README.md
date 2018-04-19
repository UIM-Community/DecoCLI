# DecoCLI
CA UIM - Agent/Device decomission CLI too

```bash
Usage: Usage: perl decocli.pl [options]

A Commande Line Interface (CLI) tool for deleting UIM Robot/Device.

Options:
        [--alarms] Enable disabling of active alarms (Optional) (default: 0)
        [--remove] Remove the robot from his hub (work only when option --type is equal to robot) (Optional) (default: 0)
        [--qos] Enable deletion of QOS History (Optional) (default: 0)
        [--type] Define if we have to remove a network <device> or an UIM <robot> (Optional) (default: robot)
        [--clean] Clean alarms history (Optional) (default: 0)
        [--device] Device name to remove/decom (have to be valid). (Mandatory) (default: none)
```

> Warning: This script has been tested on MySQL. Please open an issue if the script doesn't work with a other DB.

Available DB Type are :

- mysql
- mssql (GDBC)
- oracle

## Goals

The script mainly aims to provide a "safe" way to decom an UIM Robot or a UIM Network device (that work with snmpcollector or a third-party device).

## Features

Most of these features have to be activated on start.

- Remove Device entry.
- Acknowledge active alarms
- Cleanup alarms history and logs.
- Remove UIM Robot from his hub.
- Remove all QoS.
- Remove network device from "activated" snmpcollector probe(s).
- Remove NAS service entry.

## To be implemented 

- Implement QoS cleanup for SSR/MCS
- More test(s) around Database connection string & Request compatibility