package Extra::Gmail;

use strict;
use warnings;
use vars qw($VERSION);
 
$VERSION='1.30';
require Net::SMTP;
use Authen::SASL;
use MIME::Base64;
use Encode;
use File::Spec;
use LWP::MediaTypes;
use Extra::Format qw(email_date);
 
sub new{
  my $class=shift;
  my $self={@_};
  bless($self, $class);
  my %properties=@_;
  my $smtp='smtp.gmail.com'; # Default value
  my $port='default'; # Default value
  my $layer='tls'; # Default value
  my $auth='AUTO'; # Default
  my $ssl_verify_mode=''; #Default - Warning SSL_VERIFY_NONE
  my $ssl_version='';
  my $timeout=60;
 
  $smtp=$properties{'-smtp'} if defined $properties{'-smtp'};
  $port=$properties{'-port'} if defined $properties{'-port'};
  $layer=$properties{'-layer'} if defined $properties{'-layer'};
  $auth=$properties{'-auth'} if defined $properties{'-auth'};
  $ssl_verify_mode=$properties{'-ssl_verify_mode'} if defined $properties{'-ssl_verify_mode'};
  $ssl_version=$properties{'-ssl_version'} if defined $properties{'-ssl_version'};
  $timeout=$properties{'-timeout'} if defined $properties{'-timeout'};
 
  if(defined $properties{'-from'}){
    $self->{from}=$properties{'-from'};
  }
  else{
    $self->{from}=$properties{'-login'};
  }
 
  my $connect=$self->_initsmtp($smtp,$port,$properties{'-login'},$properties{'-pass'},$layer,$auth,$properties{'-debug'},$ssl_verify_mode,$ssl_version,$properties{'-ssl_verify_path'},$properties{'-$ssl_verify_ca'},$timeout);
 
  return -1,$self->{error} if(defined $self->{error});
  return $self;
}
 
sub _initsmtp{
  my $self=shift;
  my $smtp=shift;
  my $port=shift;
  my $login=shift;
  my $pass=shift;
  my $layer=shift;
  my $auth=shift;
  my $debug=shift;
  my $ssl_mode=shift;
  my $ssl_version=shift;
  my $ssl_path=shift;
  my $ssl_ca=shift;
  my $timeout=shift;
 
  # The module sets the SMTP google but could use another!
  # Set port if default
  if($port eq 'default'){
      if($layer eq 'ssl'){
          $port=465;
      }
      else{
          $port=25;
      }
  }
 print "Connecting to $smtp using $layer with $auth on port $port and timeout of $timeout\n" if $debug;
  # Set security layer from $layer
  if($layer eq 'none')
  {
    if (not $self->{sender} = Net::SMTP->new($smtp, Port =>$port, Debug=>$debug, Timeout=>$timeout)){
      my $error_string=$self->{sender}->message();
      chomp $error_string;
      $self->{error}=$error_string;
      print "Could not connect to SMTP server ($smtp $port)\n" if $debug;
      return $self;
    }
  }
  else{
    my $sec=undef;
    my $ssl=($layer eq 'ssl')?1:0;
    if (not $self->{sender} = Net::SMTP->new($smtp, Port=>$port, Debug=>$debug, SSL=>$ssl, SSL_verify_mode=>$ssl_mode, SSL_version=>$ssl_version,SSL_ca_file=>$ssl_ca,SSL_ca_path=>$ssl_path, Timeout=>$timeout)){
      $self->{error}=$@;
      print "Could not connect to SMTP server\n" if $debug;
      return $self;
    }
  }
  if($auth ne 'none'){
     $self->{sender}->starttls  if($layer eq 'tls');
 
     if($auth eq 'AUTO'){
        unless($self->{sender}->auth($login,$pass)){
           my $error_string=$self->{sender}->message();
           chomp $error_string;
           $self->{error}=$error_string;
           print "Authentication -using server methods list- (SMTP) failed: $error_string\n" if $debug;
        }
      }
      else{
       unless($self->{sender}->auth(Authen::SASL->new(mechanism => $auth, callback => { user => $login, pass => $pass }))){
           my $error_string=$self->{sender}->message();
           chomp $error_string;
           $self->{error}=$error_string;
           print "Authentication -forcing $auth -(SMTP) failed: $error_string\n" if $debug;
       }
     }
  }
  return $self;
}
 
