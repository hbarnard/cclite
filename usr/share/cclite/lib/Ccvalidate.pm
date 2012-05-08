
=head1 NAME

Ccvalidate.pm

=head1 SYNOPSIS

Validation routines for form fields

=head1 DESCRIPTION

This is the place for semantic validation routines. Nowadays
this could be done via AJAX transactions rather than explicit
round-trips, but it's also a question of available effort.

Older text:
This set of subroutines do input validation 
and produce various pieces of Javascript as returned strings
such as $validate etc.  These strings are then put into the displayed form
This keeps the display stuff seperate from the client side processing

=head1 AUTHOR

Hugh Barnard


=head1 SEE ALSO

Cclite.pm

=head1 COPYRIGHT

(c) Hugh Barnard 2005 GPL Licenced 

=cut

package Ccvalidate;

use strict;
use vars qw(@ISA @EXPORT);
use Exporter;

my $VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(create_utilityscriptlets
  check_name_exists
  check_email_exists
  validate_registry
  validate_currency
  validate_user
  validate_partner
  validate_modified_user
  validate_service_charge
  validate_transaction
  make_submitwarning
);

use Ccu;         # just for debugging take this away afterwards
use Cclitedb;    # semantic checks in database during validation

our %messages    = readmessages();
our $messagesref = \%messages;

=head3 validate_registry

Validate the fields in registry before creation

This probably needs to be extended

=cut

sub validate_registry {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;
    my @status;

    # registry name must be filled

    # registry name must start with alpha and be one 'word'
    if ( $fieldsref->{'newregistry'} !~ /^[a-zA-Z]\w+$/ ) {
        push @status, $messagesref->{'badregistryname'};
    }

   # there's no really good match for valid email addresses, in fact..
   # these two are supressed, checked by jquery 11/2009
   # if ( $fieldsref->{admemail} !~
   #    /^\+?[a-z0-9](([-+.]|[_]+)?[a-z0-9]+)*@([a-z0-9]+(\.|\-))+[a-z]{2,6}$/ )
   # {
   #    push @status, "$messagesref->{bademail} $messagesref->{regmanager}";
   # }

   # there's no really good match for valid email addresses, in fact..
   # if ( length( $fieldsref->{postemail} )
   #    && $fieldsref->{postemail} !~
   #    /^\+?[a-z0-9](([-+.]|[_]+)?[a-z0-9]+)*@([a-z0-9]+(\.|\-))+[a-z]{2,6}$/ )
   # {
   #    push @status, "$messagesref->{bademail} $messagesref->{batchtrans}";
   # }

    # commit limit must be numeric, if present
    if ( length( $fieldsref->{'commitlimit'} )
        && $fieldsref->{'commitlimit'} !~ /^\d+$/ )
    {
        push @status, $messagesref->{'badcommitlimit'};
    }
    return @status;
}

=head3 validate_currency

Validate the fields in currency before creation

Probably needs to be extended

=cut

sub validate_currency {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;
    my @status;

    # registry name must be filled

    # there's no really good match for valid email addresses, in fact..
    if ( $fieldsref->{mail} !~
        /^\+?[a-z0-9](([-+.]|[_]+)?[a-z0-9]+)*@([a-z0-9]+(\.|\-))+[a-z]{2,6}$/ )
    {
        push @status, $messagesref->{bademail};
    }

    # currency name must start with alpha, one word
    if ( $fieldsref->{cname} !~ /^[a-zA-Z]\w+$/ ) {
        push @status, $messagesref->{badcurrencyname};
    }

    return @status;
}

=head3 validate_user

Validate the fields in user before creation
A work in progress!
 
=cut

