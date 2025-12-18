package PropertyManager::Routes::Tenants;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf get_current_user);
use PropertyManager::Services::ActivityLogger;
use Try::Tiny;

prefix '/api/tenants';

# GET /api/tenants - List all tenants
get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $search = {};
    my $active = query_parameters->get('is_active') // query_parameters->get('active');
    $search->{is_active} = $active ? 1 : 0 if defined $active;

    my @tenants = schema->resultset('Tenant')->search($search, {
        order_by => 'name',
        prefetch => 'utility_percentages',
    })->all;

    my @data = map {
        my %tenant = $_->get_columns;
        $tenant{utility_percentages} = [
            map { { utility_type => $_->utility_type, percentage => $_->percentage + 0 } }
            $_->utility_percentages->all
        ];
        \%tenant;
    } @tenants;

    return { success => 1, data => { tenants => \@data } };
};

# GET /api/tenants/:id - Get single tenant
get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $tenant = schema->resultset('Tenant')->find(route_parameters->get('id'));

    unless ($tenant) {
        status 404;
        return { success => 0, error => 'Tenant not found' };
    }

    my %data = $tenant->get_columns;
    $data{percentages} = {
        map { $_->utility_type => $_->percentage + 0 }
        $tenant->utility_percentages->all
    };

    return { success => 1, data => { tenant => \%data } };
};

# POST /api/tenants - Create tenant
post '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $data = request->data;

    unless ($data->{name} && $data->{address} && $data->{city} && $data->{county}) {
        status 400;
        return { success => 0, error => 'Required: name, address, city, county' };
    }

    # Validate email format if provided
    if ($data->{email} && $data->{email} !~ /^[^\s@]+@[^\s@]+\.[^\s@]+$/) {
        status 400;
        return { success => 0, error => 'Invalid email format' };
    }

    # Validate rent amount is a valid number and not negative
    if (exists $data->{rent_amount_eur}) {
        my $rent = $data->{rent_amount_eur};
        # Check if it looks like a number
        if (!defined $rent || $rent !~ /^-?\d+\.?\d*$/) {
            status 400;
            return { success => 0, error => 'Rent amount must be a valid number' };
        }
        if ($rent < 0) {
            status 400;
            return { success => 0, error => 'Rent amount must be non-negative' };
        }
    }

    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};

    my ($tenant, $error);
    try {
        schema->txn_do(sub {
            my $percentages = delete $data->{utility_percentages};
            $tenant = schema->resultset('Tenant')->create($data);

            # Create utility percentages if provided
            if ($percentages && ref $percentages eq 'ARRAY') {
                foreach my $pct (@$percentages) {
                    $tenant->create_related('utility_percentages', {
                        utility_type => $pct->{utility_type},
                        percentage => $pct->{percentage},
                    });
                }
            }
        });
    } catch {
        $error = $_;
        error("Failed to create tenant: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Failed to create tenant' };
    }

    # Log activity
    my $user = get_current_user();
    PropertyManager::Services::ActivityLogger::log_create(
        schema(),
        'tenant',
        $tenant->id,
        $tenant->name,
        sprintf('Chiriaș nou adăugat: %s', $tenant->name),
        $user ? $user->{id} : undef,
        request->address
    );

    return { success => 1, data => { tenant => { $tenant->get_columns } } };
};

# PUT /api/tenants/:id - Update tenant
put '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $tenant = schema->resultset('Tenant')->find(route_parameters->get('id'));
    unless ($tenant) {
        status 404;
        return { success => 0, error => 'Tenant not found' };
    }

    my $data = request->data;

    # Validate rent amount is a valid number and not negative
    if (exists $data->{rent_amount_eur}) {
        my $rent = $data->{rent_amount_eur};
        # Check if it looks like a number
        if (!defined $rent || $rent !~ /^-?\d+\.?\d*$/) {
            status 400;
            return { success => 0, error => 'Rent amount must be a valid number' };
        }
        if ($rent < 0) {
            status 400;
            return { success => 0, error => 'Rent amount must be non-negative' };
        }
    }

    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};
    delete $data->{utility_percentages};  # Handle separately

    my $error;
    try {
        $tenant->update($data);
    } catch {
        $error = $_;
        error("Failed to update tenant: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Failed to update tenant' };
    }

    # Log activity
    my $user = get_current_user();
    PropertyManager::Services::ActivityLogger::log_update(
        schema(),
        'tenant',
        $tenant->id,
        $tenant->name,
        sprintf('Chiriaș modificat: %s', $tenant->name),
        $user ? $user->{id} : undef,
        request->address
    );

    return { success => 1, data => { tenant => { $tenant->get_columns } } };
};

# DELETE /api/tenants/:id - Soft delete tenant
del '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $tenant = schema->resultset('Tenant')->find(route_parameters->get('id'));
    unless ($tenant) {
        status 404;
        return { success => 0, error => 'Tenant not found' };
    }

    my $tenant_name = $tenant->name;
    $tenant->update({ is_active => 0 });

    # Log activity
    my $user = get_current_user();
    PropertyManager::Services::ActivityLogger::log_delete(
        schema(),
        'tenant',
        $tenant->id,
        $tenant_name,
        sprintf('Chiriaș dezactivat: %s', $tenant_name),
        $user ? $user->{id} : undef,
        request->address
    );

    return { success => 1, message => 'Tenant deactivated' };
};

# PUT /api/tenants/:id/percentages - Update utility percentages
put '/:id/percentages' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $tenant = schema->resultset('Tenant')->find(route_parameters->get('id'));
    unless ($tenant) {
        status 404;
        return { success => 0, error => 'Tenant not found' };
    }

    my $percentages = request->data->{percentages};

    unless ($percentages && ref $percentages eq 'HASH') {
        status 400;
        return { success => 0, error => 'percentages hash is required' };
    }

    # Validate all percentages are within valid range (0-100)
    foreach my $utility_type (keys %$percentages) {
        my $pct = $percentages->{$utility_type};
        if ($pct < 0 || $pct > 100) {
            status 400;
            return { success => 0, error => "Percentage for $utility_type must be between 0 and 100" };
        }
    }

    my $error;
    try {
        schema->txn_do(sub {
            foreach my $utility_type (keys %$percentages) {
                schema->resultset('TenantUtilityPercentage')->update_or_create({
                    tenant_id => $tenant->id,
                    utility_type => $utility_type,
                    percentage => $percentages->{$utility_type},
                }, {
                    key => 'tenant_utility_unique',
                });
            }
        });
    } catch {
        $error = $_;
        error("Failed to update percentages: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Failed to update percentages' };
    }

    # Retrieve updated percentages
    my %result_percentages = map { $_->utility_type => $_->percentage + 0 }
        $tenant->utility_percentages->all;

    return { success => 1, data => { percentages => \%result_percentages } };
};

1;
