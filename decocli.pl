# use perl5 core dependencie(s)
use strict;
use warnings;

# Use Nimbus dependencie(s)
# Update path depending on your system!
$ENV{'NIM_ROOT'} = "/opt/nimsoft";
use lib "/opt/nimsoft/perllib/";
use lib "/opt/nimsoft/perl/";
use Nimbus::API;
use Nimbus::PDS;
use Nimbus::CFG;

# Use internal dependencie(s)
use src::utils qw(findProbeByHisName);
use src::uimdb;
use src::cli;

#
# DESC: print to STDERR unexpected die handle
#
$SIG{__DIE__} = \&exitScriptWithError;
sub exitScriptWithError {
    my ($err) = @_;
    print STDERR "$err\n";
    exit 1;
}

# Declare script GLOBALS & CONSTANTS
use constant {
    VERSION => "1.0.0"
};
my $deviceRegex = '^[a-zA-Z0-9-_@]{2,50}$';
my ($deviceName, $closeBy);

#
# DESC: Setup available CLI command(s)
#
my $cli = src::cli->new({
    usage => "Usage: perl decocli.pl [options]",
    description => "A Commande Line Interface (CLI) tool for deleting UIM Robot/Device.",
    version => "1.0.0"
});

# --device command to set string* device name
$cli->setCommand("device", {
    description => "The device name that have to be removed/decom.",
    match => qr/$deviceRegex/,
    required => 1
});

# --type define if we work with a Network device or a UIM Robot.
$cli->setCommand("type", {
    expect => ["robot", "device"],
    description => "Define if we have to remove a network `device` or an UIM (Nimsoft) `robot`",
    defaultValue => "device"
});

# --alarms Enable the option that will acknowledge all active alarms!
$cli->setCommand("alarms", {
    description =>  "Enable acknowledge of all active alarms",
    defaultValue => 0
});

# --qos Enable delete of all QoS history
$cli->setCommand("qos", {
    description => "Enable deletion of all QOS History",
    defaultValue => 0
});

# --remove Remove the UIM Robot from his hub (Work only for type robot).
$cli->setCommand("remove", {
    description => "Remove the robot from his hub (work only when option --type is equal to robot)",
    defaultValue => 0
});

# --clean Remove alarms history
$cli->setCommand("clean", {
    description => "Clean alarms history and logs",
    defaultValue => 0
});

# --nokia Enable decom of SNMP Nokia device
$cli->setCommand("nokia", {
    description => "Enable decom of SNMP Nokia device",
    defaultValue => 0
});

#
# DESC: Remove Device/Agent from UIM with discovery_server probe
#
sub remove_from_uim {
    my ($DB, $Robotname, $nasAddr) = @_;
    print STDOUT "---------------------------\n";
    print STDOUT "Entering step - remove_from_uim\n";

    # Get CS Key
    my $cs_key = $DB->cs_key($deviceName);
    return 0 if not defined($cs_key);
    print STDOUT "Device cs_key => $cs_key\n";

    # Find (at least one) Discovery_server Addr
    my $addr = findProbeByHisName("discovery_server");
    return 0 if not defined($addr);
    print STDOUT "Discovery_server Addr found: $addr\n";

    # Trigger callback remove_master_devices_by_cskeys on discovery_server
    {
        my $PDS = Nimbus::PDS->new();
        $PDS->string("csKeys", $cs_key);
        my ($RC, $AlarmsRET) = nimNamedRequest($addr, "remove_master_devices_by_cskeys", $PDS->data);
        if($RC != NIME_OK) {
            my $nimError = nimError2Txt($RC);
            print STDERR "Failed to trigger callback remove_master_devices_by_cskeys, Error ($RC): $nimError\n";

            return 0;
        }
    }

    # Cleanup nas service memory table (not mandatory).
    my $PDS = Nimbus::PDS->new();
    $PDS->string("ip", $deviceName);
    my ($RC, $AlarmsRET) = nimNamedRequest($nasAddr, "nameservice_delete", $PDS->data);
    if($RC != NIME_OK) {
        my $nimError = nimError2Txt($RC);
        print STDERR "Failed to trigger callback nameservice_delete on NAS, Error ($RC): $nimError\n";
    }

    return 1;
}

