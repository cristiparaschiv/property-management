package PropertyManager::Routes::Tenants;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf get_current_user);
use PropertyManager::Services::ActivityLogger;
use Try::Tiny;
use DateTime;

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
            map { {
                utility_type => $_->utility_type,
                percentage => $_->percentage + 0,
                uses_meter => $_->uses_meter ? 1 : 0,
            } }
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
    $data{utility_percentages} = [
        map { {
            utility_type => $_->utility_type,
            percentage => $_->percentage + 0,
            uses_meter => $_->uses_meter ? 1 : 0,
        } }
        $tenant->utility_percentages->all
    ];

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
                        uses_meter => $pct->{uses_meter} ? 1 : 0,
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

    # Normalize entries: accept either scalar percentage or hashref
    # { percentage => X, uses_meter => 0|1 }
    my %normalized;
    foreach my $utility_type (keys %$percentages) {
        my $entry = $percentages->{$utility_type};
        if (ref $entry eq 'HASH') {
            $normalized{$utility_type} = {
                percentage => $entry->{percentage} // 0,
                uses_meter => $entry->{uses_meter} ? 1 : 0,
            };
        } else {
            # Scalar: pastreaza uses_meter existent din DB (nu-l reseta).
            my $existing = schema->resultset('TenantUtilityPercentage')->search({
                tenant_id    => $tenant->id,
                utility_type => $utility_type,
            })->first;
            $normalized{$utility_type} = {
                percentage => $entry // 0,
                uses_meter => ($existing && $existing->uses_meter) ? 1 : 0,
            };
        }
    }

    # Validate all percentages are within valid range (0-100)
    foreach my $utility_type (keys %normalized) {
        my $pct = $normalized{$utility_type}{percentage};
        if ($pct < 0 || $pct > 100) {
            status 400;
            return { success => 0, error => "Percentage for $utility_type must be between 0 and 100" };
        }
    }

    my $error;
    try {
        schema->txn_do(sub {
            foreach my $utility_type (keys %normalized) {
                schema->resultset('TenantUtilityPercentage')->update_or_create({
                    tenant_id => $tenant->id,
                    utility_type => $utility_type,
                    percentage => $normalized{$utility_type}{percentage},
                    uses_meter => $normalized{$utility_type}{uses_meter},
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
    my @rows = $tenant->utility_percentages->all;
    my %result_percentages = map { $_->utility_type => $_->percentage + 0 } @rows;
    my @utility_percentages = map { {
        utility_type => $_->utility_type,
        percentage => $_->percentage + 0,
        uses_meter => $_->uses_meter ? 1 : 0,
    } } @rows;

    return { success => 1, data => {
        percentages => \%result_percentages,
        utility_percentages => \@utility_percentages,
    } };
};

# GET /api/tenants/:id/overview - read-only analytical read-model for tenant 360
get '/:id/overview' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $tenant = schema->resultset('Tenant')->find(route_parameters->get('id'), {
        prefetch => 'utility_percentages',
    });
    unless ($tenant) {
        status 404;
        return { success => 0, error => 'Tenant not found' };
    }

    # --- tenant block ---
    my %tenant_data = $tenant->get_columns;
    $tenant_data{utility_percentages} = [
        map { { utility_type => $_->utility_type, percentage => $_->percentage + 0,
                uses_meter => $_->uses_meter ? 1 : 0 } }
        $tenant->utility_percentages->all
    ];

    # --- invoices -> KPIs + payment behaviour ---
    my @invoices = schema->resultset('Invoice')->search(
        { tenant_id => $tenant->id }, { order_by => 'invoice_date' }
    )->all;

    my $days_between = sub {
        my ($from, $to) = @_;                       # 'YYYY-MM-DD' strings
        return undef unless $from && $to;
        my @a = $from =~ /^(\d{4})-(\d{2})-(\d{2})/ or return undef;
        my @b = $to   =~ /^(\d{4})-(\d{2})-(\d{2})/ or return undef;
        my $d1 = DateTime->new(year=>$a[0], month=>$a[1], day=>$a[2]);
        my $d2 = DateTime->new(year=>$b[0], month=>$b[1], day=>$b[2]);
        return $d2->delta_days($d1)->in_units('days') * ($d2 >= $d1 ? 1 : -1);
    };

    my ($billed, $paid, $open_count) = (0, 0, 0);
    my (@pay_points, @pay_lags, @overdue_days);
    my $today = DateTime->now->ymd;
    for my $inv (@invoices) {
        my $amt = $inv->total_ron + 0;
        $billed += $amt;
        if ($inv->is_paid) {
            $paid += $amt;
            if ($inv->paid_date) {
                my $lag = $days_between->($inv->invoice_date . '', $inv->paid_date . '');
                if (defined $lag) {
                    push @pay_points, { invoice_date => $inv->invoice_date . '', days_to_pay => $lag };
                    push @pay_lags, $lag;
                }
            }
        } else {
            $open_count++;
            my $ref = ($inv->due_date // $inv->invoice_date) . '';
            my $od = $days_between->($ref, $today);
            push @overdue_days, $od if defined $od && $od > 0;
        }
    }
    my $avg_days = @pay_lags ? int(0.5 + (eval { my $s=0; $s+=$_ for @pay_lags; $s } / @pay_lags)) : undef;
    my $oldest   = @overdue_days ? (sort { $b <=> $a } @overdue_days)[0] : undef;

    my %kpis = (
        billed_ron        => sprintf('%.2f', $billed) + 0,
        paid_ron          => sprintf('%.2f', $paid) + 0,
        outstanding_ron   => sprintf('%.2f', $billed - $paid) + 0,
        open_count        => $open_count,
        oldest_unpaid_days => $oldest,
        avg_days_to_pay   => $avg_days,
    );

    # --- utility allocation (finalized calcs only), grouped by utility ---
    my $alloc_rs = schema->resultset('UtilityCalculationDetail')->search(
        { 'me.tenant_id' => $tenant->id, 'calculation.is_finalized' => 1 },
        { join => 'calculation',
          select => ['me.utility_type', { sum => 'me.amount' }],
          as     => ['utility_type', 'total'],
          group_by => ['me.utility_type'] }
    );
    my %alloc;
    while (my $row = $alloc_rs->next) {
        $alloc{ $row->get_column('utility_type') } = sprintf('%.2f', $row->get_column('total') || 0) + 0;
    }
    # keep a 0 bar for utilities the tenant carries a standing rate for
    for my $up ($tenant->utility_percentages->all) {
        $alloc{ $up->utility_type } //= 0 if $up->percentage > 0 || $up->uses_meter;
    }
    my @utility_allocation = map { { utility_type => $_, total_ron => $alloc{$_} } }
        sort keys %alloc;

    # --- metered consumption per utility (gas/water direct; electricity via meters) ---
    # Build a series over the FULL contiguous month range from the earliest to the
    # latest reading for that utility, filling any month with no reading as an
    # explicit { period, value => undef } gap (never a 0). This is required so the
    # frontend's period-union merge can render a real gap even when a month is
    # missing across every utility series.
    my $fill_gaps = sub {
        my (@rows_with_pm) = @_;   # list of [period_year, period_month, value_or_undef]
        return [] unless @rows_with_pm;
        my %by_period = map { sprintf('%04d-%02d', $_->[0], $_->[1]) => $_->[2] } @rows_with_pm;

        my ($first_y, $first_m) = @{ $rows_with_pm[0] }[0,1];
        my ($last_y, $last_m)   = @{ $rows_with_pm[-1] }[0,1];

        my @series;
        my ($y, $m) = ($first_y, $first_m);
        while ($y < $last_y || ($y == $last_y && $m <= $last_m)) {
            my $period = sprintf('%04d-%02d', $y, $m);
            push @series, { period => $period, value => $by_period{$period} };
            $m++;
            if ($m > 12) { $m = 1; $y++; }
        }
        return \@series;
    };

    my %metered;
    # gas + water
    for my $pair (['gas','GasReading'], ['water','WaterReading']) {
        my ($ut, $rs) = @$pair;
        my @rows = schema->resultset($rs)->search(
            { tenant_id => $tenant->id },
            { order_by => [{ -asc => 'period_year' }, { -asc => 'period_month' }] }
        )->all;
        next unless @rows;
        $metered{$ut} = $fill_gaps->(
            map { [ $_->period_year, $_->period_month,
                     defined $_->consumption ? $_->consumption + 0 : undef ] } @rows
        );
    }
    # electricity via this tenant's meters
    my @meter_ids = map { $_->id }
        schema->resultset('ElectricityMeter')->search({ tenant_id => $tenant->id })->all;
    if (@meter_ids) {
        my @rows = schema->resultset('MeterReading')->search(
            { meter_id => { -in => \@meter_ids } },
            { order_by => [{ -asc => 'period_year' }, { -asc => 'period_month' }] }
        )->all;
        $metered{electricity} = $fill_gaps->(
            map { [ $_->period_year, $_->period_month,
                     defined $_->consumption ? $_->consumption + 0 : undef ] } @rows
        ) if @rows;
    }

    # --- data completeness ---
    my @empty;
    for my $f (qw(cui_cnp j_number postal_code phone email contract_start contract_end notes)) {
        my $v = $tenant->get_column($f);
        push @empty, $f unless defined $v && $v ne '';
    }
    my %data_completeness = (
        empty_fields => \@empty,
        not_modelled => [qw(deposit area_sqm lease_term signed_contract contact_person iban)],
    );

    return { success => 1, data => {
        tenant             => \%tenant_data,
        kpis               => \%kpis,
        payment_behaviour  => \@pay_points,
        utility_allocation => \@utility_allocation,
        metered_consumption => \%metered,
        data_completeness  => \%data_completeness,
    } };
};

1;
