#!/var/bin/perl
#!/usr/bin/perl
################################################################################
##                                                                            ##
## Author     : Monty Scroggins                                               ##
## Description: Manage the turnover log. Allows multiple to make logfile      ##
##              entries at the same time                                      ##
##                                                                            ##
##  Parameters: none                                                          ##
##                                                                            ##
## +++++++++++++++++++++++++++ Maintenance Log ++++++++++++++++++++++++++++++ ##
# Monty Scroggins 04-08-98 Script created.
#
# Monty Scroggins  Thu May 7 13:11:12 CDT 1998 
#   Modified search routines, added "find_all" and "clear_highlight" routines
#
# Monty Scroggins Fri May 8 14:55:42 CDT 1998  
#   Small bug fixes
#
# Monty Scroggins Tue May 12 13:08:10 CDT 1998
#   Added color codeing, wrote insert routine so the new entries are inserted
#   properly into the timeline of the log.
#
# Monty Scroggins Wed May 13 12:09:36 CDT 1998
#   Modified check_inuse to only lock the logfile when a read or write is
#   being performed allowing multiple users to have the turnover log utility
#   up at the same time.
#
# Monty Scroggins Sat May 16 12:21:21 CDT 1998
#   Made modifications to _try_ and handle odd formatting when users manually
#   edit the log.  word wrapping modified.  Some cleanup. Path specified to 
#   datafiles to allow users to run turnover.pl without having to set default
#   to the turnover directory. 
#
# Monty scroggins Thu May 21 17:54:39 CDT 1998
#   Added case sensitivity toggle for searches.  Added search hit tally to 
#   search titlebars.  Updated help screen. Added code to do nothing if no
#   words are entered for a log entry and submit is attempted.
#
# Monty Scroggins Thu Jun 11 11:55:34 CDT 1998
#   Increased the name field to handle multiple word entries of extended
#   length.  Added code to clean up any non word characters in initials.
#   Changed color of new entry bar to be more pleasant since the bar is now
#   extended to 80 chars.
#
# Monty Scroggins Wed May 5 22:45:47 GMT 1999
#   Cleaned up the text formatting routine a bit.  Added pod lines
################################################################################
#

#the current version
local $VERSION="1.7.0";

=head1 NAME

Turnover - a shared logfile manager. 

=head1 DESCRIPTION

Turnover features:

=over 4

Allows multiple people to make logfile entries concurrently without overwriting 
each others logfile entries.

View the logfile entries with colorization for easy delineation.

View archived logfiles with the same colorization.

Perform incremental or standard searches.

Timestamps can be manually set to enter a logfile entry for a specific date/time.

=back

=head1 PREREQUISITES

This script requires the following non-core Perl Modules:

=over 4

C<Tk Toolkit>

C<Tk::HistEntry>

=back


=pod SCRIPT CATEGORIES

CPAN/Administrative
Fun/Educational

=cut

use Tk;
use Tk::Dialog;
use Tk::ROText;
use Text::Wrap;
use Tk::HistEntry;