#
# DESC: Remove the robot from his UIM Hub
#
sub remove_robot {
    print STDOUT "---------------------------\n";
    print STDOUT "Entering step - remove_robot\n";

    # Try to find the UIM Robot addr
    my $hubAddr;
    {
        my $PDS = Nimbus::PDS->new();
        $PDS->string("robotname", $deviceName);
        my ($RC, $nimRET) = nimFindAsPds($PDS->data, NIMF_ROBOT);
        if ($RC != NIME_OK) {
            my $nimError = nimError2Txt($RC);
            print STDERR "Failed to find robot addr for $deviceName, Error ($RC): $nimError\n";

            return;
        }

        # Get the device hub addr
        my $addr = Nimbus::PDS->new($nimRET)->getTable("addr", PDS_PCH);
        return if not defined($addr);
        print STDOUT "Device Nimsoft addr => $addr\n";

        my @groups = split("/", $addr);
        $hubAddr = "/$groups[1]/$groups[2]/hub";
        print STDOUT "Device Nimsoft hub addr => $hubAddr\n";
    }

    # trigger removerobot callback on hub
    my $PDS = Nimbus::PDS->new();
    $PDS->string("name", $deviceName);
    my ($RC, $nimRET) = nimNamedRequest($hubAddr, "removerobot", $PDS->data);
    if ($RC != NIME_OK) {
        my $nimError = nimError2Txt($RC);
        print STDERR "Failed to remove device $deviceName from hub $hubAddr, Error ($RC): $nimError\n";

        return;
    }
    print STDOUT "Successfully removed the device $deviceName from hub $hubAddr\n";
}

#
# DESC: Remove the device from any collectors
#
sub remove_collector {
    my ($DB, $nokiadecom) = @_;
    print STDOUT "---------------------------\n";
    print STDOUT "Entering step - remove_collector\n";

    # Retrieve all snmpcollector probes
    my $PDS = Nimbus::PDS->new();
    $PDS->string("probename", "snmpcollector");
    my ($RC, $nimRET) = nimFindAsPds($PDS->data, NIMF_PROBE);
    if ($RC != NIME_OK) {
        my $nimError = nimError2Txt($RC);
        print STDERR "Failed to find any snmpcollector Addr, Error ($RC): $nimError\n";
    }
    else {
        undef $RC;
        undef $PDS;

        # Delete our network host for every snmpcollector probe(s) retrieved
        my $PDSRet = Nimbus::PDS->new($nimRET);
        my $SNMPPDS = Nimbus::PDS->new();
        $SNMPPDS->string("Host", $deviceName);
        for( my $i = 0; my $addr = $PDSRet->getTable("addr", PDS_PCH, $i); $i++) {
            print STDOUT "Found an snmp_collector probe at $addr\n";
            my ($RC, $AlarmsRET) = nimNamedRequest($addr, "remove_snmp_device", $SNMPPDS->data);
            if($RC != NIME_OK) {
                my $nimError = nimError2Txt($RC);
                print STDERR "Failed to execute callback `remove_snmp_device` on probe snmpcollector at $addr, Error ($RC): $nimError\n";
                next;
            }
            print STDOUT "Successfully trigerred callback `remove_snmp_device`\n";
        }
    }

    # Insert new row for nokia_ipsla probe!
    if ($nokiadecom == 1) {
        print STDOUT "Decom nokia_ipsla device\n";
        $DB->decom_nokiaipsla($deviceName);
    }
}

#
# DESC: Close "active" alarms for the subject
# 
sub close_alarms {
    my ($Robotname, $addr) = @_;
    print STDOUT "---------------------------\n";
    print STDOUT "Entering step - close_alarms\n";

    # Get alarms table from NAS probe
    my $PDS = Nimbus::PDS->new();
    $PDS->string("hostname", $deviceName);
    my ($RC, $AlarmsRET) = nimNamedRequest($addr, "get_alarms", $PDS->data);
    if($RC != NIME_OK) {
        my $nimError = nimError2Txt($RC);
        print STDERR "Failed to get alarms for device $deviceName, Error ($RC): $nimError\n";

        return;
    }
    undef $PDS;
    undef $RC;

    # Close all retrieved alarms !
    my $PPDS = Nimbus::PDS->new($AlarmsRET);
    for( my $i = 0; my $AlarmPDS = $PPDS->getTable("alarms", PDS_PDS, $i); $i++) {
        my $nimid = $AlarmPDS->get("nimid");
        print "Closing alarm with nimid => $nimid\n";

        my $PDS = Nimbus::PDS->new();
        $PDS->string("by", $closeBy);
        $PDS->string("nimid", $nimid);
        my ($RC) = nimNamedRequest($addr, "close_alarms", $PDS->data);
        if ($RC != NIME_OK) {
            my $nimError = nimError2Txt($RC);
            print STDERR "Failed to close alarm $nimid, Error ($RC): $nimError\n";
        }
    }
}

