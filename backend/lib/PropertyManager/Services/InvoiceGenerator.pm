package PropertyManager::Services::InvoiceGenerator;

use strict;
use warnings;
use utf8;
use Try::Tiny;
use DateTime;

=head1 NAME

PropertyManager::Services::InvoiceGenerator - Invoice generation service

=head1 SYNOPSIS

  use PropertyManager::Services::InvoiceGenerator;

  my $gen = PropertyManager::Services::InvoiceGenerator->new(
      schema => $schema,
      config => $config,
      exchange_rate_service => $bnr_service,
  );

  # Generate rent invoice
  my $invoice = $gen->create_rent_invoice(
      tenant_id => 1,
      invoice_date => '2025-12-01',
      due_date => '2025-12-15',
  );

  # Generate utility invoice
  my $invoice = $gen->create_utility_invoice(
      tenant_id => 1,
      calculation_id => 5,
      invoice_date => '2025-12-01',
      due_date => '2025-12-15',
  );

  # Generate generic invoice
  my $invoice = $gen->create_generic_invoice(
      invoice_date => '2025-12-01',
      due_date => '2025-12-15',
      client_name => 'Client Name',
      client_address => '123 Main St, Bucharest',
      client_cui => 'RO12345678',
      items => [
          {
              description => 'Consulting Services',
              quantity => 10,
              unit_price => 100,
              vat_rate => 19,
          },
      ],
  );

=cut

# Romanian month names
my @ROMANIAN_MONTHS = qw(
    Ianuarie Februarie Martie Aprilie Mai Iunie
    Iulie August Septembrie Octombrie Noiembrie Decembrie
);

sub new {
    my ($class, %args) = @_;

    die "schema is required" unless $args{schema};
    die "config is required" unless $args{config};
    die "exchange_rate_service is required" unless $args{exchange_rate_service};

    return bless \%args, $class;
}

=head2 get_next_invoice_number

Generate next sequential invoice number using company settings.
Format: PREFIX 123, PREFIX 456, etc.
Thread-safe using database transaction.
Updates company.last_invoice_number after generation.

=cut

sub get_next_invoice_number {
    my ($self) = @_;

    # Use transaction to ensure atomicity
    my $invoice_number;

    $self->{schema}->txn_do(sub {
        # Get company settings
        my $company = $self->{schema}->resultset('Company')->search()->first;

        unless ($company) {
            die "Company information not found - cannot generate invoice number\n";
        }

        # Get prefix and last number from company
        my $prefix = $company->invoice_prefix || 'ARC';
        my $last_number = $company->last_invoice_number || 0;

        # Extract highest number from existing invoices to handle migration
        # from old format (ARC00451) to new format (ARC 451)
        my @invoices = $self->{schema}->resultset('Invoice')->search(
            {},
            { columns => ['invoice_number'] }
        )->all;

        my $max_from_db = 0;
        foreach my $inv (@invoices) {
            my $num_str = $inv->invoice_number;
            # Handle both old format (ARC00451) and new format (ARC 451)
            if ($num_str =~ /^[A-Z]+\s*(\d+)$/) {
                my $num = int($1);
                $max_from_db = $num if $num > $max_from_db;
            }
        }

        # Use the maximum of last_invoice_number and max from database
        $last_number = $max_from_db if $max_from_db > $last_number;

        # Increment the invoice number
        my $next_number = $last_number + 1;

        # Format: PREFIX NUMBER (with space, no leading zeros)
        $invoice_number = "$prefix $next_number";

        # Update company with new last invoice number
        $company->update({ last_invoice_number => $next_number });
    });

    return $invoice_number;
}

=head2 create_rent_invoice

Create a rent invoice for a tenant.
Automatically converts EUR to RON using BNR exchange rate.

Parameters:
- tenant_id: Required tenant ID
- invoice_date: Invoice date (YYYY-MM-DD), defaults to today
- due_date: Payment due date (YYYY-MM-DD), defaults to invoice_date + 15 days
- period_month: Month the rent is for (1-12), defaults to current month
- period_year: Year the rent is for, defaults to current year
- exchange_rate: Manual exchange rate (optional). If provided, uses this instead of BNR
- notes: Additional notes for the invoice
- additional_items: Array of additional line items

=cut

