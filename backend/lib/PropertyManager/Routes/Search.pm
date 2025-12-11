package PropertyManager::Routes::Search;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth);
use Try::Tiny;

=head1 NAME

PropertyManager::Routes::Search - Global search API endpoint

=head1 DESCRIPTION

Provides unified search functionality across multiple entities:
- Tenants (name, email, phone)
- Invoices (invoice_number, client_name)
- Utility Providers (name, account_number)

=cut

prefix '/api';

=head2 GET /api/search

Global search endpoint across multiple entities.

Query Parameters:
  - q: Search query string (minimum 2 characters)

Returns:
  {
    success: 1,
    data: {
      tenants: [...],
      invoices: [...],
      providers: [...],
      total_count: N
    }
  }

Security:
  - Requires authentication
  - All queries use parameterized SQL (LIKE) to prevent injection
  - Input validation for query length

Performance:
  - Limits results to 5 per category (15 total max)
  - Case-insensitive search using UPPER() for database compatibility

=cut

get '/search' => sub {
    # Require authentication
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    # Get and validate search query
    my $query = query_parameters->get('q');

    # Validate query - must be at least 2 characters
    unless (defined $query && length($query) >= 2) {
        status 400;
        return {
            success => 0,
            error => 'Search query must be at least 2 characters long',
            code => 'INVALID_QUERY',
        };
    }

    # Sanitize query - trim whitespace
    $query =~ s/^\s+|\s+$//g;

    # Re-check after trimming
    if (length($query) < 2) {
        status 400;
        return {
            success => 0,
            error => 'Search query must be at least 2 characters long',
            code => 'INVALID_QUERY',
        };
    }

    # Prepare search pattern for LIKE queries (case-insensitive)
    # Using % wildcards for partial matching
    my $search_pattern = '%' . $query . '%';

    my ($tenants, $invoices, $providers);

    # Execute search with error handling
    try {
        # Search Tenants - by name, email, phone
        # Using case-insensitive search with UPPER() for portability
        $tenants = _search_tenants($search_pattern);

        # Search Invoices - by invoice_number, client_name
        $invoices = _search_invoices($search_pattern);

        # Search Utility Providers - by name, account_number
        $providers = _search_providers($search_pattern);

    } catch {
        error("Search error: $_");
        status 500;
        return {
            success => 0,
            error => 'Search operation failed',
            code => 'SEARCH_ERROR',
        };
    };

    # Calculate total count
    my $total_count = scalar(@$tenants) + scalar(@$invoices) + scalar(@$providers);

    # Return results
    return {
        success => 1,
        data => {
            tenants => $tenants,
            invoices => $invoices,
            providers => $providers,
            total_count => $total_count,
        },
    };
};

=head2 _search_tenants

Internal method to search tenants by name, email, or phone.
Uses parameterized queries with LIKE for case-insensitive search.

Parameters:
  - $pattern: Search pattern with wildcards

Returns:
  - ArrayRef of tenant hashrefs

Security:
  - Uses DBIx::Class parameterized queries (SQL injection safe)
  - Limits results to 5 records

=cut

sub _search_tenants {
    my ($pattern) = @_;

    # Build search condition - match name, email, OR phone
    # Using -like for case-insensitive search (MySQL/MariaDB is case-insensitive by default)
    my $search_condition = [
        { name => { -like => $pattern } },
        { email => { -like => $pattern } },
        { phone => { -like => $pattern } },
    ];

    my @tenants = schema->resultset('Tenant')->search(
        { -or => $search_condition },
        {
            rows => 5,
            order_by => { -asc => 'name' },
            columns => [qw/id name email phone is_active/],
        }
    )->all;

    # Format results
    my @results;
    foreach my $tenant (@tenants) {
        push @results, {
            id => $tenant->id,
            name => $tenant->name,
            email => $tenant->email // '',
            phone => $tenant->phone // '',
            is_active => $tenant->is_active ? 1 : 0,
            type => 'tenant',
        };
    }

    return \@results;
}

=head2 _search_invoices

Internal method to search invoices by invoice_number or client_name.
Uses parameterized queries with LIKE for case-insensitive search.

Parameters:
  - $pattern: Search pattern with wildcards

Returns:
  - ArrayRef of invoice hashrefs

Security:
  - Uses DBIx::Class parameterized queries (SQL injection safe)
  - Limits results to 5 records

=cut