sub validate_user {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;
    my ( @status, %messages );
    my $action = $fieldsref->{'action'};    # simplify code somewaht

    # deals with problem comming from update_database_record
    if ( !length($messagesref) ) {
        %messages    = readmessages();
        $messagesref = \%messages;
    }

    if ( !length( $fieldsref->{userLang} ) && $action eq "adduser" ) {
        push @status, $messagesref->{'invalidlanguage'};
    }

    if (   $fieldsref->{userLogin} !~ /^\w[\w\d_]+$/
        && $action eq "adduser" )
    {
        push @status, $messagesref->{'invalidlogin'};
    }

    # there's no really good match for valid email addresses, in fact..
    if ( $fieldsref->{userEmail} !~
        /^\+?[a-z0-9](([-+.]|[_]+)?[a-z0-9]+)*@([a-z0-9]+(\.|\-))+[a-z]{2,6}$/ )
    {
        push @status, $messagesref->{'bademail'};
    }

    # mobile phone numbers need to contain spaces and numbers, if present
    if ( length( $fieldsref->{'userMobile'} )
        && $fieldsref->{userMobile} =~ /[^\d\s]+/ )
    {
        push @status, $messagesref->{badphone};
    }

    # mobile phone numbers must be unique
    $fieldsref->{userMobile} =
      format_for_standard_mobile( $fieldsref->{userMobile} );

    # only do these, if there is a mobile number:  3045485 27/9/2010

    if ( length( $fieldsref->{'userMobile'} ) ) {

        my ( $error, $fromuserref ) =
          get_where( $class, $db, 'om_users', '*', 'userMobile',
            $fieldsref->{userMobile},
            $token, $offset, $limit );

        # not unique, another record contains this number
        if ( length($fromuserref) && $action eq 'adduser' ) {
            push @status, $messagesref->{mobphoneexists};
        }

        # not unique another record, not yours, contains this number
        if ( length($fromuserref) && $action eq 'update' ) {
            if ( $$fromuserref{'userId'} != $fieldsref->{'userId'} ) {
                push @status, $messagesref->{mobphoneexists};
            }
        }

    }

    # do address validation in private function
    my @address_status =
      _validate_address( $class, $db, $fieldsref, $messagesref, $token, $offset,
        $limit );
    if ( scalar(@address_status) > 0 ) {
        @status = ( @status, @address_status );
    }

    # do new password validation and comparison in private function
    my @password_status =
      _validate_new_password( $class, $db, $fieldsref, $messagesref, $token,
        $offset, $limit )
      if ( $fieldsref->{action} eq "adduser" );
    if ( scalar(@password_status) > 0 ) {
        @status = ( @status, @password_status );
    }

    # do new pin validation and comparison in private function
    # pin is not obligatory when mobile phone number is absent

    if ( length( $fieldsref->{userMobile} ) && $action eq "adduser" ) {
        my @pin_status =
          _validate_new_pin( $class, $db, $fieldsref, $messagesref, $token,
            $offset, $limit );
        if ( scalar(@pin_status) > 0 ) {
            @status = ( @status, @pin_status );
        }
    }

    # if new pin entered during update, needs revalidation
    if ( length( $fieldsref->{userPin} ) && $action eq "update" ) {
        my @pin_status =
          _validate_new_pin( $class, $db, $fieldsref, $messagesref, $token,
            $offset, $limit );
        if ( scalar(@pin_status) > 0 ) {
            @status = ( @status, @pin_status );
        }
    }

    my $user_ref1 =
      check_name_exists( $class, $db, $fieldsref, $messagesref, $token, $offset,
        $limit );

    # adding a user that already exists
    if ( length($user_ref1) && $action eq "adduser" ) {
        push @status, $messagesref->{userexists};
    }

    my $user_ref2 =
      check_email_exists( $class, $db, $fieldsref, $messagesref, $token,
        $offset, $limit );

    # adding a user email exists
    if ( length($user_ref2) && $action eq "adduser" ) {
        push @status, $messagesref->{emailexists};
    }

    # modifying a user email exists and not this user
    # FIXME: this is probably inadequate...race condition
    if ( length($user_ref2) && $action eq "update" ) {
        if ( $user_ref2->{'userId'} != $fieldsref->{'userId'} ) {
            push @status, $messagesref->{emailexists};
        }
    }

    # last operation add major status, if minor values are present
    if ( scalar(@status) > 0 ) {
        unshift @status, -1;
    } else {
        unshift @status, 1;
    }
    return @status;
}

