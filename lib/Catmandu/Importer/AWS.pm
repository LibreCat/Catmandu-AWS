package Catmandu::Importer::AWS;

use Catmandu::Sane;
use Moo;

use Furl;
use XML::LibXML::Simple qw(XMLin);

use Digest;
use Digest::SHA qw(hmac_sha256_base64);
use URI::Escape qw(uri_escape_utf8);

# use Data::Dumper;

with 'Catmandu::Importer';

# Constants. ------------------------------------------------------------------

use constant DEFAULT_URL => 'http://webservices.amazon.com/onca/xml';

# Properties. -----------------------------------------------------------------

has AWSRequestUrl => (is => 'ro', default => sub { return DEFAULT_URL; });
has AWSAccessKeyId => (is => 'ro', required => 1);
has AWSSecretAccessKey => (is => 'ro', required => 1);

has unsigned_request => (is => 'ro', lazy => 1, builder => '_unsigned_request');
has canonical_string => (is => 'ro', lazy => 1, builder => '_canonical_string');
has signature => (is => 'ro', lazy => 1, builder => '_signature');
has signed_request => (is => 'ro', lazy => 1, builder => '_signed_request');
has results => (is => 'ro', lazy => 1, builder => '_send_request');

# Internal Methods. -----------------------------------------------------------

sub _unsigned_request {
  my ($self) = @_;

  my $params = $self->{requestParams};

  my $req = $self->AWSRequestUrl . '?';
  $req .= 'AWSAccessKeyId=' . $self->AWSAccessKeyId;

  while (my ($k, $v) = each %$params) {
    $req .= '&' . $self->url_encode($k) . "=" . $self->url_encode($v);
  }

  # print 'UNSIGNED REQUEST: ' . Dumper($req) . "\n";

  return $req;
}

sub _canonical_string {
  my ($self) = @_;

  my $params = $self->{requestParams};

  # Append the AWSAccessKeyId.
  $params->{AWSAccessKeyId} = $self->AWSAccessKeyId;

  # Append the timestamp.
  $params->{Timestamp} = $self->construct_timestamp();

  my @parts;
  while (my ($k, $v) = each %$params) {
    # URL encode , and : characters.
    my $x = $self->url_encode($k) . "=" . $self->url_encode($v);
    push @parts, $x;
  }

  # Rejoin the sorted parameter/value list with ampersands.
  my $canonical = join('&', sort @parts);

  # print 'CANONICAL: ' . Dumper($canonical) . "\n";

  # The result is the canonical string that we'll sign.
  return $canonical;
}

sub _signature {
  my ($self) = @_;

  # Prepend the following three lines (with line breaks) before the canonical string.
  my $str_to_sign = "GET\nwebservices.amazon.com\n/onca/xml\n" . $self->canonical_string;

  # print 'STR_TO_SIGN: ' . Dumper($str_to_sign) . "\n";

  # Calculate an RFC 2104-compliant HMAC with the SHA256 hash algorithm using the Secret Access Key.
  my $signature = hmac_sha256_base64($str_to_sign, $self->AWSSecretAccessKey);

  # Digest::MMM modules do not pad their base64 output, so we do
  # it ourselves to keep the service happy.
  $signature = $signature . "=";

  return $signature;
}

sub _signed_request {
  my ($self) = @_;

  # URL encode the + and = characters in the signature.
  my $url_encoded_signature = $self->url_encode($self->signature);

  # Add the URL encoded signature to your request, and the result is a properly-formatted signed request.
  my $original_request = $self->unsigned_request;
  my $signed_request = $original_request . '&Signature=' . $url_encoded_signature;

  # return properly-formatted signed request.
  return $signed_request;
}

sub _send_request {
  my ($self) = @_;

  # Send the signed request to AWS.
  my $signed_request = $self->signed_request;

  # print 'SIGNED REQUEST: ' . Dumper($signed_request) . "\n";

  my $results = $self->get($signed_request)->content;

  # print 'AMAZON RESPONSE (XML): ' . Dumper($results) . "\n";

  # Convert XML to Perl Hash.
  $results = $self->hashify($results);

  # Return results hash.
  return $results;
}

# Public Methods. --------------------------------------------------------------

sub to_array {
  return [$_[0]->_get_record];
}

sub generator {
  my ($self) = @_;
  my $return = 1;

  return sub {
    # hack to make iterator stop.
    if ($return) {
      $return = 0;
      return $self->_send_request;
    }
    return undef;
  };
}

sub fetch {
  my ($self, $params) = @_;
  $self->{requestParams} = $params;
  return $self;
}

# Helper methods. -------------------------------------------------------------

sub construct_timestamp {
  return sprintf("%04d-%02d-%02dT%02d:%02d:%02d.000Z",
     sub {    ($_[5]+1900,
               $_[4]+1,
               $_[3],
               $_[2],
               $_[1],
               $_[0])
         }->(gmtime(time)));
}

sub url_encode {
  my ($self, $in) = @_;
  my $out = uri_escape_utf8($in, '^A-Za-z0-9\-_.~');
  return $out;
}

sub get {
  my ($self, $url) = @_;

  my $furl = Furl->new(agent => 'Mozilla/5.0', timeout => 10 );

  my $res = $furl->get($url);
  die $res->status_line unless $res->is_success;

  return $res;
}

sub hashify {
  my ($self, $in) = @_;

  my $xs = XML::LibXML::Simple->new();
  my $out = $xs->XMLin(
    $in,
    KeyAttr => [],
    ForceArray => [ 'Item' ]
  );

  return $out;
}

# PerlDoc. --------------------------------------------------------------------

=head1 NAME

Catmandu::Importer::AWS - Package that imports data for AWS.

=head1 SYNOPSIS

  my %params = (
    AWSAccessKeyId => '[your-access-key-id]',
    AWSSecretAccessKey => '[your-secret-access-key]',
    Service => 'AWSECommerceService',
    Operation => 'ItemLookup',
    Version => '2009-03-31',
    ItemId => $itemId,
    ResponseGroup => 'Small',
  );

  my $importer = Catmandu::Importer::AWS->new(%params);

  my $n = $importer->each(sub {
    print Dumper($_[0]);
  });

  print "DONE. $n \n"

=head1 INTERNALS

  1. Append the timestamp.

  2. URL encode , and : characters.

  3. Split the parameter/value pairs and delete the ampersand characters.

  4. Sort your parameter/value pairs by byte value.

  5. Rejoin the sorted parameter/value list with ampersands. The result is the canonical string that we'll sign.

  6. Prepend the following three lines (with line breaks) before the canonical string.

  7. Calculate an RFC 2104-compliant HMAC with the SHA256 hash algorithm using the Secret Access Key.

  8. URL encode the + and = characters in the signature.

  9. Add the URL encoded signature to your request,
     and the result is a properly-formatted signed request.

=head1 SEE ALSO

L<Catmandu::Iterable>

=cut

1;
