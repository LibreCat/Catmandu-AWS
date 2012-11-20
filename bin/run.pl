#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu::Importer::AWS;
use Data::Dumper::Simple;

my $aws = Catmandu::Importer::AWS->new({
  AWSAccessKeyId => '[AWSAccessKeyId]',
  AWSSecretAccessKey => '[AWSSecretAccessKey]',
});

my $request_params = {
  Service => 'AWSECommerceService',
  Operation => 'ItemLookup',
  ItemId => 'B000Q678OO',
  ResponseGroup => 'ItemAttributes,Images',
  AssociateTag => 'Title',
  Version => '2011-08-01',
};

my $n = $aws->fetch($request_params)->each(sub {
  print Dumper($_[0]);
});

print "DONE. $n \n";

# http://webservices.amazon.com/onca/xml
#   ?Service=AWSECommerceService
#   &AWSAccessKeyId=[AWS Access Key ID]
#   &Operation=ItemSearch
#   &ItemId=B000Q678OO
#   &ResponseGroup=Images
#   &SearchIndex=Blended
#   &Version=2011-08-01
#
#   &Timestamp=[YYYY-MM-DDThh:mm:ssZ]
#   &Signature=[Request Signature]
