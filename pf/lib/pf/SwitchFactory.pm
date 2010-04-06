package pf::SwitchFactory;

=head1 NAME

pf::SwitchFactory - Object oriented factory to instantiate objects

=head1 SYNOPSIS

The pf::SwitchFactory module implements an object oriented factory to
instantiate objects of type pf::SNMP or subclasses of this. This module
is meant to read in a switches.conf configuration file containing all
the necessary information needed to actually instantiate the objects.

=cut

use strict;
use warnings;
use diagnostics;

use Carp;
use Config::IniFiles;
use UNIVERSAL::require;
use Log::Log4perl;

use pf::config;
use pf::util;

=head1 METHODS

=over

=cut
#TODO: transform into a singleton? http://perldesignpatterns.com/?SingletonPattern
sub new {
    my $logger = Log::Log4perl::get_logger("pf::SwitchFactory");
    $logger->debug("instantiating new SwitchFactory object");
    my ( $class, %argv ) = @_;
    my $this = bless {
        '_configFile' => undef,
        '_config'     => undef
    }, $class;

    foreach ( keys %argv ) {
        if (/^-?configFile$/i) {
            $this->{_configFile} = $argv{$_};
        }
    }

    if ( defined( $this->{_configFile} ) ) {
        $this->readConfig();
    }

    return $this;
}

=item instantiate - create new pf::SNMP (or subclass) object

  $switch = SwitchFactory->instantiate( <switchIdentifier> );

=cut

