package PropertyManager::Services::Loan;

use strict;
use warnings;
use POSIX qw(ceil);

=head1 NAME

PropertyManager::Services::Loan - arithmetic for the personal loan ledger

=head1 DESCRIPTION

Money lent out and paid back, plus an optional monthly offset credited against
the debt.

Sign convention matches the table: C<amount> below zero is money advanced,
above zero is money repaid. The outstanding balance is the negated sum.

All arithmetic runs in integer cents and returns strings with two decimals.
DBIx::Class hands DECIMAL columns back as strings, and Perl will silently
coerce those to floats the moment you add them; a repayment schedule is not
the place to discover binary rounding error.

This module is deliberately free of Dancer2 and of the database, so it can be
tested without either.

=cut

# -- money ------------------------------------------------------------------

sub _cents {
    my ($class, $value) = @_;
    return 0 unless defined $value && $value ne '';
    # sprintf rounds half-away-from-zero, which is what a ledger expects.
    return int(sprintf('%.0f', $value * 100));
}

sub _money {
    my ($class, $cents) = @_;
    return sprintf('%.2f', $cents / 100);
}

# -- dates ------------------------------------------------------------------

sub _ymd {
    my ($class, $date) = @_;
    return unless defined $date;
    my ($y, $m, $d) = $date =~ /^(\d{4})-(\d{2})-(\d{2})/ or return;
    return ($y + 0, $m + 0, $d + 0);
}

=head2 months_accrued($start, $as_of)

Whole months from C<$start>'s month through C<$as_of>'s month, inclusive, so
January to July is seven. Zero when C<$start> is missing or in the future.

=cut

sub months_accrued {
    my ($class, $start, $as_of) = @_;
    my ($sy, $sm) = $class->_ymd($start) or return 0;
    my ($ay, $am) = $class->_ymd($as_of) or return 0;
    my $months = ($ay - $sy) * 12 + ($am - $sm) + 1;
    return $months > 0 ? $months : 0;
}

sub _add_months {
    my ($class, $date, $months) = @_;
    my ($y, $m, $d) = $class->_ymd($date) or return;
    my $total = ($y * 12) + ($m - 1) + $months;
    my ($ny, $nm) = (int($total / 12), ($total % 12) + 1);
    # Clamp the day so 31 January + 1 month is not 31 February.
    my @len = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    my $last = $len[$nm - 1];
    $last = 29 if $nm == 2 && (($ny % 4 == 0 && $ny % 100 != 0) || $ny % 400 == 0);
    $d = $last if $d > $last;
    return sprintf('%04d-%02d-%02d', $ny, $nm, $d);
}

# -- the ledger -------------------------------------------------------------

sub _ordered {
    my ($class, $entries) = @_;
    my $i = 0;
    my @indexed = map { { %$_, _seq => $i++ } } @$entries;
    return [ sort { $a->{entry_date} cmp $b->{entry_date} || $a->{_seq} <=> $b->{_seq} }
             @indexed ];
}

=head2 balance_series($entries)

One point per entry in date order, each carrying the balance outstanding
immediately after it. Entries sharing a date keep their input order.

=cut

sub balance_series {
    my ($class, $entries) = @_;
    my $running = 0;
    my @points;
    for my $e (@{ $class->_ordered($entries) }) {
        $running -= $class->_cents($e->{amount});
        push @points, {
            entry_date => $e->{entry_date},
            label      => $e->{label},
            amount     => $class->_money($class->_cents($e->{amount})),
            balance    => $class->_money($running),
        };
    }
    return \@points;
}

=head2 summarise($loan, $entries, $as_of)

Totals, the monthly offset, repayment pace and a payoff projection.

=cut

sub summarise {
    my ($class, $loan, $entries, $as_of) = @_;
    $entries ||= [];

    my ($lent, $repaid) = (0, 0);
    for my $e (@$entries) {
        my $c = $class->_cents($e->{amount});
        $c < 0 ? ($lent -= $c) : ($repaid += $c);
    }
    my $outstanding = $lent - $repaid;

    my $months = 0;
    my $rate = $class->_cents($loan->{offset_rate});
    $months = $class->months_accrued($loan->{offset_start}, $as_of) if $rate > 0;
    my $offset = $rate * $months;

    # Pace is measured across the repayment period only. Averaging over the
    # whole ledger would include the months he was still borrowing and
    # understate how fast he is actually paying.
    my ($first_repayment) = map  { $_->{entry_date} }
                            grep { $class->_cents($_->{amount}) > 0 }
                            @{ $class->_ordered($entries) };
    my $span = $first_repayment ? $class->months_accrued($first_repayment, $as_of) : 0;
    my $pace = $span > 0 ? int($repaid / $span) : 0;

    # A straight-line estimate, and only that: it assumes the current cadence
    # holds and ignores the offset, which moves the target every month.
    my $payoff;
    if ($outstanding > 0 && $pace > 0) {
        $payoff = $class->_add_months($as_of, ceil($outstanding / $pace));
    }

    return {
        currency         => $loan->{currency} || 'RON',
        lent             => $class->_money($lent),
        repaid           => $class->_money($repaid),
        outstanding      => $class->_money($outstanding),
        offset_label     => $loan->{offset_label},
        offset_rate      => $class->_money($rate),
        offset_months    => $months,
        offset_total     => $class->_money($offset),
        net_owed         => $class->_money($outstanding - $offset),
        monthly_pace     => $class->_money($pace),
        projected_payoff => $payoff,
        pct_repaid       => $lent > 0 ? sprintf('%.1f', 100 * $repaid / $lent) : '0.0',
        entry_count      => scalar @$entries,
    };
}

1;