sub create_rent_invoice {
    my ($self, %params) = @_;

    my $tenant_id = $params{tenant_id};
    my $invoice_date = $params{invoice_date} || DateTime->now->ymd;
    my $due_date = $params{due_date};
    my $notes = $params{notes};
    my $additional_items = $params{additional_items} || [];
    my $manual_exchange_rate = $params{exchange_rate};
    my $period_month = $params{period_month};
    my $period_year = $params{period_year};

    die "tenant_id is required" unless $tenant_id;

    # Get tenant
    my $tenant = $self->{schema}->resultset('Tenant')->find($tenant_id)
        or die "Tenant not found";

    # Determine period month/year for description
    unless ($period_month) {
        my $dt = DateTime->now;
        if ($invoice_date =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
            $dt = DateTime->new(year => $1, month => $2, day => $3);
        }
        $period_month = $dt->month;
        $period_year = $dt->year;
    }
    $period_year ||= DateTime->now->year;

    # Validate period_month
    if ($period_month < 1 || $period_month > 12) {
        die "period_month must be between 1 and 12";
    }

    # Get month name in Romanian for description
    my $month_name = $ROMANIAN_MONTHS[$period_month - 1];

    # Handle exchange rate - manual or from service
    my ($exchange_rate, $rate_date, $exchange_rate_manual);

    if (defined $manual_exchange_rate) {
        # Use manually provided exchange rate
        $exchange_rate = $manual_exchange_rate;
        $rate_date = $invoice_date;
        $exchange_rate_manual = 1;
    } else {
        # Attempt to fetch from BNR service
        my $rate_data = $self->{exchange_rate_service}->get_rate_for_invoice_date($invoice_date);

        unless ($rate_data) {
            # Return error instead of dying - let the caller handle it
            die "EXCHANGE_RATE_REQUIRED: Exchange rate not available for date $invoice_date. Please provide manual exchange rate.";
        }

        $exchange_rate = $rate_data->{rate};
        $rate_date = $rate_data->{date};
        $exchange_rate_manual = 0;
    }

    # Calculate rent in RON
    my $rent_eur = $tenant->rent_amount_eur;
    my $rent_ron = $rent_eur * $exchange_rate;

    # Generate invoice number
    my $invoice_number = $self->get_next_invoice_number();

    # Default due date (15 days from invoice date if not specified)
    unless ($due_date) {
        my $dt = DateTime->now;
        if ($invoice_date =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
            $dt = DateTime->new(year => $1, month => $2, day => $3);
        }
        $dt->add(days => 15);
        $due_date = $dt->ymd;
    }

    # Get default template
    my $template = $self->{schema}->resultset('InvoiceTemplate')->search(
        { is_default => 1 }
    )->first;

    my $invoice;
    $self->{schema}->txn_do(sub {
        # Create invoice
        $invoice = $self->{schema}->resultset('Invoice')->create({
            invoice_number => $invoice_number,
            invoice_type => 'rent',
            tenant_id => $tenant_id,
            invoice_date => $invoice_date,
            due_date => $due_date,
            exchange_rate => $exchange_rate,
            exchange_rate_date => $rate_date,
            exchange_rate_manual => $exchange_rate_manual,
            subtotal_eur => $rent_eur,
            subtotal_ron => $rent_ron,
            vat_amount => 0,  # Rent typically has no VAT in Romania
            total_ron => $rent_ron,
            template_id => $template ? $template->id : undef,
            notes => $notes,
        });

        # Create rent line item with specified period
        $invoice->create_related('items', {
            description => "Contravaloare chirie conform contract $month_name $period_year",
            quantity => 1,
            unit_price => $rent_ron,
            vat_rate => 0,
            total => $rent_ron,
            sort_order => 1,
        });

        # Add additional items if provided
        my $sort_order = 2;
        foreach my $item (@$additional_items) {
            $self->add_item(
                invoice_id => $invoice->id,
                description => $item->{description},
                quantity => $item->{quantity} || 1,
                unit_price => $item->{unit_price},
                vat_rate => $item->{vat_rate} || 0,
                sort_order => $sort_order++,
            );
        }

        # Recalculate totals if additional items were added
        if (@$additional_items) {
            $self->calculate_totals($invoice->id);
            $invoice->discard_changes;  # Refresh from database
        }
    });

    return $invoice;
}

=head2 create_utility_invoice

Create a utility invoice for a tenant based on a calculation.

=cut

