package PropertyManager::Services::PDFGenerator;

use strict;
use warnings;
use PDF::API2;
use PDF::Table;
use Try::Tiny;
use Encode qw(decode encode);
use POSIX qw(locale_h);
use Template;
use IPC::Run3;
use File::Temp qw(tempfile);
use FindBin;
use File::Spec;

# Romanian month names for utility breakdown
my @ROMANIAN_MONTHS = qw(
    Ianuarie Februarie Martie Aprilie Mai Iunie
    Iulie August Septembrie Octombrie Noiembrie Decembrie
);

=head1 NAME

PropertyManager::Services::PDFGenerator - PDF invoice generation service

=head1 SYNOPSIS

  use PropertyManager::Services::PDFGenerator;

  my $gen = PropertyManager::Services::PDFGenerator->new(schema => $schema);

  my $pdf_data = $gen->generate_invoice_pdf($invoice_id);

=cut

sub new {
    my ($class, %args) = @_;

    die "schema is required" unless $args{schema};
    # config is optional for PDFGenerator

    return bless \%args, $class;
}

=head2 _format_number_romanian

Format number with Romanian locale (1.234,56)

=cut

sub _format_number_romanian {
    my ($self, $number, $decimals) = @_;
    $decimals //= 2;

    # Format with decimals
    my $formatted = sprintf("%.${decimals}f", $number);

    # Split integer and decimal parts
    my ($integer, $decimal) = split(/\./, $formatted);

    # Add thousands separator (period)
    $integer = reverse $integer;
    $integer =~ s/(\d{3})(?=\d)/$1./g;
    $integer = reverse $integer;

    # Join with comma as decimal separator
    return $decimal ? "$integer,$decimal" : $integer;
}

=head2 _format_date_romanian

Format date to Romanian format DD.MM.YYYY

=cut

sub _format_date_romanian {
    my ($self, $date) = @_;

    # Handle various input formats (YYYY-MM-DD, etc.)
    if ($date =~ /^(\d{4})-(\d{2})-(\d{2})/) {
        return "$3.$2.$1";
    }

    return $date;
}

=head2 generate_invoice_pdf

Generate PDF for an invoice.
Returns PDF binary data.

Parameters:
- $invoice_id: Invoice ID (required)
- %options: Optional parameters
  - user: User object for delegate information (optional, will use first user if not provided)

=cut