sub instantiate {
    my $logger = Log::Log4perl::get_logger("pf::SwitchFactory");
    my ( $this, $requestedSwitch ) = @_;
    my %SwitchConfig = %{ $this->{_config} };
    if ( !exists $SwitchConfig{$requestedSwitch} ) {
        $logger->error("ERROR ! Unknown switch $requestedSwitch");
        return 0;
    }

    # find the module to instantiate
    my $type;
    if ($requestedSwitch ne 'default') {
        $type = "pf::SNMP::" . ($SwitchConfig{$requestedSwitch}{'type'} || $SwitchConfig{'default'}{'type'});
    } else {
        $type = "pf::SNMP";
    }
    # load the module to instantiate
    if (!$type->require()) {
        $logger->error("Can not load perl module for switch $requestedSwitch, type: $type. "
            . "Either the type is unknown or the perl module has compilation errors. "
            . "Read the following message for details: $@");
        return 0;
    }

    my @uplink = ();
    if (   $SwitchConfig{$requestedSwitch}{'uplink'}
        || $SwitchConfig{'default'}{'uplink'} )
    {

        my @_uplink_tmp = split(
            /,/,
            (          $SwitchConfig{$requestedSwitch}{'uplink'}
                    || $SwitchConfig{'default'}{'uplink'}
            )
        );
        foreach my $_tmp (@_uplink_tmp) {
            $_tmp =~ s/ //g;
            push @uplink, $_tmp;
        }
    }
    my @vlans      = ();
    my @_vlans_tmp = split(
        /,/,
        (          $SwitchConfig{$requestedSwitch}{'vlans'}
                || $SwitchConfig{'default'}{'vlans'}
        )
    );
    foreach my $_tmp (@_vlans_tmp) {
        $_tmp =~ s/ //g;
        push @vlans, $_tmp;
    }
    my $switch_mode;
    if ( isenabled( $Config{'trapping'}{'testing'} ) ) {
        $switch_mode = 'testing';
        $logger->warn(
            'setting switch mode to testing since trapping.testing=enabled');
    } else {
        $switch_mode = lc(
            (          $SwitchConfig{$requestedSwitch}{'mode'}
                    || $SwitchConfig{'default'}{'mode'}
            )
        );
    }
    $logger->debug("creating new $type object");
    return $type->new(
        '-customVlan1' => (
                   $SwitchConfig{$requestedSwitch}{'customVlan1'}
                || $SwitchConfig{'default'}{'customVlan1'}
        ),
        '-customVlan2' => (
                   $SwitchConfig{$requestedSwitch}{'customVlan2'}
                || $SwitchConfig{'default'}{'customVlan2'}
        ),
        '-customVlan3' => (
                   $SwitchConfig{$requestedSwitch}{'customVlan3'}
                || $SwitchConfig{'default'}{'customVlan3'}
        ),
        '-customVlan4' => (
                   $SwitchConfig{$requestedSwitch}{'customVlan4'}
                || $SwitchConfig{'default'}{'customVlan4'}
        ),
        '-customVlan5' => (
                   $SwitchConfig{$requestedSwitch}{'customVlan5'}
                || $SwitchConfig{'default'}{'customVlan5'}
        ),
        '-dbHostname'  => $Config{'database'}{'host'},
        '-dbName'      => $Config{'database'}{'db'},
        '-dbPassword'  => $Config{'database'}{'pass'},
        '-dbUser'      => $Config{'database'}{'user'},
        '-guestVlan' => (
                   $SwitchConfig{$requestedSwitch}{'guestVlan'}
                || $SwitchConfig{'default'}{'guestVlan'}
        ),
        '-htaccessPwd' => (
                   $SwitchConfig{$requestedSwitch}{'htaccessPwd'}
                || $SwitchConfig{'default'}{'htaccessPwd'}
        ),
        '-htaccessUser' => (
                   $SwitchConfig{$requestedSwitch}{'htaccessUser'}
                || $SwitchConfig{'default'}{'htaccessUser'}
        ),
        '-ip'            => $requestedSwitch,
        '-isolationVlan' => (
                   $SwitchConfig{$requestedSwitch}{'isolationVlan'}
                || $SwitchConfig{'default'}{'isolationVlan'}
        ),
        '-macDetectionVlan' => (
                   $SwitchConfig{$requestedSwitch}{'macDetectionVlan'}
                || $SwitchConfig{'default'}{'macDetectionVlan'}
        ),
        '-macSearchesMaxNb' => (
                   $SwitchConfig{$requestedSwitch}{'macSearchesMaxNb'}
                || $SwitchConfig{'default'}{'macSearchesMaxNb'}
        ),
        '-macSearchesSleepInterval' => (
                   $SwitchConfig{$requestedSwitch}{'macSearchesSleepInterval'}
                || $SwitchConfig{'default'}{'macSearchesSleepInterval'}
        ),
        '-mode'       => $switch_mode,
        '-normalVlan' => (
                   $SwitchConfig{$requestedSwitch}{'normalVlan'}
                || $SwitchConfig{'default'}{'normalVlan'}
        ),
        '-registrationVlan' => (
                   $SwitchConfig{$requestedSwitch}{'registrationVlan'}
                || $SwitchConfig{'default'}{'registrationVlan'}
        ),
        '-SNMPAuthPasswordRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthPasswordRead'}
                || $SwitchConfig{'default'}{'SNMPAuthPasswordRead'}
        ),
        '-SNMPAuthPasswordTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthPasswordTrap'}
                || $SwitchConfig{'default'}{'SNMPAuthPasswordTrap'}
        ),
        '-SNMPAuthPasswordWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthPasswordWrite'}
                || $SwitchConfig{'default'}{'SNMPAuthPasswordWrite'}
        ),
        '-SNMPAuthProtocolRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthProtocolRead'}
                || $SwitchConfig{'default'}{'SNMPAuthProtocolRead'}
        ),
        '-SNMPAuthProtocolTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthProtocolTrap'}
                || $SwitchConfig{'default'}{'SNMPAuthProtocolTrap'}
        ),
        '-SNMPAuthProtocolWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthProtocolWrite'}
                || $SwitchConfig{'default'}{'SNMPAuthProtocolWrite'}
        ),
        '-SNMPCommunityRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPCommunityRead'}
                || $SwitchConfig{$requestedSwitch}{'communityRead'}
                || $SwitchConfig{'default'}{'SNMPCommunityRead'}
                || $SwitchConfig{'default'}{'communityRead'}
        ),
        '-SNMPCommunityTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPCommunityTrap'}
                || $SwitchConfig{$requestedSwitch}{'communityTrap'}
                || $SwitchConfig{'default'}{'SNMPCommunityTrap'}
                || $SwitchConfig{'default'}{'communityTrap'}
        ),
        '-SNMPCommunityWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPCommunityWrite'}
                || $SwitchConfig{$requestedSwitch}{'communityWrite'}
                || $SwitchConfig{'default'}{'SNMPCommunityWrite'}
                || $SwitchConfig{'default'}{'communityWrite'}
        ),
        '-SNMPPrivPasswordRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivPasswordRead'}
                || $SwitchConfig{'default'}{'SNMPPrivPasswordRead'}
        ),
        '-SNMPPrivPasswordTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivPasswordTrap'}
                || $SwitchConfig{'default'}{'SNMPPrivPasswordTrap'}
        ),
        '-SNMPPrivPasswordWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivPasswordWrite'}
                || $SwitchConfig{'default'}{'SNMPPrivPasswordWrite'}
        ),
        '-SNMPPrivProtocolRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivProtocolRead'}
                || $SwitchConfig{'default'}{'SNMPPrivProtocolRead'}
        ),
        '-SNMPPrivProtocolTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivProtocolTrap'}
                || $SwitchConfig{'default'}{'SNMPPrivProtocolTrap'}
        ),
        '-SNMPPrivProtocolWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivProtocolWrite'}
                || $SwitchConfig{'default'}{'SNMPPrivProtocolWrite'}
        ),
        '-SNMPUserNameRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPUserNameRead'}
                || $SwitchConfig{'default'}{'SNMPUserNameRead'}
        ),
        '-SNMPUserNameTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPUserNameTrap'}
                || $SwitchConfig{'default'}{'SNMPUserNameTrap'}
        ),
        '-SNMPUserNameWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPUserNameWrite'}
                || $SwitchConfig{'default'}{'SNMPUserNameWrite'}
        ),
        '-SNMPVersion' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPVersion'}
                || $SwitchConfig{$requestedSwitch}{'version'}
                || $SwitchConfig{'default'}{'SNMPVersion'}
                || $SwitchConfig{'default'}{'version'}
        ),
        '-SNMPEngineID' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPEngineID'}
                || $SwitchConfig{'default'}{'SNMPEngineID'}
        ),
        '-SNMPVersionTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPVersionTrap'}
                || $SwitchConfig{'default'}{'SNMPVersionTrap'}
        ),
        '-cliEnablePwd' => (
                   $SwitchConfig{$requestedSwitch}{'cliEnablePwd'}
                || $SwitchConfig{$requestedSwitch}{'telnetEnablePwd'}
                || $SwitchConfig{'default'}{'cliEnablePwd'}
                || $SwitchConfig{'default'}{'telnetEnablePwd'}
        ),
        '-cliPwd' => (
                   $SwitchConfig{$requestedSwitch}{'cliPwd'}
                || $SwitchConfig{$requestedSwitch}{'telnetPwd'}
                || $SwitchConfig{'default'}{'cliPwd'}
                || $SwitchConfig{'default'}{'telnetPwd'}
        ),
        '-cliUser' => (
                   $SwitchConfig{$requestedSwitch}{'cliUser'}
                || $SwitchConfig{$requestedSwitch}{'telnetUser'}
                || $SwitchConfig{'default'}{'cliUser'}
                || $SwitchConfig{'default'}{'telnetUser'}
        ),
        '-cliTransport' => (
                   $SwitchConfig{$requestedSwitch}{'cliTransport'}
                || $SwitchConfig{'default'}{'cliTransport'}
                || 'Telnet'
        ),
        '-uplink'    => \@uplink,
        '-vlans'     => \@vlans,
        '-voiceVlan' => (
                   $SwitchConfig{$requestedSwitch}{'voiceVlan'}
                || $SwitchConfig{'default'}{'voiceVlan'}
        ),
        '-VoIPEnabled' => (
            (          $SwitchConfig{$requestedSwitch}{'VoIPEnabled'}
                    || $SwitchConfig{'default'}{'VoIPEnabled'}
            ) =~ /^\s*(y|yes|true|enabled|1)\s*$/i ? 1 : 0
        )
    );
}

=item readConfig - read configuration file

  $switchFactory->readConfig();

=cut

sub readConfig {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger("pf::SwitchFactory");
    $logger->debug("reading config file $this->{_configFile}");
    if ( !defined( $this->{_configFile} ) ) {
        croak "Config file has not been defined\n";
    }
    my %SwitchConfig;
    if ( !-e $this->{_configFile} ) {
        croak "Config file " . $this->{_configFile} . " cannot be read\n";
    }
    tie %SwitchConfig, 'Config::IniFiles', ( -file => $this->{_configFile} );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        croak "Error reading config file: " . join( "\n", @errors ) . "\n";
    }

    #remove trailing spaces..
    foreach my $section ( tied(%SwitchConfig)->Sections ) {
        foreach my $key ( keys %{ $SwitchConfig{$section} } ) {
            $SwitchConfig{$section}{$key} =~ s/\s+$//;
        }
    }
    %{ $this->{_config} } = %SwitchConfig;

    return 1;
}

=back

=head1 AUTHOR

Regis Balzard <rbalzard@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2009 Inverse inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
