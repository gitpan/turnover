#!/var/bin/perl
#!/usr/bin/perl
################################################################################
##                                                                            ##
## Author     : Monty Scroggins                                               ##
## Description: View the old turnover logs in a different window              ##
##                                                                            ##
##  Parameters: none                                                          ##
##                                                                            ##
## +++++++++++++++++++++++++++ Maintenance Log ++++++++++++++++++++++++++++++ ##
# Monty Scroggins Mon Jun 1 12:20:30 CDT 1998 Script created.
#
################################################################################
#
use Tk;
use Tk::ROText;
use Text::Wrap;
use Tk::HistEntry;

#perl variables
$|=1; # set output buffering to off
$[ = 0; # set array base to 0
$, = ' '; # set output field separator
$\ = "\n"; # set output record separator to null

local $VERSION="1.7.0";

#The colors
$txtbackground="snow2";
$background="bisque3";
$troughbackground="bisque4";
$buttonbackground="tan";
$txtforeground="black";
$windowfont="8x13bold";

#the path prefix...  if the "-loc" argument is given, the local dir is used instead
my $pathprefix="/usr/tools/turnover";

#the turnover log filename (if specified)
my $archlog=$ARGV[0];

#short wrap is the wrap point for any text entered into the new item widget
$wrap=82;

#null out the history list for the search dialog
my @searchlist=""; 
  
my $helptext="
 $0
 
 This utility is used to view archived logfiles. 
  
 The Buttons are:
 
 Search  - Allows searching of turnover log for a specific string.
 
      Find     - Incrementally searches the turnover log and scrolls to the 
                 location of the string location.
 
      Find All - Searches and highlights all locations of the matching string.
   
      Case     - Toggles case sensitivity on and off for searches.  
 
 Help    - Displays this window
 
 Exit    - Exits the turnover program. 
 
 -------------------------------------------------------------------------
 
 Version 1.1
 Wed Apr 14 14:26:19 CDT 1999
 
";

#===============================================================================
#readin the datafile for the first time
#if the delete pid file dialog was cancelled off exit;  
&mainwin;
MainLoop;
#  
#########################################################################
#Subs

sub mainwin {
  # The main window
  $AV = MainWindow->new;
  $AV->optionAdd("*background","$background"); 
  $AV->optionAdd("*highlightBackground", "$background");
  #set the window title
  $AV->configure(
    -title=>"Archived Turnover Log Viewer",
    -foreground=>$txtforeground,
    -borderwidth=>0,
    -highlightthickness=>0,
    -relief=>'flat',
    );

  #width,height in lines    
  $AV->minsize(96,35);
  $AV->maxsize(96,50);

  #log text frame
  $archframe2=$AV->Frame(
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

  #buttonrow frame
  $archframe6=$AV->Frame(
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
  $archscrollx=$archframe2->Scrollbar(
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
  $archscrolly=$archframe2->Scrollbar(
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

  $loglist=$archframe2->ROText(
    -xscrollcommand=>['set', $archscrollx],
    -yscrollcommand=>['set', $archscrolly],
    -font=>$windowfont,
    -relief=>'sunken',
    -selectforeground=>$txtforeground,
    -selectbackground=>'#c0d0c0',
    -highlightthickness=>0,
    -background=>$txtbackground,
    -foreground=>$txtforeground,
    -borderwidth=>1, 
    -setgrid => 1,
    -wrap=>'none',
    -width=>88,
    )->pack(
      -expand=>1,
      -fill=>'both'
      );

  $archscrollx->configure(-command => ['xview', $loglist]);
  $archscrolly->configure(-command => ['yview', $loglist]);
  ############################
  #ext buttons

  $archframe6->Button(
    -text=>'Select Log',
    -borderwidth=>'1',
    -width=>'10',
    -background=>$buttonbackground,
     -foreground=>$txtforeground,
    -highlightthickness=>0,
    -font=>$windowfont,
    -command=>sub{&select_log},
    )->pack(
      -side=>'left',
      -padx=>2,
      );
      
  $archframe6->Button(
    -text=>'Search',
    -borderwidth=>'1',
    -width=>'8',
    -background=>$buttonbackground,
     -foreground=>$txtforeground,
    -highlightthickness=>0,
    -font=>$windowfont,
    -command=>sub{&search},
    )->pack(
      -side=>'left',
      -padx=>2,
      );

  $archframe6->Button(
    -text=>'Help',
    -borderwidth=>'1',
    -width=>'8',
    -background=>$buttonbackground,
     -foreground=>$txtforeground,
    -highlightthickness=>0,
    -font=>$windowfont,
    -command=>sub{&sel_help},
    )->pack(
      -side=>'left',
      -padx=>2,
      );

  $archframe6->Button(
    -text=>'Exit',
    -borderwidth=>'1',
    -width=>'8',
    -background=>$buttonbackground,
     -foreground=>$txtforeground,
    -highlightthickness=>0,
    -font=>$windowfont,
    -command=>sub{&destroy_all},
    )->pack(
      -side=>'right',
      -padx=>2,
      ); 
}#sub archreadin

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
sub loadlines {
  ##############################################################
  #built the display window, now lock and load the logfile
    open(logfile, $archlogfile) || die "Fatal Error - Can't open $archlogfile!";
    @loglines=<logfile>;
    close(logfile);
    #release the lock on the logfile now that it has been loaded

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
  }#sub loadlines

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
}

#Search the Turnover Log File
sub search {
  $ASW->destroy if Exists($ASW);
  $ASW=new MainWindow;
  $ASW->configure(-title=>'Archived Turnover Log Search');
  #width,height in pixels    
  $ASW->minsize(424,55);
  $ASW->maxsize(724,55);
  #default to non case sensitive
  $caseflag="nocase";
  $newsearch=1;
  #The top frame for the text
  $searchframe1=$ASW->Frame(
    -borderwidth=>'0',
    -relief=>'flat',
    -background=>$background,)
    ->pack(
      -expand=>1,
      -fill=>'both',
      );
 
  $searchframe2=$ASW->Frame(
    -borderwidth=>'0',
    -relief=>'flat',
    -background=>$background,
    )->pack(
      -fill=>'x',
      -pady=>2,
      );

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
    -command=>sub{$current='0.0',$searchcount=0;$newsearch=1},
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
   -textvariable=>\$archsrchstring,
   -highlightthickness=>1,
   -highlightcolor=>'black',
   -highlightbackground=>$background,
   -bg=>$background,
   -foreground=>$txtforeground,
   -borderwidth=>1,
   -width=>12,
   -bg=> 'white',
   -command=>sub{
      return unless $archsrchstring;
      $ssentry->historyAdd($archsrchstring);
      #reset the title in case a previous search has been performed 
      $ASW->configure(-title=>'Archived Log Search');
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
    -command=>sub{$ASW->destroy;&colorize}
      )->pack(
        -side=>'right',
        -padx=>2,
        );
        
  #press enter and perform a single fine
  $ssentry->bind('<KeyPress-Return>'=>sub{&find_one;});
  if ($#searchlist>0) {
     $ssentry->history([@searchlist]);
      }
  $ssentry->focus;
} # sub search

# Search the Logfile for a term and return a highlighted line
# containing the term.
sub find_all {
  &update_searchlist;
  #delete any old tags so new ones will show
  $loglist->tag('remove','search', qw/0.0 end/);
  $loglist->tag('remove','fullident', qw/0.0 end/);
  $loglist->tag('remove','yearmonth', qw/0.0 end/);
  $current='0.0';
  $stringlength=length($archsrchstring);
  $searchcount=0;
  while (1) {
    if ($caseflag eq "case") {  
    $current=$loglist->search(-exact,$archsrchstring,$current,'end');
    }else{
      $current=$loglist->search(-nocase,$archsrchstring,$current,'end');
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
  $ASW->configure(-title=>"$searchcount Matches");
  $searchcount=0;
  $current='0.0';
}

#find and highlight one instance of a string at a time
sub find_one {
  return if ($archsrchstring eq "");
  &update_searchlist;
  #delete any old tags so new ones will show
  $loglist->tag('remove','search', qw/0.0 end/);
  $loglist->tag('remove','fullident', qw/0.0 end/);
  $loglist->tag('remove','yearmonth', qw/0.0 end/);
  if ($archsrchstring ne $archsrchstringold || $newsearch==1) {
    $allcount=0;
    $tempcurrent='0.0';
    $archsrchstringold=$archsrchstring;
    while (1) {
      if ($caseflag eq "case") {  
      $tempcurrent=$loglist->search(-exact,$archsrchstring,$tempcurrent,'end');
      }else{
        $tempcurrent=$loglist->search(-nocase,$archsrchstring,$tempcurrent,'end');
        }  
      last if (!$tempcurrent);
      $allcount++;       
      $tempcurrent=$loglist->index("$tempcurrent + 1 char");
      $searchcount=0;
      $current='0.0';
      }
     $newsearch=0; 
    }
  $ASW->configure(-title=>"$allcount Matches");  
  $stringlength=length($archsrchstring);
  if (!$current) {
    $current='0.0';
    $searchcount=0;
    } # if current
  my $currentold=$current;   
  if ($caseflag eq "case") {  
    $current=$loglist->search(-exact,$archsrchstring,"$current +1 char");
    }else{
      $current=$loglist->search(-nocase,$archsrchstring,"$current +1 char");
      }  
  if ($current eq "") {
    $ASW->configure(-title=>"No Matches");
    return;
    }      
  $current=$loglist->index($current);
  $loglist->tag('add','search',$current,"$current + $stringlength char");
  $loglist->tag('configure','search',
    -background=>'chartreuse',
    -foreground=>'black',
    -borderwidth=>1,
    -relief=>'raised',
     );         
  $loglist->see($current);   
} #sub find one

sub update_searchlist {
  $Last="";
  push (@searchlist, $archsrchstring);
  #a method to ensure no duplicates are stored in the array
  @searchlist=grep(($Last eq $_ ? 0 : ($Last = $_, 1)),sort @searchlist);
  $ssentry->invoke;
  $ssentry->focus;
}

# bring up the help Window
sub sel_help {
  #The main help window
  $AHW=new MainWindow;
  $AHW->configure(-title=>'Turnover Log Utility Help');
  #width,height in lines    
  $AHW->minsize(88,25);
  $AHW->maxsize(88,49);

  #The top frame for the text
  $helpframe1=$AHW->Frame(
    -borderwidth=>'0',
    -relief=>'flat',
    -background=>$background,)->pack(-expand=>1,-fill=>'both');

  $helpframe2=$AHW->Frame(
    -borderwidth=>'0',
    -relief=>'flat',
    -background=>$background,)->pack(-fill=>'x');

  # Create a scrollbar on the right side and bottom of the text
  $hscrolly=$helpframe1->Scrollbar(
    -orient=>'vert',
    -elementborderwidth=>1,
    -highlightthickness=>0,
    -background=>$background,
    -troughcolor=>$troughbackground,
    -relief=>'flat')
    ->pack(
      -side=>'right',
      -fill =>'y',
      );

  $hscrollx=$helpframe1->Scrollbar(
    -orient=>'horiz',
    -elementborderwidth=>1,
    -highlightthickness=>0,
    -background=>$background,
    -troughcolor=>$troughbackground,
    -relief=>'flat')
    ->pack(
      -side=>'bottom',
      -fill=>'x',
      );

  $helpwin=$helpframe1->Text(
    -yscrollcommand => ['set', $hscrolly],
    -xscrollcommand => ['set', $hscrollx],
    -font=>$windowfont,
    -relief => 'sunken',
    -highlightthickness=>0,
    -foreground=>$txtforeground,
    -background=>$txtbackground,
    -borderwidth=>1, 
    -wrap=>'none',
    -width=>90,
    -height=>24,
    -setgrid=>1,
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
    -command=>sub{$AHW->destroy;}
      )->pack(
         -side=>'bottom',
         -padx=>2);
   
}#sub del_help

sub select_log {
    @types =
      (["Log files",           ['.log']],
       ["All files",		'*']
      );
   $archlogfile = $AV->getOpenFile(-filetypes => \@types);

  if ($archlogfile) {
    &loadlines; 
    &colorize;
    $loglist->see('0.8'); 
    }
}#sub sel_list

#kill all of the windows
sub destroy_all {
   #if any windows are up, kill them
   $AHW->destroy if Exists($AHW);
   $ASW->destroy if Exists($ASW);
   #kill the main window
   $AV->destroy;
   exit;
}#sub destroy_all

#return a positive status 
1;