sub bye{
  my $self=shift;
  $self->{sender}->quit();
  return $self;
}
 
sub banner{
  my $self=shift;
  my $banner=$self->{sender}->banner();
  chomp $banner;
  return $banner;
}
 
sub _checkfiles
{
# Checks that all the attachments exist
  my $attachs=shift;
  my $verbose=shift;
 
  my $result=''; # list of valid attachments
 
  my @attachments=split(/,/,$attachs);
  foreach my $attach(@attachments)
  {
     $attach=~s/\A[\s,\0,\t,\n,\r]*//;
     $attach=~s/[\s,\0,\t,\n,\r]*\Z//;
 
     unless (-f $attach) {
       print "Unable to find the attachment file: $attach (removed from list)\n" if $verbose;
     }
     else{
       my $opened=open(my $file,'<',$attach);
       if( not $opened){
         print "Unable to open the attachment file: $attach (removed from list)\n" if $verbose;
       }
       else{
         close $file;
         $result.=','.$attach;
         print "Attachment file: $attach added\n" if $verbose;
       }
     }
  }
  $result=~s/\A\,//;
  return $result;
}
 
sub _checkfilelist
{
# Checks that all the attachments exist
  my $attachs=shift;
  my $verbose=shift;
 
  my $result=undef; # list of valid attachments
  my $i=0;
 
  foreach my $attach(@$attachs)
  {
     $attach->{file}=~s/\A[\s,\0,\t,\n,\r]*//;
     $attach->{file}=~s/[\s,\0,\t,\n,\r]*\Z//;
 
     unless (-f $attach->{file}) {
       print "Unable to find the attachment file: $attach->{file} (removed from list)\n" if $verbose;
     }
     else{
       my $opened=open(my $file,'<',$attach->{file});
       if( not $opened){
          print "Unable to open the attachment file: $attach->{file} (removed from list)\n" if $verbose;
       }
       else{
         close $file;
         $result->[$i]->{file}=$attach->{file};
         $i++;
         print "Attachment file: $attach->{file} added\n" if $verbose;
       }
     }
  }
  return $result;
}
 
sub _createboundary
{
# Create arbitrary frontier text used to separate different parts of the message
  return "This-is-a-mail-boundary-8217539";
}
 
