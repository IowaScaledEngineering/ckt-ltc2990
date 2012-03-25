#!/usr/bin/env perl
################################################################################
#  batchup.pl is a perl script that got out of hand for prepping gerber files
#  output by gEDA pcb for upload to batchpcb.com.  It first takes the pertinent
#  files in the project directory, changes the file extensions to fit batchpcb
#  criteria, if there are two .cnc drill files, it will merge them together
#  it will then pack the whole mess up into a *.tar.gz ready for upload.
################################################################################

use strict;
use warnings;
use File::Copy;
use File::Basename;
use Archive::Tar;

################################################################################
# cncmerge is a subroutine for mergeing the differences between 2 cnc format
# drill files into one file. this is because batch pcb will only allow the up-
# load of one cnc file in the archive.
################################################################################
sub cncmerge
{
   #locals
   my @files = @_;
   my $fhone;
   my $fhtwo;
   my $fhoutput;
   my $fileone = $files[0];
   my $filetwo = $files[1];
   my $fileout = "drillfile.cnc";

   #open input files and read lines into arrays
   #then open the output file for merge.
   open($fhone,"<",$fileone) or die "couldn't open file $!";
   my @onelines = <$fhone>;
   open($fhtwo,"<",$filetwo) or die "couldn't open file $!";
   my @twolines = <$fhtwo>;
   open($fhoutput,">>",$fileout) or die " couldn't make output file $!";

   #print out the first 2 lines of the header M48, which is the header start
   #and INCH, which marks the units.
   print $fhoutput "$onelines[0]";
   print $fhoutput "$onelines[1]";
   
   #initialize iteration indexes to start at beginning of header info.
   my $startdex1 = my $startdex2 = 2;
   
   #write header info from file one to merged file
   while($onelines[$startdex1] !~ m/%/)
   {
      print $fhoutput "$onelines[$startdex1]";
      $startdex1 ++;
   }
   #write header info from file two to merged file.
   while($twolines[$startdex2] !~ m/%/)
   {
      print $fhoutput "$twolines[$startdex2]";
      $startdex2 ++;
   }
   #print the header end '%' to file and kick up the counters 1
   print $fhoutput "$twolines[$startdex2]";
   $startdex1++;
   $startdex2++;

   #write all of the body information to the merge file.
   while($onelines[$startdex1] !~ m/M30/)
   {
      print $fhoutput "$onelines[$startdex1]";
      $startdex1 ++;
   }
   while($twolines[$startdex2] !~ m/M30/)
   {
      print $fhoutput "$twolines[$startdex2]";
      $startdex2 ++;
   }

   #print 'M48' file end marker
   print $fhoutput "$twolines[$startdex2]";

   #close filehandles
   close($fhone);
   close($fhtwo);
   close($fhoutput);


}

my $dir = ".";
my $dirhandle;
my $outdir = "UPLOAD";
my $outdirhandle;

#open current directory.
opendir($dirhandle,$dir);

#create an array of gerber files
my @gerbers = grep {m/.gbr$/} readdir($dirhandle);
closedir($dirhandle);

#reopen dir and create an array of drill files.
opendir($dirhandle,$dir);
my @drills = grep {m/.cnc$/} readdir($dirhandle);

#make a directory to store the results
if (!-d $outdir)
{
   mkdir($outdir) or die "couldn't create directory $!";
}

#rename gerber files appropriately and move to $outdir
foreach(@gerbers)
{
   my $newfile = $_;
   my $copy;
   if(m/\.front\./)
   {
      $newfile =~ s/.gbr/.top/;
      $copy = 1;
   }
   elsif(m/\.frontmask\./)
   {
      $newfile =~ s/.gbr/.tsm/;
      $copy = 1;
   }
   elsif(m/\.back\./)
   {
      $newfile =~ s/.gbr/.bot/;
      $copy = 1;
   }
   elsif(m/\.backmask\./)
   {
      $newfile =~ s/.gbr/.bsm/;
      $copy = 1;
   }
   elsif(m/\.frontsilk\./)
   {
      $newfile =~ s/.gbr/.slk/;
      $copy = 1;
   }
   elsif(m/\.backsilk\./)
   {
      $newfile =~ s/.gbr/.bsk/;
      $copy = 1;
   }
   else
   {
      $copy = undef;
   }
   if($copy)
   {
      copy("$_","$outdir/$newfile")
         or die "couldn't copy file $!";
   }
}
# Handle Drill files, with merge between unplated and plated.
my $drillfile;
#only one drill file
if(scalar(@drills) == 0)
{
   print("No drill file found, proceeding anyway.\n");
}
elsif (scalar(@drills) == 1)
{
   $drillfile = $drills[0];
   copy("$drillfile","$outdir/$drillfile")
             or die "Couldn't copy drill file $!";
}
#if plated and unplated perform a merge on the two files.
elsif(scalar(@drills) == 2)
{
   $drillfile = "drillfile.cnc";
   &cncmerge(@drills);
   move("$drillfile","$outdir/$drillfile")
             or die "Couldn't copy drill file $!";
}
#too lazy to handle more than two files, shouldn't need to.
else
{
   print "there are > 2 drill files, requires manual merge.\n";
}

#list files in outdir and prepare for archiving.
opendir($outdirhandle,$outdir);
my @modgerber = readdir($outdirhandle);
my @files_tar;

print "the following files have been archived: \n";
foreach(@modgerber)
{
   #add to array if not a dotfile or a previously generated archive.
   if(!($_ eq "." || $_ eq ".." || $_ eq "output.tgz"))
   {
      print "\t$_\n";
      push(@files_tar,$_);
   }
}
#go in and archive this sucker up!
chdir($outdir);
Archive::Tar->create_archive('output.tgz', COMPRESS_GZIP, @files_tar) or die "what the hell $!";
print("Files Archived in output.tgz\n");

#and just for fun, delete all of the copied files.
foreach(@files_tar)
{
   unlink($_) or die "couldn't delete stupid files $!";
}
print("Temporary files are deleted. please ensure all files in list are g2g!\n");
#close filehandles
closedir($outdirhandle);
closedir($dirhandle);
