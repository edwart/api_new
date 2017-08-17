=head1 NAME

TkTail.pm - A Perl module to graphically tail -f files via Tk

=head1 DESCRIPTION

A Perl Module to display 'tail -f' style files in an X window

=head1 AMENDMENT HISTORY

 $Version$

 $Log: TkTail.pm,v $
 Revision 1.1  2006/12/20 22:07:50  radsvc07
 Initial revision

 Revision 1.1.1.1  2004/11/11 11:11:15  murex
 Imported using TkCVS

 Revision 1.1 2004/11/04 10:00:16GMT murex 
 Initial revision
 Member added to project d:/Data/MHI/Projects/murex/env11.pj
# 
#    Rev 1.10   07 Apr 2004 14:56:34   te1tre
# Bug
# 
#    Rev 1.9   25 Mar 2004 07:33:52   te1tre
# Bug fixes
# 
#    Rev 1.8   14 Oct 2003 08:44:58   te1tre
# Improved Searching facility
# 
#    Rev 1.7   18 Jul 2003 12:06:44   te1tre
# Testing
# 
#    Rev 1.6   Jul 08 2003 08:11:44   te1tre
# To check it out on Unix
# 
#    Rev 1.5   30 Jun 2003 13:06:44   te1tre
# Various Improvements
 
    Rev 1.4   25 Jun 2003 14:04:22   te1tre
 Various stuff
 
    Rev 1.3   24 Jun 2003 12:32:08   te1tre
 Added Font Handling
 
    Rev 1.2   24 Jun 2003 12:04:40   te1tre
 Bug fixes

=cut

package TkTail;

use strict;
use English;
use Trace;
use Data::Dumper;
use Tk;
use Tk::DynaTabFrame;
use Tk::FileDialog;
use Tk::Font;
use Tk::FontDialog;
use Tk::HistEntry;
use Cwd;
use FileHandle;
use File::Basename;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK
  $mw %files $notebook $fullpath $refresh_interval $do_refresh
  $srchstring $srchstringold $curr_wid $ssentry $default_font $filter_window $search_window $background);
require Exporter;
$VERSION   = "1.00";
@ISA       = qw(Exporter);
@EXPORT    = qw(TkTail add_file);
@EXPORT_OK = qw($notebook %files);

%files = ();
my $winfont = "8x13";
my $txtforeground="black";
my $background="bisque3";
my $troughbackground="bisque4";
my $buttonbackground="tan";
my $headerbackground='#f0f0c7';
my $headerforeground='#800000';
my $datatypeforeground='#604030';
my $trbgd="bisque4";
my $labelbackground='bisque2';
my $rowcolcolor='#002030';
my $entrywidth=11;
my $toplabelwidth=12;
my $tophistentrywidth=9;
my $buttonwidth=4;
my $ypad=4;
my $busy="Ready";
my $busycolor="red2";
my $unbusycolor='#009f00';
my $current="1.0";
my $searchcount=0;
my $histlimit=100;
my $delim='#@';
my $caseflag="nocase";
my $srchstringold;
my $newsearch=0;
my $allcount=0;
#get the hostname used for the connection info in the server
#my $localhostname=hostname;
our @searchhist=();
our @filterhist=();

our $filter = undef;