#perl variables
$|=1; # set output buffering to off
$[ = 0; # set array base to 0
$, = ' '; # set output field separator
$\ = "\n"; # set output record separator to null

$VERSION=1.7;

#The colors
$txtbackground="snow2";
$background="bisque3";
$troughbackground="bisque4";
$buttonbackground="#caaa89";
$txtforeground="black";
$windowfont="8x13bold";
$standout="\#cfc0b4";
$buttonwidth=8;

#uhh...  the path prefix...  if the "-loc" argument is given, the local dir is used instead
$pathprefix="/usr/tools/turnover";

#the pid file used to detect if the proggie is being used
$pidfile="$pathprefix/turnover.pid";

#the turnover log filename
$logfile="$pathprefix/turnover.log";

#the utility to view previously archived logs
$archviewer="$pathprefix/archlogview.pl";

#the direcotry where the archived logs are kept
$archivedir="$pathprefix/archive";

$editcommand="nedit -tabs 8 -nowrap -autosave -xrm \"nedit.emulateTabs: 8\" ";

#if the "-local" argument is specified, use the local directory 
#for data instead of going to the real log
if ($ARGV[0] =~ /^\-loc/i) {
   print "local directory used";
   $prtfile="turnover.prt";
   $pidfile="turnover.pid";
   $logfile="turnover.log";
   $archviewer="archlogview.pl";
   }
  
#short wrap is the wrap point for any text entered into the new item widget
$wrap=82;

#null out the history list for the search dialog
my @searchlist="";  

#get the current date info
($year,$month,$day,$hour,$minute,$seconds)=split(",",`date '+%Y,%m,%d,%H,%M,%S'`);

#define the help text for the help window
$helptext="
 $0
 
 This utility is used to update the turnover logfile. Multiple 
 users can safely use turnover.pl to make log entries concurrently
 without the worry of over-writing each others entries.
 
 
 The Sliders are:
         
 Month     => Used to set the date/time stamp for a new entry submission.
 Day       => The date/time is automatically set to the current date/time,
 Hour      => but can be manually manipulated to set a specific date/time
 Minute    => for a new log entry.  This date/time stamp will be used to
 Seconds   => insert the new log entry into the turnover log at the proper
              placement to maintain a chronological order.
                             
 
 The Entries are:
 
 Your Name => Used to collect the users initals or name to be used in the
              new log entry marker.
 
 
 The Buttons are:
 
 Submit  => Submits a log entry to the turnover log file.
 
 Edit    => Allows editing of the entire turnover log file.  
       
      Save     => Saves the edited turnover log.
 
      Cancel   => Exits the edit menu without saving.
 
 
 Archive => Creates an archive of the turnover logfile under the subdirectory
            \"archive\".  the format is (yyyymmdd_hh:mm.log).
 
            ** Note - This function clears the current logfile. **
 
 Re-Read => Re-reads the logfile into the viewing pane. 
 
 Search  => Allows searching of turnover log for a specific string.
 
      Find     => Incrementally searches the turnover log and scrolls to the 
                  location of the string location.
 
      Find All => Searches and highlights all locations of the matching string.
   
      Case     => Toggles case sensitivity on and off for searches.  
 
 Help    => Displays this window
 
 Exit    => Exits the turnover program. 
 
 -------------------------------------------------------------------------
 
 Version 1.5
 Wed Apr 14 14:26:51 CDT 1999
 
";

#===============================================================================
#readin the datafile for the first time
#check to see if a pid file exists.  This would indicate the logfile is locked.
#which can only happen in some odd circumstance.
&check_inuse;
#if the delete pid dialog was cancelled off, exit;
if ($fileclosed==0) {
  exit;
  };
  
&readin;
MainLoop;
#  
#########################################################################
#Subs
#
#check to see if the turnover log is locked
sub check_inuse {
   $confirm="Delete";
   $fileclosed=1;
   if (-e $pidfile) {
      $waitcount=0;
      $fileclosed=0;
      $retrycount=10;
      print "\nwaiting for the logfile to be closed";
      until ("$waitcount" eq "$retrycount") {
         print "retrying..";
         sleep(1);
         if (!-e $pidfile) {
            $fileclosed=1;
            return;
            }
         $waitcount++;  
         }#until
      }#if -e pidfile
   if ($fileclosed==0) {
      open(pidfile, $pidfile) || die "PID File exists but can't be opened - $pidfile";
      $empid=<pidfile>;
      chomp $empid;
      close (pidfile);
      $stillon=`p\s -o user -o pid -o etime -o tty -p $empid`;
      my ($head,$data)=split("\n",$stillon);
      if ($data ne "") {
         ($olduser)=split(" ",$data);
         $addinfo=$stillon;
         }else{
            $olduser="Another user";
            $addinfo="The PID no longer exists on this machine.";
            }#else
    $confirmtext="
- WARNING -\n
A lock file for PID \"$empid\" exists.\n 
\"$olduser\" has the logfile locked. The logfile 
is only locked when reads or writes are being 
made OR THE FILE IS BEING MANUALLY EDITED!..\n
If you are sure another user is not using the
turnover utility, you can select delete and 
have the lock file removed.\n\n
IT IS STRONGLY RECOMMENDED YOU CONTACT THIS 
PERSON BEFORE DELETING THE LOCKFILE!\n\
$addinfo\nDelete the lock file and continue??";
      &oper_confirm("Delete","Cancel",2);
      if ($confirm eq "Delete") {
         &pid_remove;
         }
      }#if fileclosed
}#sub check_inuse

# Read in the Turnover Log
sub readin {
   return if ($fileclosed==0);
   # The main window
   $MW = MainWindow->new;

   #set the window title
   $MW->configure(
      -title=>"Turnover Log as of $year$month$day $hour:$minute:$seconds",
      -background=>$background,
      -foreground=>$txtforeground,
      -borderwidth=>0,
      -highlightthickness=>0,
      -relief=>'flat',
      );

   #width,height in lines    
   $MW->minsize(92,30);
   $MW->maxsize(92,50);

   #log text frame
   $logframe2=$MW->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      )->pack(
         -expand=>1,
         -fill=>'both',
         -pady=>'0',
         -padx=>'1',
         );

   #log entry frame
   $logframe3=$MW->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      )->pack(
         -pady=>'2',
         -padx=>'1',
         -anchor=>'w',
         );

   #buttonrow frame
   $logframe4=$MW->Frame(
      -borderwidth=>'1',
      -relief=>'raised',
      -background=>$standout,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      )->pack(
         -fill=>'x',
         -pady=>'4',
         -padx=>'1',
         );

   #initials frame
   $logframe5=$logframe4->Frame(
      -borderwidth=>'1',
      -relief=>'sunken',
      -background=>$background,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      )->pack(
         -pady=>'2',
         -padx=>2,
         -side=>'right',
         -expand=>0,
         -fill=>'y',
         );

   #buttonrow frame
   $logframe6=$MW->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      )->pack(
         -fill=>'x',
         -pady=>'2',
         -padx=>'1',
         );

   # Create a scrollbar on the right side and bottom of the listbox
   $scrollx=$logframe2->Scrollbar(
      -orient=>'horiz',
      -elementborderwidth=>1,
      -highlightthickness=>0,
      -background=>$background,
      -troughcolor=>$troughbackground,
      -relief=>'flat',
      )->pack(
         -side=>'bottom',
         -fill=>'x',
         );
   # Create a scrollbar on the right side and bottom of the listbox
   $scrolly=$logframe2->Scrollbar(
      -orient=>'vert',
      -elementborderwidth=>1,
      -highlightthickness=>0,
      -background=>$background,
      -troughcolor=>$troughbackground,
      -relief=>'flat',
      )->pack(
         -side=>'right',
         -fill=>'y',
         );

   #the logfile readonly text widget
   $loglist=$logframe2->ROText(
      -xscrollcommand=>['set', $scrollx],
      -yscrollcommand=>['set', $scrolly],
      -font=>$windowfont,
      -relief=>'sunken',
      -highlightthickness=>0,
      -background=>$txtbackground,
      -foreground=>$txtforeground,
      -selectforeground=>$txtforeground,
      -selectbackground=>'#c0d0c0',
      -wrap=>'none',
      -borderwidth=>1, 
      -setgrid => 1,
      -width=>89,
      )->pack(
         -expand=>1,
         -fill=>'both'
         );

   $scrollx->configure(-command => ['xview', $loglist]);
   $scrolly->configure(-command => ['yview', $loglist]);

   ##############################################################
   #The log entry section

   #spacing for the ruler label.. This label is not seen.
   $logframe3->Label(
      -text=>'',
      -background=>$background,
      -foreground=>$txtforeground,
      -font=>$windowfont,
      -width=>7,
      )->pack(
         -pady=>0,
         -padx=>0,
         -side=>'left',
         );

   #a ruler to show column numbers - with wrapping set to the width of the text
   #widget, this becomes a WYSIWYG style edit box..  the wrapping of the text entry
   #widget stays in tact.  :-)    
   $logframe3->Label(
      -text=>'.........1.........2.........3.........4.........5.........6.........7.........8',
      -borderwidth=>'0',
      -background=>$background,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>'8x13',
      )->pack(
         -padx=>2,
         -anchor=>'nw',
         );

   # Create a scrollbar on the right side of the log text
   $entrylistscroll=$logframe3->Scrollbar(
      -orient=>'vert',
      -elementborderwidth=>1,
      -highlightthickness=>0,
      -background=>$background,
      -troughcolor=>$troughbackground,
      -relief=>'flat',
      )->pack(
         -side=>'right',
         -fill=>'y',
         );

   #the editable text entry widget
   $entrylist=$logframe3->Text(
      -yscrollcommand=>['set', $entrylistscroll],
      -font=>$windowfont,
      -relief=>'sunken',
      -highlightthickness=>1,
      -highlightcolor=>'black',
      -highlightbackground=>$background,
      -selectforeground=>$txtforeground,
      -selectbackground=>'#c0d0c0',
      -background=>$txtbackground,
      -foreground=>$txtforeground,
      -borderwidth=>1,
      -width=>81,
      -height=>7, 
      -wrap=>'word',
      -setgrid=>'yes',
      )->pack(
         -fill=>'y',
         -expand=>0,
         -side=>'left',
         );

   $entrylistscroll->configure(-command => ['yview', $entrylist]);

   #buttonrow frame
   $dateframe=$logframe4->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$standout,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -width=>30,
      )->pack(
         -padx=>'0',
         -side=>'left',
         -fill=>'y',
         );

   ##############################################################
   #the time scales allow the user to specify the time/date string 
   #used in a new log entry submission
   #month
   $logframe4->Scale(
      -variable=>\$month,
      -orient=>'horizontal',
      -label=>'Month:',
      -from=>01,
      -to=>11,
      -borderwidth=>'1',
      -width=>12,
      -length=>92,    
      -troughcolor=>$troughbackground,    
      -background=>$standout,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      )->pack(
         -side=>'left',
         -padx=>1,
         );

   #day
   $logframe4->Scale(
      -variable=>\$day,
      -label=>'Day:',
      -orient=>'horizontal',
      -from=>1,
      -to=>31,
      -borderwidth=>'1',
      -width=>12,
      -length=>92,    
      -troughcolor=>$troughbackground,    
      -background=>$standout,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      )->pack(
         -side=>'left',
         -padx=>1,
         );

   #hour
   $logframe4->Scale(
      -variable=>\$hour,
      -label=>'Hour:',
      -orient=>'horizontal',
      -from=>0,
      -to=>23,
      -borderwidth=>'1',
      -width=>12,
      -length=>92,    
      -troughcolor=>$troughbackground,    
      -background=>$standout,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      )->pack(
         -side=>'left',
         -padx=>1,
         );

   #minute
   $logframe4->Scale(
      -variable=>\$minute,
      -label=>'Minute:',
      -orient=>'horizontal',
      -from=>0,
      -to=>59,
      -borderwidth=>'1',
      -width=>12,
      -length=>92,
      -troughcolor=>$troughbackground,    
      -background=>$standout,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      )->pack(
         -side=>'left',
         -padx=>1,
         );

   #seconds
   $logframe4->Scale(
      -variable=>\$seconds,
      -label=>'Seconds:',
      -orient=>'horizontal',
      -from=>0,
      -to=>59,
      -borderwidth=>'1',
      -width=>12,
      -length=>92,
      -troughcolor=>$troughbackground,    
      -background=>$standout,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      )->pack(
         -side=>'left',
         -padx=>1);

   ##############################################################
   #the username or initials entry
   $logframe5->Entry(
      -background=>$txtbackground,
      -foreground=>$txtforeground,
      -width=>16,
      -borderwidth=>1,
      -relief=>'sunken',
      -font=>$windowfont,
      -highlightthickness=>0,
      -textvariable=>\$initials,
      )->pack(
         -pady=>7,
         -padx=>6,
         -side=>'right',
         );

   $logframe5->Label(
      -text=>'Your Name:',
      -background=>$background,
      -foreground=>$txtforeground,
      -font=>$windowfont,
      )->pack(
         -pady=>7,
         -padx=>6,
         -side=>'right',
         );

   ##############################################################
   #buttonrow

   $submitbutton=$logframe6->Button(
      -text=>'Submit!',
      -borderwidth=>'1',
      -width=>$buttonwidth,
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub{&sel_submit},
      )->pack(
         -expand=>1,
         -fill=>'x',
         -side=>'left',
         -padx=>1,
         );

   $editbutton=$logframe6->Button(
      -text=>'Edit',
      -borderwidth=>'1',
      -width=>$buttonwidth,
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub{&edit},
      )->pack(
          -side=>'left',
          -padx=>1,
          );

   $prevlogsbutton=$logframe6->Button(
      -text=>'Prev Logs',
      -borderwidth=>'1',
      -width=>$buttonwidth,
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub{
       $prevlogsbutton->configure(-state=>'normal');
       system ("$archviewer \&");
       },
      )->pack(
         -side=>'left',
         -padx=>1,
         );

   $archivebutton=$logframe6->Button(
      -text=>'Archive',
      -borderwidth=>'1',
      -width=>$buttonwidth,
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub{&archive},
      )->pack(
         -side=>'left',
         -padx=>1,
         );

   $rereadbutton=$logframe6->Button(
      -text=>'Re-Read',
      -borderwidth=>'1',
      -width=>$buttonwidth,
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub{&reread},
      )->pack(
         -side=>'left',
         -padx=>1,
         );

   $searchbutton=$logframe6->Button(
      -text=>'Search',
      -borderwidth=>'1',
      -width=>$buttonwidth,
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub{&search},
      )->pack(
         -side=>'left',
         -padx=>1,
         );

   $helpbutton=$logframe6->Button(
      -text=>'Help',
      -borderwidth=>'1',
      -width=>$buttonwidth,
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub{&sel_help},
      )->pack(
         -side=>'left',
         -padx=>1,
         );

   $logframe6->Button(
      -text=>'Exit',
      -borderwidth=>'1',
      -width=>$buttonwidth,
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub{&destroy_all},
      )->pack(
         -side=>'left',
         -padx=>1,
         );
   &loadlines;    
   &colorize;  
   $entrylist->focus;
}#sub readin