sub create_utility_invoice {
    my ($self, %params) = @_;

    my $tenant_id = $params{tenant_id};
    my $calculation_id = $params{calculation_id};
    my $invoice_date = $params{invoice_date} || DateTime->now->ymd;
    my $due_date = $params{due_date};
    my $notes = $params{notes};
    my $additional_items = $params{additional_items} || [];

    die "tenant_id and calculation_id are required" unless $tenant_id && $calculation_id;

    # Get tenant
    my $tenant = $self->{schema}->resultset('Tenant')->find($tenant_id)
        or die "Tenant not found";

    # Get calculation
    my $calculation = $self->{schema}->resultset('UtilityCalculation')->find($calculation_id)
        or die "Calculation not found";

    # Get calculation details for this tenant
    my @details = $self->{schema}->resultset('UtilityCalculationDetail')->search(
        {
            calculation_id => $calculation_id,
            tenant_id => $tenant_id,
        }
    )->all;

    die "No calculation details found for tenant" unless @details;

    # Generate invoice number
    my $invoice_number = $self->get_next_invoice_number();

    # Default due date (15 days)
    unless ($due_date) {
        my $dt = DateTime->now;
        if ($invoice_date =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
            $dt = DateTime->new(year => $1, month => $2, day => $3);
        }
        $dt->add(days => 15);
        $due_date = $dt->ymd;
    }

    # Get default template
    my $template = $self->{schema}->resultset('InvoiceTemplate')->search(
        { is_default => 1 }
    )->first;

    # Calculate total from all utility details
    my $total_ron = 0;
    foreach my $detail (@details) {
        $total_ron += $detail->amount;
    }

    # Get period month/year for description
    my $period_month = $calculation->period_month;
    my $period_year = $calculation->period_year;
    my $month_name = $ROMANIAN_MONTHS[$period_month - 1];
    my $item_description = "Contravaloare cheltuieli utilități - $month_name $period_year";

    my $invoice;
    $self->{schema}->txn_do(sub {
        # Create invoice
        $invoice = $self->{schema}->resultset('Invoice')->create({
            invoice_number => $invoice_number,
            invoice_type => 'utility',
            tenant_id => $tenant_id,
            invoice_date => $invoice_date,
            due_date => $due_date,
            calculation_id => $calculation_id,
            subtotal_ron => $total_ron,
            vat_amount => 0,
            total_ron => $total_ron,
            template_id => $template ? $template->id : undef,
            notes => $notes,
        });

        # Create single line item for total utilities
        $invoice->create_related('items', {
            description => $item_description,
            quantity => 1,
            unit_price => $total_ron,
            vat_rate => 0,
            total => $total_ron,
            sort_order => 1,
        });

        # Add additional items if provided
        my $sort_order = 2;
        foreach my $item (@$additional_items) {
            $self->add_item(
                invoice_id => $invoice->id,
                description => $item->{description},
                quantity => $item->{quantity} || 1,
                unit_price => $item->{unit_price},
                vat_rate => $item->{vat_rate} || 0,
                sort_order => $sort_order++,
            );
        }

        # Recalculate totals if additional items were added
        if (@$additional_items) {
            $self->calculate_totals($invoice->id);
            $invoice->discard_changes;  # Refresh from database
        }
    });

    return $invoice;
}

=head2 create_generic_invoice

Create a generic invoice without tenant association.
These invoices are standalone and don't require exchange rates or utility calculations.

Parameters:
- items: Required array of line items, each with:
  - description: Required item description
  - quantity: Required quantity (default 1)
  - unit_price: Required price per unit in RON
  - vat_rate: Required VAT percentage (0-100)
- invoice_date: Invoice date (YYYY-MM-DD), defaults to today
- due_date: Payment due date (YYYY-MM-DD), defaults to invoice_date + 15 days
- notes: Additional notes for the invoice
- client_name: Optional client name (for display on invoice)
- client_address: Optional client address
- client_cui: Optional client CUI/CIF

=cut

