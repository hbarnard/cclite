#!/usr/bin/perl -w

=head1 NAME

 ccserver.cgi

=head1 SYNOPSIS

 This is the standard SOAP server for Cclite

=head1 DESCRIPTION

 This is the SOAP server for cclite, uses the Cclite package which
 is also used by the user/web interface

 Uses mixed Dispatch: Direct quote from www.soaplite.com

 Why do we need this? Unfortunately, both dynamic and static dispatch have disadvantages. During dynamic dispatch access to @INC is disabled (due to security reasons) and static dispatch loads modules on startup, but this may not be what we want if we have a bunch of modules we want to access. To avoid this, you can combine the dynamic and static approaches. 
 Let's assume you have 10 modules in /home/soaplite/modules directory, and want to provide access, but don't want to load all of them on startup. All you need to do is this:

#  use SOAP::Transport::HTTP;
#  SOAP::Transport::HTTP::CGI
#    -> dispatch_to('/home/soaplite/modules', 'Demo', 'Demo1', 'Demo2')
#    -> handle;

 Now access to all of these modules is enabled and they'll be loaded on a demand basis, 
 only when needed. And, more importantly, all these modules now have access to @INC array, 
 so can do any use they want.


---------------------------------------------------------------------------
 THE cclite SOFTWARE IS PROVIDED TO YOU "AS IS," AND WE MAKE NO EXPRESS
 OR IMPLIED WARRANTIES WHATSOEVER WITH RESPECT TO ITS FUNCTIONALITY,
 OPERABILITY, OR USE, INCLUDING, WITHOUT LIMITATION,
 ANY IMPLIED WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE, OR INFRINGEMENT.
 WE EXPRESSLY DISCLAIM ANY LIABILITY WHATSOEVER FOR ANY DIRECT,
 INDIRECT, CONSEQUENTIAL, INCIDENTAL OR SPECIAL DAMAGES,
 INCLUDING, WITHOUT LIMITATION, LOST REVENUES, LOST PROFITS,
 LOSSES RESULTING FROM BUSINESS INTERRUPTION OR LOSS OF DATA,
 REGARDLESS OF THE FORM OF ACTION OR LEGAL THEORY UNDER
 WHICH THE LIABILITY MAY BE ASSERTED,
 EVEN IF ADVISED OF THE POSSIBILITY OR LIKELIHOOD OF SUCH DAMAGES.
---------------------------------------------------------------------------

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=head1 AUTHOR

Hugh Barnard


=head1 SEE ALSO

cclite.cgi
ccadmin.cgi
ccinstall.cgi

=head1 COPYRIGHT

(c) Hugh Barnard 2005-2009 GPL Licenced 

=cut

$ENV{IFS} = '';    # security precaution

use SOAP::Transport::HTTP;
use strict;
use locale;        # treat accents correctly etc.

# added Ccinterfaces, since the sms function can also use SOAP...December 2008
SOAP::Transport::HTTP::CGI->dispatch_to(
    '../lib',       'Cclite',       'Cclitedb', 'Ccconfig',
    'Ccinterfaces', 'Ccsmsgateway', 'Ccu'
)->handle;

# should never reach here, I (hope) believe

1;
