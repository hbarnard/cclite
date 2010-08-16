
=head1 NAME

Cchooks.pm


=head1 SYNOPSIS

Standard API hooks for transactions and users

=head1 DESCRIPTION

This package will contain API hooks into all the major
transactions. For the less experienced, it will avoid
getting deep into the code. At the moment there are just
stubs, so one can see the philosophy

=head1 AUTHOR

Hugh Barnard

=head1 COPYRIGHT

(c) Hugh Barnard 2005 GPL Licenced 

=cut

package Cchooks;
use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
use DBI;    # Database abstraction
use Ccu;    # for paging routine, at least
my $VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(pre_transaction
  post_transaction
  pre_add_user
  post_add_user);

=head3 pre_transaction

action to be done before a transaction

=cut

sub pre_transaction {
    return;
}

=head3 post_transaction

action to be done after a transaction

=cut

sub post_transaction {

    return;

}

=head3 pre_add_user

action to be done before adding a user

=cut

sub pre_add_user {
    return;
}

=head3 post_add_user

action to be done after adding a user

=cut

sub post_add_user {
    return;
}

1;

