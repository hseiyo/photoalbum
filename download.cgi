#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);
use CGI;
use File::MMagic;

# set date
open TMP, ">/tmp/rururu";
print TMP $0 . "\n";
$0 =~ m#^.+/([^/]+).cgi$#;
my $yyyymmdd = $1;
print TMP $yyyymmdd . "\n";
close TMP;

# set file name and type
my $file = "photo.tgz";
my $type = File::MMagic->new->checktype_filename($file);

# print HTTP header
my $cgi = CGI->new;
print $cgi->header(
  -type => $type,
    -attachment => "photo.tgz"
);

# print content of $file
my $buf = undef;
my $bufsize = 1034;
open(FILE, "/home/seiyo/bin/photo/${yyyymmdd}.sh |"); # should read from conf.
binmode(FILE);
binmode(STDOUT);
while (1) {
  read(FILE, $buf, $bufsize);
    last unless (length($buf));
    print $buf;
}
close(FILE);

