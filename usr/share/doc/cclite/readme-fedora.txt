This will be replace by an update to the manual  and some automation sooner or later...

# getting cclite to go, for example...
#==============================
# chmod -R a+w config
# chmod -R a+x cgi-bin

# chmod a+w /home/<yourdomainuser>/domains/<yoursubdomain>/var/cclite/log/
for example /home/acme/domains/cclite.acme.com/var/cclite/log/
#==============================
# tighten these permissions afterwards!

1. Make sure that the Log::Log4Perl is present, it's necessary for release 0.6.0 

2. Make sure that /config/logging.cf points to the correct log file:

log4perl.appender.LOGFILE.filename=/home/<yourdomainuser>/var/cclite/log/cclite.log
or
log4perl.appender.LOGFILE.filename=/home/<yourdomainuser>/domains/<yoursubdomain>/var/cclite/log/cclite.log
for example, change this line to where you keep this log..BEFORE running the configurator

These layouts are the kind created by virtualmin used from webmin. If you use a hand configured apache
your mileage may vary (but in this case I assume that you know some stuff as well :-) )


3. Make sure that the log path in the installer is correct:
logger config path /home/3wave/domains/cclite.3wave.co.uk/config/logging.cf
for example, the configurator will try and guess this...

4. Change the database user and password at least in the configuration...

5. On Fedora, using virtual you may have to comment SUEXEC in the virtual hosting configuration for Apache
I don't have an immediate workaround for this that preserves SUEXEC.


Use my website contact form to ask for help...but it's not usually immediate..

#  Hugh Barnard 2008...
