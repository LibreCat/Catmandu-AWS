#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu::Importer::AWS;
use Data::Dumper::Simple;

my $aws = Catmandu::Importer::AWS->new({
  AWSAccessKeyId => $ENV{'AWS_ID'},
  AWSSecretAccessKey => $ENV{'AWS_SECRET'},
});

my $request_params = {
  Service => 'AWSECommerceService',
  Operation => 'ItemLookup',
  IdType => 'ISBN', # type of item identifier.
  ItemId => '0137081073', # uniquely identify an item.
  AssociateTag => 'Title',
  SearchIndex => 'Books', # the product category to search.
  ResponseGroup => 'Images',
  Version => '2011-08-01',
};

my $n = $aws->fetch($request_params)->to_array();

print Dumper($n);
