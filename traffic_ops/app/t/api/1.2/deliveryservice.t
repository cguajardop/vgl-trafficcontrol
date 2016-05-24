package main;
#
# Copyright 2015 Comcast Cable Communications Management, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use DBI;
use strict;
use warnings;
no warnings 'once';
use warnings 'all';
use Test::TestHelper;

#no_transactions=>1 ==> keep fixtures after every execution, beware of duplicate data!
#no_transactions=>0 ==> delete fixtures after every execution

BEGIN { $ENV{MOJO_MODE} = "test" }

my $schema = Schema->connect_to_database;
my $dbh    = Schema->database_handle;
my $t      = Test::Mojo->new('TrafficOps');

Test::TestHelper->unload_core_data($schema);
Test::TestHelper->load_core_data($schema);

ok $t->post_ok( '/login', => form => { u => Test::TestHelper::ADMIN_USER, p => Test::TestHelper::ADMIN_USER_PASSWORD } )->status_is(302)
	->or( sub { diag $t->tx->res->content->asset->{content}; } ), 'Should login?';

ok $t->post_ok('/api/1.2/deliveryservices' => {Accept => 'application/json'} => json => {
        "xmlId" => "ds_1",
        "displayName" => "ds_displayname_1",
        "protocol" => "1",
        "orgServerFqdn" => "http://10.75.168.91",
        "cdnName" => "cdn1",
        "profileName" => "CCR1",
        "type" => "HTTP",
        "multiSiteOrigin" => "0",
        "regionalGeoBlocking" => "1",
        "active" => "0",
        "matchList" => [
            {
                "type" =>  "HOST_REGEXP",
                "setNumber" =>  "0",
                "pattern" => ".*\\.ds_1\\..*"
            },
            {
                "type" =>  "HOST_REGEXP",
                "setNumber" =>  "1",
                "pattern" => ".*\\.my_vod1\\..*"
            }
        ]})
    ->status_is(200)->or( sub { diag $t->tx->res->content->asset->{content}; } )
    ->json_is( "/response/xmlId" => "ds_1")
    ->json_is( "/response/displayName" => "ds_displayname_1")
    ->json_is( "/response/orgServerFqdn" => "http://10.75.168.91")
    ->json_is( "/response/cdnName" => "cdn1")
    ->json_is( "/response/profileName" => "CCR1")
    ->json_is( "/response/protocol" => "1")
    ->json_is( "/response/multiSiteOrigin" => "0")
    ->json_is( "/response/regionalGeoBlocking" => "1")
    ->json_is( "/response/matchList/0/type" => "HOST_REGEXP")
    ->json_is( "/response/matchList/0/setNumber" => "0")
    ->json_is( "/response/matchList/0/pattern" => ".*\\.ds_1\\..*")
    ->json_is( "/response/matchList/1/type" => "HOST_REGEXP")
    ->json_is( "/response/matchList/1/setNumber" => "1")
    ->json_is( "/response/matchList/1/pattern" => ".*\\.my_vod1\\..*")
            , 'Does the deliveryservice details return?';

my $ds_id = &get_ds_id('ds_1');

ok $t->put_ok('/api/1.2/deliveryservices/' . $ds_id  => {Accept => 'application/json'} => json => {
        "xmlId" => "ds_1",
        "displayName" => "ds_displayname_2",
        "protocol" => "1",
        "orgServerFqdn" => "http://10.75.168.91",
        "cdnName" => "cdn1",
        "profileName" => "CCR1",
        "type" => "HTTP",
        "multiSiteOrigin" => "0",
        "regionalGeoBlocking" => "0",
        "active" => "1",
        "matchList" => [
            {
                "type" =>  "HOST_REGEXP",
                "setNumber" =>  "0",
                "pattern" => ".*\\.my_vod2\\..*"
            }
        ]})
    ->status_is(200)->or( sub { diag $t->tx->res->content->asset->{content}; } )
    ->json_is( "/response/xmlId" => "ds_1")
    ->json_is( "/response/displayName" => "ds_displayname_2")
    ->json_is( "/response/orgServerFqdn" => "http://10.75.168.91")
    ->json_is( "/response/cdnName" => "cdn1")
    ->json_is( "/response/profileName" => "CCR1")
    ->json_is( "/response/protocol" => "1")
    ->json_is( "/response/multiSiteOrigin" => "0")
    ->json_is( "/response/regionalGeoBlocking" => "0")
    ->json_is( "/response/matchList/0/type" => "HOST_REGEXP")
    ->json_is( "/response/matchList/0/setNumber" => "0")
    ->json_is( "/response/matchList/0/pattern" => ".*\\.my_vod2\\..*")
            , 'Does the deliveryservice details return?';

ok $t->delete_ok('/api/1.2/deliveryservices/' . $ds_id)->status_is(200)->or( sub { diag $t->tx->res->content->asset->{content}; } );

ok $t->put_ok('/api/1.2/deliveryservices/' . $ds_id  => {Accept => 'application/json'} => json => {
        "xmlId" => "ds_3"
})
    ->status_is(404)->or( sub { diag $t->tx->res->content->asset->{content}; } );

ok $t->post_ok('/api/1.2/deliveryservices/test-ds1/servers' => {Accept => 'application/json'} => json => {
        "server_names" => [
             "atlanta-edge-01",
             "atlanta-edge-02"
        ]})
     ->status_is(200)->or( sub { diag $t->tx->res->content->asset->{content}; } )
    ->json_is( "/response/xml_id" => "test-ds1")
     ->json_is( "/response/server_names/0" => "atlanta-edge-01")
     ->json_is( "/response/server_names/1" => "atlanta-edge-02")
            , 'Does the assigned servers return?';

ok $t->put_ok('/api/1.2/snapshot/cdn1') 
     ->status_is(200)->or( sub { diag $t->tx->res->content->asset->{content}; } );
 
ok $t->get_ok('/logout')->status_is(302)->or( sub { diag $t->tx->res->content->asset->{content}; } );
$dbh->disconnect();
done_testing();

sub get_ds_id {
    my $xml_id = shift;
    my $q      = "select id from deliveryservice where xml_id = \'$xml_id\'";
    my $get_svr = $dbh->prepare($q);
    $get_svr->execute();
    my $p = $get_svr->fetchall_arrayref( {} );
    $get_svr->finish();
    my $id = $p->[0]->{id};
    return $id;
}
