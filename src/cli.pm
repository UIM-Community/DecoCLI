package src::cli;

# use perl5 core dependencies
use strict;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

# use internal dependencies
use src::utils qw(scriptArgsAsHash checkDefined);

#
# DESC: Commande Line interface manager
#
sub new {
    my ($class, $optionsHashRef) = @_;
    return bless({
        usage => $optionsHashRef->{usage} || "",
        description => $optionsHashRef->{description} || "",
        version => $optionsHashRef->{version} || "1.0.0",
        commands => {}
    }, ref($class) || $class);
}

#
# DESC: Setup a new command
#
sub setCommand {
    my ($self, $command, $optionsHashRef) = @_;
    $self->{"commands"}->{$command} = $optionsHashRef;
}

#
# DESC: Initialize the CLI class with default ARGV entry
#
sub init {
    my ($self) = @_;
    my $script_arguments = scriptArgsAsHash({});
    my $ret = {};

    #
    # DESC: Script start arguments contains --h and/or --help
    #
    if (defined $script_arguments->{h} || defined $script_arguments->{help}) {
        print STDOUT "\nUsage: $self->{usage}\n\n";
        print STDOUT "$self->{description}\n\n";
        print STDOUT "Options:\n";
        foreach my $command (keys %{ $self->{commands} }) {
            my $description = $self->{commands}->{$command}->{description} || "";
            my $required = $self->{commands}->{$command}->{required} ? "Mandatory" : "Optional";
            my $defaultValue = defined($self->{commands}->{$command}->{defaultValue}) ? $self->{commands}->{$command}->{defaultValue} : "none";
            print STDOUT "\t[--${command}] $description ($required) (default: $defaultValue)\n";
        }
        print STDOUT "\n";

        # Help will automatically exit the script
        exit 0;
    }

    #
    # DESC: Script start arguments contains --v and/or --version
    #
    if (defined $script_arguments->{v} || defined $script_arguments->{version}) {
        print STDOUT "Version ".$self->{version}."\n\n";

        # Output script version will automatically exit the script
        exit 0;
    }

    foreach my $commandName (keys %{ $self->{commands} }) {
        my $cmd = $self->{commands}->{$commandName};

        my $required = defined($cmd->{required}) ? $cmd->{required} : 0;
        my $expect = ref($cmd->{expect}) eq "ARRAY" ? $cmd->{expect} : undef;
        my $defaultValue;
        if (defined($cmd->{defaultValue})) {
            $defaultValue = $cmd->{defaultValue};
            $required = 0;
        }

        my $finalValue;
        my $keyFound = defined($script_arguments->{$commandName});

        if ($keyFound == 0 && $required == 1) {
            die "Command line option --$commandName is required !!! Trigger --help for more information on how to use CLI options.\n";
        }
        elsif ($keyFound == 0 && defined($defaultValue)) {
            $finalValue = $defaultValue;
        }
        if($keyFound == 1) {
            $finalValue = $script_arguments->{$commandName};
            if (defined($cmd->{match})) {
                unless($finalValue =~ $cmd->{match}) {
                    die "Command line option --$commandName value doesn't match expected Regexp Expression\n";
                }
            }
        }

        if (defined($expect)) {
            my %params = map { $_ => 1 } @{ $expect };
            if (not exists($params{$finalValue})) {
                die "Command line option --$commandName value doesn't match expected values: @{$expect}\n";
            }
        }

        $ret->{$commandName} = $finalValue;
    }
    return $ret;
}

1;