################################################################
#
#
#
#
#
###############################################################
sub TkTail {
    my (@files) = @_;

    $do_refresh = 1;
    $refresh_interval = 1200;    # Miliseconds between each window refresh
         # If we already have a main window then just add the new files to it
    if ( defined($mw) ) {
        foreach my $file (@files) {
            ref $file eq "ARRAY" ? add_file( @{$file} ) : add_file($file);
        }
        return;
    }
    $mw = MainWindow->new( -title => "TkTail" );
	$mw->geometry("1200x600");
    $mw->optionAdd( "*font", "$winfont" );
    setup_menus();
    my $frame = $mw->Frame()->pack( -fill => 'both', -expand => 1 );
    my $options = $mw->Frame()->pack( -expand => 0 );
    $fullpath = $options->Label( -text => cwd() );

    $notebook =
      $frame->DynaTabFrame(-tabclose=>sub {
						my $raised = $notebook->raised_name();
						$notebook->delete($raised);
						delete $files{$raised};
					});
    foreach my $file (@files) {
        ref $file eq "ARRAY" ? add_file( @{$file} ) : add_file($file);
    }
    $notebook->pack( -fill => 'both', -expand => 1 );
    $options->Label( -text => "FullPath" )->grid( $fullpath, -sticky => 'w' );

    MainLoop;
}
sub setup_menus {
	my $menubar = $mw->Frame(-relief 	=> "raised",
				 -borderwidth	=> 2)
			 ->pack(-anchor	=> "nw",
				-fill	=> "x");
	my $file_menu = $menubar->Menubutton(-text => "File",
					     -underline => "1")
				->pack(-side => "left");
	$file_menu->command(-label => "Add File",
			     -command => sub {
 					my $filedialog = $menubar->FileDialog( -Title  => 'Open new file',
												-Create => 0,
												-Path   => cwd()
											  );

						my $fname = $filedialog->Show();
						add_file($fname) if $fname;
					});
	$file_menu->command(-label => "Remove File",
			    -command => sub {
						my $raised = $notebook->raised_name();
						$notebook->delete($raised);
						delete $files{$raised};
					});
	$file_menu->command(-label => "Exit",
			    -command => sub {
						foreach my $file ( keys %files ) {
							$files{$file}{filehandle}->close if defined $files{$file}{filehandle};
						}
						$mw->destroy;
						undef $mw;
					});
	my $edit_menu = $menubar->Menubutton(-text => "Edit",
					     -underline => "1")->pack(-side => "left");
	$edit_menu->command(-label => "Search",
			    -command => \&searchit
				);
	$edit_menu->command(-label => "Filter",
			    -command => \&filterit
				);
	$edit_menu->command(-label => "Stop Refresh",
			    -command => \&stop_refresh
				);
	$edit_menu->command(-label => "Start Refresh",
			    -command => \&start_refresh
				);
	$edit_menu->command(-label => "Clear this Window",
				  -command => sub {
					my $raised = $notebook->raised_name();
					$files{$raised}{textwidget}->delete( "1.0", 'end' );
				});
	$edit_menu->command(-label => "Clear all Windows",
			    -command => sub {
					foreach my $window ( keys %files ) {
						$files{$window}{textwidget}->delete( "1.0", 'end' );
					}
			});
	$edit_menu->command(-label => "Refresh Window",
			    -command => sub {
				my $raised = $notebook->raised_name();
				$files{$raised}{textwidget}->delete( "1.0", 'end' );
				my $fh = $files{$raised}{filehandle};
				$fh->seek( 1, 0 );
				while (<$fh>) {
					insert_line( $files{$raised}{textwidget}, $_ );
				}
			   });
	$edit_menu->command(-label => "Refresh all Windows",
			    -command => sub {
				foreach my $window ( keys %files ) {
					$files{$window}{textwidget}->delete( "1.0", 'end' );
					my $fh = $files{$window}{filehandle};
					$fh->seek( 1, 0 );
					while (<$fh>) {
						insert_line( $files{$window}{textwidget}, $_ );
					}
				}
			   });
	$edit_menu->command(-label => "Change Font - this file only",
			    -command => sub {
				my $font   = $mw->FontDialog->Show;
				my $raised = $notebook->raised_name();
				$files{$raised}{textwidget}->configure( -font => $font );

			});
	$edit_menu->command(-label => "Change Font - all files",
			    -command => sub {
				my $font   = $mw->FontDialog->Show;
				foreach my $window ( keys %files ) {
					$files{$window}{textwidget}->configure( -font => $font );
				}

			});




}
sub start_refresh {
    $do_refresh = 1;
}
sub stop_refresh {
    $do_refresh = 0;
}
sub filterit {
	my $raised = $notebook->raised_name();
	$curr_wid = $files{$raised}{textwidget};
    $filter_window->destroy if Exists($filter_window);
    $filter_window=new MainWindow(-title=>'Filter');
   $filter_window->optionAdd("*frame*relief", "flat");
   $filter_window->optionAdd("*font", "8x13bold");

   #width,height in pixels
   $filter_window->minsize(424,51);
   $filter_window->maxsize(724,51);

   my $filterframe1=$filter_window->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      )->pack(
         -expand=>1,
         -fill=>'both',
         );
    my $filterentry=$filterframe1->HistEntry(
      -font=>$winfont,
      -relief=>'sunken',
      -textvariable=>\$filter,
      -highlightthickness=>0,
      -highlightcolor=>'black',
      -selectforeground=>$txtforeground,
      -selectbackground=>'#c0d0c0',
      -background=> 'white',
      -bg=>$background,
      -foreground=>$txtforeground,
      -borderwidth=>0,
      -bg=> 'white',
      -limit=>$histlimit,
      -dup=>0,
      -match => 1,
      -justify=>'left',
      -command=>sub{@filterhist=$ssentry->history;},
      )->pack(
         -fill=>'both',
         -expand=>0,
         );
   $filterentry->bind('<Return>'=>\&find_one);
   $filterframe1->Button(
      -text=>'Filter',
      -borderwidth=>'1',
      -width=>'10',
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$winfont,
      -command=>\&filter,
      )->pack(
         -side=>'left',
         -padx=>2,
         );
}
sub searchit {
   $srchstring="";
	my $raised = $notebook->raised_name();
	$curr_wid = $files{$raised}{textwidget};
   $search_window->destroy if Exists($search_window);
   $search_window=new MainWindow(-title=>'Search');

   #set some nice parameters to be inherited by the search histentry
   #$search_window->optionAdd("*background","$background");
   $search_window->optionAdd("*frame*relief", "flat");
   $search_window->optionAdd("*font", "8x13bold");

   #width,height in pixels
   $search_window->minsize(424,51);
   $search_window->maxsize(724,51);

   #default to non case sensitive
   $caseflag="nocase";
   my $newsearch=1;

   #The top frame for the text
   my $searchframe1=$search_window->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      )->pack(
         -expand=>1,
         -fill=>'both',
         );

   my $searchframe2=$search_window->Frame(
      -borderwidth=>'0',
      -relief=>'flat',
      -background=>$background,
      )->pack(
         -fill=>'x',
         -pady=>2,
         );

    $searchframe1->Checkbutton(
      -variable=>\$caseflag,
      -font=>$winfont,
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
      -background=>$background,
      )->pack(
         -side=>'left',
         -expand=>0,
         );

   my $searchhistframe=$searchframe1->Frame(
      -borderwidth=>1,
      -relief=>'sunken',
      -background=>$background,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      )->pack(
         -side=>'bottom',
         -expand=>0,
         -pady=>0,
         -padx=>1,
         -fill=>'x',
         );

    $ssentry=$searchhistframe->HistEntry(
      -font=>$winfont,
      -relief=>'sunken',
      -textvariable=>\$srchstring,
      -highlightthickness=>0,
      -highlightcolor=>'black',
      -selectforeground=>$txtforeground,
      -selectbackground=>'#c0d0c0',
      -background=> 'white',
      -bg=>$background,
      -foreground=>$txtforeground,
      -borderwidth=>0,
      -bg=> 'white',
      -limit=>$histlimit,
      -dup=>0,
      -match => 1,
      -justify=>'left',
      -command=>sub{@searchhist=$ssentry->history;},
      )->pack(
         -fill=>'both',
         -expand=>0,
         );

   #press enter and perform a single fine
   $ssentry->bind('<Return>'=>\&find_one);
   $ssentry->history([@searchhist]);

   $searchframe2->Button(
      -text=>'Find',
      -borderwidth=>'1',
      -width=>'10',
      -background=>$buttonbackground,
      -foreground=>$txtforeground,
      -highlightthickness=>0,
      -font=>$winfont,
      -command=>\&find_one,
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
      -font=>$winfont,
      -command=>\&find_all,
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
      -font=>$winfont,
      -command=>sub{$search_window->destroy;$curr_wid->tag('remove','search', qw/0.0 end/);}
      )->pack(
         -side=>'right',
         -padx=>2,
         );
   $ssentry->invoke;
   $ssentry->focus;
} # sub search
sub find_one {
  return if ($srchstring eq "");
   my $tempcurrent;
   my $stringlength;
   $ssentry->invoke;
   $curr_wid->tag('remove','search', qw/0.0 end/);
   #mull through the text tagging the matched strings along the way
   my $newsearch=0;

   if ($srchstring ne $srchstringold || $newsearch==1) {
      $allcount=0;
      $tempcurrent='0.0';
      $srchstringold=$srchstring;
      while (1) {
         if ($caseflag eq "case") {
            $tempcurrent=$curr_wid->search(-exact,"$srchstring",$tempcurrent,'end');
            }else{
               $tempcurrent=$curr_wid->search(-nocase,"$srchstring",$tempcurrent,'end');
               }#else
         last if (!$tempcurrent);
         $allcount++;
         $tempcurrent=$curr_wid->index("$tempcurrent + 1 char");
         $searchcount=0;
         $current='0.0';
         }#while true
     $newsearch=0;
    }#if srchstring ne srstringold
   #set the titlebar of the search dialog to indicate the matches
   $search_window->configure(-title=>"$allcount Matches");
   $stringlength=length($srchstring);
   if (!$current) {
      $current='0.0';
      $searchcount=0;
      } # if current
   if ($caseflag eq "case") {
      $current=$curr_wid->search(-exact,$srchstring,"$current +1 char");
      }else{
         $current=$curr_wid->search(-nocase,$srchstring,"$current +1 char");
         }#else
   #no matches were found - set the titlebar
   if ($current eq "") {
      $search_window->configure(-title=>"No Matches");
      return;
      }
   $current=$curr_wid->index($current);
   $curr_wid->tag('add','search',$current,"$current + $stringlength char");
   $curr_wid->tag('configure','search',
      -background=>'chartreuse',
      -foreground=>'black',
      );
   $curr_wid->see($current);
   #see where the display has horizontally scrolled and move the header text to match
   my ($tscrollx,$rest)=$curr_wid->xview;
   $curr_wid->xview(moveto=>$tscrollx);
}
sub find_all {
   return if ($srchstring eq "");
   $ssentry->invoke;
   #delete any old tags so new ones will show
   $curr_wid->tag('remove','search', qw/0.0 end/);
   $current='0.0';
   my $stringlength=length($srchstring);
   my $searchcount=0;
   while (1) {
      if ($caseflag eq "case") {
         $current=$curr_wid->search(-exact,"$srchstring",$current,'end');
         }else{
            $current=$curr_wid->search(-nocase,"$srchstring",$current,'end');
            }#else
      last if (!$current);
      $curr_wid->tag('add','search',$current,"$current + $stringlength char");
      $curr_wid->tag('configure','search',
         -background=>'chartreuse',
         -foreground=>'black',
         );
      $searchcount++;
      $current=$curr_wid->index("$current + 1 char");
      }#while true
      #no matches were found - set the titlebar
   if ($searchcount==0) {
      $search_window->configure(-title=>"No Matches");
      }else{
         $search_window->configure(-title=>"$searchcount Matches");
         }

}