sub loadlines {
  ##############################################################
  #built the display window, now lock and load the logfile
    &pid_create;
    open(logfile, $logfile) || die "Fatal Error - Can't open $logfile!";
    @loglines=<logfile>;
    close(logfile);
    #release the lock on the logfile now that it has been loaded
    &pid_remove;

  $loglist->delete(0.1,'end');
  foreach (@loglines) {
      next if (/^\W*$/);
      $_=&format_entries("$_",$wrap);
      if (/^ *\+\>/) {
         $loglist->insert('end',"\n$_");
         }else{
            $loglist->insert('end',"        $_");
            } 
      } #foreach loglines  
    #remove the first line if it doesnt contain a word character  
    $firstline=$loglist->get('0.0','2.0');
    if ($firstline =~ /^\W+$/) {
      $loglist->delete('0.0','2.0');
     }
    #set the window title
  ($year,$month,$day,$hour,$minute,$seconds)=split(",",`date '+%Y,%m,%d,%H,%M,%S'`);
  $MW->configure(-title=>"Turnover Log as of $year$month$day $hour:$minute:$seconds"); 
  }#sub loadlines

sub format_entries {
  my ($line,$wrap)=@_;
  $padding="                                                                                ";
  local $Text::Wrap::columns=$wrap;
  #wrap is slow, dont execute it unless we have to..
  if (length($line) >$wrap) {
     $line=wrap("","","$line");
     }
  $line=~ s/^ *\t+ */\t/;
  $line=~ s/\n */\n/g;
  $line=~ s/\t/\ \ \ \ \ \ \ \ /g;
  #+> is a new entry marker
  if ($line =~ /^[ \t]*\+\>/) {
     #remove any preceeding spaces or tabs from the new entry designator
     chomp $line;
     $line=~ s/^[\t]*\+\>/\+\>/;
     $line=~ s/^ *\+\>/\+\>/;
     #ensure the entry designator is at least 80 characters for colorizing
     $line=(substr("$line$padding",0,82)."\n");
     }#if  ($line =~ /^[ \t]*\+\>/)
  return "$line";
}