sub generate_invoice_pdf {
    my ($self, $invoice_id, %options) = @_;

    die "invoice_id is required" unless $invoice_id;

    # Load invoice with all relationships
    my $invoice = $self->{schema}->resultset('Invoice')->find(
        $invoice_id,
        {
            prefetch => ['tenant', 'items'],
        }
    ) or die "Invoice not found";

    # Load company
    my $company = $self->{schema}->resultset('Company')->search()->first
        or die "Company information not found";

    # Load user for delegate information (use provided user or get first user)
    my $user = $options{user};
    unless ($user) {
        $user = $self->{schema}->resultset('User')->search(
            {},
            { rows => 1 }
        )->first;
    }

    # Create PDF
    my $pdf = PDF::API2->new();
    $pdf->mediabox('A4');

    my $page = $pdf->page();
    my $text = $page->text();
    my $gfx = $page->gfx();

    # Fonts
    my $font_bold = $pdf->font('Helvetica-Bold');
    my $font_regular = $pdf->font('Helvetica');
    my $font_italic = $pdf->font('Helvetica-Oblique');

    # Page dimensions (A4: 595 x 842 points)
    my $page_width = 595;
    my $page_height = 842;
    my $margin = 50;
    my $y = $page_height - $margin;

    # Header with black background and white text for invoice number
    my $header_height = 25;
    my $header_width = 250;

    # Draw black rectangle for invoice header
    #$gfx->fillcolor('black');
    #$gfx->rect($margin, $y - $header_height, $header_width, $header_height);
    #$gfx->fill();

    # Invoice number in white on black background
    $text->font($font_bold, 14);
    $text->fillcolor('black');
    $text->translate($margin + 0, $y - 17);
    $text->text(encode('UTF-8', "Factura " . $invoice->invoice_number));

    # Reset text color to black for rest of document
    $text->fillcolor('black');

    $y -= ($header_height + 15);

    # Invoice date on the next line
    $text->font($font_regular, 10);
    $text->translate($margin, $y);
    my $formatted_date = $self->_format_date_romanian($invoice->invoice_date);
    $text->text(encode('UTF-8', "Data emiterii: $formatted_date"));
    $y -= 25;

    # Two-column layout for Supplier (Furnizor) and Client
    my $col1_x = $margin;
    my $col2_x = $page_width / 2 + 10;
    my $col_start_y = $y;

    # Left column: Furnizor (Supplier/Company)
    $text->font($font_bold, 11);
    $text->translate($col1_x, $col_start_y);
    $text->text(encode('UTF-8', "Furnizor:"));

    my $left_y = $col_start_y - 15;
    $text->font($font_regular, 9);

    $text->translate($col1_x, $left_y);
    $text->text(encode('UTF-8', $company->name));
    $left_y -= 12;

    if ($company->j_number) {
        $text->translate($col1_x, $left_y);
        $text->text(encode('UTF-8', "Reg. Com.: " . $company->j_number));
        $left_y -= 12;
    }

    $text->translate($col1_x, $left_y);
    $text->text(encode('UTF-8', "C.I.F.: " . $company->cui_cif));
    $left_y -= 12;

    $text->translate($col1_x, $left_y);
    my $company_address = join(", ",
        grep { defined $_ && $_ ne '' }
        ($company->address, $company->city, $company->county)
    );
    $text->text(encode('UTF-8', "Adresa: $company_address"));
    $left_y -= 12;

    if ($company->bank_name) {
        $text->translate($col1_x, $left_y);
        $text->text(encode('UTF-8', "Banca: " . $company->bank_name));
        $left_y -= 12;
    }

    if ($company->iban) {
        $text->translate($col1_x, $left_y);
        $text->text(encode('UTF-8', "IBAN: " . $company->iban));
        $left_y -= 12;
    }

    # Right column: Client
    my $tenant = $invoice->tenant;
    $text->font($font_bold, 11);
    $text->translate($col2_x, $col_start_y);
    $text->text(encode('UTF-8', "Client:"));

    my $right_y = $col_start_y - 15;
    $text->font($font_regular, 9);

    # Handle generic invoices (no tenant) vs tenant-based invoices
    if ($tenant) {
        # Use tenant information
        $text->translate($col2_x, $right_y);
        $text->text(encode('UTF-8', $tenant->name));
        $right_y -= 12;

        if ($tenant->j_number) {
            $text->translate($col2_x, $right_y);
            $text->text(encode('UTF-8', "Reg. Com.: " . $tenant->j_number));
            $right_y -= 12;
        }

        if ($tenant->cui_cnp) {
            $text->translate($col2_x, $right_y);
            $text->text(encode('UTF-8', "C.I.F.: " . $tenant->cui_cnp));
            $right_y -= 12;
        }

        my $tenant_address = join(", ",
            grep { defined $_ && $_ ne '' }
            ($tenant->address, $tenant->city)
        );
        $text->translate($col2_x, $right_y);
        $text->text(encode('UTF-8', "Adresa: $tenant_address"));
        $right_y -= 12;
    } else {
        # Use client information from invoice (for generic invoices)
        if ($invoice->client_name) {
            $text->translate($col2_x, $right_y);
            $text->text(encode('UTF-8', $invoice->client_name));
            $right_y -= 12;
        }

        if ($invoice->client_cui) {
            $text->translate($col2_x, $right_y);
            $text->text(encode('UTF-8', "C.I.F.: " . $invoice->client_cui));
            $right_y -= 12;
        }

        if ($invoice->client_address) {
            $text->translate($col2_x, $right_y);
            $text->text(encode('UTF-8', "Adresa: " . $invoice->client_address));
            $right_y -= 12;
        }
    }

    # Note: Tenants typically don't have bank info in the current schema
    # This section is reserved for future use if bank info is added to tenants

    # Move y to the lower of the two columns
    $y = ($left_y < $right_y) ? $left_y : $right_y;
    $y -= 25;

    # Exchange Rate (for rent invoices) - optional
    if ($invoice->invoice_type eq 'rent' && $invoice->exchange_rate) {
        $text->font($font_italic, 8);
        $text->translate($margin, $y);
        my $rate_formatted = $self->_format_number_romanian($invoice->exchange_rate, 4);
        my $rate_date = $self->_format_date_romanian($invoice->exchange_rate_date);
        $text->text(encode('UTF-8', "Curs valutar EUR/RON: $rate_formatted (Data: $rate_date)"));
        $y -= 20;
    }

    # Line Items Table with Romanian headers
    my $table_data = [
        ['Nr.', 'Descriere', 'Cant.', 'Pret (RON)', 'TVA %', 'Total (RON)'],
    ];

    my $row_num = 1;
    foreach my $item (sort { $a->sort_order <=> $b->sort_order } $invoice->items->all) {
        push @$table_data, [
            $row_num++,
            encode('UTF-8', $item->description),
            $self->_format_number_romanian($item->quantity, 2),
            $self->_format_number_romanian($item->unit_price, 2),
            $self->_format_number_romanian($item->vat_rate, 2),
            $self->_format_number_romanian($item->total, 2),
        ];
    }

    # Create table
    my $pdftable = PDF::Table->new();
    my $table_y = $pdftable->table(
        $pdf,
        $page,
        $table_data,
        x => $margin,
        w => $page_width - (2 * $margin),
        start_y => $y,
        next_y => 200,
        start_h => $y - 200,
        next_h => $page_height - 200,
        padding => 5,
        border => 1,
        border_color => '#000000',
        font => $font_regular,
        font_size => 9,
        header_props => {
            font => $font_bold,
            font_size => 10,
            bg_color => '#CCCCCC',
            repeat => 1,
        },
        column_props => [
            { min_w => 30 },   # Nr
            { min_w => 200 },  # Descriere
            { min_w => 50 },   # Cant.
            { min_w => 80 },   # Pret
            { min_w => 50 },   # TVA
            { min_w => 80 },   # Total
        ],
    );

    $y = $table_y - 20;

    # Totals with Romanian formatting
    my $totals_x = $page_width - $margin - 200;

    $text->font($font_bold, 11);
    $text->translate($totals_x, $y);
    my $subtotal_formatted = $self->_format_number_romanian($invoice->subtotal_ron, 2);
    $text->text(encode('UTF-8', "Subtotal: $subtotal_formatted RON"));
    $y -= 18;

    if ($invoice->vat_amount > 0) {
        $text->translate($totals_x, $y);
        my $vat_formatted = $self->_format_number_romanian($invoice->vat_amount, 2);
        $text->text(encode('UTF-8', "TVA: $vat_formatted RON"));
        $y -= 18;
    }

    $text->font($font_bold, 13);
    $text->translate($totals_x, $y);
    my $total_formatted = $self->_format_number_romanian($invoice->total_ron, 2);
    $text->text(encode('UTF-8', "TOTAL: $total_formatted RON"));

    # Footer section with expedition/delegate information
    $y = $margin + 120;

    # Draw a separator line
    $gfx->strokecolor('black');
    $gfx->move($margin, $y);
    $gfx->line($page_width - $margin, $y);
    $gfx->stroke();
    $y -= 15;

    # Expedition section header
    $text->font($font_bold, 10);
    $text->translate($margin, $y);
    $text->text(encode('UTF-8', "EXPEDITIA"));
    $y -= 15;

    # Delegate information from user profile
    $text->font($font_regular, 9);

    # Delegate name
    if ($user && $user->full_name) {
        $text->translate($margin, $y);
        $text->text(encode('UTF-8', "Numele delegatului: " . $user->full_name));
        $y -= 12;
    }

    # ID card information
    if ($user && $user->id_card_series && $user->id_card_number) {
        $text->translate($margin, $y);
        my $id_card = "C.I.: Seria " . $user->id_card_series . " nr. " . $user->id_card_number;
        $text->text(encode('UTF-8', $id_card));
        $y -= 12;
    }

    # Issued by
    if ($user && $user->id_card_issued_by) {
        $text->translate($margin, $y);
        $text->text(encode('UTF-8', "Eliberat: " . $user->id_card_issued_by));
        $y -= 12;
    }

    $y -= 3;  # Small spacing adjustment

    # Legal notice
    $text->font($font_italic, 8);
    $text->translate($margin, $y);
    $text->text(encode('UTF-8', "Factura circula fara semnatura si stampila conform Cod Fiscal art.319 din Legea nr.227/2015."));
    $y -= 15;

    # Due date if available
    if ($invoice->due_date) {
        $text->font($font_regular, 8);
        $text->translate($margin, $y);
        my $due_date_formatted = $self->_format_date_romanian($invoice->due_date);
        $text->text(encode('UTF-8', "Scadenta: $due_date_formatted"));
        $y -= 12;
    }

    # Notes if available
    if ($invoice->notes) {
        $text->font($font_italic, 8);
        $text->translate($margin, $y);
        $text->text(encode('UTF-8', "Note: " . $invoice->notes));
    }

    # Add utility breakdown page for utility invoices
    if ($invoice->invoice_type eq 'utility' && $invoice->calculation_id) {
        $self->_add_utility_breakdown_page($pdf, $invoice, $company, $tenant);
    }

    # Generate PDF binary
    my $pdf_data = $pdf->to_string();

    return $pdf_data;
}