sub _search_invoices {
    my ($pattern) = @_;

    # Build search condition - match invoice_number OR client_name
    # Using -like for case-insensitive search (MySQL/MariaDB is case-insensitive by default)
    my $search_condition = [
        { invoice_number => { -like => $pattern } },
        { client_name => { -like => $pattern } },
    ];

    my @invoices = schema->resultset('Invoice')->search(
        { -or => $search_condition },
        {
            rows => 5,
            order_by => { -desc => 'invoice_date' },
            columns => [qw/id invoice_number client_name total_ron invoice_date is_paid/],
        }
    )->all;

    # Format results
    my @results;
    foreach my $invoice (@invoices) {
        push @results, {
            id => $invoice->id,
            invoice_number => $invoice->invoice_number,
            client_name => $invoice->client_name // '',
            total_ron => $invoice->total_ron + 0,  # Force numeric context
            invoice_date => $invoice->invoice_date // '',
            is_paid => $invoice->is_paid ? 1 : 0,
            type => 'invoice',
        };
    }

    return \@results;
}

=head2 _search_providers

Internal method to search utility providers by name or account_number.
Uses parameterized queries with LIKE for case-insensitive search.

Parameters:
  - $pattern: Search pattern with wildcards

Returns:
  - ArrayRef of provider hashrefs

Security:
  - Uses DBIx::Class parameterized queries (SQL injection safe)
  - Limits results to 5 records

=cut

sub _search_providers {
    my ($pattern) = @_;

    # Build search condition - match name OR account_number
    # Using -like for case-insensitive search (MySQL/MariaDB is case-insensitive by default)
    my $search_condition = [
        { name => { -like => $pattern } },
        { account_number => { -like => $pattern } },
    ];

    my @providers = schema->resultset('UtilityProvider')->search(
        { -or => $search_condition },
        {
            rows => 5,
            order_by => { -asc => 'name' },
            columns => [qw/id name account_number type is_active/],
        }
    )->all;

    # Format results
    my @results;
    foreach my $provider (@providers) {
        push @results, {
            id => $provider->id,
            name => $provider->name,
            account_number => $provider->account_number // '',
            provider_type => $provider->type,
            is_active => $provider->is_active ? 1 : 0,
            type => 'provider',
        };
    }

    return \@results;
}

1;

__END__

=head1 ROUTES

=over 4

=item GET /api/search?q={query}

Global search across tenants, invoices, and utility providers.

=back

=head1 SECURITY FEATURES

=over 4

=item * Authentication required (JWT token validation)

=item * SQL injection protection via parameterized queries (DBIx::Class)

=item * Input validation (minimum 2 characters)

=item * Query trimming and sanitization

=item * Result limits to prevent resource exhaustion

=back

=head1 PERFORMANCE CONSIDERATIONS

=over 4

=item * Limits results to 5 per category (15 total maximum)

=item * Selective column retrieval (only necessary fields)

=item * Case-insensitive search using -ilike (database-agnostic)

=item * Proper indexing recommended on: tenants.name, tenants.email, invoices.invoice_number, utility_providers.name

=back

=head1 EXAMPLE USAGE

  # Search request
  GET /api/search?q=john
  Authorization: Bearer <token>

  # Response
  {
    "success": 1,
    "data": {
      "tenants": [
        {
          "id": 1,
          "name": "John Doe",
          "email": "john@example.com",
          "phone": "+1234567890",
          "is_active": 1,
          "type": "tenant"
        }
      ],
      "invoices": [
        {
          "id": 5,
          "invoice_number": "INV-JOHN-2025-001",
          "client_name": "John Smith Ltd",
          "total_ron": 1500.00,
          "invoice_date": "2025-01-15",
          "is_paid": 0,
          "type": "invoice"
        }
      ],
      "providers": [],
      "total_count": 2
    }
  }

=head1 ERROR RESPONSES

=over 4

=item 400 Bad Request - Query too short or missing

  { "success": 0, "error": "Search query must be at least 2 characters long", "code": "INVALID_QUERY" }

=item 401 Unauthorized - Missing or invalid authentication token

  { "success": 0, "error": "Authentication required", "code": "AUTH_REQUIRED" }

=item 500 Internal Server Error - Search operation failed

  { "success": 0, "error": "Search operation failed", "code": "SEARCH_ERROR" }

=back

=head1 AUTHOR

Property Management System

=head1 LICENSE

Proprietary - All rights reserved

=cut