=head3 check_name_exists

Abstrated out of validate because this is used
for validation of REST style additions

This doesn't deal will database problems

=cut

sub check_name_exists {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;

    #FIXME: not accepted if username exists already or email exists already
    # now updated for blank 'order by' string after sql string
    # ugly needs doing with count, really

    my ( $error, $user_ref ) =
      get_where( $class, $db, 'om_users', '*', 'userLogin',
        $fieldsref->{userLogin},
        $token, $offset, $limit );

    if ( !length($error) && length($user_ref) ) {
        return $user_ref;    # exists already
    } else {
        return undef;        # userLogin is unique
    }

}

=head3 check_email_exists

Abstrated out of validate because this is used
for validation of REST style additions

FIXME: This doesn't deal will any database problems


=cut

sub check_email_exists {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;

    #FIXME: not accepted if username exists already or email exists already
    # now updated for blank 'order by' string after sql string
    # ugly needs doing with count, really

    my ( $error, $user_ref ) =
      get_where( $class, $db, 'om_users', '*', 'userEmail',
        $fieldsref->{'userEmail'},
        $token, $offset, $limit );

    if ( !length($error) && length($user_ref->{'userId'}) ) {
        return $user_ref;    # exists already
    } else {
        return undef;        # email is unique
    }

}

=head3 validate_partner

Validate the fields in partner registry before action

=cut

sub validate_partner {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;
    my @status;

    # registry name must start with alpha
    if ( $fieldsref->{dname} !~ /^[a-zA-Z]\w+$/ ) {
        push @status, $messagesref->{badregistryname};
    }

    if ( $fieldsref->{'type'} eq 'local' ) {
        my @registries =
          Ccadmin::show_registries( 'local', $db, '', $fieldsref, 'values',
            $token );
        my $regex = join( '|', @registries );

        if ( $fieldsref->{'dname'} !~ /$regex/ ) {
            push @status, $messagesref->{nonexistentpartner};
        }
    }

    # only need uri and proxy for proxy type partners
    if ( $fieldsref->{'type'} eq 'proxy' ) {

        # uri must start with http://
        if ( $fieldsref->{uri} !~ /^http\:\/\/.*\/Cclite/ ) {
            push @status, $messagesref->{baduriname};
        }

        # proxy must start with http://
        if ( $fieldsref->{proxy} !~ /^http\:\/\/.*ccserver.cgi/ ) {
            push @status, $messagesref->{badproxyname};
        }
    }

    # there's no really good match for valid email addresses, in fact..
    if ( $fieldsref->{email} !~
        /^\+?[a-z0-9](([-+.]|[_]+)?[a-z0-9]+)*@([a-z0-9]+(\.|\-))+[a-z]{2,6}$/ )
    {
        push @status, $messagesref->{bademail};
    }

    # type must not be blank
    if ( !length( $fieldsref->{type} ) ) {
        push @status, $messagesref->{blankpartnertype};
    }

    return @status;
}

=head3 validate_transaction

Validate the fields in transaction before action

=cut

sub validate_transaction {

    my ( $class, $db, $fieldsref, $token, $offset, $limit ) = @_;
    my @status;

    # registry name must be filled
    # quantity isn't absent, negative or non-numeric
    if (   ( !length( $fieldsref->{quantity} ) )
        || ( $fieldsref->{quantity} lt 0 )
        || ( $fieldsref->{quantity} !~ /^[\d\056]+$/ ) )
    {
        push @status, "can't accept negative quantities";
    }

    # last operation add major status, if minor values are present
    if ( scalar(@status) > 0 ) {
        unshift @status, -1;
    } else {
        unshift @status, 1;
    }
    return @status;
}

=head3 _validate_address

Validate address

This should be private, it's used by other validation
functions and not on its own. Switched off at present
full addresses not kept currently

=cut