sub create_generic_invoice {
    my ($self, %params) = @_;

    my $items = $params{items};
    my $invoice_date = $params{invoice_date} || DateTime->now->ymd;
    my $due_date = $params{due_date};
    my $notes = $params{notes};
    my $tenant_id = $params{tenant_id};
    my $client_name = $params{client_name};
    my $client_address = $params{client_address};
    my $client_cui = $params{client_tax_id} || $params{client_cui};

    die "items array is required" unless $items && ref $items eq 'ARRAY' && @$items;

    # Validate items
    foreach my $item (@$items) {
        die "Each item must have description and unit_price"
            unless $item->{description} && defined $item->{unit_price};

        # Set defaults
        $item->{quantity} //= 1;
        $item->{vat_rate} //= 0;

        # Validate numeric values
        die "quantity must be a positive number"
            unless $item->{quantity} > 0;
        die "unit_price must be a number"
            unless defined $item->{unit_price} && $item->{unit_price} =~ /^-?\d+(\.\d+)?$/;
        die "vat_rate must be between 0 and 100"
            unless $item->{vat_rate} >= 0 && $item->{vat_rate} <= 100;
    }

    # Generate invoice number
    my $invoice_number = $self->get_next_invoice_number();

    # Default due date (15 days from invoice date if not specified)
    unless ($due_date) {
        my $dt = DateTime->now;
        if ($invoice_date =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
            $dt = DateTime->new(year => $1, month => $2, day => $3);
        }
        $dt->add(days => 15);
        $due_date = $dt->ymd;
    }

    # Get default template
    my $template = $self->{schema}->resultset('InvoiceTemplate')->search(
        { is_default => 1 }
    )->first;

    # Calculate totals from items
    my $subtotal_ron = 0;
    my $vat_total = 0;

    foreach my $item (@$items) {
        my $line_total = $item->{quantity} * $item->{unit_price};
        my $line_vat = $line_total * ($item->{vat_rate} / 100);
        $subtotal_ron += $line_total;
        $vat_total += $line_vat;
    }

    my $total_ron = $subtotal_ron + $vat_total;

    my $invoice;
    $self->{schema}->txn_do(sub {
        # Create invoice
        $invoice = $self->{schema}->resultset('Invoice')->create({
            invoice_number => $invoice_number,
            invoice_type => 'generic',
            tenant_id => $tenant_id,  # Optional tenant for generic invoices
            invoice_date => $invoice_date,
            due_date => $due_date,
            exchange_rate => undef,  # No exchange rate needed
            exchange_rate_date => undef,
            exchange_rate_manual => 0,
            subtotal_eur => undef,  # No EUR amounts
            subtotal_ron => $subtotal_ron,
            vat_amount => $vat_total,
            total_ron => $total_ron,
            template_id => $template ? $template->id : undef,
            notes => $notes,
            client_name => $client_name,
            client_address => $client_address,
            client_cui => $client_cui,
        });

        # Create line items
        my $sort_order = 1;
        foreach my $item (@$items) {
            my $line_total = $item->{quantity} * $item->{unit_price};

            $invoice->create_related('items', {
                description => $item->{description},
                quantity => $item->{quantity},
                unit_price => $item->{unit_price},
                vat_rate => $item->{vat_rate},
                total => $line_total,
                sort_order => $sort_order++,
            });
        }
    });

    return $invoice;
}

=head2 add_item

Add a line item to an existing invoice.

=cut

sub add_item {
    my ($self, %params) = @_;

    my $invoice_id = $params{invoice_id};
    my $description = $params{description};
    my $quantity = $params{quantity} || 1;
    my $unit_price = $params{unit_price};
    my $vat_rate = $params{vat_rate} || 0;
    my $sort_order = $params{sort_order} || 0;

    die "invoice_id, description, and unit_price are required"
        unless $invoice_id && $description && defined $unit_price;

    # Calculate total
    my $total = $quantity * $unit_price;

    my $item = $self->{schema}->resultset('InvoiceItem')->create({
        invoice_id => $invoice_id,
        description => $description,
        quantity => $quantity,
        unit_price => $unit_price,
        vat_rate => $vat_rate,
        total => $total,
        sort_order => $sort_order,
    });

    return $item;
}

=head2 calculate_totals

Recalculate invoice totals from all line items.

=cut

sub calculate_totals {
    my ($self, $invoice_id) = @_;

    my $invoice = $self->{schema}->resultset('Invoice')->find($invoice_id)
        or die "Invoice not found";

    my @items = $invoice->items->all;

    my $subtotal = 0;
    my $vat_total = 0;

    foreach my $item (@items) {
        $subtotal += $item->total;
        $vat_total += ($item->total * $item->vat_rate / 100);
    }

    my $total = $subtotal + $vat_total;

    # Update invoice
    # Note: subtotal_eur is NOT updated here because it represents only the
    # EUR-denominated portion (rent). Additional items in RON should not
    # affect the EUR subtotal.
    $invoice->update({
        subtotal_ron => $subtotal,
        vat_amount => $vat_total,
        total_ron => $total,
    });

    return $invoice;
}

1;

__END__

=head1 DESCRIPTION

This service handles invoice generation for both rent and utility invoices.

=head1 RENT INVOICES

Rent invoices:
- Use tenant's rent_amount_eur
- Convert to RON using BNR exchange rate for invoice date
- Store exchange rate and date for audit trail
- Typically have no VAT (Romanian rental income taxation)

=head1 UTILITY INVOICES

Utility invoices:
- Based on utility calculations
- Pull amounts from utility_calculation_details
- One invoice per tenant per calculation
- List each utility type as separate line item

=head1 INVOICE NUMBERING

Invoice numbers follow the format: PREFIX 123, PREFIX 456, etc.
- Prefix: stored in company.invoice_prefix (default "ARC")
- Format: Prefix followed by space and number (no leading zeros)
- Sequential: numbers increment globally across all invoices
- Counter: stored in company.last_invoice_number
- Thread-safe: uses database transaction to prevent duplicates
- Updates: company.last_invoice_number is incremented with each invoice
- Migration: supports reading old format (ARC00451) and new format (ARC 451)

=head1 AUTHOR

Property Management System

=cut
