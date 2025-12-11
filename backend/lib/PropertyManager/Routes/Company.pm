package PropertyManager::Routes::Company;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth);
use Try::Tiny;

prefix '/api/company';

=head2 GET /api/company

Get company information.

=cut

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $company = schema->resultset('Company')->search()->first;

    unless ($company) {
        status 404;
        return {
            success => 0,
            error => 'Company not configured',
            code => 'COMPANY_NOT_FOUND',
        };
    }

    return {
        success => 1,
        data => { company => { $company->get_columns } },
    };
};

=head2 POST /api/company

Create company (only if none exists).

=cut

post '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    # Check if company already exists
    my $existing = schema->resultset('Company')->search()->first;
    if ($existing) {
        status 400;
        return {
            success => 0,
            error => 'Company already exists. Use PUT to update.',
            code => 'COMPANY_EXISTS',
        };
    }

    my $data = request->data;

    unless ($data->{name} && $data->{cui_cif} && $data->{address} && $data->{city} && $data->{county}) {
        status 400;
        return {
            success => 0,
            error => 'Required fields: name, cui_cif, address, city, county',
        };
    }

    my $company;
    try {
        $company = schema->resultset('Company')->create($data);
    } catch {
        error("Failed to create company: $_");
        status 500;
        return {
            success => 0,
            error => 'Failed to create company',
        };
    };

    return {
        success => 1,
        data => { company => { $company->get_columns } },
    };
};

=head2 PUT /api/company

Update company information.

=cut

put '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $company = schema->resultset('Company')->search()->first;

    unless ($company) {
        status 404;
        return {
            success => 0,
            error => 'Company not found. Use POST to create.',
        };
    }

    my $data = request->data;

    try {
        $company->update($data);
    } catch {
        error("Failed to update company: $_");
        status 500;
        return {
            success => 0,
            error => 'Failed to update company',
        };
    };

    return {
        success => 1,
        data => { company => { $company->get_columns } },
    };
};

1;