sub update_tail {
    my ($file) = @_;
    return unless $do_refresh;
    $file = cwd() . "/$file" unless $file =~ m#^/#;
    my $fh             = $files{$file}{filehandle};
    my $lines_inserted = 0;
    while (<$fh>) {
        insert_line( $files{$file}{textwidget}, $_ );
        $lines_inserted++;
    }
    $files{$file}{textwidget}->yviewMoveto(1.0) if $lines_inserted > 0;
}

sub add_file {
    my ( $file, $label ) = @_;
    $label ||= basename $file;

    $file = cwd() . "/$file" unless $file =~ m#^/#;
    unless ( $files{$file}{filehandle} = FileHandle->new("<$file") ) {
        warn "Can't open file $file: $!\n";
        delete $files{$file};
        next;
    }
	Trace::FILES("Adding ".Dumper(\@_));
    $files{$file}{pagewidget} = $notebook->add(
        "$file",
        -wraplength => 0,
        -label      => $label,
        -raisecmd   => sub {

            $fullpath->configure( -text => $file );
        }
    );
	$files{$file}{VerticalScrollbar} =  $files{$file}{pagewidget}->Scrollbar(-orient=>'vertical', -jump=>1);
	$files{$file}{HorizontalScrollbar} =  $files{$file}{pagewidget}->Scrollbar(-orient=>'horizontal', -jump=>1);

    $files{$file}{textwidget} = $files{$file}{pagewidget}->Text(
					-wrap => 'none',
					-xscrollcommand => ['set' => $files{$file}{HorizontalScrollbar}],
					-yscrollcommand => ['set' => $files{$file}{VerticalScrollbar}] );
	$files{$file}{VerticalScrollbar}->configure(-command => ['yview' => $files{$file}{textwidget}]);
	$files{$file}{HorizontalScrollbar}->configure(-command => ['xview' => $files{$file}{textwidget}]);
	$files{$file}{VerticalScrollbar}->pack(-side=>'right', -fill=>'y');
#	$files{$file}{HorizontalScrollbar}->set(0,0.5);
	$files{$file}{HorizontalScrollbar}->pack(-side=>'bottom', -fill=>'x');
    $files{$file}{textwidget}->pack( -expand => 1, -fill => 'both' );
    $files{$file}{textwidget} ->tagConfigure( "highlight", -background => "yellow" );
    $files{$file}{textwidget}->tagConfigure( "normal", -background => "white" );
    my $fh = $files{$file}{filehandle};
    while (<$fh>) {
        insert_line( $files{$file}{textwidget}, $_ );
    }
    $files{$file}{textwidget}->yviewMoveto(1.0);
    $files{$file}{textwidget}
      ->repeat( $refresh_interval, [ \&update_tail, $file ] );
}

sub insert_line {
    my ( $widget, $line ) = @_;

#    if ( defined($srchstring) and $srchstring ne "" ) {
#		if ($case) {
#			if ($line =~ m/$srchstring/) { 
#				$widget->insert( 'end', $PREMATCH,  'normal' );
#				$widget->insert( 'end', $MATCH,     'highlight' );
#				$widget->insert( 'end', $POSTMATCH, 'normal' );
#			}
#		}
#		else {
#			if ($line =~ m/$srchstring/i) { 
#				$widget->insert( 'end', $PREMATCH,  'normal' );
#				$widget->insert( 'end', $MATCH,     'highlight' );
#				$widget->insert( 'end', $POSTMATCH, 'normal' );
#			}
#		}
#    }
#    else {
    if (defined($filter)) {
        return unless $line =~ /$filter/;
    }
    $widget->insert( 'end', $line, 'normal' );

}
1;
__END__




