package src::uimdb;

# use perl5 core dependencie(s)
use strict;
use DBI;

#
# DESC: Database manager (connector) for the UIM Database
#
sub new {
    my ($class, $CS, $user, $password) = @_;
    my $DB = DBI->connect($CS, $user, $password, {
        RaiseError => 1
    });
    die "Failed to establish a connection to the Database, Error: ".$DBI::errstr."\n" if not defined($DB);
    return bless({
        DB => $DB
    }, ref($class) || $class);
}

#
# DESC: Get the cs_key of a given device
#
sub cs_key {
    my ($self, $deviceName) = @_;
}

#
# DESC: Clean all QoS for a given device
#
sub clean_qos {
    my ($self, $deviceName) = @_;
}

#
# DESC: Clean all alarms history for a given device
#
sub clean_alarms_history {
    my ($self, $deviceName) = @_;
}

1;