#
# DESC: Clean alarms history
#
sub clean_alarms_history {
    my ($DB) = @_;
    print STDOUT "---------------------------\n";
    print STDOUT "Entering step - clean_alarms_history\n";

    $DB->clean_alarms_history($deviceName);
}

#
# DESC: Delete ALL Quality of Service for the subject
#
sub delete_qos {
    my ($DB) = @_;
    print STDOUT "---------------------------\n";
    print STDOUT "Entering step - delete_qos\n";

    $DB->clean_qos($deviceName);
}

#
# DESC: Initialize and execute each steps
#
sub main {

    # Init CLI options
    my $argv = $cli->init;
    my $type = $argv->{type};
    $deviceName = $argv->{device};

    # Open the local configuration file
    my $CFG = Nimbus::CFG->new("decocli.cfg");
    if (not defined($CFG->{"setup"})) {
        die "The section <setup> of decocli.cfg is mandatory";
    }
    $closeBy = $CFG->{"setup"}->{"close_alarms_by"} || "decocli";

    # Connect the script to Nimbus (mandatory).
    my ($nimCS) = nimLogin(
        $CFG->{"setup"}->{"nimbus_login"} || "administrator",
        $CFG->{"setup"}->{"nimbus_password"}
    );
    if (not defined $nimCS) {
        die "Unable to establish a proper connection to NimBUS. Please review setup.nimbus_login and setup.nimbus_password";
    }
    print STDOUT "Successfully connected to NimBUS!\n";

    # GET The current robotname for further nimRequests (mandatory).
    my ($RC, $Robotname) = nimGetVarStr(NIMV_ROBOTNAME);
    if ($RC != NIME_OK) {
        my $nimError = nimError2Txt($RC);
        die "Unable to get the current UIM Robot name, Error ($RC): $nimError\n"
    }
    print STDOUT "Current (local) UIM Robot name: $Robotname\n\n";
    undef $RC;

    my $DB;
    # Initialize a connection to the product table!
    {
        my $DBType  = $CFG->{"database"}->{"type"} || "mysql";
        my $db      = $CFG->{"database"}->{"database"} || "ca_uim";
        my $host    = $CFG->{"database"}->{"host"} || "127.0.0.1";
        my $port    = $CFG->{"database"}->{"port"} || 33006;
        my $user    = $CFG->{"database"}->{"user"} || "sa";
        my $passwd  = $CFG->{"database"}->{"password"} || "";

        my $CS;
        if ($DBType eq "mysql") {
            $CS = "DBI:mysql:database=$db;host=$host;port=$port";
        }
        elsif ($DBType eq "mssql") {
            $CS = "DBI:ODBC:Driver={SQL Server};SERVER=$host,$port;Database=$db;UID=$user;PWD=$passwd"
        }
        elsif ($DBType eq "oracle") {
            $CS = "DBI:Oracle:host=$host;sid=$db;port=$port";
        }
        print STDOUT "SQL connection string: $CS\n";
        $DB = src::uimdb->new($DBType, $CS, $user, $passwd);
        $DB->{DB}->do("use ${db};") if $DBType eq "mssql";
    }
    undef $CFG;

    # Find (at least one) NAS Addr
    my $nasAddr = findProbeByHisName("nas");
    return if not defined($nasAddr);
    print STDOUT "NAS Addr found: $nasAddr\n";

    # Finally execute each steps
    my $iRC = remove_from_uim($DB, $Robotname, $nasAddr);
    die "Failed to terminate remove_from_uim without critical error(s)!" if $iRC == 0;

    remove_robot($Robotname) if $type eq "robot" && $argv->{remove} == 1;
    remove_collector($DB, $argv->{nokia}) if $type eq "device";
    close_alarms($Robotname, $nasAddr) if $argv->{alarms} == 1;
    clean_alarms_history($DB) if $argv->{clean} == 1;
    delete_qos($DB) if $argv->{qos} == 1;

    $DB->{DB}->disconnect();
    print STDOUT "---------------------------\n";
    print STDOUT "\nExiting CLI tool with code 0\n";
}

# Execute main script handler!
eval {
    main();
};
print STDERR $@ if $@;
exit 0;