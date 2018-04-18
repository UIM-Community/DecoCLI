#!/opt/nimsoft/perl/bin/perl5.14.2
# use perl5 core dependencie(s)
use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Scalar::Util qw(looks_like_number);

# Use Nimbus dependencie(s)
# Update path depending on your system!
$ENV{'NIM_ROOT'} = "/opt/nimsoft";
use lib "/opt/nimsoft/perllib/";
use lib "/opt/nimsoft/perl/";
use Nimbus::API;
use Nimbus::PDS;
use Nimbus::CFG;

# Use internal dependencie(s)
use src::utils qw(scriptArgsAsHash checkDefined);
use src::uimdb;

#
# DESC: print to STDERR unexpected die handle
#
$SIG{__DIE__} = \&exitScriptWithError;
sub exitScriptWithError {
    my ($err) = @_;
    print STDERR "$err\n";
    exit(1);
}

# Declare script GLOBALS & CONSTANTS
use constant {
    VERSION => "1.0.0"
};
my ($type, $deleteQoS, $closeAlarms, $removeRobot, $cleanAlarms, $deviceName, $closeBy);

#
# DESC: Get start script arguments (with default payload)
#
my $script_arguments = scriptArgsAsHash({
    type => "robot"
});

#
# DESC: Script start arguments contains --h and/or --help
#
if (defined $script_arguments->{h} || defined $script_arguments->{help}) {
    print STDOUT "\nUsage: perl decocli.pl [options]\n\n";
    print STDOUT "\t< perl decocli.pl --device name --type device --alarms --qos >\n\n";
    print STDOUT "A Commande Line Interface (CLI) tool for deleting UIM Robot/Device.\n\n";
    print STDOUT "Options:\n";
    print STDOUT "\t-h, --help        output usage information\n";
    print STDOUT "\t-v, --version     output the version number\n";
    print STDOUT "\t-d, --device      Device name to remove/decom. This option is mandatory.\n";
    print STDOUT "\t-t, --type        Define if we have to remove a network <device> or an UIM <robot>\n";
    print STDOUT "\tPossible values are: <robot> or <device> and the default value if none: robot\n\n";
    print STDOUT "\t-a, --alarms      Enable disabling of active alarms\n";
    print STDOUT "\t-q, --qos         Enable deletion of QOS History\n";
    print STDOUT "\t-r, --remove      Remove the robot from his hub (work only when option --type is equal to robot)\n";
    print STDOUT "\t-c, --clean       Clean alarms history\n";
    print STDOUT "\n";

    # Help will automatically exit the script
    exit 0;
}

#
# DESC: Script start arguments contains --v and/or --version
#
if (defined $script_arguments->{v} || defined $script_arguments->{version}) {
    print STDOUT "Version ".VERSION."\n\n";

    # Output script version will automatically exit the script
    exit 0;
}

#
# DESC: Device have to be defined
#
if (defined $script_arguments->{device} || defined $script_arguments->{d}) {
    $deviceName = $script_arguments->{device} || $script_arguments->{d};
    $deviceName =~ s/^\s+|\s+$//g;
    if ($deviceName eq "" || looks_like_number($deviceName)) {
        die "Device name is mandatory. It can't be an empty string or a number.\n";
    }
}
else {
    die "Device name is mandatory. Please, define a device with the command --d [name] or --device [name]\n";
}

#
# DESC: Check CLI default arguments and values
#
if (defined $script_arguments->{type} || defined $script_arguments->{t}) {
    $type = $script_arguments->{type} || $script_arguments->{t};
    $type =~ s/^\s+|\s+$//g;
    if ($type ne "robot" && $type ne "device") {
        die "Invalid value for option --type. It should be equal to one of these values: robot or device\n";
    }
}
$deleteQoS = checkDefined($script_arguments, 0, ["qos", "q"]);
$closeAlarms = checkDefined($script_arguments, 0, ["alarms", "a"]);
$removeRobot = checkDefined($script_arguments, 0, ["remove", "r"]);
$cleanAlarms = checkDefined($script_arguments, 0, ["clean", "c"]);

#
# DESC: Find a probe addr by his name
#
sub find_probe_byname {
    my ($probeName) = @_;

    my $PDS = Nimbus::PDS->new();
    $PDS->string("probename", $probeName);
    my ($RC, $nimRET) = nimFindAsPds($PDS->data, NIMF_PROBE);
    if ($RC != NIME_OK) {
        my $nimError = nimError2Txt($RC);
        print STDERR "Failed to find any $probeName Addr, Error ($RC): $nimError\n";

        return undef;
    }

    return Nimbus::PDS->new($nimRET)->getTable("addr", PDS_PCH);
}

#
# DESC: Remove Device/Agent from UIM with discovery_server probe
#
sub remove_from_uim {
    my ($DB, $Robotname, $nasAddr) = @_;
    print STDOUT "---------------------------\n";
    print STDOUT "Entering step - remove_from_uim\n";

    # Get CS Key
    my $cs_key = $DB->cs_key($deviceName);
    print STDOUT "Device cs_key => $cs_key\n";

    # Find (at least one) Discovery_server Addr
    my $addr = find_probe_byname("discovery_server");
    return if not defined($addr);
    print STDOUT "Discovery_server Addr found: $addr\n";

    # Trigger callback remove_master_devices_by_cskeys on discovery_server
    {
        my $PDS = Nimbus::PDS->new();
        $PDS->string("csKeys", $cs_key);
        my ($RC, $AlarmsRET) = nimNamedRequest($addr, "remove_master_devices_by_cskeys", $PDS->data);
        if($RC != NIME_OK) {
            my $nimError = nimError2Txt($RC);
            print STDERR "Failed to trigger callback remove_master_devices_by_cskeys, Error ($RC): $nimError\n";

            return;
        }
    }

    # Clean-up NAS addr table
}

#
# TODO
# DESC: Remove the robot from his UIM Hub
#
sub remove_robot {
    print STDOUT "---------------------------\n";
    print STDOUT "Entering step - remove_robot\n";
    # Search on all hubs
    # trigger removerobot callback!
}

#
# DESC: Remove the device from any collectors
#
sub remove_collector {
    print STDOUT "---------------------------\n";
    print STDOUT "Entering step - remove_collector\n";
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
        my $type    = $CFG->{"database"}->{"type"} || "mysql";
        my $db      = $CFG->{"database"}->{"database"} || "ca_uim";
        my $host    = $CFG->{"database"}->{"host"} || "127.0.0.1";
        my $port    = $CFG->{"database"}->{"port"} || 33006;
        my $user    = $CFG->{"database"}->{"user"} || "sa";
        my $passwd  = $CFG->{"database"}->{"password"} || "";

        my $CS      = "DBI:$type:database=$db;host=$host;port=$port";
        print STDOUT "SQL connection string: $CS\n";
        $DB = src::uimdb->new($CS, $user, $passwd);
    }

    # Find (at least one) NAS Addr
    my $nasAddr = find_probe_byname("nas");
    return if not defined($nasAddr);
    print STDOUT "NAS Addr found: $nasAddr\n";

    exit 0;

    # Finally execute each steps
    remove_from_uim($DB, $Robotname, $nasAddr);
    remove_robot() if $type eq "robot" && $removeRobot;
    remove_collector() if $type eq "device";
    close_alarms($Robotname, $nasAddr) if $closeAlarms;
    clean_alarms_history($DB) if $cleanAlarms;
    delete_qos($DB) if $deleteQoS;

    print STDOUT "\nExiting CLI tool with code 0\n";
}

# Execute main script handler!
main();