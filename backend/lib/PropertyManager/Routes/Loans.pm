package PropertyManager::Routes::Loans;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);
use PropertyManager::Services::Loan;
use POSIX qw(strftime);
use Try::Tiny;

prefix '/api/loans';

my $SVC = 'PropertyManager::Services::Loan';

sub _today { strftime('%Y-%m-%d', localtime) }

sub _entries_of {
    my ($loan) = @_;
    return [ map { { $_->get_columns } }
             $loan->entries->search({}, { order_by => ['entry_date', 'id'] })->all ];
}

get '' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;

    my @loans = schema->resultset('Loan')->search(
        {}, { order_by => [{ -desc => 'is_active' }, 'person'] })->all;

    my $today = _today();
    my @data = map {
        my %l = $_->get_columns;
        my $summary = $SVC->summarise(\%l, _entries_of($_), $today);
        { %l, summary => $summary };
    } @loans;

    return { success => 1, data => { loans => \@data } };
};

get '/:id' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;

    my $loan = schema->resultset('Loan')->find(route_parameters->get('id'));
    unless ($loan) { status 404; return { success => 0, error => 'Loan not found' }; }

    my %l = $loan->get_columns;
    my $entries = _entries_of($loan);
    my $today = _today();

    return { success => 1, data => {
        loan     => \%l,
        entries  => [ reverse @$entries ],          # newest first for the table
        series   => $SVC->balance_series($entries), # oldest first for the chart
        summary  => $SVC->summarise(\%l, $entries, $today),
        as_of    => $today,
    } };
};

put '/:id' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $loan = schema->resultset('Loan')->find(route_parameters->get('id'));
    unless ($loan) { status 404; return { success => 0, error => 'Loan not found' }; }

    my $d = request->data;
    if (exists $d->{offset_rate} && $d->{offset_rate} < 0) {
        status 400; return { success => 0, error => 'offset_rate must be non-negative' };
    }

    my $error;
    try {
        $loan->update({
            map { $_ => $d->{$_} } grep { exists $d->{$_} }
            qw(person currency offset_label offset_rate offset_start notes is_active)
        });
    } catch { $error = $_ };

    if ($error) { status 500; return { success => 0, error => "Update failed: $error" }; }

    return { success => 1, data => { loan => { $loan->get_columns } } };
};

# -- entries ----------------------------------------------------------------

post '/:id/entries' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $loan = schema->resultset('Loan')->find(route_parameters->get('id'));
    unless ($loan) { status 404; return { success => 0, error => 'Loan not found' }; }

    my $d = request->data;
    for my $f (qw(entry_date amount)) {
        unless (defined $d->{$f} && $d->{$f} ne '') {
            status 400; return { success => 0, error => "$f is required" };
        }
    }
    unless ($d->{entry_date} =~ /^\d{4}-\d{2}-\d{2}$/) {
        status 400; return { success => 0, error => 'entry_date must be YYYY-MM-DD' };
    }

    my $amount = $d->{amount} + 0;
    if ($amount == 0) {
        status 400; return { success => 0, error => 'amount cannot be zero' };
    }

    # The client sends a positive amount and a direction, so nobody has to
    # remember that an advance is stored negative. A signed amount still works.
    my $kind = $d->{kind} || ($amount < 0 ? 'advance' : 'payment');
    $amount = $kind eq 'advance' ? -abs($amount) : abs($amount);

    # A `return` inside a Try::Tiny catch block leaves the block, not the route,
    # so the error is captured and handled after the try instead.
    my ($created, $error);
    try {
        $created = schema->resultset('LoanEntry')->create({
            loan_id    => $loan->id,
            entry_date => $d->{entry_date},
            label      => ($d->{label} // '') ne '' ? $d->{label} : '—',
            amount     => sprintf('%.2f', $amount),
            note       => $d->{note},
        });
    } catch {
        $error = $_;
    };

    if ($error) {
        if ($error =~ /Duplicate entry/i) {
            status 409;
            return { success => 0,
                     error => 'Există deja o înregistrare identică la acea dată' };
        }
        status 500;
        return { success => 0, error => "Create failed: $error" };
    }

    return { success => 1, data => { entry => { $created->get_columns } } };
};

del '/:id/entries/:entry_id' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $row = schema->resultset('LoanEntry')->find({
        id      => route_parameters->get('entry_id'),
        loan_id => route_parameters->get('id'),
    });
    unless ($row) { status 404; return { success => 0, error => 'Entry not found' }; }

    my $error;
    try { $row->delete } catch { $error = $_ };

    if ($error) { status 500; return { success => 0, error => "Delete failed: $error" }; }

    return { success => 1 };
};

1;
