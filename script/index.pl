#!/usr/bin/perl
#
# Author: Tomasz Miklas
# License: GPLv2
# https://github.com/tmiklas/ahfe-openshift
#
use Digest::SHA1;
use File::Path qw/remove_tree/;
use Mojolicious::Lite;
use Mojolicious::Plugin::RenderFile;
use Mojo::Upload;
use Data::Dumper;

# default purge time if someone manipulates the form
my $purgeTimeDefault = 30 * 60; # 30 minutes

sub cleanup_old_files {
  if (! -d $ENV{OPENSHIFT_DATA_DIR} . ".meta") {
    mkdir ($ENV{OPENSHIFT_DATA_DIR} . ".meta");
  }
  opendir (my $dh, $ENV{OPENSHIFT_DATA_DIR} . ".meta");
  my %dirs;
  map {
    open (T, "$ENV{OPENSHIFT_DATA_DIR}.meta/$_");
    chomp(my @t = <T>);
    close (T);
    $dirs{$_} = \@t;
  } grep { m/^\d{10,}$/ } readdir($dh);
  close ($dh);
  map {
    my $d = $_;
    unlink "$ENV{OPENSHIFT_DATA_DIR}.meta/$_";
    map {
      remove_tree ("$ENV{OPENSHIFT_DATA_DIR}$_", {verbose=>0});
    } @{$dirs{$d}};
  } grep { $_ < time() } keys %dirs;
}

# this generates random(ish) directory names
# takes 1024 chars, sticks current time at the end and SHA1 hashes
sub generate_rand_string {
    my $chars = shift || 'aAeEiIoOuUyYabcdefghijkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    my $num   = shift || 1024;
    my @chars = split '', $chars;
    my $ran;
    for(1..$num){
        $ran .= $chars[rand @chars];
    }
    return Digest::SHA1::sha1_hex($ran . time());
 }

# Upload form in DATA section
get '/' => 'form';

# fetch the files
get '/files/:dir/*file' => sub {
  my $c = shift;
  my $dir = $c->param('dir');
  my $file = $c->param('file');
  if (-e "$ENV{OPENSHIFT_DATA_DIR}$dir/$file") {
    $c->render_file('filepath' => "$ENV{OPENSHIFT_DATA_DIR}$dir/$file", filename=>$file);
  } else {
    $c->render(template=>"not_found", status=>404); # built in Mojolicious template
  }
};

# Multipart upload handler
post '/upload' => sub {
  my $c = shift;
  return $c->redirect_to('form') unless my $upload = $c->param('upload');
  my $uploadedfile = $c->req->upload('upload');
  my $name = $upload->filename;
  # accept only the expiry times listed here
  my @allowed_expiry_times = (300, 1800, 3600, 21600, 86400);
  my $purgeTime = $c->param('expiry') ~~ @allowed_expiry_times ? $c->param('expiry') : $purgeTimeDefault;
  my $dirname = generate_rand_string;
  if (mkdir($ENV{OPENSHIFT_DATA_DIR} . $dirname)) {
    $uploadedfile->move_to($ENV{OPENSHIFT_DATA_DIR} . "$dirname/$name") || say "Can't move file: $!";
  } else {
    $c->redner(text => "Upload failed - please check logs", status=>500);
  }
  if (! -d $ENV{OPENSHIFT_DATA_DIR} . ".meta") {
    mkdir ($ENV{OPENSHIFT_DATA_DIR} . ".meta");
  }
  # write expiry time to meta directory: expiry = now + purge time
  my $expiry = time + $purgeTime;
  open (FH, ">> $ENV{OPENSHIFT_DATA_DIR}.meta/$expiry");
  print FH "$dirname\n";
  close (FH);
  $c->render(text => "<html><body>Uploaded to <a href='/files/$dirname/$name'>/files/$dirname/$name</a></body></html>", status=>200);
};

# aux cleanup hook
app->hook(after_build_tx => sub {
  # this code runs on all web requests before they are parsed
  my ($tx, $app) = @_;
  cleanup_old_files;
});
app->plugin('RenderFile');
app->mode('production');
app->start;

__DATA__

@@ form.html.ep
<!DOCTYPE html>
<html>
  <head><title>Upload</title></head>
  <body>
    %= form_for upload => (enctype => 'multipart/form-data') => begin
      <%= file_field 'upload' =%><br>
      Store for: <%= select_field 'expiry' => [['5min' => '300', selected => 'selected'], ['30min' => 1800], ['1h' => 3600], ['6h' => 6*60*60], ['1d' => 24*60*60]] =%><br>
      %= submit_button 'Upload'
    % end
  </body>
</html>
