package src::utils;

# Perl Core packages
use strict;
use Exporter qw(import);

# Use Nimbus dependencies
use Nimbus::API;
use Nimbus::PDS;

# Export functions
our @EXPORT_OK = qw(scriptArgsAsHash assignHash checkDefined findProbeByHisName);

#
# DESC: Get the script arguments values mapped as a hash
#
sub scriptArgsAsHash {
    my ($defaultPayload) = @_;
    my $hashRef = {};
    my $seekForValue = 0;
    my $vOld;
    foreach(@ARGV) {
        if(substr($_, 0, 2) eq "--") {
            if($seekForValue) {
                $hashRef->{$vOld} = 1;
            }
            $seekForValue = 1;
            $vOld = substr($_, 2);
        }
        elsif($seekForValue) {
            $hashRef->{$vOld} = $_;
            $seekForValue = 0;
        }
    }

    if($seekForValue) {
        $hashRef->{$vOld} = 1;
    }
    return assignHash($hashRef, $defaultPayload);
}

#
# DESC: Assign hash ref properties to an another hash ref
#
sub assignHash {
    my ($targetRef,$cibleRef,@othersRef) = @_;
    foreach my $key (keys %{ $cibleRef }) {
        next if defined($targetRef->{$key});
        $targetRef->{$key} = $cibleRef->{$key};
    }
    return $targetRef if scalar @othersRef == 0;

    foreach(@othersRef) {
        $targetRef = assignHash($targetRef, $_);
    }
    return $targetRef;
}

#
# DESC: Assign multiple values to one variable (with default payload).
#
sub checkDefined {
    my ($ref, $default, $arrRef) = @_;
    foreach(@{ $arrRef }) {
        return $ref->{$_} if defined $ref->{$_};
    }
    return $default;
}

#
# DESC: Find a probe addr by his name
#
sub findProbeByHisName {
    my ($probeName) = @_;

    my $PDS = Nimbus::PDS->new();
    $PDS->string("probename", $probeName);
    my ($RC, $nimRET) = nimFindAsPds($PDS->data, NIMF_PROBE);
    if ($RC != NIME_OK) {
        my $nimError = nimError2Txt($RC);
        print STDERR "Failed to find any $probeName Addr, Error ($RC): $nimError\n";

        return undef;
    }

    my @ret = ();
    my $PDSRet = Nimbus::PDS->new($nimRET);
    for( my $i = 0; my $addr = $PDSRet->getTable("addr", PDS_PCH, $i); $i++) {
        push(@ret, $addr);
    }
    
    return \@ret;
}

1;