#reading the log on demand
sub reread {
   $rereadbutton->configure(-state=>'normal');
   #lock the log file momentarily
   &check_inuse;
   return if ($fileclosed==0);
   &loadlines;   
   &colorize;  
   $entrylist->focus;
}

# Confirm operator actions
sub oper_confirm {
   (@buttons)=@_;
   if (!@buttons) {
      @buttons=("Yes","Cancel",1);
      } # if buttons
   #set the default button to the element number of the buttons array
   #and pop it off of the array so we dont create a button for it
   $defbutt=(@buttons[pop(@buttons)]);
   $confirmbox=$MW->Dialog(
       -title=>"Message",
       -text=>$confirmtext,
       -borderwidth=>'1',
       -wraplength=>'5i',
       -background=>$background,
       -fg=>$txtforeground, #must be fg and not foreground for text color
       -highlightthickness=>0,
       -font=>$windowfont,
       -bitmap=>'questhead',
       -default_button=>$defbutt,
       -buttons=>[@buttons],
       );
   #the global option does a grab   
   $confirm=$confirmbox->Show(-global);
   return $confirm;
} # sub oper_confirm

# Add Log Entries 
sub sel_submit {
   $submitbutton->configure(-state=>'normal');
   if (!$initials) {
      $confirm="OK";
      $confirmtext="Please Enter Your Name or Initials";
      &oper_confirm("OK",1);
      return;
      }  
   #check to see if the log is locked
   &check_inuse;
   #if the file is closed at this point, ten retries have been attempted to open it  
   return if ($fileclosed==0);
   $newlines=$entrylist->get(0.1,"end");
   #do nothing if no words have been entered into log entry widget
   return if ($newlines =~ /^[\W\s]+$/);
   #if the sliders are used , the values can be one digit, force them to 2 digits 
   $month=sprintf("%02d",$month);
   $day=sprintf("%02d",$day);
   $hour=sprintf("%02d",$hour);
   $minute=sprintf("%02d",$minute);
   $seconds=sprintf("%02d",$seconds);
   #read in the log file again before inserting the new entry
   open(logfile, "<$logfile") || die "Fatal Error - Can't open $logfile!";
   @loglines=<logfile>;
   close(logfile);
   #format the strings to be inserted
   #invariably someone pastes a name in with newlines or a really long string
   #is entered for the initials.  Have to handle it..
   $initials=~ s/[\r\n\t]+//g;
   if ((length($initials))>58) {
      $initials=substr($initials,0,58);
      }
   $entrystring="\+\>$year$month$day $hour:$minute:$seconds - $initials";
   $entrystring=~s/ +/ /g;
   #force the new entry to wrap regardless of the length
   $newlines=&format_entries("$newlines",$wrap);
   $newcmpdate=$year.$month.$day.$hour.$minute.$seconds;
   #set the oldcmpdate to a really big number so we have a starting value and
   #we dont insert the entry twice
   $oldcmpdate=9999999999999999;
   $element=0;
   $written=0;
   foreach (@loglines) {
      #if the line starts with the +> we have a timestamp to parse
      if (/^[ \t]*\+\>/) {
         #if somebody manually edited the file and placed the new entry marker
         #in the wrong place, remove the preceeding spaces or tabs.
         $_=~ s/^[ \t]+\+\>/\+\>/;
         ($cmpdate)=substr($_,2,17);
         #remove the spaces, colon or dash from the date substring
         $cmpdate=~tr/ :-//d;
         #add zeros to the date timestamp if they arent already in the timestamp
         #if the datestamp was manually entered, this can happen
         if ((length($cmpdate)) < 14) {
            $zeropad="000000";
            $cmpdate=substr("$cmpdate$zeropad",0,14);
            } 
         if ($newcmpdate >$cmpdate && $newcmpdate <$oldcmpdate) {
            #splice in the new lines at the proper place
            splice (@loglines,$element,0,"$newlines");
            splice (@loglines,$element,0,$entrystring);
            $written=1;
            }
         if ($newcmpdate > $cmpdate) {
            $oldcmpdate=$cmpdate;
            }
         }#if /^\+\>/
      $element++;
      }# foreach loglines
   #if the end of the elements has been reached but no new entries have been
   #made, the date must preceed any dates in the file..  write to the bottom
   if ($element>$#loglines && $written==0) {
      splice (@loglines,$element,0,"$newlines");
      splice (@loglines,$element,0,$entrystring);
      }
   open(logfile, ">$logfile") || die "Fatal Error - Can't open $logfile!";
   #empty the log widget so it can be reloaded from the file
   $loglist->delete('0.0','end');
   foreach (@loglines) {  
      $_=&format_entries("$_",$wrap);
      #inbetween each new log entry, place a blank line for nice spacing
      #write out the new array
      if (/^[ \t]*\+\>/) {
         print logfile " ";
         }
      if ($_ !~ /^\W$/) {
         chomp $_;
         print logfile $_;
         } 
      }#foreach loglines
   close(logfile);
   &reread;
   #clear out the new entry widget
   $entrylist->delete('0.0','end');
}#sub  sel_submit  

