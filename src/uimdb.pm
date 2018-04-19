package src::uimdb;

# use perl5 core dependencie(s)
use strict;
use DBI;
use Data::Dumper;

#
# DESC: Database manager (connector) for the UIM Database
#
sub new {
    my ($class, $type, $CS, $user, $password) = @_;
    my $DB = DBI->connect($CS, $user, $password);
    die "Failed to establish a connection to the Database, Error: ".$DBI::errstr."\n" if not defined($DB);
    return bless({
        type => $type,
        DB => $DB
    }, ref($class) || $class);
}

#
# DESC: Get the cs_key of a given device on the SQL Table `CM_COMPUTER_SYSTEM`
#
sub cs_key {
    my ($self, $deviceName) = @_;

    # Build SQL Request
    my $lock = $self->{type} ne "mysql" ? " WITH(nolock)" : "";
    my $sth = $self->{DB}->prepare("SELECT cs_key FROM CM_COMPUTER_SYSTEM $lock WHERE name=?");
    $sth->execute($deviceName) or die $DBI::errstr;

    # Get cs_key from the response!
    my $cs_key;
    while (my $ref = $sth->fetchrow_hashref()) {
        $cs_key = $ref->{"cs_key"};
    }
    if (not defined $cs_key) {
        print STDERR "Unable to found cs_key for device $deviceName\n";
    }
    $sth->finish();

    return $cs_key;
}

#
# DESC: Clean all QoS for a given device
#
sub clean_qos {
    my ($self, $deviceName) = @_;

    # Build SQL Request
    my $lock = $self->{type} ne "mysql" ? " WITH(nolock)" : "";
    my $sth = $self->{DB}->prepare("SELECT table_id, r_table, h_table FROM S_QOS_DATA $lock WHERE source=?");
    $sth->execute($deviceName);
    my @EntryToClean = ();

    # Handle response!
    while (my $ref = $sth->fetchrow_hashref()) {
        my $tableId = $ref->{"table_id"};
        my $id = substr($ref->{"r_table"}, -4);
        push(@EntryToClean, {
            table => $ref->{"r_table"},
            id => $tableId
        });
        push(@EntryToClean, {
            table => $ref->{"h_table"},
            id => $tableId
        });
        push(@EntryToClean, {
            table => "DN_QOS_DATA_$id",
            id => $tableId
        });
        push(@EntryToClean, {
            table => "BN_QOS_DATA_$id",
            id => $tableId
        });
    }
    $sth->finish();

    my $entryCount = scalar @EntryToClean;
    print STDOUT "Number of QOS Table to cleanup => $entryCount\n";

    # Bulk delete
    $self->{DB}->begin_work;
    foreach(@EntryToClean) {
        my $table = $_->{table};
        my $deleteSth = $self->{DB}->prepare("DELETE FROM $table WHERE table_id=?");
        my $deletedCount = $deleteSth->execute($_->{id});
        if ($deletedCount eq "0E0") {
            $deletedCount = "0";
        }
        print STDOUT "Deleted $deletedCount row(s) on table $table with table_id = $_->{id}\n";
        $deleteSth->finish();
    }
    $self->{DB}->commit;

    return $self;
}

#
# DESC: Clean all alarms history for a given device
#
sub clean_alarms_history {
    my ($self, $deviceName) = @_;

    # Clean nas_transaction_log table
    {
        my $sth_log = $self->{DB}->prepare(
            "DELETE FROM nas_transaction_log WHERE hostname=?"
        );
        my $deletedCount = $sth_log->execute($deviceName) or die $DBI::errstr;
        if ($deletedCount eq "0E0") {
            $deletedCount = "0";
        }
        print STDOUT "$deletedCount rows deleted from `nas_transaction_log`\n";
        $sth_log->finish();
    }

    # Clean nas_transaction_summary table
    {
        my $sth_summary = $self->{DB}->prepare(
            "DELETE FROM nas_transaction_summary WHERE hostname=?"
        );
        my $deletedCount = $sth_summary->execute($deviceName) or die $DBI::errstr;
        if ($deletedCount eq "0E0") {
            $deletedCount = "0";
        }
        print STDOUT "$deletedCount rows deleted from `nas_transaction_summary`\n";
        $sth_summary->finish();
    }

    return $self;
}

1;