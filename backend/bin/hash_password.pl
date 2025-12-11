#!/usr/bin/env perl
use strict;
use warnings;
use Crypt::Bcrypt qw(bcrypt);

my $password = shift @ARGV;

unless ($password) {
    print "Usage: $0 <password>\n";
    print "Example: $0 'MySecretPassword123!'\n";
    exit 1;
}

my $cost = 12;

# Generate random 16-byte salt
my $salt = '';
$salt .= chr(int(rand(256))) for 1..16;

my $hash = bcrypt($password, '2b', $cost, $salt);

print "Password: $password\n";
print "Hash: $hash\n";