#colorize the date strings for easy identification
sub colorize {  
   #highlight the date lines  
   my $current='1.0';
   $loglist->tag('remove','search', qw/0.0 end/);
   $loglist->tag('remove','fullident', qw/0.0 end/);
   $loglist->tag('remove','yearmonth', qw/0.0 end/);
   while (1) {
      $current=$loglist->search("\+\>",$current,'end');
      last if (!$current);
      #I have overlapping tags so the date will be a different color than
      #the persons name.  Do the longest one first
      $loglist->tag('add','fullident',$current,"$current + 1 line");
      $loglist->tag('configure','fullident',
      -foreground=>'#002040',
      -relief=>'raised',
      -borderwidth=>1,
      -background=>'#f1efe4',
      );
      #now set the date string color
      $loglist->tag('add','yearmonth',$current,"$current + 19 char");
      $loglist->tag('configure','yearmonth',-foreground=>'#660024'); 
      $current=$loglist->index("$current + 1 char"); 
      }
}#sub colorize

sub edit {
  #the edit button fails to return to its normal state - setting it manually
  $editbutton->configure(-state=>'normal');
  $confirm="OK";
  $confirmtext="WARNING - WHEN YOU ARE IN MANUAL EDIT MODE, No OTHER 
USER WILL NOT BE ABLE TO UPDATE THE TURNOVER LOG!\n
Please do not use this mode any longer than absolutely necessary.";
   &oper_confirm("OK","Cancel",0);
   return if ($confirm ne "OK");
   &check_inuse;
   return if ($fileclosed==0);
   &pid_create;
   #call nedit to handle the manual edits... no need to do this in perl
   #if anyone removes nedit from the tools bin directory, may they grow
   #nostrils the size of oil drums..
   system("$editcommand $logfile");
   #when control is returned, remove the pid file
   &pid_remove;
   &reread;
}#sub edit

