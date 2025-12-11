package PropertyManager::Schema;

use strict;
use warnings;
use base 'DBIx::Class::Schema';

our $VERSION = '1.0.0';

# Load all Result classes
__PACKAGE__->load_namespaces(
    result_namespace => 'Result',
);

# Set up connection to use MySQL/MariaDB LIMIT dialect
sub connection {
    my $self = shift;
    my $schema = $self->next::method(@_);

    # Force MySQL/MariaDB limit style (LIMIT X, Y instead of subquery)
    $schema->storage->sql_maker->limit_dialect('LimitXY');

    return $schema;
}

1;

__END__

=head1 NAME

PropertyManager::Schema - DBIx::Class Schema for Property Management System

=head1 SYNOPSIS

  use PropertyManager::Schema;

  my $schema = PropertyManager::Schema->connect(
      'dbi:mysql:database=property_management',
      'username',
      'password',
      { mysql_enable_utf8mb4 => 1 }
  );

  # Query the database
  my $users = $schema->resultset('User')->search({});

=head1 DESCRIPTION

This is the DBIx::Class schema for the Property Management & Invoicing System.
It provides object-relational mapping for all database tables.

=head1 RESULT CLASSES

=over 4

=item * User - User authentication

=item * Company - Company information

=item * Tenant - Tenant management

=item * TenantUtilityPercentage - Tenant utility percentages

=item * UtilityProvider - Utility provider information

=item * ReceivedInvoice - Received invoices from providers

=item * ElectricityMeter - Electricity meter definitions

=item * MeterReading - Meter readings

=item * UtilityCalculation - Utility calculation sessions

=item * UtilityCalculationDetail - Individual tenant utility shares

=item * InvoiceTemplate - Invoice HTML templates

=item * Invoice - Generated invoices

=item * InvoiceItem - Invoice line items

=item * ExchangeRate - BNR exchange rates

=back

=head1 AUTHOR

Property Management System

=cut
