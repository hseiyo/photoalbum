#!/usr/bin/perl

use strict;
use CGI;

my $query = new CGI;

my $debug_level = 1;
my $LINK_CMD = "/home/seiyo/bin/makephotolink.sh"; 
my $BASE_DIR = "/home/seiyo/public_html";
my $FROM_BASE = "/photo";
my $DEST_BASE = "/photo/open";
# my $FROM_DIR = $BASE_DIR . $ENV{REQUEST_URI};
my $FROM_DIR = $ENV{REQUEST_URI};
$FROM_DIR =~ s#/photo/open/#/photo/#;
my $DEST_DIR;

sub debug{
	my $level = shift @_;
	
	if( $level >= $debug_level ){
		foreach my $msg ( @_ ){
			print "DEBUG: $msg<br>\n";
		}
	}
}

sub eliminate_dot{
	my $str = shift;
	$str =~ s#/\./#/#g;
	return $str;
}

sub make_link{
	my @options;
	if( $_[0] eq "-force" ){
		push( @options , "-force" );
		shift;
	}
	my $from = &eliminate_dot( shift );
	my $to = &eliminate_dot( shift );
	push( @options , "-make" , $from , $to );
		
	&debug( 1, $LINK_CMD , join( ":" , @options ) );
	system($LINK_CMD , @options );
}

sub delete_link{
	my @options;
	if( $_[0] eq "-force" ){
		push( @options , "-force" );
		shift;
	}
	my $from = &eliminate_dot( shift );
	my $to = &eliminate_dot( shift );
	push( @options , "-delete" , $from , $to );

	&debug( 1, $LINK_CMD , join( ":" , @options ) );
	system($LINK_CMD , @options );
}
sub unlock_link{
	my @options;
	my $from = &eliminate_dot( shift );
	my $to = &eliminate_dot( shift );
	push( @options , "-unlock" , $from , $to );

	&debug( 1, $LINK_CMD , join( ":" , @options ) );
	system($LINK_CMD , @options );
}



my @params;
@params = $query->param();
print $query->header(),
	$query->start_html();
print "params: " . join( ":" , @params ) . "<br>\n";
foreach my $para ( $query->param() ){
	print "$para : " . $query->param( $para ) . "<br>\n";
}

print "<script type=\"text/javascript\">window.blur(); window.opener.forcus();</script><br>\n";

if( defined $query->param('all') ){
	&debug( 1, "in all<br>\n" );
	$FROM_DIR =~ s#/[^/]+$##;
	$DEST_DIR = $FROM_DIR;
	$DEST_DIR =~ s#$FROM_BASE#$DEST_BASE#;

	if( $query->param('all') eq "open" ){
		&make_link( "-force" , $FROM_DIR, $DEST_DIR);
	}elsif( $query->param('all') eq "close" ){
		&delete_link( "-force" , $FROM_DIR, $DEST_DIR);
	}elsif( $query->param('all') eq "unlock" ){
		&unlock_link( $FROM_DIR, $DEST_DIR);
	}else{
		print "unknown mode: " . $query->param('all') . "<br>\n";
	}
}elsif( defined $query->param('file') ){
	&debug( 1, "in file<br>\n" );
	# $FROM_DIR =~ s#/[^/]+$##;
	# $DEST_DIR = $FROM_DIR;
	$FROM_DIR = &url_decode( $query->param('file') );
	$DEST_DIR = $FROM_DIR;
	$DEST_DIR =~ s#$FROM_BASE#$DEST_BASE#;

	if( $query->param('mode') eq "open" ){
		&make_link($FROM_DIR, $DEST_DIR);
	}elsif( $query->param('mode') eq "close" ){
		&delete_link($FROM_DIR, $DEST_DIR);
	}else{
		print "unknown mode: " . $query->param('mode') . "<br>\n";
	}
}else{
	&debug( 1, "in else<br>\n" );
}


print $query->end_html;

sub url_encode{
	my $str = shift;
	$str =~ s/([^\w ])/'%'.unpack('H2', $1)/eg;
	$str =~ tr/ /+/;
	return $str;
}

sub url_decode{
	my $str = shift;
	$str =~ tr/+/ /;
	$str =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack('H2', $1)/eg;
	return $str;
}