=head2 _add_utility_breakdown_page

Add a second page to utility invoices showing the detailed breakdown of utility costs.

=cut

sub _add_utility_breakdown_page {
    my ($self, $pdf, $invoice, $company, $tenant) = @_;

    # Get calculation
    my $calculation = $self->{schema}->resultset('UtilityCalculation')->find($invoice->calculation_id);
    return unless $calculation;

    # Get calculation details for this tenant
    my @details = $self->{schema}->resultset('UtilityCalculationDetail')->search(
        {
            calculation_id => $calculation->id,
            tenant_id => $tenant->id,
        },
        {
            prefetch => 'received_invoice',
        }
    )->all;

    return unless @details;

    # Create new page
    my $page = $pdf->page();

    my $text = $page->text();
    my $gfx = $page->gfx();

    # Fonts
    my $font_bold = $pdf->font('Helvetica-Bold');
    my $font_regular = $pdf->font('Helvetica');

    # Page dimensions
    my $page_width = 595;
    my $page_height = 842;
    my $margin = 50;
    my $y = $page_height - $margin;

    # Company header
    $text->font($font_bold, 12);
    $text->fillcolor('black');
    $text->translate($margin, $y);
    $text->text(encode('UTF-8', $company->name));
    $y -= 15;

    $text->font($font_regular, 10);
    $text->translate($margin, $y);
    $text->text(encode('UTF-8', "C.I.F.: " . $company->cui_cif));
    $y -= 12;

    my $company_address = join(", ",
        grep { defined $_ && $_ ne '' }
        ($company->address, $company->city, $company->county)
    );
    $text->translate($margin, $y);
    $text->text(encode('UTF-8', $company_address));
    $y -= 30;

    # CATRE section (centered)
    $text->font($font_bold, 11);
    my $catre_x = ($page_width - $margin * 2) / 2 + $margin;
    $text->translate($catre_x - 20, $y);
    $text->text(encode('UTF-8', "CATRE"));
    $y -= 20;

    # Tenant name (centered, indented)
    $text->font($font_regular, 11);
    $text->translate($catre_x + 50, $y);
    $text->text(encode('UTF-8', $tenant->name));
    $y -= 40;

    # Title: UTILITATI - LUNA [month year]
    my $period_month = $calculation->period_month;
    my $period_year = $calculation->period_year;
    my $month_name = $ROMANIAN_MONTHS[$period_month - 1];

    $text->font($font_bold, 14);
    $text->translate($margin, $y);
    $text->text(encode('UTF-8', "UTILITATI - LUNA $month_name $period_year"));
    $y -= 30;

    # Build table data
    my $table_data = [
        ['Nr.', 'Denumire Furnizor', 'Factura', 'Data', 'Suma', 'Cota', 'Observatii'],
    ];

    my $row_num = 1;
    foreach my $detail (@details) {
        my $received_invoice = $detail->received_invoice;
        next unless $received_invoice;

        # Get utility provider name
        my $provider = $received_invoice->provider;
        my $provider_name = $provider ? $provider->name : 'N/A';

        # Calculate tenant share
        my $invoice_amount = $received_invoice->amount;
        my $percentage = $detail->percentage;
        my $tenant_share = $detail->amount;

        push @$table_data, [
            $row_num++,
            encode('UTF-8', $provider_name),
            encode('UTF-8', $received_invoice->invoice_number),
            $self->_format_date_romanian($received_invoice->invoice_date),
            $self->_format_number_romanian($invoice_amount, 2),
            $self->_format_number_romanian($tenant_share, 2),
            $self->_format_number_romanian($percentage, 2) . '%',
        ];
    }

    # Create table
    my $pdftable = PDF::Table->new();
    my $table_y = $pdftable->table(
        $pdf,
        $page,
        $table_data,
        x => $margin,
        w => $page_width - (2 * $margin),
        start_y => $y,
        next_y => 200,
        start_h => $y - 200,
        next_h => $page_height - 200,
        padding => 4,
        border => 1,
        border_color => '#000000',
        font => $font_regular,
        font_size => 9,
        header_props => {
            font => $font_bold,
            font_size => 9,
            bg_color => '#CCCCCC',
            repeat => 1,
        },
        column_props => [
            { min_w => 25 },    # Nr
            { min_w => 120 },   # Denumire Furnizor
            { min_w => 70 },    # Factura
            { min_w => 60 },    # Data
            { min_w => 60 },    # Suma
            { min_w => 60 },    # Cota
            { min_w => 60 },    # Observatii
        ],
    );

    # Administrator signature section at bottom
    $y = $margin + 80;

    $text->font($font_bold, 11);
    my $sig_x = $page_width - $margin - 150;
    $text->translate($sig_x, $y);
    $text->text(encode('UTF-8', "ADMINISTRATOR,"));
    $y -= 20;

    $text->font($font_regular, 11);
    $text->translate($sig_x, $y);
    $text->text(encode('UTF-8', $company->representative_name || $company->name));
}

