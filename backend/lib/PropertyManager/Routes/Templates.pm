package PropertyManager::Routes::Templates;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth);

prefix '/api/templates';

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my @templates = schema->resultset('InvoiceTemplate')->search({}, { order_by => 'name' })->all;
    return { success => 1, data => [ map { { $_->get_columns } } @templates ] };
};

get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $template = schema->resultset('InvoiceTemplate')->find(route_parameters->get('id'));
    return { success => 0, error => 'Template not found' } unless $template;
    return { success => 1, data => { $template->get_columns } };
};

post '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $data = request->data;
    unless ($data->{name} && $data->{html_template}) {
        status 400;
        return { success => 0, error => 'name and html_template are required' };
    }

    my $template = schema->resultset('InvoiceTemplate')->create($data);
    return { success => 1, data => { $template->get_columns } };
};

put '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $template = schema->resultset('InvoiceTemplate')->find(route_parameters->get('id'));
    return { success => 0, error => 'Template not found' } unless $template;

    $template->update(request->data);
    return { success => 1, data => { $template->get_columns } };
};

del '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $template = schema->resultset('InvoiceTemplate')->find(route_parameters->get('id'));
    return { success => 0, error => 'Template not found' } unless $template;

    if ($template->is_default) {
        status 400;
        return { success => 0, error => 'Cannot delete default template' };
    }

    $template->delete;
    return { success => 1, message => 'Template deleted' };
};

post '/:id/set-default' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $template = schema->resultset('InvoiceTemplate')->find(route_parameters->get('id'));
    return { success => 0, error => 'Template not found' } unless $template;

    schema->txn_do(sub {
        schema->resultset('InvoiceTemplate')->update({ is_default => 0 });
        $template->update({ is_default => 1 });
    });

    return { success => 1, data => { $template->get_columns } };
};

1;