sub send
{
  my $self=shift;
  my %properties=@_; # rest of params by hash
 
  my $verbose=0;
  $verbose=$properties{'-verbose'} if defined $properties{'-verbose'};
  # Load all the email param
  my $mail;
 
  $mail->{to}=$properties{'-to'} if defined $properties{'-to'};
 
  $mail->{to}=' ' if((not defined $mail->{to}) or ($mail->{to} eq ''));
 
  $mail->{from}=$self->{from};
  $mail->{from}=$properties{'-from'} if defined $properties{'-from'};
 
  $mail->{replyto}=$mail->{from};
  $mail->{replyto}=$properties{'-replyto'} if defined $properties{'-replyto'};
 
  $mail->{cc}='';
  $mail->{cc}=$properties{'-cc'} if defined $properties{'-cc'};
 
  $mail->{bcc}='';
  $mail->{bcc}=$properties{'-bcc'} if defined $properties{'-bcc'};
 
  $mail->{charset}='UTF-8';
  $mail->{charset}=$properties{'-charset'} if defined $properties{'-charset'};
 
  $mail->{contenttype}='text/plain';
  $mail->{contenttype}=$properties{'-contenttype'} if defined $properties{'-contenttype'};
 
  $mail->{subject}='';
  #$mail->{subject}=$properties{'-subject'} if defined $properties{'-subject'};
  # Encode Subject to accomplish RFC
  $mail->{subject}=encode("MIME-Q",$properties{'-subject'}) if defined $properties{'-subject'};
 
  $mail->{body}='';
  $mail->{body}=$properties{'-body'} if defined $properties{'-body'};
 
  $mail->{attachments}='';
  $mail->{attachments}=$properties{'-attachments'} if defined $properties{'-attachments'};
 
  $mail->{attachmentlist}=$properties{'-attachmentlist'} if defined $properties{'-attachmentlist'};
 
  if($mail->{attachments} ne '')
  {
      $mail->{attachments}=_checkfiles($mail->{attachments},$verbose);
      print "Attachments separated by comma successfully verified\n" if $verbose;
  }
  if(defined $mail->{attachmentlist}){
      $mail->{attachmentlist}=_checkfilelist($mail->{attachmentlist},$verbose);
      print "Attachments \@list successfully verified\n" if $verbose;
  }
 
      my $boundary=_createboundary();
 
      $self->{sender}->mail($mail->{from} . "\n");
 
      my @recepients = split(/,/, $mail->{to});
      foreach my $recp (@recepients) {
          $self->{sender}->to($recp . "\n");
      }
      my @ccrecepients = split(/,/, $mail->{cc});
      foreach my $recp (@ccrecepients) {
          $self->{sender}->cc($recp . "\n");
      }
      my @bccrecepients = split(/,/, $mail->{bcc});
      foreach my $recp (@bccrecepients) {
          $self->{sender}->bcc($recp . "\n");
      }
 
      $self->{sender}->data();
 
      #Send header
      $self->{sender}->datasend("From: " . $mail->{from} . "\n");
      $self->{sender}->datasend("To: " . $mail->{to} . "\n");
      $self->{sender}->datasend("Cc: " . $mail->{cc} . "\n") if ($mail->{cc} ne '');
      $self->{sender}->datasend("Reply-To: " . $mail->{replyto} . "\n");
      $self->{sender}->datasend("Subject: " . $mail->{subject} . "\n");
      $self->{sender}->datasend("Date: " . email_date(). "\n");
 
      if($mail->{attachments} ne '')
      {
        print "With Attachments\n" if $verbose;
        $self->{sender}->datasend("MIME-Version: 1.0\n");
        if ((defined $properties{'-disposition'}) and ('inline' eq lc($properties{'-disposition'}))) {
           $self->{sender}->datasend("Content-Type: multipart/related; BOUNDARY=\"$boundary\"\n");
        }
        else {
           $self->{sender}->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundary\"\n");
       }
 
        # Send text body
        $self->{sender}->datasend("\n--$boundary\n");
        $self->{sender}->datasend("Content-Type: ".$mail->{contenttype}."; charset=".$mail->{charset}."\n");
 
        $self->{sender}->datasend("\n");
 
        #################################################
        # Chunk body in sections (Gmail SMTP limitations)
        #my @groups_body = split(/(.{76})/,$mail->{body});
        #$self->{sender}->datasend($_) foreach @groups_body;
 
        # Or better. Encode and split
        #my $str=encode_base64($mail->{body});
        #my @groups_body = split(/(.{76})/,$str);
        #$self->{sender}->datasend($_) foreach @groups_body;
 
        # Limitation removed
        $self->{sender}->datasend($mail->{body});
        ##################################################
 
        $self->{sender}->datasend("\n\n");
 
        my @attachments=split(/,/,$mail->{attachments});
 
        foreach my $attach(@attachments)
        {
            #my($bytesread, $buffer, $data, $total);
 
           $attach=~s/\A[\s,\0,\t,\n,\r]*//;
           $attach=~s/[\s,\0,\t,\n,\r]*\Z//;
 
           # Get the file name without its directory
           my ($volume, $dir, $fileName) = File::Spec->splitpath($attach);
           # Get the MIME type
           my $contentType = guess_media_type($attach);
           print "Composing MIME with attach $attach\n" if $verbose;
 
           $self->{sender}->datasend("--$boundary\n");
           $self->{sender}->datasend("Content-Type: $contentType; name=\"$fileName\"\n");
           $self->{sender}->datasend("Content-Transfer-Encoding: base64\n");
           if ((defined $properties{'-disposition'}) and ('inline' eq lc($properties{'-disposition'}))) {
              $self->{sender}->datasend("Content-ID: <$fileName>\n");
              $self->{sender}->datasend("Content-Disposition: inline; =filename=\"$fileName\"\n\n");
           }
           else {
             $self->{sender}->datasend("Content-Disposition: attachment; =filename=\"$fileName\"\n\n");
           }
 
           # Google requires us to divide the attachment
           # First read -> Encode -> Send in chunks of 76
           # Read
           my $opened=open(my $file,'<',$attach);
           binmode($file);
           # Encode
           local $/ = undef;
           my $d=<$file>;
           my $str=encode_base64($d);
           # Chunks by 76
           my @groups = split(/(.{76})/,$str);
           $self->{sender}->datasend($_) foreach @groups;
           close $file;
 
           #$self->{sender}->datasend("--$boundary\n"); # avoid dummy attachment
         }
         $self->{sender}->datasend("\n--$boundary--\n"); # send endboundary end message
      }
      elsif(defined $mail->{attachmentlist})
      {
        print "With Attachments\n" if $verbose;
        $self->{sender}->datasend("MIME-Version: 1.0\n");
        #  $self->{sender}->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundary\"\n");
        if ((defined $properties{'-disposition'}) and ('inline' eq lc($properties{'-disposition'}))) {
            $self->{sender}->datasend("Content-Type: multipart/related; BOUNDARY=\"$boundary\"\n");
        }
        else {
           $self->{sender}->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundary\"\n");
       }
 
        # Send text body
        $self->{sender}->datasend("\n--$boundary\n");
        $self->{sender}->datasend("Content-Type: ".$mail->{contenttype}."; charset=".$mail->{charset}."\n");
 
        $self->{sender}->datasend("\n");
 
        # Chunk body in sections (Gmail SMTP limitations)
        #$self->{sender}->datasend($mail->{body} . "\n\n");
        my @groups_body = split(/(.{76})/,$mail->{body});
        $self->{sender}->datasend($_) foreach @groups_body;
        $self->{sender}->datasend("\n\n");
 
        my $attachments=$mail->{attachmentlist};
        foreach my $attach(@$attachments)
        {
            #my($bytesread, $buffer, $data, $total);
 
           $attach->{file}=~s/\A[\s,\0,\t,\n,\r]*//;
           $attach->{file}=~s/[\s,\0,\t,\n,\r]*\Z//;
 
           my ($volume, $dir, $fileName) = File::Spec->splitpath($attach->{file});
           # Get the MIME type
           my $contentType = guess_media_type($attach->{file});
           print "Composing MIME with attach $attach->{file}\n" if $verbose;
 
           $self->{sender}->datasend("--$boundary\n");
           $self->{sender}->datasend("Content-Type: $contentType; name=\"$fileName\"\n");
           $self->{sender}->datasend("Content-Transfer-Encoding: base64\n");
           if ((defined $properties{'-disposition'}) and ('inline' eq lc($properties{'-disposition'}))) {
              $self->{sender}->datasend("Content-ID: <$fileName>\n");
              $self->{sender}->datasend("Content-Disposition: inline; =filename=\"$fileName\"\n\n");
           }
           else {
             $self->{sender}->datasend("Content-Disposition: attachment; =filename=\"$fileName\"\n\n");
           }
           # $self->{sender}->datasend("Content-Disposition: attachment; =filename=\"$fileName\"\n\n");
 
           # Google requires us to divide the attachment
           # First read -> Encode -> Send in chunks of 76
           # Read
           my $opened=open(my $file,'<',$attach->{file});
           binmode($file);
           # Encode
           local $/ = undef;
           my $d=<$file>;
           my $str=encode_base64($d);
           # Chunks by 76
           my @groups = split(/(.{76})/,$str);
           $self->{sender}->datasend($_) foreach @groups;
           close $file;
 
           #$self->{sender}->datasend("--$boundary\n"); # to avoid noname.txt dummy attachment
        }
        $self->{sender}->datasend("\n--$boundary--\n"); # send endboundary end message
      }
      else { # No attachment
        print "With No attachments\n" if $verbose;
        # Send text body
        $self->{sender}->datasend("MIME-Version: 1.0\n");
        $self->{sender}->datasend("Content-Type: ".$mail->{contenttype}."; charset=".$mail->{charset}."\n");
 
        $self->{sender}->datasend("\n");
        # Chunk body in sections (Gmail SMTP limitations)
        #$self->{sender}->datasend($mail->{body} . "\n\n");
        my @groups_body = split(/(.{76})/,$mail->{body});
        $self->{sender}->datasend($_) foreach @groups_body;
      }
 
      $self->{sender}->datasend("\n");
 
      if($self->{sender}->dataend()) {
          print "Email sent\n" if $verbose;
          return 1;
      }
      else{
          my $error_string=$self->{sender}->message();
          chomp $error_string;
          $self->{error}=$error_string;
 
          print "Sorry, there was an error during sending. Please, retry or use Debug\n" if $verbose;
          return -1,$self->{error};
      }
 
}
 
1;
__END__