=head2 generate_invoice_pdf_html

Generate PDF for an invoice using HTML templates and wkhtmltopdf.
Returns PDF binary data with proper Romanian character support.

Parameters:
- $invoice_id: Invoice ID (required)
- %options: Optional parameters
  - user: User object for delegate information

=cut

sub generate_invoice_pdf_html {
    my ($self, $invoice_id, %options) = @_;

    die "invoice_id is required" unless $invoice_id;

    # Load invoice with all relationships
    my $invoice = $self->{schema}->resultset('Invoice')->find(
        $invoice_id,
        {
            prefetch => ['tenant', 'items'],
        }
    ) or die "Invoice not found";

    # Load company
    my $company = $self->{schema}->resultset('Company')->search()->first
        or die "Company information not found";

    # Load user for delegate information
    my $user = $options{user};
    unless ($user) {
        $user = $self->{schema}->resultset('User')->search(
            {},
            { rows => 1 }
        )->first;
    }

    # Prepare template variables
    my $tenant = $invoice->tenant;

    # Get items and format them
    my @items;
    foreach my $item (sort { $a->sort_order <=> $b->sort_order } $invoice->items->all) {
        push @items, {
            description => $item->description,
            quantity => $item->quantity,
            unit_price => $item->unit_price,
            vat_rate => $item->vat_rate,
            total => $item->total,
            formatted_unit_price => $self->_format_number_romanian($item->unit_price, 2) . ' RON',
            formatted_total => $self->_format_number_romanian($item->total, 2) . ' RON',
        };
    }

    # Build template variables
    my $vars = {
        invoice => {
            invoice_number => $invoice->invoice_number,
            invoice_type => $invoice->invoice_type,
            invoice_date => $invoice->invoice_date,
            due_date => $invoice->due_date,
            exchange_rate => $invoice->exchange_rate,
            exchange_rate_date => $invoice->exchange_rate_date,
            subtotal_ron => $invoice->subtotal_ron,
            vat_amount => $invoice->vat_amount,
            total_ron => $invoice->total_ron,
            is_paid => $invoice->is_paid,
            notes => $invoice->notes,
            client_name => $invoice->client_name,
            client_address => $invoice->client_address,
            client_cui => $invoice->client_cui,
        },
        company => {
            name => $company->name,
            j_number => $company->j_number,
            cui_cif => $company->cui_cif,
            address => $company->address,
            city => $company->city,
            county => $company->county,
            phone => $company->phone,
            bank_name => $company->bank_name,
            iban => $company->iban,
        },
        tenant => $tenant ? {
            name => $tenant->name,
            j_number => $tenant->j_number,
            cui_cnp => $tenant->cui_cnp,
            address => $tenant->address,
            city => $tenant->city,
            phone => $tenant->phone,
            email => $tenant->email,
        } : undef,
        user => $user ? {
            full_name => $user->full_name,
            id_card_series => $user->id_card_series,
            id_card_number => $user->id_card_number,
            id_card_issued_by => $user->id_card_issued_by,
        } : undef,
        items => \@items,
        formatted => {
            invoice_date => $self->_format_date_romanian($invoice->invoice_date),
            due_date => $self->_format_date_romanian($invoice->due_date),
            exchange_rate => $invoice->exchange_rate ? $self->_format_number_romanian($invoice->exchange_rate, 4) : undef,
            exchange_rate_date => $invoice->exchange_rate_date ? $self->_format_date_romanian($invoice->exchange_rate_date) : undef,
            subtotal => $self->_format_number_romanian($invoice->subtotal_ron, 2),
            vat => $self->_format_number_romanian($invoice->vat_amount, 2),
            total => $self->_format_number_romanian($invoice->total_ron, 2),
        },
    };

    # Add utility breakdown for utility invoices
    if ($invoice->invoice_type eq 'utility' && $invoice->calculation_id && $tenant) {
        my $calculation = $self->{schema}->resultset('UtilityCalculation')->find($invoice->calculation_id);
        if ($calculation) {
            my @details = $self->{schema}->resultset('UtilityCalculationDetail')->search(
                {
                    calculation_id => $calculation->id,
                    tenant_id => $tenant->id,
                },
                {
                    prefetch => 'received_invoice',
                }
            )->all;

            my @utility_details;
            foreach my $detail (@details) {
                my $received_invoice = $detail->received_invoice;
                next unless $received_invoice;

                my $provider = $received_invoice->provider;
                push @utility_details, {
                    provider_name => $provider ? $provider->name : 'N/A',
                    invoice_number => $received_invoice->invoice_number,
                    invoice_date => $self->_format_date_romanian($received_invoice->invoice_date),
                    total_amount => $self->_format_number_romanian($received_invoice->amount, 2),
                    tenant_amount => $self->_format_number_romanian($detail->amount, 2),
                    percentage => $self->_format_number_romanian($detail->percentage, 2),
                };
            }

            $vars->{utility_details} = \@utility_details;
            $vars->{period_month_name} = $ROMANIAN_MONTHS[$calculation->period_month - 1];
            $vars->{period_year} = $calculation->period_year;
        }
    }

    # Get template directory (relative to bin/ directory)
    my $template_dir = $self->{config}{app}{template_dir}
        || File::Spec->catdir($FindBin::Bin, '..', 'templates', 'pdf');

    # Initialize Template Toolkit
    my $tt = Template->new({
        INCLUDE_PATH => $template_dir,
        ENCODING => 'utf8',
        ABSOLUTE => 1,
    }) or die "Template error: " . Template->error();

    # Render HTML
    my $html;
    $tt->process('invoice.tt', $vars, \$html)
        or die "Template processing error: " . $tt->error();

    # Convert HTML to PDF using wkhtmltopdf
    my $pdf_data = $self->_html_to_pdf($html);

    return $pdf_data;
}