#write out the pid file to manage file locking and set the fileclosed variable
sub pid_create {
   $newpid=getppid();
   open(pidfile, ">$pidfile") || die "Can't open $pidfile for writing";
   print pidfile $newpid;
   close (pidfile);
   $fileclosed=0;
}#sub pid_create

#remove the pid file and unset the fileclosed variable
sub pid_remove {
   if (-e $pidfile) {unlink $pidfile};
   $fileclosed=1;
}#sub pid_remove

# Archive the logfile
sub archive {
   $archivebutton->configure(-state=>'normal');
   $archivefile= "$archivedir/`date '+%Y%m%d_%H%M'`.log";
   if ($ARGV[0] =~ /^-tes|^-Tes|^-TES|^-loc|^-Loc|^-LOC/) {
      $archivefile= "./archive/`date '+%Y%m%d_%H%M'`.log";
      }
   $confirm="Yes";
   $confirmtext="
This procedure will move the turnover log to 
the archive subdirectory with the naming 
convention YYYYMMDD_HHMM.log.
\nThe old logfile will be cleared in preparation
for new data.
\nArchive the turnover log and continue??";
   &oper_confirm;
   if ($confirm eq "Yes") {
      $cpstat=system("/bin/cp $logfile $archivefile");
      if ($cpstat==0) {
         #dont wipe out the logfile unless the copy is successful
         system("/bin/echo \" \" > $logfile");
         }else{
            $confirmtext="An error has occured trying to archive the\nturnover log.\nPlease check file permissions etc. and try again";
            &oper_confirm("OK",1);
            return;
            }#else
      &reread;
      }#$confirn eq yes
} # sub archive