sub _validate_address {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;
    my @status;

    # Street starts with alpha, has two components
    if ( $fieldsref->{userStreet} !~ /[\'a-zA-z](\w+)(\W+)(\w+)/ ) {
        push @status, $messagesref->{badstreet};
    }

    # Town starts with alpha, is alphanumeric
    if ( $fieldsref->{userTown} !~ /^[\'a-zA-z](\w+)$/ ) {
        push @status, $messagesref->{badtown};
    }

    # this will do UK, Canada, US and (afaik) most of Europe
    if (
        $fieldsref->{userPostcode} !~
        /\b[a-z]{1,2}\d{1,2}[a-z]?\s*\d[a-z]{2}\b/i
        && $fieldsref->{userPostcode} !~ /\b\d{5}(?:[-\s]\d{4})?\b/
        && $fieldsref->{userPostcode} !~ /\b[0-9]{6}\b/i

      )
    {
        push @status, $messagesref->{badpostcode};
    }

    return @status;
}

=head3 _validate_new_password

Check that the password and confirmation are the same
Need to add checks for easy passwords etc.

=cut

sub _validate_new_password {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;
    my @status;

    # password must be filled
    # they must be equal
    if ( $fieldsref->{userPassword} ne $fieldsref->{cuserPassword} ) {
        push @status, $messagesref->{passwordnotsame};
    }
    if ( $fieldsref->{userPassword} eq $fieldsref->{userLogin} ) {
        push @status, $messagesref->{passwordnelogin};
    }
    if ( length( $fieldsref->{userPassword} ) < 6 ) {
        push @status, $messagesref->{passwordgesix};
    }
    return @status;
}

=head3 validate_service_charge

Check that the service charge fields are sensible, if service charge limit is numeric
it's tested against

=cut

sub validate_service_charge {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;
    my @status;
    if ( ( $fieldsref->{value} > $fieldsref->{servicechargelimit} )
        && $fieldsref->{servicechargelimit} =~ /^\d+$/ )
    {
        push @status, $messagesref->{overservicechargelimit};
    }
    return @status;
}

=head3 _validate_new_pin

Check that the pin and confirmation are the same
Need to add checks for easy passwords etc.
If there's a mobile phone number, need a PIN number

=cut

sub _validate_new_pin {

    my ( $class, $db, $fieldsref, $messagesref, $token, $offset, $limit ) = @_;
    my @status;

    # pin and confirmation must be filled
    if ( !length( $fieldsref->{userPin} ) || !length( $fieldsref->{cuserPin} ) )
    {
        push @status, $messagesref->{'needpin'};
    }
    if ( $fieldsref->{userPin} =~
        /123|234|345|456|789|321|432|543|654|765|876|987/ )
    {
        push @status, $messagesref->{'pinobvious'};
    }
    if ( $fieldsref->{userPin} =~ /(\d)(\d)(\d)/ && $1 == $2 && $2 == $3 ) {
        push @status, $messagesref->{'pinsamenumbers'};
    }

    # they must be equal
    if ( $fieldsref->{userPin} ne $fieldsref->{cuserPin} ) {
        push @status, $messagesref->{'pinconfirmdifferent'};
    }

    return @status;
}

=head3 create_utilityscriptlets

This is probably dead code as of 11/2008

=cut

sub create_utilityscriptlets {

    my ( $language, $literalsref ) = @_;

    my $validate = <<EOT;
   //
   // these functions are automatically supplied from Ccscript.pm
   // they are small functions that validate individual fields 
   //
   function alphanotempty (element,value) {
     if (value == "") {
       alert (element + ' must be filled ' + \' $$literalsref{1}\' );
       focus() ;
     } 

     var match = /\d/.test(value) ;

     if (match) {
       alert (element + 'match must be letters only' + \' $$literalsref{1}\' );
       focus() ;
     }
      return true ;    
   }

   function notempty (element,value) {
    if (value == "") {
      alert (element + ' must be filled');
      focus() ;
    } else {
    return ;
    }  
   }


   function thisequalsthat (element,value,element1,value1) {
    if (value != value1) {
      alert (element1 + ' must equal ' + element);
      focus() ;
    } else {
     return false;
    }  
   }

EOT

    return $validate;
}

=head3 make_submitwarning

This is currently unused but required for inter-registry
transactions. Perhaps not in this form.

Make a warning that the submit process will take some time to complete. This is
the case for checkin/export operations, for example.

Kept in code as a reminder

=cut

sub make_submitwarning {
    my $warning_text =
"This operation may take a moment please do not press Submit several times!"
      ;    # abstracted to deal with multilingual operation
    my $be_patient = <<EOT;
// make a warning about a lengthy operation after submit
//
  function warnsubmit () {
    alert(\'$warning_text\') ;
  }
EOT
    return $be_patient;
}

=head3 make_sha1

Provide the SHA1 algorithm functions as Javascript
Need this for SHA2 now, to be replaced or removed

2007 will remain for the moment because of prospective
Windows version

=cut

sub make_sha1 {

    my $sha1_functions = <<EOT;
/*
 * A JavaScript implementation of the Secure Hash Algorithm, SHA-1, as defined
 * in FIPS PUB 180-1
 * Version 2.1 Copyright Paul Johnston 2000 - 2002.
 * Other contributors: Greg Holt, Andrew Kepert, Ydnar, Lostinet
 * Distributed under the BSD License
 * See http://pajhome.org.uk/crypt/md5 for details.
 */

/*
 * Configurable variables. You may need to tweak these to be compatible with
 * the server-side, but the defaults work in most cases.
 */
var hexcase = 0;  /* hex output format. 0 - lowercase; 1 - uppercase        */
var b64pad  = ""; /* base-64 pad character. "=" for strict RFC compliance   */
var chrsz   = 8;  /* bits per input character. 8 - ASCII; 16 - Unicode      */

/*
 * These are the functions you'll usually want to call
 * They take string arguments and return either hex or base-64 encoded strings
 */
function hex_sha1(s){return binb2hex(core_sha1(str2binb(s),s.length * chrsz));}
function b64_sha1(s){return binb2b64(core_sha1(str2binb(s),s.length * chrsz));}
function str_sha1(s){return binb2str(core_sha1(str2binb(s),s.length * chrsz));}
function hex_hmac_sha1(key, data){ return binb2hex(core_hmac_sha1(key, data));}
function b64_hmac_sha1(key, data){ return binb2b64(core_hmac_sha1(key, data));}
function str_hmac_sha1(key, data){ return binb2str(core_hmac_sha1(key, data));}

/*
 * Perform a simple self-test to see if the VM is working
 */
function sha1_vm_test()
{
  return hex_sha1("abc") == "a9993e364706816aba3e25717850c26c9cd0d89d";
}

/*
 * Calculate the SHA-1 of an array of big-endian words, and a bit length
 */
function core_sha1(x, len)
{
  /* append padding */
  x[len >> 5] |= 0x80 << (24 - len % 32);
  x[((len + 64 >> 9) << 4) + 15] = len;

  var w = Array(80);
  var a =  1732584193;
  var b = -271733879;
  var c = -1732584194;
  var d =  271733878;
  var e = -1009589776;

  for(var i = 0; i < x.length; i += 16)
  {
    var olda = a;
    var oldb = b;
    var oldc = c;
    var oldd = d;
    var olde = e;

    for(var j = 0; j < 80; j++)
    {
      if(j < 16) w[j] = x[i + j];
      else w[j] = rol(w[j-3] ^ w[j-8] ^ w[j-14] ^ w[j-16], 1);
      var t = safe_add(safe_add(rol(a, 5), sha1_ft(j, b, c, d)), 
                       safe_add(safe_add(e, w[j]), sha1_kt(j)));
      e = d;
      d = c;
      c = rol(b, 30);
      b = a;
      a = t;
    }

    a = safe_add(a, olda);
    b = safe_add(b, oldb);
    c = safe_add(c, oldc);
    d = safe_add(d, oldd);
    e = safe_add(e, olde);
  }
  return Array(a, b, c, d, e);
  
}

/*
 * Perform the appropriate triplet combination function for the current
 * iteration
 */
function sha1_ft(t, b, c, d)
{
  if(t < 20) return (b & c) | ((~b) & d);
  if(t < 40) return b ^ c ^ d;
  if(t < 60) return (b & c) | (b & d) | (c & d);
  return b ^ c ^ d;
}

/*
 * Determine the appropriate additive constant for the current iteration
 */
function sha1_kt(t)
{
  return (t < 20) ?  1518500249 : (t < 40) ?  1859775393 :
         (t < 60) ? -1894007588 : -899497514;
}  

/*
 * Calculate the HMAC-SHA1 of a key and some data
 */
function core_hmac_sha1(key, data)
{
  var bkey = str2binb(key);
  if(bkey.length > 16) bkey = core_sha1(bkey, key.length * chrsz);

  var ipad = Array(16), opad = Array(16);
  for(var i = 0; i < 16; i++) 
  {
    ipad[i] = bkey[i] ^ 0x36363636;
    opad[i] = bkey[i] ^ 0x5C5C5C5C;
  }

  var hash = core_sha1(ipad.concat(str2binb(data)), 512 + data.length * chrsz);
  return core_sha1(opad.concat(hash), 512 + 160);
}

/*
 * Add integers, wrapping at 2^32. This uses 16-bit operations internally
 * to work around bugs in some JS interpreters.
 */
function safe_add(x, y)
{
  var lsw = (x & 0xFFFF) + (y & 0xFFFF);
  var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
  return (msw << 16) | (lsw & 0xFFFF);
}

/*
 * Bitwise rotate a 32-bit number to the left.
 */
function rol(num, cnt)
{
  return (num << cnt) | (num >>> (32 - cnt));
}

/*
 * Convert an 8-bit or 16-bit string to an array of big-endian words
 * In 8-bit function, characters >255 have their hi-byte silently ignored.
 */
function str2binb(str)
{
  var bin = Array();
  var mask = (1 << chrsz) - 1;
  for(var i = 0; i < str.length * chrsz; i += chrsz)
    bin[i>>5] |= (str.charCodeAt(i / chrsz) & mask) << (24 - i%32);
  return bin;
}

/*
 * Convert an array of big-endian words to a string
 */
function binb2str(bin)
{
  var str = "";
  var mask = (1 << chrsz) - 1;
  for(var i = 0; i < bin.length * 32; i += chrsz)
    str += String.fromCharCode((bin[i>>5] >>> (24 - i%32)) & mask);
  return str;
}

/*
 * Convert an array of big-endian words to a hex string.
 */
function binb2hex(binarray)
{
  var hex_tab = hexcase ? "0123456789ABCDEF" : "0123456789abcdef";
  var str = "";
  for(var i = 0; i < binarray.length * 4; i++)
  {
    str += hex_tab.charAt((binarray[i>>2] >> ((3 - i%4)*8+4)) & 0xF) +
           hex_tab.charAt((binarray[i>>2] >> ((3 - i%4)*8  )) & 0xF);
  }
  return str;
}

/*
 * Convert an array of big-endian words to a base-64 string
 */
function binb2b64(binarray)
{
  var tab = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  var str = "";
  for(var i = 0; i < binarray.length * 4; i += 3)
  {
    var triplet = (((binarray[i   >> 2] >> 8 * (3 -  i   %4)) & 0xFF) << 16)
                | (((binarray[i+1 >> 2] >> 8 * (3 - (i+1)%4)) & 0xFF) << 8 )
                |  ((binarray[i+2 >> 2] >> 8 * (3 - (i+2)%4)) & 0xFF);
    for(var j = 0; j < 4; j++)
    {
      if(i * 8 + j * 6 > binarray.length * 32) str += b64pad;
      else str += tab.charAt((triplet >> 6*(3-j)) & 0x3F);
    }
  }
  return str;
}

EOT

    return $sha1_functions;

}

1;