=head2 _html_to_pdf

Convert HTML content to PDF using wkhtmltopdf.

=cut

sub _html_to_pdf {
    my ($self, $html_content) = @_;

    # Write HTML to temporary file
    my ($html_fh, $html_file) = tempfile(
        SUFFIX => '.html',
        UNLINK => 1,
    );
    binmode($html_fh, ':utf8');
    print $html_fh $html_content;
    close $html_fh;

    # Convert to PDF using wkhtmltopdf
    my $pdf_data;
    my $stderr;

    my @cmd = (
        'wkhtmltopdf',
        '--encoding', 'UTF-8',
        '--page-size', 'A4',
        '--margin-top', '0',
        '--margin-bottom', '0',
        '--margin-left', '0',
        '--margin-right', '0',
        '--quiet',
        '--enable-local-file-access',
        '--disable-smart-shrinking',
        $html_file,
        '-',  # Output to STDOUT
    );

    run3 \@cmd, \undef, \$pdf_data, \$stderr;

    if ($? != 0) {
        die "wkhtmltopdf failed: $stderr";
    }

    return $pdf_data;
}

1;

__END__

=head1 DESCRIPTION

This service generates PDF invoices using PDF::API2 with full Romanian localization.

=head1 PDF LAYOUT

The generated PDF includes:

- Header with invoice number in white text on black background
- Issue date (Data emiterii) in Romanian DD.MM.YYYY format
- Two-column layout:
  - Left: Furnizor (Supplier) - Company information
  - Right: Client - Tenant information
- Company and tenant details including:
  - Name
  - Reg. Com. (J number)
  - C.I.F. (CUI/CIF)
  - Address
  - Bank name
  - IBAN
- Exchange rate for rent invoices (optional)
- Line items table with Romanian headers:
  - Nr. (Number)
  - Descriere (Description)
  - Cant. (Quantity)
  - Pret (RON) (Price)
  - TVA % (VAT %)
  - Total (RON)
- Subtotal, TVA, and Total with Romanian number formatting
- Footer with expedition/delegate information:
  - EXPEDITIA section
  - Delegate name: from user.full_name
  - ID card details: from user.id_card_series and user.id_card_number
  - Issued by: from user.id_card_issued_by
  - Legal notice about signature/stamp (Cod Fiscal art.319)
- Due date (Scadenta) if available
- Notes if available

=head1 ROMANIAN LOCALIZATION

=head2 Number Formatting

All numbers use Romanian format:
- Decimal separator: comma (,)
- Thousands separator: period (.)
- Example: 1.234,56 RON

=head2 Date Formatting