#Search the Turnover Log File
sub search {
   $searchbutton->configure(-state=>'normal');
   $SW->destroy if Exists($SW);
   $SW=new MainWindow;
   $SW->configure(-title=>'Turnover Log Search');
   #width,height in pixels    
   $SW->minsize(424,55);
   $SW->maxsize(724,55);
   #default to non case sensitive
   $caseflag="nocase";
   $newsearch=1;
   #The top frame for the text
   $searchframe1=$SW->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      )->pack(
         -expand=>1,
         -fill=>'both',
         );
 
   $searchframe2=$SW->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      )->pack(
         -fill=>'x',
         -pady=>2,
         );

   #the checkbox to allow toggling of the case sensitivity flag
   $searchframe1->Checkbutton(
      -variable=>\$caseflag,
      -font=>$windowfont,
      -relief=>'flat',
      -text=>"Case",
      -highlightthickness=>0,
      -highlightcolor=>'black',
      -activebackground=>$background,
      -bg=>$background,
      -foreground=>$txtforeground,
      -borderwidth=>'1',
      -width=>6,
      -offvalue=>"nocase",
      -onvalue=>"case",
      -command=>sub{
         $current='0.0';
         $searchcount=0;
         $newsearch=1;
         },
      )->pack(
         -side=>'left',
         -expand=>0,
         );

   $ssentry=$searchframe1->HistEntry(
      -limit=>20,
      -dup=>0,
      -match => 1,  
      -justify=>'left',
      -font=>$windowfont,
      -relief=>'sunken',
      -textvariable=>\$searchstring,
      -highlightthickness=>1,
      -highlightcolor=>'black',
      -highlightbackground=>$background,
      -bg=>$background,
      -foreground=>$txtforeground,
      -borderwidth=>1,
      -width=>12,
      -bg=> 'white',
      -command=>sub{
         return unless $searchstring;
         $ssentry->historyAdd($searchstring);
         #reset the title in case a previous search has been performed 
         $SW->configure(-title=>'Turnover Log Search');
         },
      )->pack(
         -expand=>1,
         -pady=>3,
         -padx=>0,
         -fill=>'both',
         );

   $searchframe2->Button(
      -text=>'Find',
      -borderwidth=>'1',
      -width=>'10',
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub {&find_one;},
      )->pack(
         -side=>'left',
         -padx=>2,
         );

   $searchframe2->Button(
      -text=>'Find All',
      -borderwidth=>'1',
      -width=>'10',
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub {&find_all;},
      )->pack(
         -side=>'left',
         -padx=>2,
         );

   $searchframe2->Button(
   -text=>'Cancel',
   -borderwidth=>'1',
   -width=>'10',
   -background=>$buttonbackground,
   -foreground=>$txtforeground,
   -highlightthickness=>0,
   -font=>$windowfont,
   -command=>sub{$SW->destroy;&colorize}
   )->pack(
      -side=>'right',
      -padx=>2,
      );
        
   #press enter and perform a single find
   $ssentry->bind('<KeyPress-Return>'=>sub{&find_one;});
   if ($#searchlist>0) {
      $ssentry->history([@searchlist]);
      }
   $ssentry->focus;
} # sub search

#update the search history array with any new strings entered into the
#combobox widget.  Dont allow any duplicates
sub update_searchlist {
   $Last="";
   push (@searchlist, $searchstring);
   #a method to ensure no duplicates are stored in the array
   @searchlist=grep(($Last eq $_ ? 0 : ($Last = $_, 1)),sort @searchlist);
   $ssentry->invoke;
   $ssentry->focus;
}

#search out and highlight any occurance of the specifed search string
sub find_all {
   &update_searchlist;
   #delete any old tags so new ones will show
   $loglist->tag('remove','search', qw/0.0 end/);
   $loglist->tag('remove','fullident', qw/0.0 end/);
   $loglist->tag('remove','yearmonth', qw/0.0 end/);
   $current='0.0';
   $stringlength=length($searchstring);
   $searchcount=0;
   while (1) {
      if ($caseflag eq "case") {  
         $current=$loglist->search(-exact,$searchstring,$current,'end');
         }else{
            $current=$loglist->search(-nocase,$searchstring,$current,'end');
            }  
      last if (!$current);
      $loglist->tag('add','search',$current,"$current + $stringlength char");
      $loglist->tag('configure','search',
         -background=>'chartreuse',
         -foreground=>'black',
         -borderwidth=>1,
         -relief=>'raised',
         );
      $searchcount++;       
      $current=$loglist->index("$current + 1 char");
      }
   $SW->configure(-title=>"$searchcount Matches");
   $searchcount=0;
   $current='0.0';
}

