#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu::Importer::AWS;
use Data::Dumper::Simple;


# http://webservices.amazon.com/onca/xml
#   ?Service=AWSECommerceService
#   &AWSAccessKeyId=[AWS Access Key ID]
#   &Operation=ItemSearch
#   &ItemId=B000Q678OO
#   &ResponseGroup=Images
#   &SearchIndex=Blended
#   &Version=2011-08-01
#   &Timestamp=[YYYY-MM-DDThh:mm:ssZ]
#   &Signature=[Request Signature]


# Supported Common Request Parameters:
#   AWSAccessKeyId
#   ContentType
#   Operation
#   Service
#   Version

# Supported Actions:
#   ItemSearch
#   ItemLookup - IdType, ItemId

my %params = (
  aws_access_key_id => '[AWS Access Key ID]',
  aws_secret_access_key => '[AWS Secret Access Key]',
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
