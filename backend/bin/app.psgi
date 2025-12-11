#!/usr/bin/env perl

# PropertyManager - PSGI Application Entry Point
# Property Management & Invoicing System

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Load the main application
use PropertyManager::App;
use Dancer2;

# Enable UTF-8 for all output
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

# Return the PSGI application
Dancer2->psgi_app;

__END__

=head1 NAME

app.psgi - PSGI application entry point for PropertyManager

=head1 SYNOPSIS

  # Development server
  plackup -r bin/app.psgi

  # Production with Starman
  starman --workers 10 --port 5000 bin/app.psgi

  # With environment
  DANCER_ENVIRONMENT=production plackup bin/app.psgi

=head1 DESCRIPTION

This is the PSGI entry point for the PropertyManager application.
It loads the Dancer2 application and returns a PSGI-compatible application.

=cut