#find and highlight one instance of a string at a time
sub find_one {
   &update_searchlist;
   #delete any old tags so new ones will show
   $loglist->tag('remove','search', qw/0.0 end/);
   $loglist->tag('remove','fullident', qw/0.0 end/);
   $loglist->tag('remove','yearmonth', qw/0.0 end/);
   if ($searchstring ne $searchstringold || $newsearch==1) {
      $allcount=0;
      $tempcurrent='0.0';
      $searchstringold=$searchstring;
      while (1) {
         if ($caseflag eq "case") {  
            $tempcurrent=$loglist->search(-exact,$searchstring,$tempcurrent,'end');
            }else{
               $tempcurrent=$loglist->search(-nocase,$searchstring,$tempcurrent,'end');
               }  
         last if (!$tempcurrent);
         $allcount++;       
         $tempcurrent=$loglist->index("$tempcurrent + 1 char");
         $searchcount=0;
         $current='0.0';
         }
      $newsearch=0; 
      }
   #set the title to indicat the number of searches
   $SW->configure(-title=>"$allcount Matches");  
   #get the length of the search string so we can highlight the proper number
   #of characters
   $stringlength=length($searchstring);
   if (!$current) {
      $current='0.0';
      $searchcount=0;
      } # if current
   my $currentold=$current;   
   if ($caseflag eq "case") {  
      $current=$loglist->search(-exact,$searchstring,"$current +1 char");
      }else{
         $current=$loglist->search(-nocase,$searchstring,"$current +1 char");
         }  
   if ($current eq "") {
      $SW->configure(-title=>"No Matches");
      return;
      }      
   $current=$loglist->index($current);
   $loglist->tag('add','search',$current,"$current + $stringlength char");
   #cant miss the chartreuse and black combination!
   $loglist->tag('configure','search',
      -background=>'chartreuse',
      -foreground=>'black',
      -borderwidth=>1,
      -relief=>'raised',
      );         
   $loglist->see($current);   
} #sub find one

#The help Window
sub sel_help {
   $helpbutton->configure(-state=>'normal');
   #The main help window
   $HW=new MainWindow;
   $HW->configure(-title=>'Turnover Log Utility Help');
   #width,height in lines    
   $HW->minsize(88,25);
   $HW->maxsize(88,49);

   #The top frame for the text
   $helpframe1=$HW->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      )->pack(
         -expand=>1,
         -fill=>'both',
         );

   $helpframe2=$HW->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      )->pack(
         -fill=>'x',
         );

   # Create a scrollbar on the right side and bottom of the text
   $hscrolly=$helpframe1->Scrollbar(
      -orient=>'vert',
      -elementborderwidth=>1,
      -highlightthickness=>0,
      -background=>$background,
      -troughcolor=>$troughbackground,
      -relief=>'flat',
      )->pack(
         -side=>'right',
         -fill =>'y',
         );

   $hscrollx=$helpframe1->Scrollbar(
      -orient=>'horiz',
      -elementborderwidth=>1,
      -highlightthickness=>0,
      -background=>$background,
      -troughcolor=>$troughbackground,
      -relief=>'flat',
      )->pack(
         -side=>'bottom',
         -fill=>'x',
         );

   $helpwin=$helpframe1->ROText(
      -yscrollcommand => ['set', $hscrolly],
      -xscrollcommand => ['set', $hscrollx],
      -font=>$windowfont,
      -relief => 'sunken',
      -highlightthickness=>0,
      -foreground=>$txtforeground,
      -background=>$txtbackground,
      -borderwidth=>1, 
      -width=>90,
      -height=>24,
      -setgrid=>1,
      -wrap=>'none',
      )->pack(
         -expand=>1,
         -fill=>'both',
         );

   $hscrollx->configure(-command => ['xview', $helpwin]);
   $hscrolly->configure(-command => ['yview', $helpwin]);

   $helpwin->insert('end',$helptext);  
   $helpframe2->Button(
      -text=>'Cancel',
      -borderwidth=>'1',
      -width=>'10',
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$windowfont,
      -command=>sub{$HW->destroy;}
      )->pack(
         -side=>'bottom',
         -padx=>2,
         );

}#sub del_help

# Kill any and all turnover windows if they exist
sub destroy_all {
   #check the new entry text widget to see if anything has been entered
   $newlines=$entrylist->get(0.1,"end");
   if ($newlines=~/\S/) {
      $confirmtext="Really Exit??  \nAny Unsubmitted Data Will Be Lost.";
      &oper_confirm;
      }else{
         $confirm="Yes";
         }
   if ($confirm eq "Yes") {
      #if any windows are up, kill them
      $HW->destroy if Exists($HW);
      $SW->destroy if Exists($SW);
      #kill the main window
      $MW->destroy;
      #remove the pid file 
      &pid_remove;
      exit;
      } # if confirm 
}#sub destroy_all

#return a positive status 
1;