All dates use Romanian format DD.MM.YYYY
- Example: 23.12.2025

=head2 Romanian Labels

All labels are in Romanian:
- Factura (Invoice)
- Data emiterii (Issue date)
- Furnizor (Supplier)
- Client (Client)
- Reg. Com. (Commercial Registry)
- C.I.F. (Tax ID)
- Adresa (Address)
- Banca (Bank)
- Descriere (Description)
- Cant. (Quantity)
- Pret (Price)
- TVA (VAT)
- Subtotal (Subtotal)
- TOTAL (Total)
- EXPEDITIA (Expedition)
- Numele delegatului (Delegate name)
- C.I. (ID card)
- Eliberat (Issued by)
- Scadenta (Due date)
- Note (Notes)

=head1 INTERNATIONALIZATION

The PDF supports Romanian characters (ă, â, î, ș, ț) through UTF-8 encoding.
All text is properly encoded using Encode::encode('UTF-8', ...) to ensure
correct display of Romanian diacritics.

=head1 METHODS

=head2 new(%args)

Constructor. Requires 'schema' parameter (DBIx::Class schema object).

=head2 generate_invoice_pdf($invoice_id)

Generates a PDF invoice for the given invoice ID. Returns PDF binary data.

=head2 _format_number_romanian($number, $decimals)

Formats a number according to Romanian conventions:
- Uses comma (,) as decimal separator
- Uses period (.) as thousands separator
- Example: 1234.56 becomes "1.234,56"

Parameters:
- $number: The number to format
- $decimals: Number of decimal places (default: 2)

Returns: Formatted string

=head2 _format_date_romanian($date)

Formats a date to Romanian format DD.MM.YYYY

Parameters:
- $date: Date string (typically YYYY-MM-DD from database)

Returns: Formatted date string (DD.MM.YYYY)

=head1 AUTHOR

Property Management System

=cut
