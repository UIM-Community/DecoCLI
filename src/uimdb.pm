package src::uimdb;

# use perl5 core dependencie(s)
use strict;
use DBI;
use threads;
use Thread::Queue;

# Constants
our $QOS_THREAD = 15;

#
# DESC: Database manager (connector) for the UIM Database
#
sub new {
    my ($class, $type, $CS, $user, $password) = @_;
    my $DB = DBI->connect($CS, $user, $password);
    die "Failed to establish a connection to the Database, Error: ".$DBI::errstr."\n" if not defined($DB);
    return bless({
        CS => $CS,
        user => $user,
        password => $password,
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
    print STDOUT "Number of (Raw) QOS entry to cleanup => $entryCount\n";

    # Agregate by tableName
    my $Agregate = {};
    foreach(@EntryToClean) {
        if (not defined $Agregate->{$_->{table}}) {
            $Agregate->{$_->{table}} = [];
        }
        push(@{ $Agregate->{$_->{table}} }, $_->{id});
    }

    my $tableCount = scalar keys %{ $Agregate };
    print STDOUT "Number of QOS Table to cleanup => $tableCount\n";

    # Enqueue all tasks!
    my $queue = Thread::Queue->new();
    foreach my $table (keys %{ $Agregate }) {
        $queue->enqueue({
            table => $table,
            ids => join(',', @{ $Agregate->{$table} } )
        });
    }

    # Define the thread
    my $thr = sub {
        my ($type, $cs, $user, $password) = @_; 
        my $DB = src::uimdb->new($type, $cs, $user, $password);

        while ( defined ( my $hash = $queue->dequeue() ) )  {
            eval {
                my $table = $hash->{table};
                my $deleteSth = $DB->{DB}->prepare("DELETE FROM $table WHERE table_id IN ($hash->{ids})");
                my $deletedCount = $deleteSth->execute();
                if ($deletedCount eq "0E0") {
                    $deletedCount = "0";
                }
                print STDOUT "Deleted $deletedCount row(s) on table $table\n";
            };
            if ($@) {
                print STDERR $@;
            }
        }
    };

    # Join thread pools!
    my @thr = map {
        threads->create(
            \&$thr,
            $self->{type},
            $self->{CS},
            $self->{user},
            $self->{password}
        );
    } 1..$QOS_THREAD;
    for(my $i = 0; $i < $QOS_THREAD; $i++) {
        $queue->enqueue(undef);
    }
    $_->join() for @thr;

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

#
# DESC: Clean all alarms history for a given device
#
sub decom_nokiaipsla {
    my ($self, $deviceName) = @_;
    my $sth = $self->{DB}->prepare("INSERT INTO nokia_ipsla_decommission (device) VALUES (?)");
    my $ret = $sth->execute($deviceName);
    print STDOUT "decom_nokiaipsla return => $ret\n";
    $sth->finish();
}

1;